import 'package:cloud_firestore/cloud_firestore.dart';

/// Instructor-side attendance statuses. Wider than the student view, which
/// records Present / Absent / Leave — instructors mark Late instead of Leave.
class InstructorAttendanceStatus {
  InstructorAttendanceStatus._();

  static const String present = 'Present';
  static const String absent = 'Absent';
  static const String late = 'Late';

  static const List<String> all = [present, absent, late];

  static String letter(String status) {
    switch (status) {
      case present:
        return 'P';
      case absent:
        return 'A';
      case late:
        return 'L';
      default:
        return '-';
    }
  }

  /// Cycles Present → Absent → Late → Present for one-tap marking.
  static String next(String current) {
    switch (current) {
      case present:
        return absent;
      case absent:
        return late;
      default:
        return present;
    }
  }
}

/// One day's attendance for a whole batch, stored as a `{uid: status}` map.
/// Firestore collection: `attendance`.
///
/// The student screens read per-student `attendance` documents; this batch
/// form is written alongside them by [FirebaseService.saveBatchAttendance],
/// which fans the map out into individual records too.
class AttendanceRecordModel {
  final String attendanceId;
  final String batchId;
  final DateTime date;
  final Map<String, String> statusMap;
  final DateTime? timestamp;

  const AttendanceRecordModel({
    required this.attendanceId,
    required this.batchId,
    required this.date,
    this.statusMap = const {},
    this.timestamp,
  });

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['statusMap'];
    return AttendanceRecordModel(
      attendanceId: id,
      batchId: (map['batchId'] ?? '').toString(),
      date: _parseDate(map['date']) ?? DateTime(1970),
      statusMap: raw is Map
          ? raw.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      timestamp: _parseDate(map['timestamp']),
    );
  }

  factory AttendanceRecordModel.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      AttendanceRecordModel.fromMap(doc.data() ?? {}, doc.id);

  static DateTime? _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  Map<String, dynamic> toMap() => {
        'batchId': batchId,
        'date': Timestamp.fromDate(date),
        'statusMap': statusMap,
        'timestamp': FieldValue.serverTimestamp(),
      };

  /// `yyyy-MM-dd`, also used as the document id suffix so one batch has at
  /// most one record per day.
  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int get presentCount => statusMap.values
      .where((s) => s == InstructorAttendanceStatus.present)
      .length;
  int get absentCount => statusMap.values
      .where((s) => s == InstructorAttendanceStatus.absent)
      .length;
  int get lateCount =>
      statusMap.values.where((s) => s == InstructorAttendanceStatus.late).length;
}
