"""Firestore demo-data seeder.

Shared by the `POST /api/v1/seed-demo-data` endpoint and the standalone
`scripts/seed_demo_data.py`, so both write exactly the same dataset.

Every document uses a fixed id, making the seeder idempotent: running it twice
overwrites the demo documents instead of duplicating them.
"""

from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Dict, List, Optional

from app.core.firebase_admin import get_db

BATCH_CODE = "FL-2026-01"
CAMPUS_NAME = "Lahore Campus"
CAMPUS_ID = "lahore-campus"
COURSE_NAME = "Flutter Development"
COURSE_ID = "flutter-development"
# Real Firebase Auth UIDs for the three demo accounts on skillbridge-32f45.
# Seeding against these rather than synthetic ids is what makes signing in as
# a demo account land on a populated dashboard.
STUDENT_UID = "phxpBxchb1TDv3ZxbgPEsRGE7CU2"
INSTRUCTOR_ID = "YvKxpyVjqfPicIsV4pp0E5n1CIs2"
COORDINATOR_UID = "xRaLAojCVmgHbcvr9VY2wsrR3Kg2"

INSTRUCTOR_NAME = "Sir Hamza"
STUDENT_COUNT = 12

# id, title, level, duration, description
COURSES = [
    (COURSE_ID, COURSE_NAME, "Beginner", "6 Months",
     "Build cross-platform mobile apps with Flutter and Dart."),
    ("web-development", "Web Development", "Beginner", "6 Months",
     "Modern responsive web development with HTML, CSS and JavaScript."),
    ("cybersecurity", "Cybersecurity", "Intermediate", "6 Months",
     "Network security, ethical hacking and defensive fundamentals."),
    ("digital-marketing", "Digital Marketing", "Beginner", "6 Months",
     "SEO, social media and campaign analytics."),
    ("graphic-design", "Graphic Design", "Beginner", "6 Months",
     "Design principles, branding and industry-standard tooling."),
    ("cloud-computing", "Cloud Computing", "Intermediate", "6 Months",
     "Cloud infrastructure, deployment and DevOps practices."),
]

# id, city, province
CAMPUSES = [
    (CAMPUS_ID, "Lahore", "Punjab"),
    ("karachi-campus", "Karachi", "Sindh"),
    ("islamabad-campus", "Islamabad", "Islamabad"),
    ("peshawar-campus", "Peshawar", "Khyber Pakhtunkhwa"),
    ("quetta-campus", "Quetta", "Balochistan"),
    ("rawalpindi-campus", "Rawalpindi", "Punjab"),
    ("multan-campus", "Multan", "Punjab"),
    ("faisalabad-campus", "Faisalabad", "Punjab"),
]

STUDENT_NAMES = [
    "Ayesha Khan", "Bilal Ahmed", "Sara Malik", "Hamza Raza",
    "Fatima Noor", "Ali Hassan", "Zainab Tariq", "Usman Sheikh",
    "Maryam Javed", "Ahmed Siddiqui", "Hina Aslam", "Omar Farooq",
]

# status, rejection reason
APPLICATION_STATUSES = [
    ("Submitted", ""),
    ("Under Review", ""),
    ("Interview / Test", ""),
    ("Accepted", ""),
    ("Rejected", "Course seats are currently full."),
]

ProgressFn = Callable[[str, float], None]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _student_uid(index: int) -> str:
    """Student 0 is the real demo account; the rest are synthetic."""
    return STUDENT_UID if index == 0 else f"demo_flutter_student_{index + 1}"


def _student_uids() -> List[str]:
    return [_student_uid(i) for i in range(STUDENT_COUNT)]


