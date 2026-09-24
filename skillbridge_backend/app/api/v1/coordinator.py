"""Campus coordinator endpoints backed by Firestore via the Admin SDK."""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import require_coordinator
from app.core.firebase_admin import (
    FirebaseUnavailable,
    field_filter,
    get_db,
)
from app.models.schemas import (
    ApplicationStatusUpdateRequest,
    BatchCreateRequest,
)

# Every route here is coordinator-only: campus metrics expose the whole
# cohort, and creating batches or deciding applications are administrative
# actions. Declaring it on the router means a new route cannot be added
# without the check.
router = APIRouter(
    prefix="/coordinator",
    tags=["Coordinator"],
    dependencies=[Depends(require_coordinator)],
)

ACCEPTED = "Accepted"
REJECTED = "Rejected"
MARKED = "Marked"
PRESENT = "Present"
ABSENT = "Absent"
LATE = "Late"


def _db():
    try:
        return get_db()
    except FirebaseUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


def _matches_campus(data: Dict[str, Any], campus_id: str) -> bool:
    """Campus is recorded by id on some documents and by name on others."""
    if campus_id in ("", "all"):
        return True
    return (
        str(data.get("campusId", "")) == campus_id
        or str(data.get("campusName", "")) == campus_id
        or str(data.get("campus", "")) == campus_id
    )


def _attendance_percentage(records: List[Dict[str, Any]]) -> float:
    present = sum(1 for r in records if r.get("status") == PRESENT)
    counted = sum(
        1 for r in records if r.get("status") in (PRESENT, ABSENT, LATE)
    )
    if counted == 0:
        return 0.0
    return round((present / counted) * 100, 1)


@router.get("/metrics/{campus_id}")
def campus_metrics(campus_id: str):
    """Real-time campus analytics. Pass `all` to report across every campus."""
    db = _db()

    applications = [
        d.to_dict() for d in db.collection("applications").stream()
    ]
    applications = [a for a in applications if _matches_campus(a, campus_id)]

    now = datetime.now(timezone.utc)
    month_start = datetime(now.year, now.month, 1, tzinfo=timezone.utc)

    def in_this_month(app: Dict[str, Any]) -> bool:
        created = app.get("createdAt")
        if not isinstance(created, datetime):
            # A document written moments ago may not have its server
            # timestamp resolved yet; count it as current.
            return True
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        return created >= month_start

    applications_this_month = sum(1 for a in applications if in_this_month(a))
    accepted = sum(1 for a in applications if a.get("status") == ACCEPTED)

    batches = [
        {**d.to_dict(), "id": d.id} for d in db.collection("batches").stream()
    ]
    batches = [b for b in batches if _matches_campus(b, campus_id)]
    active_batches = sum(
        1 for b in batches if str(b.get("status", "Active")) != "Closed"
    )
    batch_labels = {
        str(b.get("batchCode") or b.get("batchId") or b["id"]) for b in batches
    }

    students = [
        {**d.to_dict(), "uid": d.id}
        for d in db.collection("users")
        .where(filter=field_filter("role", "==", "student"))
        .stream()
    ]
    students = [s for s in students if _matches_campus(s, campus_id)]

    total = 0.0
    counted = 0
    for s in students:
        cached = s.get("attendancePercentage")
        if cached is not None:
            total += float(cached)
            counted += 1
            continue
        records = [
            d.to_dict()
            for d in db.collection("attendance")
            .where(filter=field_filter("uid", "==", s["uid"]))
            .stream()
        ]
        if not records:
            continue
        total += _attendance_percentage(records)
        counted += 1
    average_attendance = round(total / counted, 1) if counted else 0.0

    assignments = [
        {**d.to_dict(), "id": d.id}
        for d in db.collection("assignments").stream()
    ]
    if batch_labels:
        assignments = [
            a for a in assignments if str(a.get("batchId", "")) in batch_labels
        ]

    pending = 0
    for a in assignments:
        subs = [
            d.to_dict()
            for d in db.collection("submissions")
            .where(filter=field_filter("assignmentId", "==", a["id"]))
            .stream()
        ]
        marked = sum(1 for s in subs if s.get("status") == MARKED)
        enrolled = 0
        for b in batches:
            label = str(b.get("batchCode") or b.get("batchId") or b["id"])
            if label == str(a.get("batchId", "")):
                enrolled = len(b.get("studentUids") or [])
                break
        expected = enrolled if enrolled else len(subs)
        pending += max(expected - marked, 0)

    return {
        "campusId": campus_id,
        "applicationsThisMonth": applications_this_month,
        "acceptedStudentsCount": accepted,
        "averageAttendancePercentage": average_attendance,
        "pendingAssignmentsCount": pending,
        "totalApplications": len(applications),
        "activeBatches": active_batches,
        "totalStudents": len(students),
    }


