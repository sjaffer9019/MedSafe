import 'dart:convert';

class Medicine {
  final int? id;
  final String name;
  final String type;
  final String dosage;
  final String frequency;
  final List<String> times;
  final String startDate;
  final String endDate;
  final String notes;

  Medicine({
    this.id,
    required this.name,
    this.type = 'Tablet',
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.startDate,
    required this.endDate,
    this.notes = '',
  });

  // For legacy SQLite compatibility (kept but unused after Supabase migration)
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'dosage': dosage,
        'frequency': frequency,
        'times': jsonEncode(times),
        'startDate': startDate,
        'endDate': endDate,
        'notes': notes,
      };

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
        id: map['id'],
        name: map['name'],
        type: map['type'] ?? 'Tablet',
        dosage: map['dosage'],
        frequency: map['frequency'],
        times: List<String>.from(jsonDecode(map['times'])),
        startDate: map['startDate'],
        endDate: map['endDate'],
        notes: (map['notes'] as String?) ?? '',
      );

  // ── Supabase (snake_case columns, JSONB times) ──
  factory Medicine.fromSupabase(Map<String, dynamic> map) => Medicine(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: (map['type'] as String?) ?? 'Tablet',
        dosage: map['dosage'] as String,
        frequency: map['frequency'] as String,
        times: List<String>.from(map['times'] ?? []),
        startDate: map['start_date'] as String,
        endDate: map['end_date'] as String,
        notes: (map['notes'] as String?) ?? '',
      );

  /// Whether the medicine is currently active (end date is today or later).
  bool get isActive {
    try {
      final end = DateTime.parse(endDate);
      final today = DateTime.now();
      return !end.isBefore(DateTime(today.year, today.month, today.day));
    } catch (_) {
      return true;
    }
  }

  /// Whether the medicine was explicitly paused (end date set to yesterday).
  bool get isPaused {
    if (isActive) return false;
    try {
      final end = DateTime.parse(endDate);
      final today = DateTime.now();
      final diff = DateTime(today.year, today.month, today.day)
          .difference(DateTime(end.year, end.month, end.day))
          .inDays;
      return diff <= 1; // Paused = ended yesterday or today-minus-1
    } catch (_) {
      return false;
    }
  }

  /// Whether the medicine course is completed (end date passed by >1 day).
  bool get isCompleted => !isActive && !isPaused;
}
