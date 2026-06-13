import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/medicine_model.dart';
import '../models/medicine_dose_model.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

/// Timer-based scheduler that checks medicine schedules every 60 seconds.
/// Creates dose records + reminder alerts for any dose that is due today.
/// Auto-marks expired pending doses as missed after 12 hours.
class DoseSchedulerService {
  static final DoseSchedulerService instance = DoseSchedulerService._();
  DoseSchedulerService._();

  Timer? _timer;
  final SupabaseService _svc = SupabaseService.instance;
  VoidCallback? onDosesUpdated;

  /// Start the periodic scheduler.
  void start({VoidCallback? onUpdate}) {
    onDosesUpdated = onUpdate;
    // Run immediately on start
    _tick();
    // Then every 60 seconds
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  /// Stop the scheduler.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    try {
      // 1. Auto-miss any expired pending doses (12h past)
      await _svc.autoMissExpiredDoses();

      // 2. Create dose records + alerts for ALL due doses today
      await _createDosesForToday();

      // 3. Notify listeners to refresh UI
      onDosesUpdated?.call();
    } catch (e) {
      debugPrint('DoseScheduler tick error: $e');
    }
  }

  /// Creates dose records and alerts for every medicine time
  /// that is at or before the current time TODAY.
  Future<void> _createDosesForToday() async {
    try {
      final medicines = await _svc.getMedicines();
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final currentMinutes = now.hour * 60 + now.minute;

      // Pre-fetch today's doses so we know which already exist & their status
      final todayDoses = await _svc.getTodayDoses();
      // Pre-fetch all alerts to check for existing reminders
      final existingAlerts = await _svc.getAlerts();

      for (final med in medicines) {
        if (med.isPaused) continue; // Skip paused medicines
        if (!_isMedicineActiveToday(med, today)) continue;
        if (med.id == null) continue;

        for (final timeStr in med.times) {
          final parts = timeStr.split(':');
          if (parts.length < 2) continue;
          final schedHour = int.tryParse(parts[0]) ?? -1;
          final schedMinute = int.tryParse(parts[1]) ?? -1;
          if (schedHour < 0) continue;

          final schedMinutesTotal = schedHour * 60 + schedMinute;

          // Only for times that have already passed today
          if (currentMinutes >= schedMinutesTotal) {
            // Check if dose already exists for this medicine+date+time
            final existingDose = todayDoses.where((d) =>
                d.medicineId == med.id &&
                d.scheduledTime == timeStr).toList();

            if (existingDose.isNotEmpty) {
              // Dose exists — only create alert if dose is still PENDING
              // and no reminder alert exists for it yet
              final dose = existingDose.first;
              if (dose.isPending) {
                final hasAlert = existingAlerts.any(
                  (a) => a.doseId == dose.id && a.alertType == 'reminder',
                );
                if (!hasAlert) {
                  await _createAlertForDose(med, timeStr, dose.id!);
                }
              }
              // If dose is already taken/missed, skip — don't create new alert
            } else {
              // No dose exists yet — create dose + alert
              await _createDoseAndAlert(med, today, timeStr);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error creating today doses: $e');
    }
  }

  bool _isMedicineActiveToday(Medicine med, String today) {
    try {
      final start = DateTime.parse(med.startDate);
      final end = DateTime.parse(med.endDate);
      final todayDate = DateTime.parse(today);
      return !todayDate.isBefore(DateTime(start.year, start.month, start.day)) &&
          !todayDate.isAfter(DateTime(end.year, end.month, end.day));
    } catch (_) {
      return true;
    }
  }

  Future<void> _createDoseAndAlert(
      Medicine med, String date, String time) async {
    try {
      final doseId = await _svc.createDoseRecord(
        medicineId: med.id!,
        scheduledDate: date,
        scheduledTime: time,
      );
      await _createAlertForDose(med, time, doseId);
    } catch (e) {
      debugPrint('Error creating dose for ${med.name} at $time: $e');
    }
  }

  Future<void> _createAlertForDose(
      Medicine med, String time, int doseId) async {
    try {
      final expiresAt =
          DateTime.now().toUtc().add(const Duration(hours: 12));
      await _svc.insertReminderAlert(
        medicineId: med.id!,
        medicineName: med.name,
        doseTime: time,
        doseId: doseId,
        expiresAt: expiresAt,
      );
      debugPrint('✅ Created dose alert for ${med.name} at $time');

      // 🔔 Fire an immediate push notification on the device
      final notifId = med.id.hashCode ^ time.hashCode;
      await NotificationService().showReminderNotification(
        id: notifId,
        medicineName: med.name,
        dosage: med.dosage,
        time: time,
      );
    } catch (e) {
      debugPrint('Error creating alert for ${med.name}: $e');
    }
  }

  /// Force a manual check (e.g., on app resume or pull-to-refresh).
  Future<void> forceCheck() async {
    await _tick();
  }
}
