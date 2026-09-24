import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/constants/firestore_collections.dart';
import '../models/application_model.dart';
import '../models/assignment_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_record_model.dart';
import '../models/batch_model.dart';
import '../models/campus_model.dart';
import '../models/career_checklist_model.dart';
import '../models/course_model.dart';
import '../models/notice_model.dart';
import '../models/report_metrics_model.dart';
import '../models/submission_model.dart';

typedef DocMap = Map<String, dynamic>;

/// Firestore, Auth and Storage handles plus the queries the app needs.
class FirebaseService {
  static final db = FirebaseFirestore.instance;
  static final auth = FirebaseAuth.instance;
  static final storage = FirebaseStorage.instance;

  /// The signed-in user's uid, or the demo student uid when running
  /// unauthenticated so the student screens still have something to read.
  static String get currentUid =>
      auth.currentUser?.uid ?? 'demo_flutter_student_1';

  static Stream<DocumentSnapshot<DocMap>> userDoc(String uid) =>
      db.collection(FirestoreCollections.users).doc(uid).snapshots();

  static Future<void> ensureCoordinatorProfile(User user) async {
    final ref = db.collection(FirestoreCollections.users).doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': 'Campus Coordinator — Lahore',
        'email': user.email ?? '',
        'phone': '',
        'role': 'coordinator',
        'city': 'Lahore',
        'campus': 'Lahore Campus',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ------------------------------------------------------------- Courses

  static Future<List<CourseModel>> fetchCourses() async {
    final snap = await db.collection(FirestoreCollections.courses).get();
    return snap.docs.map(CourseModel.fromDoc).toList();
  }

  static Future<CourseModel?> fetchCourse(String courseId) async {
    final doc =
        await db.collection(FirestoreCollections.courses).doc(courseId).get();
    return doc.exists ? CourseModel.fromDoc(doc) : null;
  }

  // ------------------------------------------------------------- Campuses

  static Future<List<CampusModel>> fetchCampuses() async {
    final snap = await db.collection(FirestoreCollections.campuses).get();
    return snap.docs.map(CampusModel.fromDoc).toList();
  }

  // --------------------------------------------------------- Applications

  static Future<String> submitApplication(ApplicationModel application) async {
    final ref = await db
        .collection(FirestoreCollections.applications)
        .add(application.toMap());
    return ref.id;
  }

  /// Applications for one student, newest first.
  ///
  /// Ordering is done client-side: a `where` + `orderBy` on different fields
  /// needs a composite index, which a fresh Firebase project will not have.
  static Stream<List<ApplicationModel>> watchApplications(String uid) {
    return db
        .collection(FirestoreCollections.applications)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ApplicationModel.fromDoc).toList();
      list.sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      return list;
    });
  }

  // ------------------------------------------------------------- Batches

  static Future<DocMap?> fetchBatch(String batchId) async {
    final doc =
        await db.collection(FirestoreCollections.batches).doc(batchId).get();
    return doc.data();
  }

  /// The batch the student is enrolled in, read from `users/{uid}.batchId`.
  static Future<DocMap?> fetchStudentBatch(String uid) async {
    final user =
        await db.collection(FirestoreCollections.users).doc(uid).get();
    final batchId = user.data()?['batchId']?.toString();
    if (batchId == null || batchId.isEmpty) return null;
    final batch = await fetchBatch(batchId);
    if (batch == null) return null;
    return {...batch, 'batchId': batchId};
  }

  // ---------------------------------------------------------- Attendance

  static Future<List<AttendanceModel>> fetchAttendance(String uid) async {
    final snap = await db
        .collection(FirestoreCollections.attendance)
        .where('uid', isEqualTo: uid)
        .get();
    final list = snap.docs.map(AttendanceModel.fromDoc).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // --------------------------------------------------------- Assignments

  static Future<List<AssignmentModel>> fetchAssignments({
    String? batchId,
  }) async {
    Query<DocMap> query = db.collection(FirestoreCollections.assignments);
    if (batchId != null && batchId.isNotEmpty) {
      query = query.where('batchId', isEqualTo: batchId);
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => AssignmentModel.fromMap(d.data(), d.id))
        .toList();
  }

  // --------------------------------------------------------- Submissions

  static Future<List<SubmissionModel>> fetchSubmissions(String uid) async {
    final snap = await db
        .collection(FirestoreCollections.submissions)
        .where('uid', isEqualTo: uid)
        .get();
    return snap.docs.map(SubmissionModel.fromDoc).toList();
  }

  /// Creates or replaces the submission for one assignment.
  ///
  /// The document id is `{assignmentId}_{uid}`, which makes re-submitting
  /// idempotent instead of piling up duplicates.
  static Future<void> saveSubmission(SubmissionModel submission) async {
    final id = '${submission.assignmentId}_${submission.uid}';
    await db
        .collection(FirestoreCollections.submissions)
        .doc(id)
        .set(submission.toMap(), SetOptions(merge: true));
  }

  // -------------------------------------------------------------- Notices

  static Future<List<DocMap>> fetchNotices({int limit = 5}) async {
    final snap = await db
        .collection(FirestoreCollections.notices)
        .limit(limit)
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  // ---------------------------------------------------- Career checklist

  static Future<CareerChecklistModel> fetchCareerChecklist(String uid) async {
    final doc =
        await db.collection(FirestoreCollections.users).doc(uid).get();
    final raw = doc.data()?['careerChecklist'];
    return CareerChecklistModel.fromMap(
        raw is Map ? Map<String, dynamic>.from(raw) : null);
  }

  static Future<void> saveCareerChecklist(
    String uid,
    CareerChecklistModel checklist,
  ) async {
    await db.collection(FirestoreCollections.users).doc(uid).set(
      {'careerChecklist': checklist.toMap()},
      SetOptions(merge: true),
    );
  }

  // =====================================================================
  // Instructor
  // =====================================================================

  /// Batches assigned to one instructor.
  ///
  /// Seed data records the teacher by name rather than uid, so this matches
  /// on `instructorId` first and falls back to `instructorName`.
  static Future<List<BatchModel>> fetchInstructorBatches({
    required String instructorId,
    String? instructorName,
  }) async {
    final snap = await db.collection(FirestoreCollections.batches).get();
    final all = snap.docs.map(BatchModel.fromDoc).toList();

    final mine = all.where((b) {
      if (b.instructorId.isNotEmpty && b.instructorId == instructorId) {
        return true;
      }
      if (instructorName != null && instructorName.isNotEmpty) {
        return b.instructorName == instructorName;
      }
      return false;
    }).toList();

    // A fresh project may have batches with no instructor set at all; showing
    // everything beats showing an empty dashboard.
    return mine.isEmpty ? all : mine;
  }

  /// Students in a batch: the `studentUids` list when present, otherwise
  /// every user whose `batchId` points at this batch.
  static Future<List<Map<String, dynamic>>> fetchBatchStudents(
    BatchModel batch,
  ) async {
    final users = db.collection(FirestoreCollections.users);

    if (batch.studentUids.isNotEmpty) {
      final docs = await Future.wait(
        batch.studentUids.map((uid) => users.doc(uid).get()),
      );
      return docs
          .where((d) => d.exists)
          .map<Map<String, dynamic>>((d) => {...?d.data(), 'uid': d.id})
          .toList();
    }

    final byBatch = await users
        .where('batchId', isEqualTo: batch.label)
        .get();
    var docs = byBatch.docs;
    if (docs.isEmpty && batch.batchId != batch.label) {
      final alt =
          await users.where('batchId', isEqualTo: batch.batchId).get();
      docs = alt.docs;
    }
    return docs.map((d) => {...d.data(), 'uid': d.id}).toList();
  }

  /// Today's batch attendance record, if one has already been saved.
  static Future<AttendanceRecordModel?> fetchBatchAttendance({
    required String batchId,
    required DateTime date,
  }) async {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final doc = await db
        .collection(FirestoreCollections.attendance)
        .doc('${batchId}_$key')
        .get();
    return doc.exists ? AttendanceRecordModel.fromDoc(doc) : null;
  }

  /// Writes one batch attendance document plus a per-student record each,
  /// in a single atomic batch.
  ///
  /// The per-student records are what the student timetable screen reads, so
  /// both shapes have to stay in step.
  static Future<void> saveBatchAttendance({
    required String batchId,
    required DateTime date,
    required Map<String, String> statusMap,
  }) async {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final writeBatch = db.batch();
    final attendance = db.collection(FirestoreCollections.attendance);

    writeBatch.set(
      attendance.doc('${batchId}_$key'),
      {
        'batchId': batchId,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'statusMap': statusMap,
        'timestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    statusMap.forEach((uid, status) {
      writeBatch.set(
        attendance.doc('${batchId}_${key}_$uid'),
        {
          'batchId': batchId,
          'uid': uid,
          'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
          'status': status,
        },
        SetOptions(merge: true),
      );
    });

    await writeBatch.commit();
  }

  /// Recomputes and stores `attendancePercentage` on each student's user
  /// document, so other screens do not have to re-aggregate.
  static Future<void> recalculateAttendancePercentages(
    List<String> uids,
  ) async {
    if (uids.isEmpty) return;
    final writeBatch = db.batch();

    for (final uid in uids) {
      final records = await fetchAttendance(uid);
      final summary = AttendanceSummary.fromRecords(records);
      writeBatch.set(
        db.collection(FirestoreCollections.users).doc(uid),
        {'attendancePercentage': summary.percentage},
        SetOptions(merge: true),
      );
    }

    await writeBatch.commit();
  }

  /// All submissions for one assignment.
  static Future<List<SubmissionModel>> fetchAssignmentSubmissions(
    String assignmentId,
  ) async {
    final snap = await db
        .collection(FirestoreCollections.submissions)
        .where('assignmentId', isEqualTo: assignmentId)
        .get();
    return snap.docs.map(SubmissionModel.fromDoc).toList();
  }

  /// Records marks and feedback, flipping the submission to `Marked`.
  static Future<void> gradeSubmission({
    required String submissionId,
    required int marks,
    required String feedback,
  }) async {
    await db
        .collection(FirestoreCollections.submissions)
        .doc(submissionId)
        .set({
      'marks': marks,
      'feedback': feedback,
      'status': SubmissionStatus.marked,
      'gradedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Creates an assignment and notifies every student in the batch.
  static Future<String> createAssignment(
    AssignmentModel assignment,
    List<String> studentUids,
  ) async {
    final ref = await db
        .collection(FirestoreCollections.assignments)
        .add(assignment.toMap());

    await _notifyStudents(
      studentUids,
      title: 'New ${assignment.type.toLowerCase()}',
      message: '${assignment.title} · due ${assignment.formattedDueDate}',
    );

    return ref.id;
  }

  /// Posts a notice and notifies every student in the batch.
  static Future<String> postNotice(
    NoticeModel notice,
    List<String> studentUids,
  ) async {
    final ref =
        await db.collection(FirestoreCollections.notices).add(notice.toMap());

    await _notifyStudents(
      studentUids,
      title: notice.title,
      message: notice.content,
    );

    return ref.id;
  }

  /// Fans one message out into the `notifications` collection.
  static Future<void> _notifyStudents(
    List<String> uids, {
    required String title,
    required String message,
  }) async {
    if (uids.isEmpty) return;
    final writeBatch = db.batch();
    final notifications = db.collection(FirestoreCollections.notifications);

    for (final uid in uids) {
      writeBatch.set(notifications.doc(), {
        'uid': uid,
        'title': title,
        'message': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await writeBatch.commit();
  }

  // =====================================================================
  // Coordinator
  // =====================================================================

  /// Campus statistics for the coordinator dashboard.
  ///
  /// Pass null for [campusId] to report across every campus.
  static Future<ReportMetricsModel> fetchCampusMetrics({
    String? campusId,
    String? campusName,
  }) async {
    bool matchesCampus(Map<String, dynamic> data) {
      if (campusId == null && campusName == null) return true;
      final id = (data['campusId'] ?? '').toString();
      final name =
          (data['campusName'] ?? data['campus'] ?? '').toString();
      return (campusId != null && id == campusId) ||
          (campusName != null && name == campusName);
    }

    final appsSnap =
        await db.collection(FirestoreCollections.applications).get();
    final apps = appsSnap.docs
        .map((d) => d.data())
        .where(matchesCampus)
        .toList();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final thisMonth = apps.where((a) {
      final created = (a['createdAt'] as Timestamp?)?.toDate();
      // Documents written moments ago may not have a server timestamp yet;
      // counting them in the current month is the sane reading.
      if (created == null) return true;
      return created.isAfter(monthStart);
    }).length;

    final accepted =
        apps.where((a) => a['status'] == ApplicationStatus.accepted).length;

    final batchesSnap =
        await db.collection(FirestoreCollections.batches).get();
    final batches = batchesSnap.docs
        .map(BatchModel.fromDoc)
        .where((b) =>
            campusId == null && campusName == null
                ? true
                : b.campusId == campusId || b.campusName == campusName)
        .toList();
    final activeBatches = batches.where((b) => b.isActive).length;

    final usersSnap = await db
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: 'student')
        .get();
    final students = usersSnap.docs
        .map((d) => {...d.data(), 'uid': d.id})
        .where(matchesCampus)
        .toList();

    // Average attendance across students, preferring the cached percentage.
    double attendanceTotal = 0;
    int attendanceCounted = 0;
    for (final s in students) {
      final cached = s['attendancePercentage'];
      if (cached != null) {
        attendanceTotal += double.tryParse('$cached') ?? 0;
        attendanceCounted++;
        continue;
      }
      final records = await fetchAttendance(s['uid'].toString());
      if (records.isEmpty) continue;
      attendanceTotal += AttendanceSummary.fromRecords(records).percentage;
      attendanceCounted++;
    }
    final averageAttendance =
        attendanceCounted == 0 ? 0.0 : attendanceTotal / attendanceCounted;

    // Pending = expected submissions that have not been marked.
    final batchLabels = batches.map((b) => b.label).toSet();
    final assignmentsSnap =
        await db.collection(FirestoreCollections.assignments).get();
    final assignments = assignmentsSnap.docs
        .map((d) => AssignmentModel.fromMap(d.data(), d.id))
        .where((a) =>
            batchLabels.isEmpty || batchLabels.contains(a.batchId))
        .toList();

    int pending = 0;
    for (final a in assignments) {
      final subs = await fetchAssignmentSubmissions(a.assignmentId);
      final marked = subs.where((s) => s.isMarked).length;
      final enrolled = batches
          .firstWhere(
            (b) => b.label == a.batchId,
            orElse: () => const BatchModel(batchId: ''),
          )
          .enrolledCount;
      pending += (enrolled == 0 ? subs.length : enrolled) - marked;
    }

    return ReportMetricsModel(
      applicationsThisMonth: thisMonth,
      acceptedStudentsCount: accepted,
      averageAttendancePercentage: averageAttendance,
      pendingAssignmentsCount: pending < 0 ? 0 : pending,
      totalApplications: apps.length,
      activeBatches: activeBatches,
      totalStudents: students.length,
    );
  }

  /// Every application, newest first.
  static Stream<List<ApplicationModel>> watchAllApplications() {
    return db
        .collection(FirestoreCollections.applications)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ApplicationModel.fromDoc).toList();
      list.sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      return list;
    });
  }

  /// Moves an application to a new status and notifies the applicant.
  static Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    String rejectionReason = '',
    String? applicantUid,
  }) async {
    await db
        .collection(FirestoreCollections.applications)
        .doc(applicationId)
        .set({
      'status': status,
      'rejectionReason':
          status == ApplicationStatus.rejected ? rejectionReason : '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (applicantUid != null && applicantUid.isNotEmpty) {
      await _notifyStudents(
        [applicantUid],
        title: 'Application status updated',
        message: status == ApplicationStatus.rejected &&
                rejectionReason.isNotEmpty
            ? 'Your application was rejected: $rejectionReason'
            : 'Your application is now "$status".',
      );
    }
  }

  /// Creates a batch. The document id is the batch code, so codes stay unique.
  static Future<void> createBatch(BatchModel batch) async {
    final ref =
        db.collection(FirestoreCollections.batches).doc(batch.batchCode);
    final existing = await ref.get();
    if (existing.exists) {
      throw Exception('Batch code ${batch.batchCode} already exists.');
    }
    await ref.set({
      ...batch.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateBatchStatus(
      String batchDocId, String status) async {
    await db
        .collection(FirestoreCollections.batches)
        .doc(batchDocId)
        .set({'status': status}, SetOptions(merge: true));
  }

  static Future<void> assignInstructor({
    required String batchDocId,
    required String instructorId,
    required String instructorName,
  }) async {
    await db.collection(FirestoreCollections.batches).doc(batchDocId).set({
      'instructorId': instructorId,
      'instructorName': instructorName,
    }, SetOptions(merge: true));

    if (instructorId.isNotEmpty) {
      await _notifyStudents(
        [instructorId],
        title: 'Batch assigned',
        message: 'You have been assigned to batch $batchDocId.',
      );
    }
  }

  static Future<List<BatchModel>> fetchAllBatches() async {
    final snap = await db.collection(FirestoreCollections.batches).get();
    return snap.docs.map(BatchModel.fromDoc).toList();
  }

  /// Users with a given role, for the instructor-assignment dropdown.
  static Future<List<Map<String, dynamic>>> fetchUsersByRole(
      String role) async {
    final snap = await db
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: role)
        .get();
    return snap.docs
        .map<Map<String, dynamic>>((d) => {...d.data(), 'uid': d.id})
        .toList();
  }

  /// Posts a campus-wide notice and notifies everyone at that campus.
  static Future<void> postCampusNotice({
    required NoticeModel notice,
    required String campusName,
  }) async {
    await db.collection(FirestoreCollections.notices).add(notice.toMap());

    final snap = await db.collection(FirestoreCollections.users).get();
    final recipients = snap.docs
        .where((d) {
          if (notice.targetAudience == 'all') return true;
          final data = d.data();
          return (data['campus'] ?? data['campusName'] ?? '').toString() ==
                  campusName ||
              (data['campusId'] ?? '').toString() == notice.campusId;
        })
        .map((d) => d.id)
        .toList();

    await _notifyStudents(
      recipients,
      title: notice.title,
      message: notice.content,
    );
  }

  /// Notices targeted at one batch, newest first (sorted client-side to
  /// avoid needing a composite index).
  static Future<List<NoticeModel>> fetchBatchNotices(String batchId) async {
    final snap = await db
        .collection(FirestoreCollections.notices)
        .where('batchId', isEqualTo: batchId)
        .get();
    final list = snap.docs.map(NoticeModel.fromDoc).toList();
    list.sort((a, b) {
      final at = a.createdAt, bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return list;
  }
}
