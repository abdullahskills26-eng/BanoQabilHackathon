import 'package:cloud_firestore/cloud_firestore.dart';

/// Attendance marks. Firestore collection: `attendance`.
class AttendanceStatusValues {
  AttendanceStatusValues._();

  static const String present = 'Present';
  static const String absent = 'Absent';
  static const String leave = 'Leave';

  static const List<String> all = [present, absent, leave];

  /// Single-letter marker used in the monthly calendar (P / A / L).
  static String letter(String status) {
    switch (status) {
      case present:
        return 'P';
      case absent:
        return 'A';
      case leave:
        return 'L';
      default:
        return '-';
    }
  }
}

class AttendanceModel {
  final String attendanceId;
  final String batchId;
  final String uid;
  final DateTime date;
  final String status;

  const AttendanceModel({
    required this.attendanceId,
    required this.batchId,
    required this.uid,
    required this.date,
    required this.status,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      attendanceId: id,
      batchId: (map['batchId'] ?? '').toString(),
      uid: (map['uid'] ?? '').toString(),
      date: _parseDate(map['date']),
      status: (map['status'] ?? AttendanceStatusValues.absent).toString(),
    );
  }

  factory AttendanceModel.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      AttendanceModel.fromMap(doc.data() ?? {}, doc.id);

  /// Accepts a Firestore [Timestamp] or an ISO / yyyy-MM-dd string.
  static DateTime _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime(1970);
  }

  Map<String, dynamic> toMap() => {
        'batchId': batchId,
        'uid': uid,
        'date': Timestamp.fromDate(date),
        'status': status,
      };

  bool get isPresent => status == AttendanceStatusValues.present;
  bool get isAbsent => status == AttendanceStatusValues.absent;
  bool get isLeave => status == AttendanceStatusValues.leave;

  /// True when this record falls on the same calendar day as [other].
  bool isSameDay(DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;
}

/// Aggregate attendance figures for one student.
class AttendanceSummary {
  final int present;
  final int absent;
  final int leave;

  const AttendanceSummary({
    this.present = 0,
    this.absent = 0,
    this.leave = 0,
  });

  factory AttendanceSummary.fromRecords(List<AttendanceModel> records) {
    return AttendanceSummary(
      present: records.where((r) => r.isPresent).length,
      absent: records.where((r) => r.isAbsent).length,
      leave: records.where((r) => r.isLeave).length,
    );
  }

  int get total => present + absent + leave;

  /// Percentage of marked days attended. Leave counts as neither attended nor
  /// missed, so it is excluded from the denominator.
  double get percentage {
    final counted = present + absent;
    if (counted == 0) return 0;
    return (present / counted) * 100;
  }

  String get formattedPercentage => '${percentage.toStringAsFixed(0)}%';
}
