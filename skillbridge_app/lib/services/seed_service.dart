import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/demo_credentials.dart';
import '../core/constants/firestore_collections.dart';

/// Progress callback so the UI can show which stage is running.
typedef SeedProgress = void Function(String step, double fraction);

/// Writes the demo dataset into Firestore.
///
/// Every document uses a deterministic id, so re-seeding overwrites the
/// previous run instead of piling up duplicates.
class SeedService {
  static final db = FirebaseFirestore.instance;

  static const String demoBatchCode = 'FL-2026-01';
  static const String demoCampus = 'Lahore Campus';
  static const String demoCourse = 'Flutter Development';
  static const int demoStudentCount = 12;

  /// Real Firebase Auth UIDs for the three demo accounts.
  ///
  /// Seeding against these rather than synthetic ids is what makes the demo
  /// coherent: signing in as student@skillbridge.org lands on a dashboard
  /// with a batch, assignments and attendance, not an empty one.
  static String get demoStudentUid => DemoCredentials.student.uid;
  static String get demoInstructorUid => DemoCredentials.instructor.uid;
  static String get demoCoordinatorUid => DemoCredentials.coordinator.uid;

  // ---- 6 courses ----
  static const List<List<String>> _courses = [
    ['flutter-development', 'Flutter Development', 'Beginner', '6 Months',
        'Build cross-platform mobile apps with Flutter and Dart.'],
    ['web-development', 'Web Development', 'Beginner', '6 Months',
        'Modern responsive web development with HTML, CSS and JavaScript.'],
    ['cybersecurity', 'Cybersecurity', 'Intermediate', '6 Months',
        'Network security, ethical hacking and defensive fundamentals.'],
    ['digital-marketing', 'Digital Marketing', 'Beginner', '6 Months',
        'SEO, social media and campaign analytics.'],
    ['graphic-design', 'Graphic Design', 'Beginner', '6 Months',
        'Design principles, branding and industry-standard tooling.'],
    ['cloud-computing', 'Cloud Computing', 'Intermediate', '6 Months',
        'Cloud infrastructure, deployment and DevOps practices.'],
  ];

  // ---- 8 campuses: id, city, province ----
  static const List<List<String>> _campuses = [
    ['lahore-campus', 'Lahore', 'Punjab'],
    ['karachi-campus', 'Karachi', 'Sindh'],
    ['islamabad-campus', 'Islamabad', 'Islamabad'],
    ['peshawar-campus', 'Peshawar', 'Khyber Pakhtunkhwa'],
    ['quetta-campus', 'Quetta', 'Balochistan'],
    ['rawalpindi-campus', 'Rawalpindi', 'Punjab'],
    ['multan-campus', 'Multan', 'Punjab'],
    ['faisalabad-campus', 'Faisalabad', 'Punjab'],
  ];

  // ---- 5 applications, one per status ----
  static const List<List<String>> _applicationStatuses = [
    ['Submitted', ''],
    ['Under Review', ''],
    ['Interview / Test', ''],
    ['Accepted', ''],
    ['Rejected', 'Course seats are currently full.'],
  ];

  static const List<String> _studentNames = [
    'Ayesha Khan',
    'Bilal Ahmed',
    'Sara Malik',
    'Hamza Raza',
    'Fatima Noor',
    'Ali Hassan',
    'Zainab Tariq',
    'Usman Sheikh',
    'Maryam Javed',
    'Ahmed Siddiqui',
    'Hina Aslam',
    'Omar Farooq',
  ];

  /// Seeds everything. [onProgress] fires before each stage.
  static Future<void> seed({SeedProgress? onProgress}) async {
    onProgress?.call('Courses', 0.0);
    await _seedCourses();

    onProgress?.call('Campuses', 0.15);
    await _seedCampuses();

    onProgress?.call('Instructor and coordinator', 0.3);
    await _seedStaff();

    onProgress?.call('Students', 0.4);
    await _seedStudents();

    onProgress?.call('Batch $demoBatchCode', 0.55);
    await _seedBatch();

    onProgress?.call('Applications', 0.65);
    await _seedApplications();

    onProgress?.call('Assignments', 0.75);
    await _seedAssignments();

    onProgress?.call('Submissions', 0.85);
    await _seedSubmissions();

    onProgress?.call('Attendance', 0.92);
    await _seedAttendance();

    onProgress?.call('Notices', 0.97);
    await _seedNotices();

    onProgress?.call('Done', 1.0);
  }

