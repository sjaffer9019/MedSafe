class Adherence {
  final String id;
  final String date; // YYYY-MM-DD
  final int status; // 1 for taken, 0 for missed

  Adherence({
    required this.id,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'status': status,
    };
  }

  factory Adherence.fromMap(Map<String, dynamic> map) {
    return Adherence(
      id: map['id'],
      date: map['date'],
      status: map['status'],
    );
  }
}
