import 'package:cloud_firestore/cloud_firestore.dart';

/// Who a notice is aimed at.
class NoticeAudience {
  NoticeAudience._();

  static const String batch = 'batch';
  static const String campus = 'campus';

  static const List<String> all = [batch, campus];
}

/// A class or campus announcement. Firestore collection: `notices`.
class NoticeModel {
  final String noticeId;
  final String campusId;
  final String batchId;
  final String title;
  final String content;
  final String postedBy;
  final DateTime? createdAt;
  final String targetAudience;

  const NoticeModel({
    required this.noticeId,
    this.campusId = '',
    this.batchId = '',
    required this.title,
    required this.content,
    this.postedBy = '',
    this.createdAt,
    this.targetAudience = NoticeAudience.batch,
  });

  factory NoticeModel.fromMap(Map<String, dynamic> map, String id) {
    return NoticeModel(
      noticeId: id,
      campusId: (map['campusId'] ?? map['campus'] ?? '').toString(),
      batchId: (map['batchId'] ?? '').toString(),
      title: (map['title'] ?? 'Notice').toString(),
      // Coordinator screens write `body`; the spec field is `content`.
      content: (map['content'] ?? map['body'] ?? map['message'] ?? '')
          .toString(),
      postedBy: (map['postedBy'] ?? '').toString(),
      createdAt: _parseDate(map['createdAt']),
      targetAudience:
          (map['targetAudience'] ?? NoticeAudience.batch).toString(),
    );
  }

  factory NoticeModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      NoticeModel.fromMap(doc.data() ?? {}, doc.id);

  static DateTime? _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  Map<String, dynamic> toMap() => {
        'campusId': campusId,
        'campus': campusId,
        'batchId': batchId,
        'title': title,
        'content': content,
        'body': content,
        'postedBy': postedBy,
        'targetAudience': targetAudience,
        'createdAt': FieldValue.serverTimestamp(),
      };

  bool get isBatchNotice => targetAudience == NoticeAudience.batch;

  String get formattedCreatedAt {
    final d = createdAt;
    if (d == null) return 'Just now';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
