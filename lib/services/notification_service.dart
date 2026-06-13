import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/medicine_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'medsafe_reminders';
  static const _channelName = 'Medication Reminders';
  static const _channelDesc = 'Alerts when it is time to take your medication';

  /// Call once at app startup.
  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Tapping the notification — can navigate to Alerts tab here if needed
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    // Request POST_NOTIFICATIONS permission on Android 13+
    await requestPermission();
  }

  /// Ask for notification permission (Android 13+ requires runtime prompt).
  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  /// Controlled by SettingsProvider
  static bool enabled = true;
  static bool soundOn = true;

  // ── Notification details ──────────────────────────────────────
  static NotificationDetails get _notifDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: soundOn,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    ),
  );

  // ── Immediate notification (fires right now) ──────────────────
  /// Called by DoseSchedulerService whenever a new reminder is created.
  /// Shows an instant push notification on the status bar.
  Future<void> showReminderNotification({
    required int id,
    required String medicineName,
    required String dosage,
    required String time,
  }) async {
    if (!enabled) return; // Notifications disabled by user
    try {
      await _plugin.show(
        id,
        '💊 Medication Reminder',
        'Time to take $medicineName ($dosage) — scheduled at $time',
        _notifDetails,
        payload: 'reminder_$id',
      );
      debugPrint('🔔 Push notification fired for $medicineName at $time');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  // ── Scheduled daily notification (fires at a future time) ─────
  /// Used when adding a new medicine — schedules a daily recurring reminder.
  Future<void> scheduleMedicineNotifications(Medicine medicine) async {
    for (final timeStr in medicine.times) {
      final parts = timeStr.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final notifId = (medicine.id ?? 0).hashCode ^ timeStr.hashCode;

      try {
        await _plugin.zonedSchedule(
          notifId,
          '💊 Medication Reminder',
          'Time to take ${medicine.name} (${medicine.dosage})',
          _nextInstanceOfTime(hour, minute),
          _notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        debugPrint(
            '📅 Scheduled daily notification for ${medicine.name} at $timeStr');
      } catch (e) {
        debugPrint('Error scheduling notification for ${medicine.name}: $e');
      }
    }
  }

  /// Cancel all scheduled notifications for a medicine.
  Future<void> cancelMedicineNotifications(Medicine medicine) async {
    for (final timeStr in medicine.times) {
      final notifId = (medicine.id ?? 0).hashCode ^ timeStr.hashCode;
      await _plugin.cancel(notifId);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
