import 'package:cloud_firestore/cloud_firestore.dart';

/// The six states an application can be in, in flow order.
class ApplicationStatus {
  ApplicationStatus._();

  static const String submitted = 'Submitted';
  static const String underReview = 'Under Review';
  static const String interview = 'Interview / Test';
  static const String accepted = 'Accepted';
  static const String waitingList = 'Waiting List';
  static const String rejected = 'Rejected';

  /// The happy-path progression shown by the status tracker.
  static const List<String> flow = [
    submitted,
    underReview,
    interview,
    accepted,
  ];

  static const List<String> all = [
    submitted,
    underReview,
    interview,
    accepted,
    waitingList,
    rejected,
  ];

  static bool isTerminal(String status) =>
      status == accepted || status == waitingList || status == rejected;
}

/// A student's course application. Firestore collection: `applications`.
class ApplicationModel {
  final String applicationId;
  final String uid;
  final String fullName;
  final String cnic;
  final String education;
  final String city;
  final String courseId;
  final String courseName;
  final String campusId;
  final String campusName;
  final String motivation;
  final String status;
  final String rejectionReason;
  final DateTime? createdAt;

  const ApplicationModel({
    required this.applicationId,
    required this.uid,
    required this.fullName,
    required this.cnic,
    required this.education,
    required this.city,
    required this.courseId,
    required this.courseName,
    required this.campusId,
    required this.campusName,
    required this.motivation,
    this.status = ApplicationStatus.submitted,
    this.rejectionReason = '',
    this.createdAt,
  });

  factory ApplicationModel.fromMap(Map<String, dynamic> map, String id) {
    return ApplicationModel(
      applicationId: id,
      uid: (map['uid'] ?? '').toString(),
      fullName: (map['fullName'] ?? '').toString(),
      cnic: (map['cnic'] ?? '').toString(),
      education: (map['education'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      courseId: (map['courseId'] ?? '').toString(),
      courseName: (map['courseName'] ?? map['selectedCourse'] ?? '').toString(),
      campusId: (map['campusId'] ?? '').toString(),
      campusName:
          (map['campusName'] ?? map['preferredCampus'] ?? '').toString(),
      motivation: (map['motivation'] ?? '').toString(),
      status: (map['status'] ?? ApplicationStatus.submitted).toString(),
      rejectionReason: (map['rejectionReason'] ?? '').toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ApplicationModel.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      ApplicationModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'cnic': cnic,
        'education': education,
        'city': city,
        'courseId': courseId,
        'courseName': courseName,
        'selectedCourse': courseName,
        'campusId': campusId,
        'campusName': campusName,
        'preferredCampus': campusName,
        'motivation': motivation,
        'status': status,
        'rejectionReason': rejectionReason,
        'createdAt': FieldValue.serverTimestamp(),
      };

  bool get isAccepted => status == ApplicationStatus.accepted;
  bool get isRejected => status == ApplicationStatus.rejected;
  bool get isWaitingList => status == ApplicationStatus.waitingList;

  /// Index within [ApplicationStatus.flow], or the last reached step for
  /// terminal statuses that leave the happy path.
  int get stepIndex {
    final i = ApplicationStatus.flow.indexOf(status);
    if (i >= 0) return i;
    // Waiting List / Rejected both branch off after the interview stage.
    return ApplicationStatus.flow.length - 1;
  }
}
