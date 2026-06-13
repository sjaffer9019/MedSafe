import '../models/medicine_model.dart';

class InteractionService {
  // Static list of unsafe drug combinations
  static final List<Set<String>> _unsafeCombinations = [
    {'Aspirin', 'Warfarin'},
    {'Ibuprofen', 'Lisinopril'},
    {'Simvastatin', 'Amlodipine'},
    // Add more typical generic interactions if needed
  ];

  static bool hasInteraction(String newMedName, List<Medicine> currentMeds) {
    for (var med in currentMeds) {
      final pair = {newMedName.toLowerCase().trim(), med.name.toLowerCase().trim()};
      
      for (var unsafeCombo in _unsafeCombinations) {
        final lowerUnsafeCombo = unsafeCombo.map((e) => e.toLowerCase()).toSet();
        if (lowerUnsafeCombo.containsAll(pair)) {
          return true;
        }
      }
    }
    return false;
  }
}