def seed(on_progress: Optional[ProgressFn] = None) -> Dict[str, Any]:
    """Write the full demo dataset. Returns a summary of what was created."""
    db = get_db()

    def step(name: str, fraction: float) -> None:
        if on_progress:
            on_progress(name, fraction)

    step("courses", 0.0)
    batch = db.batch()
    for cid, title, level, duration, description in COURSES:
        batch.set(
            db.collection("courses").document(cid),
            {
                "title": title,
                "name": title,
                "level": level,
                "duration": duration,
                "description": description,
                "seatsAvailable": 30,
                "topics": [],
                "createdAt": _now(),
            },
            merge=True,
        )
    batch.commit()

    step("campuses", 0.15)
    batch = db.batch()
    for cid, city, province in CAMPUSES:
        batch.set(
            db.collection("campuses").document(cid),
            {
                "name": f"{city} Campus",
                "city": city,
                "province": province,
                "address": f"{city} main branch",
                "createdAt": _now(),
            },
            merge=True,
        )
    batch.commit()

    step("staff", 0.3)
    batch = db.batch()
    batch.set(
        db.collection("users").document(INSTRUCTOR_ID),
        {
            "name": INSTRUCTOR_NAME,
            "email": "instructor@skillbridge.org",
            "phone": "03001234500",
            "role": "instructor",
            "city": "Lahore",
            "campus": CAMPUS_NAME,
            "campusId": CAMPUS_ID,
            "createdAt": _now(),
        },
        merge=True,
    )
    batch.set(
        db.collection("users").document(COORDINATOR_UID),
        {
            "name": "Campus Coordinator",
            "email": "admin@skillbridge.org",
            "phone": "03001234501",
            "role": "coordinator",
            "city": "Lahore",
            "campus": CAMPUS_NAME,
            "campusId": CAMPUS_ID,
            "createdAt": _now(),
        },
        merge=True,
    )
    batch.commit()

    step("students", 0.4)
    batch = db.batch()
    for i in range(STUDENT_COUNT):
        batch.set(
            db.collection("users").document(_student_uid(i)),
            {
                "name": STUDENT_NAMES[i],
                "email": f"student{i + 1}@skillbridge.org",
                "phone": f"0300000000{i + 1}",
                "role": "student",
                "city": "Lahore",
                "campus": CAMPUS_NAME,
                "campusId": CAMPUS_ID,
                "batchId": BATCH_CODE,
                "createdAt": _now(),
            },
            merge=True,
        )
    batch.commit()

    step("batch", 0.55)
    db.collection("batches").document(BATCH_CODE).set(
        {
            "batchCode": BATCH_CODE,
            "batchId": BATCH_CODE,
            "courseId": COURSE_ID,
            "courseName": COURSE_NAME,
            "campusId": CAMPUS_ID,
            "campusName": CAMPUS_NAME,
            "campus": CAMPUS_NAME,
            "instructorId": INSTRUCTOR_ID,
            "instructorName": INSTRUCTOR_NAME,
            "maxSeats": 30,
            "seats": 30,
            "startDate": "2026-10-15",
            "status": "Active",
            "room": "Lab 2",
            "classTime": "10:00 AM - 1:00 PM",
            "studentUids": _student_uids(),
            "createdAt": _now(),
        },
        merge=True,
    )

    step("applications", 0.65)
    batch = db.batch()
    for i, (status, reason) in enumerate(APPLICATION_STATUSES):
        batch.set(
            db.collection("applications").document(f"demo_application_{i + 1}"),
            {
                # The Accepted application belongs to the real demo student,
                # so their applications screen matches their enrolment.
                "uid": (
                    STUDENT_UID if status == "Accepted"
                    else f"demo_applicant_{i + 1}"
                ),
                "fullName": STUDENT_NAMES[i],
                "cnic": f"35202-000000{i + 1}-0",
                "education": "BS Computer Science",
                "city": "Lahore",
                "courseId": COURSE_ID,
                "courseName": COURSE_NAME,
                "selectedCourse": COURSE_NAME,
                "campusId": CAMPUS_ID,
                "campusName": CAMPUS_NAME,
                "preferredCampus": CAMPUS_NAME,
                "motivation": (
                    "I want to learn IT skills and become job-ready in six "
                    "months."
                ),
                "status": status,
                "rejectionReason": reason,
                "createdAt": _now(),
            },
            merge=True,
        )
    batch.commit()

    step("assignments", 0.75)
    batch = db.batch()
    today = _now()
    for i in range(1, 5):
        batch.set(
            db.collection("assignments").document(f"demo_assignment_{i}"),
            {
                "batchId": BATCH_CODE,
                "title": f"Flutter Assignment {i}",
                "type": "Quiz" if i == 4 else "Assignment",
                "instructions": (
                    "Complete the assigned Flutter task and submit your "
                    "source code."
                ),
                "maxMarks": 20,
                "maximumMarks": 20,
                "dueDate": today + timedelta(days=i * 5),
                "createdAt": _now(),
            },
            merge=True,
        )
    batch.commit()

    step("submissions", 0.85)
    uid = STUDENT_UID
    batch = db.batch()
    # Assignments 1 and 2 stay Pending.
    for n in (1, 2):
        batch.set(
            db.collection("submissions").document(f"demo_assignment_{n}_{uid}"),
            {
                "assignmentId": f"demo_assignment_{n}",
                "uid": uid,
                "textAnswer": "",
                "fileUrl": "",
                "fileName": "",
                "status": "Pending",
                "marks": None,
                "feedback": "",
                "submittedAt": None,
            },
            merge=True,
        )
    # Assignment 3: Submitted.
    batch.set(
        db.collection("submissions").document(f"demo_assignment_3_{uid}"),
        {
            "assignmentId": "demo_assignment_3",
            "uid": uid,
            "textAnswer": (
                "Completed the responsive layout and attached the repository "
                "link."
            ),
            "fileUrl": "",
            "fileName": "assignment3_layout.zip",
            "status": "Submitted",
            "marks": None,
            "feedback": "",
            "submittedAt": _now(),
        },
        merge=True,
    )
    # Assignment 4: Marked 18/20.
    batch.set(
        db.collection("submissions").document(f"demo_assignment_4_{uid}"),
        {
            "assignmentId": "demo_assignment_4",
            "uid": uid,
            "textAnswer": "Quiz answers submitted through the portal.",
            "fileUrl": "",
            "fileName": "quiz4_answers.pdf",
            "status": "Marked",
            "marks": 18,
            "feedback": "Good implementation. Improve UI responsiveness.",
            "submittedAt": _now(),
        },
        merge=True,
    )
    batch.commit()

    step("attendance", 0.92)
    _seed_attendance(db)

    step("notices", 0.97)
    batch = db.batch()
    batch.set(
        db.collection("notices").document("demo_notice_campus"),
        {
            "campusId": CAMPUS_ID,
            "campus": CAMPUS_NAME,
            "batchId": "",
            "title": "Campus reopening schedule",
            "content": (
                "All classes resume on Monday. Please arrive fifteen minutes "
                "early."
            ),
            "body": (
                "All classes resume on Monday. Please arrive fifteen minutes "
                "early."
            ),
            "postedBy": "Campus Coordinator",
            "targetAudience": "campus",
            "createdAt": _now(),
        },
        merge=True,
    )
    batch.set(
        db.collection("notices").document("demo_notice_batch"),
        {
            "campusId": CAMPUS_ID,
            "campus": CAMPUS_NAME,
            "batchId": BATCH_CODE,
            "title": "Lab change",
            "content": "Lab shifted to Room 2 today.",
            "body": "Lab shifted to Room 2 today.",
            "postedBy": INSTRUCTOR_NAME,
            "targetAudience": "batch",
            "createdAt": _now(),
        },
        merge=True,
    )
    batch.commit()

    step("done", 1.0)

    return {
        "courses": len(COURSES),
        "campuses": len(CAMPUSES),
        "students": STUDENT_COUNT,
        "batch": BATCH_CODE,
        "assignments": 4,
        "applications": len(APPLICATION_STATUSES),
        "notices": 2,
    }


