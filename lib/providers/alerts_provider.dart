import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../services/supabase_service.dart';

class AlertsProvider with ChangeNotifier {
  final SupabaseService _svc = SupabaseService.instance;
  List<Alert> _alerts = [];
  bool _isLoading = false;

  List<Alert> get alerts => List.unmodifiable(_alerts);
  bool get isLoading => _isLoading;

  /// Total alert count (all types).
  int get count => _alerts.length;

  /// Count of actionable reminder alerts (pending dose status only).
  int get pendingReminderCount =>
      _alerts.where((a) => a.isReminder && a.doseStatus == 'pending').length;

  /// Count that matters for the badge — only pending reminders + non-reminder alerts.
  int get badgeCount {
    int pending = _alerts.where((a) => a.isReminder && a.doseStatus == 'pending').length;
    int nonReminder = _alerts.where((a) => !a.isReminder).length;
    return pending + nonReminder;
  }

  Future<void> loadAlerts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _alerts = await _svc.getAlerts();
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Respond to a medicine reminder alert — mark dose as taken or missed.
  Future<void> respondToReminder(String alertId, int doseId, String status) async {
    try {
      // Update the dose record
      await _svc.updateDoseStatus(doseId, status);
      // Update the alert's dose_status
      await _svc.updateAlertDoseStatus(alertId, status);
      // Reload all alerts from DB to get fresh state
      await loadAlerts();
    } catch (e) {
      debugPrint('Error responding to reminder: $e');
      rethrow;
    }
  }

  Future<void> dismissAlert(String id) async {
    try {
      await _svc.deleteAlert(id);
      _alerts.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error dismissing alert: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await _svc.clearAlerts();
      _alerts.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing alerts: $e');
    }
  }
}
