import 'package:flutter/material.dart';
import '../models/medicine_dose_model.dart';
import '../services/supabase_service.dart';

class MedicineDoseProvider with ChangeNotifier {
  final SupabaseService _svc = SupabaseService.instance;

  List<MedicineDose> _todayDoses = [];
  List<MedicineDose> _last7DaysDoses = [];
  bool _isLoading = false;

  List<MedicineDose> get todayDoses => List.unmodifiable(_todayDoses);
  List<MedicineDose> get last7DaysDoses => List.unmodifiable(_last7DaysDoses);
  bool get isLoading => _isLoading;

  // ── Dashboard computed stats ──
  int get takenCount =>
      _todayDoses.where((d) => d.status == 'taken').length;
  int get missedCount =>
      _todayDoses.where((d) => d.status == 'missed').length;
  int get pendingCount =>
      _todayDoses.where((d) => d.status == 'pending').length;
  int get totalTodayDoses => _todayDoses.length;

  double get weeklyAdherence {
    if (_last7DaysDoses.isEmpty) return 0.0;
    final responded =
        _last7DaysDoses.where((d) => d.status != 'pending').length;
    if (responded == 0) return 0.0;
    final taken = _last7DaysDoses.where((d) => d.status == 'taken').length;
    return (taken / _last7DaysDoses.length) * 100;
  }

  double get overallAdherence {
    final total = _last7DaysDoses.length;
    if (total == 0) return 0.0;
    final taken = _last7DaysDoses.where((d) => d.status == 'taken').length;
    return (taken / total) * 100;
  }

  Future<void> loadTodayDoses() async {
    try {
      _todayDoses = await _svc.getTodayDoses();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading today doses: $e');
    }
  }

  Future<void> loadLast7DaysDoses() async {
    try {
      _last7DaysDoses = await _svc.getLast7DaysDoses();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading 7-day doses: $e');
    }
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([loadTodayDoses(), loadLast7DaysDoses()]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a specific dose as taken or missed.
  Future<void> markDose(int doseId, String status) async {
    try {
      await _svc.updateDoseStatus(doseId, status);
      await loadAll();
    } catch (e) {
      debugPrint('Error marking dose: $e');
      rethrow;
    }
  }

  /// Get dose history for a specific medicine (last 7 days).
  Future<List<MedicineDose>> getDosesForMedicine(int medicineId) async {
    try {
      return await _svc.getDosesForMedicine(medicineId, days: 7);
    } catch (e) {
      debugPrint('Error getting doses for medicine: $e');
      return [];
    }
  }
}
