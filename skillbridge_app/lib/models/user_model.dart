/// A student as returned by the instructor-facing roster endpoint.
///
/// Shape matches `GET /api/v1/students`.
class Student {
  final int id;
  final String name;
  final double attendancePercentage;
  final String status; // "Present" | "Absent"
  final bool isAtRisk;

  Student({
    required this.id,
    required this.name,
    required this.attendancePercentage,
    required this.status,
    required this.isAtRisk,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'] ?? 'Unknown',
      attendancePercentage:
          (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Absent',
      isAtRisk: json['is_at_risk'] ?? false,
    );
  }

  /// Returns a copy with [status] replaced — used for optimistic UI updates
  /// while an attendance write is in flight.
  Student copyWithStatus(String newStatus) => Student(
        id: id,
        name: name,
        attendancePercentage: attendancePercentage,
        status: newStatus,
        isAtRisk: isAtRisk,
      );
}
