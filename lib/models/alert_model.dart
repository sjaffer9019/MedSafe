class Alert {
  final String id;
  final String message;
  final String severity; // 'Low', 'Medium', 'High'
  final DateTime date;
  // ── New fields for medicine reminder alerts ──
  final int? medicineId;
  final String? medicineName;
  final String? doseTime;
  final String alertType; // 'reminder', 'warning', 'info'
  final int? doseId;
  final DateTime? expiresAt;
  final String doseStatus; // 'pending', 'taken', 'missed' (for reminders)

  Alert({
    required this.id,
    required this.message,
    required this.severity,
    required this.date,
    this.medicineId,
    this.medicineName,
    this.doseTime,
    this.alertType = 'info',
    this.doseId,
    this.expiresAt,
    this.doseStatus = 'pending',
  });

  bool get isReminder => alertType == 'reminder';
  bool get isDoseActionable => isReminder && doseStatus == 'pending';

  bool get isDoseExpired {
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(expiresAt!);
  }

  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'severity': severity,
      'date': date.toIso8601String(),
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'dose_time': doseTime,
      'alert_type': alertType,
      'dose_id': doseId,
      'expires_at': expiresAt?.toIso8601String(),
      'dose_status': doseStatus,
    };
  }

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'].toString(),
      message: map['message'] ?? '',
      severity: map['severity'] ?? 'Low',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      medicineId: map['medicine_id'] as int?,
      medicineName: map['medicine_name'] as String?,
      doseTime: map['dose_time'] as String?,
      alertType: (map['alert_type'] as String?) ?? 'info',
      doseId: map['dose_id'] as int?,
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
      doseStatus: (map['dose_status'] as String?) ?? 'pending',
    );
  }

  Alert copyWith({String? doseStatus}) {
    return Alert(
      id: id,
      message: message,
      severity: severity,
      date: date,
      medicineId: medicineId,
      medicineName: medicineName,
      doseTime: doseTime,
      alertType: alertType,
      doseId: doseId,
      expiresAt: expiresAt,
      doseStatus: doseStatus ?? this.doseStatus,
    );
  }
}