  static Future<void> _seedCourses() async {
    final batch = db.batch();
    for (final c in _courses) {
      batch.set(
        db.collection(FirestoreCollections.courses).doc(c[0]),
        {
          'title': c[1],
          'name': c[1],
          'level': c[2],
          'duration': c[3],
          'description': c[4],
          'seatsAvailable': 30,
          'topics': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static Future<void> _seedCampuses() async {
    final batch = db.batch();
    for (final c in _campuses) {
      batch.set(
        db.collection(FirestoreCollections.campuses).doc(c[0]),
        {
          'name': '${c[1]} Campus',
          'city': c[1],
          'province': c[2],
          'address': '${c[1]} main branch',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static Future<void> _seedStaff() async {
    final batch = db.batch();
    final users = db.collection(FirestoreCollections.users);

    batch.set(
      users.doc(demoInstructorUid),
      {
        'name': DemoCredentials.instructor.name,
        'email': DemoCredentials.instructor.email,
        'phone': '03001234500',
        'role': 'instructor',
        'city': 'Lahore',
        'campus': demoCampus,
        'campusId': 'lahore-campus',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      users.doc(demoCoordinatorUid),
      {
        'name': DemoCredentials.coordinator.name,
        'email': DemoCredentials.coordinator.email,
        'phone': '03001234501',
        'role': 'coordinator',
        'city': 'Lahore',
        'campus': demoCampus,
        'campusId': 'lahore-campus',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// 12 students, all enrolled in the Flutter batch. Student 1 is the real
  /// demo account so signing in as it shows a populated dashboard.
  static Future<void> _seedStudents() async {
    final batch = db.batch();
    for (var i = 0; i < demoStudentCount; i++) {
      batch.set(
        db.collection(FirestoreCollections.users).doc(_studentUid(i)),
        {
          'name': _studentNames[i],
          'email': 'student${i + 1}@skillbridge.org',
          'phone': '0300000000${i + 1}',
          'role': 'student',
          'city': 'Lahore',
          'campus': demoCampus,
          'campusId': 'lahore-campus',
          'batchId': demoBatchCode,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Student 0 is the real demo account; the rest are synthetic.
  static String _studentUid(int index) =>
      index == 0 ? demoStudentUid : 'demo_flutter_student_${index + 1}';

  static List<String> get _studentUids =>
      List.generate(demoStudentCount, _studentUid);

  static Future<void> _seedBatch() async {
    await db
        .collection(FirestoreCollections.batches)
        .doc(demoBatchCode)
        .set({
      'batchCode': demoBatchCode,
      'batchId': demoBatchCode,
      'courseId': 'flutter-development',
      'courseName': demoCourse,
      'campusId': 'lahore-campus',
      'campusName': demoCampus,
      'campus': demoCampus,
      'instructorId': demoInstructorUid,
      'instructorName': DemoCredentials.instructor.name,
      'maxSeats': 30,
      'seats': 30,
      'startDate': '2026-10-15',
      'status': 'Active',
      'room': 'Lab 2',
      'classTime': '10:00 AM – 1:00 PM',
      'studentUids': _studentUids,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _seedApplications() async {
    final batch = db.batch();
    for (var i = 0; i < _applicationStatuses.length; i++) {
      final status = _applicationStatuses[i][0];
      final reason = _applicationStatuses[i][1];
      batch.set(
        db
            .collection(FirestoreCollections.applications)
            .doc('demo_application_${i + 1}'),
        {
          // The Accepted application belongs to the real demo student, so
          // their "My Applications" screen matches their enrolment.
          'uid': status == 'Accepted'
              ? demoStudentUid
              : 'demo_applicant_${i + 1}',
          'fullName': status == 'Accepted'
              ? DemoCredentials.student.name
              : _studentNames[i],
          'cnic': '35202-000000${i + 1}-0',
          'education': 'BS Computer Science',
          'city': 'Lahore',
          'courseId': 'flutter-development',
          'courseName': demoCourse,
          'selectedCourse': demoCourse,
          'campusId': 'lahore-campus',
          'campusName': demoCampus,
          'preferredCampus': demoCampus,
          'motivation':
              'I want to learn IT skills and become job-ready in six months.',
          'status': status,
          'rejectionReason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// 4 assignments. Statuses live on the submissions, not the assignments —
  /// assignments 1 and 2 simply have no submission from student 1.
  static Future<void> _seedAssignments() async {
    final batch = db.batch();
    final now = DateTime.now();

    for (var i = 1; i <= 4; i++) {
      batch.set(
        db
            .collection(FirestoreCollections.assignments)
            .doc('demo_assignment_$i'),
        {
          'batchId': demoBatchCode,
          'title': 'Flutter Assignment $i',
          'type': i == 4 ? 'Quiz' : 'Assignment',
          'instructions':
              'Complete the assigned Flutter task and submit your source code.',
          'maxMarks': 20,
          'maximumMarks': 20,
          'dueDate': Timestamp.fromDate(
              DateTime(now.year, now.month, now.day + (i * 5))),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Exact status distribution for student 1:
  /// A1 Pending, A2 Pending, A3 Submitted, A4 Marked (18/20).
  static Future<void> _seedSubmissions() async {
    final uid = demoStudentUid;
    final batch = db.batch();
    final submissions = db.collection(FirestoreCollections.submissions);

    // Assignments 1 and 2: pending, no work attached.
    for (final id in ['demo_assignment_1', 'demo_assignment_2']) {
      batch.set(
        submissions.doc('${id}_$uid'),
        {
          'assignmentId': id,
          'uid': uid,
          'textAnswer': '',
          'fileUrl': '',
          'fileName': '',
          'status': 'Pending',
          'marks': null,
          'feedback': '',
          'submittedAt': null,
        },
        SetOptions(merge: true),
      );
    }

    // Assignment 3: submitted, awaiting grading.
    batch.set(
      submissions.doc('demo_assignment_3_$uid'),
      {
        'assignmentId': 'demo_assignment_3',
        'uid': uid,
        'textAnswer':
            'Completed the responsive layout and attached the repository link.',
        'fileUrl': '',
        'fileName': 'assignment3_layout.zip',
        'status': 'Submitted',
        'marks': null,
        'feedback': '',
        'submittedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Assignment 4: marked 18/20.
    batch.set(
      submissions.doc('demo_assignment_4_$uid'),
      {
        'assignmentId': 'demo_assignment_4',
        'uid': uid,
        'textAnswer': 'Quiz answers submitted through the portal.',
        'fileUrl': '',
        'fileName': 'quiz4_answers.pdf',
        'status': 'Marked',
        'marks': 18,
        'feedback': 'Good implementation. Improve UI responsiveness.',
        'submittedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Ten weekdays of attendance for all 12 students, in both the batch and
  /// per-student shapes the two roles read.
  static Future<void> _seedAttendance() async {
    final attendance = db.collection(FirestoreCollections.attendance);
    final today = DateTime.now();
    var batch = db.batch();
    var writes = 0;

    for (var dayOffset = 10; dayOffset >= 1; dayOffset--) {
      final date = today.subtract(Duration(days: dayOffset));
      if (date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday) {
        continue;
      }
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final day = DateTime(date.year, date.month, date.day);

      final statusMap = <String, String>{};
      for (var i = 0; i < demoStudentCount; i++) {
        final uid = _studentUid(i);
        // Deterministic spread so some students land below the 60% at-risk
        // line and the instructor's monitor has something to show.
        final String status;
        if (i >= 9) {
          status = (dayOffset % 2 == 0) ? 'Absent' : 'Present';
        } else if (i == 8) {
          status = (dayOffset % 3 == 0) ? 'Late' : 'Present';
        } else {
          status = 'Present';
        }
        statusMap[uid] = status;

        batch.set(
          attendance.doc('${demoBatchCode}_${key}_$uid'),
          {
            'batchId': demoBatchCode,
            'uid': uid,
            'date': Timestamp.fromDate(day),
            'status': status,
          },
          SetOptions(merge: true),
        );
        writes++;
      }

      batch.set(
        attendance.doc('${demoBatchCode}_$key'),
        {
          'batchId': demoBatchCode,
          'date': Timestamp.fromDate(day),
          'statusMap': statusMap,
          'timestamp': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      writes++;

      // Firestore caps a write batch at 500 operations.
      if (writes >= 400) {
        await batch.commit();
        batch = db.batch();
        writes = 0;
      }
    }

    if (writes > 0) await batch.commit();
  }

  static Future<void> _seedNotices() async {
    final batch = db.batch();
    final notices = db.collection(FirestoreCollections.notices);

    batch.set(
      notices.doc('demo_notice_campus'),
      {
        'campusId': 'lahore-campus',
        'campus': demoCampus,
        'batchId': '',
        'title': 'Campus reopening schedule',
        'content':
            'All classes resume on Monday. Please arrive fifteen minutes early.',
        'body':
            'All classes resume on Monday. Please arrive fifteen minutes early.',
        'postedBy': DemoCredentials.coordinator.name,
        'targetAudience': 'campus',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      notices.doc('demo_notice_batch'),
      {
        'campusId': 'lahore-campus',
        'campus': demoCampus,
        'batchId': demoBatchCode,
        'title': 'Lab change',
        'content': 'Lab shifted to Room 2 today.',
        'body': 'Lab shifted to Room 2 today.',
        'postedBy': DemoCredentials.instructor.name,
        'targetAudience': 'batch',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
