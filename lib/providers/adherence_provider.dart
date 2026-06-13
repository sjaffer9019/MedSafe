import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class AdherenceProvider with ChangeNotifier {
  final SupabaseService _svc = SupabaseService.instance;

  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _last7Days = [];
  bool _hasRecordedToday = false;
  int _todayStatus = -1; // -1 = not recorded, 0 = missed, 1 = taken

  double get overallAdherence {
    if (_records.isEmpty) return 0.0;
    final taken = _records.where((r) => r['status'] == 1).length;
    return (taken / _records.length) * 100;
  }

  double get weeklyAdherence {
    if (_last7Days.isEmpty) return 0.0;
    final taken = _last7Days.where((r) => r['status'] == 1).length;
    return (taken / _last7Days.length) * 100;
  }

  bool get hasRecordedToday => _hasRecordedToday;
  int get todayStatus => _todayStatus;
  List<Map<String, dynamic>> get last7DaysRecords => List.unmodifiable(_last7Days);

  Future<void> loadAdherence() async {
    try {
      _records = await _svc.getAdherenceRaw();
      _last7Days = await _svc.getAdherenceLast7Days();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayRecord = _records.firstWhere(
        (r) => r['date'] == today,
        orElse: () => {},
      );
      _hasRecordedToday = todayRecord.isNotEmpty;
      _todayStatus = todayRecord.isNotEmpty ? (todayRecord['status'] as int) : -1;

      // Auto-alert: low adherence
      if (overallAdherence > 0 && overallAdherence < 70) {
        final hasRecentAlert = _records.isEmpty; // simplified
        if (!hasRecentAlert) {
          await _svc.insertAlert(
            message: 'Adherence is below 70%. Please take your medicines regularly.',
            severity: 'Medium',
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading adherence: $e');
    }
  }

  Future<void> recordTodayAdherence(int status) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await _svc.upsertAdherence(today, status);

      // Check 2 consecutive missed days
      if (status == 0 && _last7Days.length >= 2) {
        final sorted = [..._last7Days]..sort((a, b) => b['date'].compareTo(a['date']));
        if (sorted[0]['status'] == 0 && sorted[1]['status'] == 0) {
          await _svc.insertAlert(
            message: 'You have missed your medications for 2 consecutive days.',
            severity: 'High',
          );
        }
      }
      await loadAdherence();
    } catch (e) {
      debugPrint('Error recording adherence: $e');
      rethrow;
    }
  }
}
