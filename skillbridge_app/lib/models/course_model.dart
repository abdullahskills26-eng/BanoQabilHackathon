import 'package:cloud_firestore/cloud_firestore.dart';

/// A course offered by Bano Qabil. Firestore collection: `courses`.
class CourseModel {
  final String courseId;
  final String title;
  final String description;
  final String level; // 'Beginner' | 'Intermediate'
  final String duration;
  final int seatsAvailable;
  final List<String> topics;

  const CourseModel({
    required this.courseId,
    required this.title,
    required this.description,
    required this.level,
    required this.duration,
    required this.seatsAvailable,
    this.topics = const [],
  });

  factory CourseModel.fromMap(Map<String, dynamic> map, String id) {
    return CourseModel(
      courseId: id,
      // `name` is what the seed writer uses; `title` is the spec field.
      title: (map['title'] ?? map['name'] ?? 'Untitled course').toString(),
      description: (map['description'] ?? '').toString(),
      level: (map['level'] ?? 'Beginner').toString(),
      duration: (map['duration'] ?? '').toString(),
      seatsAvailable:
          int.tryParse('${map['seatsAvailable'] ?? map['seats'] ?? 0}') ?? 0,
      topics: (map['topics'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  factory CourseModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      CourseModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'title': title,
        'name': title,
        'description': description,
        'level': level,
        'duration': duration,
        'seatsAvailable': seatsAvailable,
        'topics': topics,
      };

  bool get hasSeats => seatsAvailable > 0;
}
