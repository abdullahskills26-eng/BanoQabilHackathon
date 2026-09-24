"""Student endpoints backed by Firestore via the Firebase Admin SDK.

Every route returns 503 with a plain explanation when Firebase is not
configured, so the API stays up and self-describing instead of failing at
import time.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import (
    CallerIdentity,
    assert_self_or_roles,
    get_current_user,
)
from app.core.firebase_admin import (
    FirebaseUnavailable,
    field_filter,
    get_db,
)
from app.models.schemas import (
    ApplicationCreateRequest,
    SubmissionCreateRequest,
)

router = APIRouter(prefix="/student", tags=["Student"])

ATTENDANCE_PRESENT = "Present"
ATTENDANCE_ABSENT = "Absent"
SUBMISSION_MARKED = "Marked"
SUBMISSION_PENDING = "Pending"


def _db():
    """Firestore client, or a 503 the client can act on."""
    try:
        return get_db()
    except FirebaseUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


def _docs_where(collection: str, field: str, value: Any) -> List[Dict[str, Any]]:
    db = _db()
    query = (
        db.collection(collection)
        .where(filter=field_filter(field, "==", value))
        .stream()
    )
    return [{**doc.to_dict(), "id": doc.id} for doc in query]


def _attendance_percentage(records: List[Dict[str, Any]]) -> float:
    """Present / (Present + Absent). Leave is excluded from the denominator,
    matching the Flutter client's AttendanceSummary."""
    present = sum(1 for r in records if r.get("status") == ATTENDANCE_PRESENT)
    absent = sum(1 for r in records if r.get("status") == ATTENDANCE_ABSENT)
    counted = present + absent
    if counted == 0:
        return 0.0
    return round((present / counted) * 100, 1)


def _assignment_average(
    submissions: List[Dict[str, Any]],
    assignments_by_id: Dict[str, Dict[str, Any]],
) -> float:
    """Mean percentage across marked submissions."""
    total = 0.0
    counted = 0
    for sub in submissions:
        if sub.get("status") != SUBMISSION_MARKED:
            continue
        marks = sub.get("marks")
        if marks is None:
            continue
        assignment = assignments_by_id.get(str(sub.get("assignmentId", "")))
        max_marks = 0
        if assignment:
            max_marks = int(
                assignment.get("maxMarks") or assignment.get("maximumMarks") or 0
            )
        if max_marks <= 0:
            continue
        total += (float(marks) / max_marks) * 100
        counted += 1
    if counted == 0:
        return 0.0
    return round(total / counted, 1)


def _student_batch(uid: str) -> Optional[Dict[str, Any]]:
    db = _db()
    user_doc = db.collection("users").document(uid).get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail=f"No user with uid {uid}")
    batch_id = (user_doc.to_dict() or {}).get("batchId")
    if not batch_id:
        return None
    batch_doc = db.collection("batches").document(str(batch_id)).get()
    if not batch_doc.exists:
        return None
    return {**(batch_doc.to_dict() or {}), "batchId": str(batch_id)}


def _assignments_for_batch(batch_id: Optional[str]) -> List[Dict[str, Any]]:
    db = _db()
    collection = db.collection("assignments")
    stream = (
        collection.where(
            filter=field_filter("batchId", "==", batch_id)
        ).stream()
        if batch_id
        else collection.stream()
    )
    return [{**doc.to_dict(), "id": doc.id} for doc in stream]


@router.get("/dashboard/{uid}")
def student_dashboard(
    uid: str,
    caller: CallerIdentity = Depends(get_current_user),
):
    """Aggregated dashboard metrics for one student.

    Readable by the student themselves, or by instructor/coordinator staff.
    """
    assert_self_or_roles(caller, uid)
    db = _db()

    user_doc = db.collection("users").document(uid).get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail=f"No user with uid {uid}")
    user = user_doc.to_dict() or {}

    batch = _student_batch(uid)
    attendance = _docs_where("attendance", "uid", uid)
    submissions = _docs_where("submissions", "uid", uid)
    assignments = _assignments_for_batch(batch.get("batchId") if batch else None)

    submitted_ids = {
        str(s.get("assignmentId"))
        for s in submissions
        if s.get("status") not in (None, SUBMISSION_PENDING)
    }
    pending = [a for a in assignments if a["id"] not in submitted_ids]

    notices = [
        {**doc.to_dict(), "id": doc.id}
        for doc in db.collection("notices").limit(5).stream()
    ]

    return {
        "uid": uid,
        "name": user.get("name", ""),
        "campus": user.get("campus", ""),
        "city": user.get("city", ""),
        "attendance_percentage": _attendance_percentage(attendance),
        "attendance_counts": {
            "present": sum(
                1 for r in attendance if r.get("status") == ATTENDANCE_PRESENT
            ),
            "absent": sum(
                1 for r in attendance if r.get("status") == ATTENDANCE_ABSENT
            ),
            "leave": sum(1 for r in attendance if r.get("status") == "Leave"),
        },
        "pending_assignments": len(pending),
        "total_assignments": len(assignments),
        "active_batch": batch,
        "recent_notices": notices,
    }


