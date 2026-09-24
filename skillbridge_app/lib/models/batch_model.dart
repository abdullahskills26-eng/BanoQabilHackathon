import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle states for a batch.
class BatchStatus {
  BatchStatus._();

  static const String active = 'Active';
  static const String closed = 'Closed';

  static const List<String> all = [active, closed];

  /// Earlier data used 'Open'; treat it as Active.
  static String normalise(Object? raw) {
    final v = (raw ?? active).toString();
    if (v.toLowerCase() == 'open') return active;
    if (v.toLowerCase() == 'closed') return closed;
    return v.isEmpty ? active : v;
  }
}

/// A cohort of students taking one course at one campus.
/// Firestore collection: `batches`.
class BatchModel {
  final String batchId;
  final String courseId;
  final String courseName;
  final String campusId;
  final String campusName;

  /// Human-readable code, e.g. `FL-2026-01`.
  final String batchCode;
  final String instructorId;
  final String instructorName;
  final int seats;
  final String startDate;
  final List<String> studentUids;
  final String status;
  final String room;
  final String classTime;

  const BatchModel({
    required this.batchId,
    this.courseId = '',
    this.courseName = '',
    this.campusId = '',
    this.campusName = '',
    this.batchCode = '',
    this.instructorId = '',
    this.instructorName = '',
    this.seats = 0,
    this.startDate = '',
    this.studentUids = const [],
    this.status = 'Open',
    this.room = 'Lab 2',
    this.classTime = '10:00 AM – 1:00 PM',
  });

  factory BatchModel.fromMap(Map<String, dynamic> map, String id) {
    return BatchModel(
      batchId: id,
      courseId: (map['courseId'] ?? '').toString(),
      courseName: (map['courseName'] ?? '').toString(),
      campusId: (map['campusId'] ?? '').toString(),
      campusName: (map['campusName'] ?? map['campus'] ?? '').toString(),
      // Seed data stores the code in `batchId`; fall back to the doc id.
      batchCode: (map['batchCode'] ?? map['batchId'] ?? id).toString(),
      instructorId: (map['instructorId'] ?? '').toString(),
      instructorName: (map['instructorName'] ?? '').toString(),
      seats: int.tryParse('${map['maxSeats'] ?? map['seats'] ?? 0}') ?? 0,
      startDate: (map['startDate'] ?? '').toString(),
      studentUids: (map['studentUids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: BatchStatus.normalise(map['status']),
      room: (map['room'] ?? 'Lab 2').toString(),
      classTime: (map['classTime'] ?? '10:00 AM – 1:00 PM').toString(),
    );
  }

  factory BatchModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      BatchModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'courseId': courseId,
        'courseName': courseName,
        'campusId': campusId,
        'campusName': campusName,
        'campus': campusName,
        'batchCode': batchCode,
        'batchId': batchCode,
        'instructorId': instructorId,
        'instructorName': instructorName,
        'maxSeats': seats,
        'seats': seats,
        'startDate': startDate,
        'studentUids': studentUids,
        'status': status,
        'room': room,
        'classTime': classTime,
      };

  /// Spec name for [seats].
  int get maxSeats => seats;

  int get enrolledCount => studentUids.length;
  int get seatsRemaining =>
      (seats - enrolledCount) < 0 ? 0 : seats - enrolledCount;

  bool get isActive => status == BatchStatus.active;

  /// Retained for existing call sites; equivalent to [isActive].
  bool get isOpen => isActive;

  BatchModel copyWith({String? status, String? instructorId,
      String? instructorName}) =>
      BatchModel(
        batchId: batchId,
        courseId: courseId,
        courseName: courseName,
        campusId: campusId,
        campusName: campusName,
        batchCode: batchCode,
        instructorId: instructorId ?? this.instructorId,
        instructorName: instructorName ?? this.instructorName,
        seats: seats,
        startDate: startDate,
        studentUids: studentUids,
        status: status ?? this.status,
        room: room,
        classTime: classTime,
      );

  /// Display label, preferring the code over the raw document id.
  String get label => batchCode.isEmpty ? batchId : batchCode;
}
