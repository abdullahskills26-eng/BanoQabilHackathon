"""Instructor endpoints backed by Firestore via the Firebase Admin SDK.

Every route returns 503 with a plain explanation when Firebase is not
configured, so the API stays up and self-describing.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import (
    CallerIdentity,
    assert_self_or_roles,
    require_staff,
)
from app.core.firebase_admin import (
    FirebaseUnavailable,
    field_filter,
    get_db,
)
from app.models.schemas import BulkAttendanceRequest, GradeSubmissionRequest

router = APIRouter(prefix="/instructor", tags=["Instructor"])

PRESENT = "Present"
ABSENT = "Absent"
LATE = "Late"
MARKED = "Marked"
PENDING = "Pending"

# Below this percentage a student is flagged as falling behind.
AT_RISK_THRESHOLD = 60.0


def _db():
    try:
        return get_db()
    except FirebaseUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


def _docs_where(collection: str, field: str, value: Any) -> List[Dict[str, Any]]:
    db = _db()
    stream = (
        db.collection(collection)
        .where(filter=field_filter(field, "==", value))
        .stream()
    )
    return [{**doc.to_dict(), "id": doc.id} for doc in stream]


def _batch_label(batch: Dict[str, Any], doc_id: str) -> str:
    """Batches are keyed by code (FL-2026-01) in some places and by document
    id in others; prefer the code."""
    return str(batch.get("batchCode") or batch.get("batchId") or doc_id)


def _instructor_batches(instructor_id: str) -> List[Dict[str, Any]]:
    """Batches for one instructor, matched by id then by name.

    Seed data records the teacher by name, so an id-only match would return
    nothing on a freshly seeded project — the name match exists for that and
    is the supported demo path.

    Returns an empty list when nothing matches. It previously fell back to
    returning *every* batch, which meant an instructor with no assignments
    silently received the whole campus: /instructor/dashboard then exposed
    another cohort's students, and /instructor/batch-progress their marks and
    attendance. An empty dashboard is the correct answer for an instructor
    who has not been assigned a batch.
    """
    db = _db()
    all_batches = [
        {**doc.to_dict(), "id": doc.id} for doc in db.collection("batches").stream()
    ]

    mine = [b for b in all_batches if b.get("instructorId") == instructor_id]
    if mine:
        return mine

    user = db.collection("users").document(instructor_id).get()
    if user.exists:
        name = (user.to_dict() or {}).get("name")
        if name:
            mine = [b for b in all_batches if b.get("instructorName") == name]
            if mine:
                return mine

    # Nothing matched. Return nothing — never fall back to every batch.
    return []


def _batch_students(batch: Dict[str, Any]) -> List[Dict[str, Any]]:
    db = _db()
    uids = batch.get("studentUids") or []
    if uids:
        docs = [db.collection("users").document(str(u)).get() for u in uids]
        return [{**d.to_dict(), "uid": d.id} for d in docs if d.exists]

    label = _batch_label(batch, batch.get("id", ""))
    stream = (
        db.collection("users")
        .where(filter=field_filter("batchId", "==", label))
        .stream()
    )
    return [{**d.to_dict(), "uid": d.id} for d in stream]


def _attendance_percentage(records: List[Dict[str, Any]]) -> float:
    """Present / (Present + Absent + Late). Late counts as a missed class for
    the percentage, matching what the instructor UI shows."""
    present = sum(1 for r in records if r.get("status") == PRESENT)
    counted = sum(
        1 for r in records if r.get("status") in (PRESENT, ABSENT, LATE)
    )
    if counted == 0:
        return 0.0
    return round((present / counted) * 100, 1)


@router.get("/dashboard/{instructor_id}")
def instructor_dashboard(
    instructor_id: str,
    caller: CallerIdentity = Depends(require_staff),
):
    """Active batch summary, pending grading count and class schedule.

    An instructor may only open their own dashboard; a coordinator may open
    any instructor's.
    """
    assert_self_or_roles(caller, instructor_id, roles=("coordinator",))
    db = _db()
    batches = _instructor_batches(instructor_id)

    if not batches:
        return {
            "instructor_id": instructor_id,
            "active_batch": None,
            "total_batches": 0,
            "total_students": 0,
            "pending_grading": 0,
            "schedule": [],
        }

    active = batches[0]
    label = _batch_label(active, active.get("id", ""))
    students = _batch_students(active)

    assignments = [
        {**doc.to_dict(), "id": doc.id}
        for doc in db.collection("assignments")
        .where(filter=field_filter("batchId", "==", label))
        .stream()
    ]

    pending = 0
    for a in assignments:
        subs = _docs_where("submissions", "assignmentId", a["id"])
        pending += sum(1 for s in subs if s.get("status") != MARKED)

    return {
        "instructor_id": instructor_id,
        "active_batch": {**active, "batchLabel": label},
        "total_batches": len(batches),
        "total_students": len(students),
        "total_assignments": len(assignments),
        "pending_grading": pending,
        "schedule": [
            {
                "course": active.get("courseName", ""),
                "batch": label,
                "room": active.get("room", "Lab 2"),
                "time": active.get("classTime", "10:00 AM - 1:00 PM"),
            }
        ],
    }


@router.post("/attendance", status_code=201)
def bulk_attendance(
    payload: BulkAttendanceRequest,
    caller: CallerIdentity = Depends(require_staff),
):
    """Write one day's attendance for a batch and recalculate each student's
    overall attendance rate.

    Staff only — marking attendance rewrites students' records.
    """
    db = _db()

    date_key = payload.date.isoformat()
    day = datetime(
        payload.date.year,
        payload.date.month,
        payload.date.day,
        tzinfo=timezone.utc,
    )

    write = db.batch()

    # Batch-level record.
    write.set(
        db.collection("attendance").document(f"{payload.batchId}_{date_key}"),
        {
            "batchId": payload.batchId,
            "date": day,
            "statusMap": payload.statusMap,
            "timestamp": datetime.now(timezone.utc),
        },
        merge=True,
    )

    # Per-student records — this is the shape the student screens read.
    for uid, status in payload.statusMap.items():
        write.set(
            db.collection("attendance").document(
                f"{payload.batchId}_{date_key}_{uid}"
            ),
            {
                "batchId": payload.batchId,
                "uid": uid,
                "date": day,
                "status": status,
            },
            merge=True,
        )

    write.commit()

    # Recalculate rates now that today's marks are in.
    updated: Dict[str, float] = {}
    rate_write = db.batch()
    for uid in payload.statusMap:
        records = _docs_where("attendance", "uid", uid)
        pct = _attendance_percentage(records)
        updated[uid] = pct
        rate_write.set(
            db.collection("users").document(uid),
            {"attendancePercentage": pct},
            merge=True,
        )
    rate_write.commit()

    return {
        "message": f"Attendance saved for {len(payload.statusMap)} students",
        "batchId": payload.batchId,
        "date": date_key,
        "attendance_percentages": updated,
    }


@router.post("/grade", status_code=200)
def grade_submission(
    payload: GradeSubmissionRequest,
    caller: CallerIdentity = Depends(require_staff),
):
    """Record marks and feedback, flipping the submission to Marked.

    Staff only — a student must not be able to grade their own work.
    """
    db = _db()

    ref = db.collection("submissions").document(payload.submissionId)
    snap = ref.get()
    if not snap.exists:
        raise HTTPException(
            status_code=404,
            detail=f"No submission with id {payload.submissionId}",
        )

    submission = snap.to_dict() or {}

    # Reject marks above the assignment's maximum.
    assignment_id = str(submission.get("assignmentId", ""))
    if assignment_id:
        a_snap = db.collection("assignments").document(assignment_id).get()
        if a_snap.exists:
            a = a_snap.to_dict() or {}
            max_marks = int(a.get("maxMarks") or a.get("maximumMarks") or 0)
            if max_marks and payload.marks > max_marks:
                raise HTTPException(
                    status_code=422,
                    detail=(
                        f"Marks {payload.marks} exceed the maximum "
                        f"{max_marks} for this assignment"
                    ),
                )

    ref.set(
        {
            "marks": payload.marks,
            "feedback": payload.feedback,
            "status": MARKED,
            "gradedAt": datetime.now(timezone.utc),
        },
        merge=True,
    )

    # Let the student know.
    uid = submission.get("uid")
    if uid:
        db.collection("notifications").document().set(
            {
                "uid": uid,
                "title": "Marks uploaded",
                "message": f"Your submission has been graded: {payload.marks}",
                "read": False,
                "createdAt": datetime.now(timezone.utc),
            }
        )

    return {
        "message": "Submission graded successfully",
        "submissionId": payload.submissionId,
        "marks": payload.marks,
        "status": MARKED,
    }


@router.get("/batch-progress/{batch_id}")
def batch_progress(
    batch_id: str,
    caller: CallerIdentity = Depends(require_staff),
):
    """Evaluate every student in the batch and flag at-risk learners.

    Staff only — this exposes every student's marks and attendance.
    """
    db = _db()

    # batch_id may be the document id or the batch code.
    batch: Optional[Dict[str, Any]] = None
    doc = db.collection("batches").document(batch_id).get()
    if doc.exists:
        batch = {**(doc.to_dict() or {}), "id": doc.id}
    else:
        matches = [
            {**d.to_dict(), "id": d.id}
            for d in db.collection("batches")
            .where(filter=field_filter("batchCode", "==", batch_id))
            .stream()
        ]
        if matches:
            batch = matches[0]

    if batch is None:
        raise HTTPException(status_code=404, detail=f"No batch {batch_id}")

    label = _batch_label(batch, batch["id"])
    students = _batch_students(batch)
    assignments = [
        {**d.to_dict(), "id": d.id}
        for d in db.collection("assignments")
        .where(filter=field_filter("batchId", "==", label))
        .stream()
    ]
    max_marks_by_id = {
        a["id"]: int(a.get("maxMarks") or a.get("maximumMarks") or 0)
        for a in assignments
    }

    results = []
    for student in students:
        uid = student["uid"]

        attendance_pct = _attendance_percentage(
            _docs_where("attendance", "uid", uid)
        )

        submissions = _docs_where("submissions", "uid", uid)
        submitted = sum(1 for s in submissions if s.get("status") != PENDING)
        submission_rate = (
            round((submitted / len(assignments)) * 100, 1) if assignments else 0.0
        )

        total = 0.0
        counted = 0
        for s in submissions:
            if s.get("status") != MARKED or s.get("marks") is None:
                continue
            max_marks = max_marks_by_id.get(str(s.get("assignmentId", "")), 0)
            if max_marks <= 0:
                continue
            total += (float(s["marks"]) / max_marks) * 100
            counted += 1
        assignment_avg = round(total / counted, 1) if counted else 0.0

        overall = round(
            (attendance_pct + submission_rate + assignment_avg) / 3, 1
        )

        results.append(
            {
                "uid": uid,
                "name": student.get("name", ""),
                "attendance_percentage": attendance_pct,
                "submission_rate": submission_rate,
                "assignment_average": assignment_avg,
                "overall": overall,
                "at_risk": overall < AT_RISK_THRESHOLD
                or attendance_pct < AT_RISK_THRESHOLD,
            }
        )

    results.sort(key=lambda r: r["overall"])
    at_risk = [r for r in results if r["at_risk"]]

    return {
        "batchId": label,
        "total_students": len(results),
        "at_risk_count": len(at_risk),
        "threshold": AT_RISK_THRESHOLD,
        "students": results,
        "at_risk_students": at_risk,
    }