@router.post("/batches", status_code=201)
def create_batch(payload: BatchCreateRequest):
    """Create a batch, associating the selected instructor."""
    db = _db()

    ref = db.collection("batches").document(payload.batchCode)
    if ref.get().exists:
        raise HTTPException(
            status_code=409,
            detail=f"Batch code {payload.batchCode} already exists",
        )

    instructor_name = payload.instructorName
    if payload.instructorId and not instructor_name:
        user = db.collection("users").document(payload.instructorId).get()
        if not user.exists:
            raise HTTPException(
                status_code=404,
                detail=f"No instructor with id {payload.instructorId}",
            )
        instructor_name = (user.to_dict() or {}).get("name", "")

    record = {
        "batchCode": payload.batchCode,
        "batchId": payload.batchCode,
        "courseId": payload.courseId,
        "courseName": payload.courseName,
        "campusId": payload.campusId,
        "campusName": payload.campusName,
        "campus": payload.campusName,
        "instructorId": payload.instructorId,
        "instructorName": instructor_name,
        "maxSeats": payload.maxSeats,
        "seats": payload.maxSeats,
        "startDate": payload.startDate.isoformat(),
        "status": "Active",
        "room": "Lab 2",
        "classTime": "10:00 AM - 1:00 PM",
        "studentUids": [],
        "createdAt": datetime.now(timezone.utc),
    }
    ref.set(record)

    if payload.instructorId:
        db.collection("notifications").document().set(
            {
                "uid": payload.instructorId,
                "title": "Batch assigned",
                "message": f"You have been assigned to {payload.batchCode}.",
                "read": False,
                "createdAt": datetime.now(timezone.utc),
            }
        )

    return {
        "message": "Batch created successfully",
        "batchId": payload.batchCode,
        "batch": record,
    }


@router.put("/applications/{app_id}/status")
def update_application_status(
    app_id: str, payload: ApplicationStatusUpdateRequest
):
    """Move an application to a new state, attaching a rejection reason."""
    db = _db()

    ref = db.collection("applications").document(app_id)
    snap = ref.get()
    if not snap.exists:
        raise HTTPException(
            status_code=404, detail=f"No application with id {app_id}"
        )

    application = snap.to_dict() or {}

    reason = payload.rejectionReason.strip()
    if payload.status == REJECTED and not reason:
        raise HTTPException(
            status_code=422,
            detail="A rejection reason is required when rejecting",
        )

    ref.set(
        {
            "status": payload.status,
            "rejectionReason": reason if payload.status == REJECTED else "",
            "updatedAt": datetime.now(timezone.utc),
        },
        merge=True,
    )

    uid: Optional[str] = application.get("uid")
    if uid:
        message = (
            f"Your application was rejected: {reason}"
            if payload.status == REJECTED
            else f'Your application is now "{payload.status}".'
        )
        db.collection("notifications").document().set(
            {
                "uid": uid,
                "title": "Application status updated",
                "message": message,
                "read": False,
                "createdAt": datetime.now(timezone.utc),
            }
        )

    return {
        "message": "Application status updated",
        "applicationId": app_id,
        "status": payload.status,
        "rejectionReason": reason if payload.status == REJECTED else "",
    }
