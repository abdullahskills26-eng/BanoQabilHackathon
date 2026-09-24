import 'package:cloud_firestore/cloud_firestore.dart';

/// The two kinds of work an instructor can set.
class AssignmentType {
  AssignmentType._();

  static const String assignment = 'Assignment';
  static const String quiz = 'Quiz';

  static const List<String> all = [assignment, quiz];
}

/// An assignment or quiz. Firestore collection: `assignments`.
class AssignmentModel {
  final String assignmentId;
  final String batchId;
  final String title;
  final String type; // 'Assignment' | 'Quiz'
  final String instructions;
  final int maxMarks;
  final DateTime? dueDate;
  final DateTime? createdAt;

  const AssignmentModel({
    required this.assignmentId,
    required this.batchId,
    required this.title,
    required this.instructions,
    required this.maxMarks,
    this.type = AssignmentType.assignment,
    this.dueDate,
    this.createdAt,
  });

  factory AssignmentModel.fromMap(Map<String, dynamic> map, String id) {
    return AssignmentModel(
      assignmentId: id,
      batchId: (map['batchId'] ?? '').toString(),
      title: (map['title'] ?? 'Untitled assignment').toString(),
      type: (map['type'] ?? AssignmentType.assignment).toString(),
      instructions: (map['instructions'] ?? '').toString(),
      maxMarks:
          int.tryParse('${map['maxMarks'] ?? map['maximumMarks'] ?? 0}') ?? 0,
      dueDate: _parseDate(map['dueDate']),
      createdAt: _parseDate(map['createdAt']),
    );
  }

  factory AssignmentModel.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      AssignmentModel.fromMap(doc.data() ?? {}, doc.id);

  static DateTime? _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  Map<String, dynamic> toMap() => {
        'batchId': batchId,
        'title': title,
        'type': type,
        'instructions': instructions,
        'maxMarks': maxMarks,
        'maximumMarks': maxMarks,
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
        'createdAt': FieldValue.serverTimestamp(),
      };

  bool get isQuiz => type == AssignmentType.quiz;

  bool get isOverdue =>
      dueDate != null && DateTime.now().isAfter(dueDate!);

  String get formattedDueDate {
    final d = dueDate;
    if (d == null) return 'No due date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

/// Instructor-facing assignment. Shape matches `GET /api/v1/assignments`
/// on the FastAPI backend — unrelated to the Firestore model above.
class Assignment {
  final int id;
  final String title;
  final String dueDate;
  final int maxMarks;
  final int submissionsCount;

  Assignment({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.maxMarks,
    required this.submissionsCount,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      dueDate: json['due_date']?.toString() ?? '',
      maxMarks: json['max_marks'] ?? 0,
      submissionsCount: json['submissions_count'] ?? 0,
    );
  }
}
