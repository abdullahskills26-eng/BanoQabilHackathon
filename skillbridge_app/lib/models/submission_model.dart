import 'package:cloud_firestore/cloud_firestore.dart';

/// The four states a submission can be in.
class SubmissionStatus {
  SubmissionStatus._();

  static const String pending = 'Pending';
  static const String submitted = 'Submitted';
  static const String late = 'Late';
  static const String marked = 'Marked';

  static const List<String> all = [pending, submitted, late, marked];
}

/// A student's submission for one assignment.
/// Firestore collection: `submissions`.
class SubmissionModel {
  final String submissionId;
  final String assignmentId;
  final String uid;
  final String textAnswer;
  final String fileUrl;
  final String fileName;
  final DateTime? submittedAt;
  final String status;
  final int? marks;
  final String feedback;

  const SubmissionModel({
    required this.submissionId,
    required this.assignmentId,
    required this.uid,
    this.textAnswer = '',
    this.fileUrl = '',
    this.fileName = '',
    this.submittedAt,
    this.status = SubmissionStatus.pending,
    this.marks,
    this.feedback = '',
  });

  factory SubmissionModel.fromMap(Map<String, dynamic> map, String id) {
    return SubmissionModel(
      submissionId: id,
      assignmentId: (map['assignmentId'] ?? '').toString(),
      uid: (map['uid'] ?? '').toString(),
      textAnswer: (map['textAnswer'] ?? '').toString(),
      fileUrl: (map['fileUrl'] ?? '').toString(),
      fileName: (map['fileName'] ?? '').toString(),
      submittedAt: _parseDate(map['submittedAt']),
      status: (map['status'] ?? SubmissionStatus.pending).toString(),
      marks: map['marks'] == null
          ? null
          : int.tryParse('${map['marks']}'),
      feedback: (map['feedback'] ?? '').toString(),
    );
  }

  factory SubmissionModel.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      SubmissionModel.fromMap(doc.data() ?? {}, doc.id);

  static DateTime? _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  Map<String, dynamic> toMap() => {
        'assignmentId': assignmentId,
        'uid': uid,
        'textAnswer': textAnswer,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'submittedAt': submittedAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(submittedAt!),
        'status': status,
        'marks': marks,
        'feedback': feedback,
      };

  bool get hasFile => fileUrl.isNotEmpty;
  bool get hasText => textAnswer.isNotEmpty;
  bool get hasFeedback => feedback.isNotEmpty;
  bool get isMarked => status == SubmissionStatus.marked;
  bool get isPending => status == SubmissionStatus.pending;

  String get formattedSubmittedAt {
    final d = submittedAt;
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Marks as a percentage of [maxMarks], or null when not yet graded.
  double? percentageOf(int maxMarks) {
    final m = marks;
    if (m == null || maxMarks <= 0) return null;
    return (m / maxMarks) * 100;
  }

  SubmissionModel copyWith({
    String? textAnswer,
    String? fileUrl,
    String? fileName,
    DateTime? submittedAt,
    String? status,
    int? marks,
    String? feedback,
  }) =>
      SubmissionModel(
        submissionId: submissionId,
        assignmentId: assignmentId,
        uid: uid,
        textAnswer: textAnswer ?? this.textAnswer,
        fileUrl: fileUrl ?? this.fileUrl,
        fileName: fileName ?? this.fileName,
        submittedAt: submittedAt ?? this.submittedAt,
        status: status ?? this.status,
        marks: marks ?? this.marks,
        feedback: feedback ?? this.feedback,
      );
}