def _seed_attendance(db) -> None:
    """Ten weekdays of attendance, written in both the batch-level and
    per-student shapes the two roles read."""
    today = _now()
    batch = db.batch()
    writes = 0

    for day_offset in range(10, 0, -1):
        date = today - timedelta(days=day_offset)
        if date.weekday() >= 5:  # skip Saturday and Sunday
            continue

        key = date.strftime("%Y-%m-%d")
        day = datetime(date.year, date.month, date.day, tzinfo=timezone.utc)
        status_map: Dict[str, str] = {}

        for i in range(STUDENT_COUNT):
            uid = _student_uid(i)
            # Deterministic spread so a couple of students fall below the 60%
            # at-risk line and the instructor's monitor has something to show.
            if i >= 9:
                status = "Absent" if day_offset % 2 == 0 else "Present"
            elif i == 8:
                status = "Late" if day_offset % 3 == 0 else "Present"
            else:
                status = "Present"
            status_map[uid] = status

            batch.set(
                db.collection("attendance").document(
                    f"{BATCH_CODE}_{key}_{uid}"
                ),
                {
                    "batchId": BATCH_CODE,
                    "uid": uid,
                    "date": day,
                    "status": status,
                },
                merge=True,
            )
            writes += 1

        batch.set(
            db.collection("attendance").document(f"{BATCH_CODE}_{key}"),
            {
                "batchId": BATCH_CODE,
                "date": day,
                "statusMap": status_map,
                "timestamp": _now(),
            },
            merge=True,
        )
        writes += 1

        # Firestore caps a write batch at 500 operations.
        if writes >= 400:
            batch.commit()
            batch = db.batch()
            writes = 0

    if writes:
        batch.commit()
