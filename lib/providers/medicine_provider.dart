import 'package:flutter/material.dart';
import '../models/medicine_model.dart';
import '../services/supabase_service.dart';
import '../services/interaction_service.dart';

class MedicineProvider with ChangeNotifier {
  final SupabaseService _svc = SupabaseService.instance;
  List<Medicine> _medicines = [];
  bool _isLoading = false;

  List<Medicine> get medicines => List.unmodifiable(_medicines);
  bool get isLoading => _isLoading;

  Future<void> loadMedicines() async {
    _isLoading = true;
    notifyListeners();
    try {
      _medicines = await _svc.getMedicines();
    } catch (e) {
      debugPrint('Error loading medicines: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMedicine(Medicine medicine) async {
    try {
      // Check interaction before saving
      final warning = InteractionService.hasInteraction(medicine.name, _medicines);
      
      final id = await _svc.insertMedicine(medicine);
      final saved = Medicine(
        id: id,
        name: medicine.name,
        dosage: medicine.dosage,
        frequency: medicine.frequency,
        times: medicine.times,
        startDate: medicine.startDate,
        endDate: medicine.endDate,
      );
      _medicines.insert(0, saved);

      if (warning) {
        await _svc.insertAlert(
          message:
              'Potential interaction: ${medicine.name} may interact with your current medications.',
          severity: 'High',
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding medicine: $e');
      rethrow;
    }
  }

  Future<void> removeMedicine(int id) async {
    try {
      await _svc.deleteMedicine(id);
      _medicines.removeWhere((m) => m.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing medicine: $e');
      rethrow;
    }
  }

  Future<void> updateMedicine(Medicine medicine) async {
    try {
      await _svc.updateMedicine(medicine);
      final idx = _medicines.indexWhere((m) => m.id == medicine.id);
      if (idx >= 0) {
        _medicines[idx] = medicine;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating medicine: $e');
      rethrow;
    }
  }
}
