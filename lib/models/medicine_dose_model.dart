class MedicineDose {
  final int? id;
  final int medicineId;
  final String scheduledDate; // YYYY-MM-DD
  final String scheduledTime; // HH:mm
  final String status; // 'pending', 'taken', 'missed'
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? respondedAt;

  MedicineDose({
    this.id,
    required this.medicineId,
    required this.scheduledDate,
    required this.scheduledTime,
    this.status = 'pending',
    this.createdAt,
    this.expiresAt,
    this.respondedAt,
  });

  factory MedicineDose.fromSupabase(Map<String, dynamic> map) {
    return MedicineDose(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      scheduledDate: map['scheduled_date'] as String,
      scheduledTime: map['scheduled_time'] as String,
      status: (map['status'] as String?) ?? 'pending',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
      respondedAt: map['responded_at'] != null
          ? DateTime.parse(map['responded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap(String userId) {
    return {
      'user_id': userId,
      'medicine_id': medicineId,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'status': status,
      'expires_at':
          DateTime.now().add(const Duration(hours: 12)).toUtc().toIso8601String(),
    };
  }

  MedicineDose copyWith({String? status, DateTime? respondedAt}) {
    return MedicineDose(
      id: id,
      medicineId: medicineId,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(expiresAt!);
  }

  bool get isPending => status == 'pending';
  bool get isTaken => status == 'taken';
  bool get isMissed => status == 'missed';
}