@router.get("/progress/{uid}")
def student_progress(
    uid: str,
    caller: CallerIdentity = Depends(get_current_user),
):
    """Module completion, attendance and assignment averages.

    Readable by the student themselves, or by instructor/coordinator staff.
    """
    assert_self_or_roles(caller, uid)
    batch = _student_batch(uid)
    attendance = _docs_where("attendance", "uid", uid)
    submissions = _docs_where("submissions", "uid", uid)
    assignments = _assignments_for_batch(batch.get("batchId") if batch else None)

    assignments_by_id = {a["id"]: a for a in assignments}

    marked = [s for s in submissions if s.get("status") == SUBMISSION_MARKED]
    modules_total = len(assignments)
    modules_completed = len(marked)
    module_pct = (
        round((modules_completed / modules_total) * 100, 1)
        if modules_total
        else 0.0
    )

    attendance_pct = _attendance_percentage(attendance)
    assignment_avg = _assignment_average(submissions, assignments_by_id)
    overall = round((module_pct + attendance_pct + assignment_avg) / 3, 1)

    return {
        "uid": uid,
        "modules_completed": modules_completed,
        "modules_total": modules_total,
        "module_percentage": module_pct,
        "attendance_percentage": attendance_pct,
        "assignment_average": assignment_avg,
        "overall_progress": overall,
    }


@router.post("/applications", status_code=201)
def create_application(
    payload: ApplicationCreateRequest,
    caller: CallerIdentity = Depends(get_current_user),
):
    """Validate and store a course application.

    The uid in the body must be the caller's own, so nobody can file an
    application in someone else's name. A coordinator may file on behalf of a
    student.
    """
    assert_self_or_roles(caller, payload.uid, roles=("coordinator",))
    db = _db()

    data = payload.model_dump()
    data["status"] = "Submitted"
    data["rejectionReason"] = ""
    data["createdAt"] = datetime.now(timezone.utc)
    # Field aliases the coordinator screens read.
    data["selectedCourse"] = payload.courseName
    data["preferredCampus"] = payload.campusName

    ref = db.collection("applications").document()
    ref.set(data)

    return {
        "message": "Application submitted successfully",
        "applicationId": ref.id,
        "status": data["status"],
    }


@router.post("/submissions", status_code=201)
def create_submission(
    payload: SubmissionCreateRequest,
    caller: CallerIdentity = Depends(get_current_user),
):
    """Register metadata for an uploaded assignment file.

    Strictly self-only: submitting work under another student's uid would be
    impersonation, so not even staff may do it.

    The file itself is uploaded to Storage by the client at
    `submissions/{assignmentId}/{uid}`; this records the resulting URL.
    Document id is `{assignmentId}_{uid}` so resubmitting overwrites rather
    than duplicating.
    """
    assert_self_or_roles(caller, payload.uid, roles=())
    db = _db()

    assignment_doc = (
        db.collection("assignments").document(payload.assignmentId).get()
    )
    if not assignment_doc.exists:
        raise HTTPException(
            status_code=404,
            detail=f"No assignment with id {payload.assignmentId}",
        )

    assignment = assignment_doc.to_dict() or {}
    status = "Submitted"

    # Mark late when the due date has already passed.
    due = assignment.get("dueDate")
    due_dt: Optional[datetime] = None
    if isinstance(due, datetime):
        due_dt = due
    elif isinstance(due, str):
        try:
            due_dt = datetime.fromisoformat(due)
        except ValueError:
            due_dt = None
    if due_dt is not None:
        if due_dt.tzinfo is None:
            due_dt = due_dt.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > due_dt:
            status = "Late"

    doc_id = f"{payload.assignmentId}_{payload.uid}"
    record = {
        "assignmentId": payload.assignmentId,
        "uid": payload.uid,
        "textAnswer": payload.textAnswer,
        "fileUrl": payload.fileUrl,
        "fileName": payload.fileName,
        "status": status,
        "marks": None,
        "feedback": "",
        "submittedAt": datetime.now(timezone.utc),
    }
    db.collection("submissions").document(doc_id).set(record, merge=True)

    return {
        "message": "Submission recorded successfully",
        "submissionId": doc_id,
        "status": status,
    }
