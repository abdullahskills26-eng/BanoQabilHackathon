"""Reporting endpoints: aggregated statistics and CSV exports.

These are the heavier queries — they fan out across several collections and
are not meant for per-frame use. The CSV writers use the standard library, so
no extra dependency is needed.
"""

import csv
import io
from collections import Counter
from datetime import datetime, timezone
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse

from app.core.auth import require_coordinator, require_staff
from app.core.firebase_admin import FirebaseUnavailable, get_db

router = APIRouter(prefix="/reports", tags=["Reports"])

PRESENT = "Present"
ABSENT = "Absent"
LATE = "Late"
MARKED = "Marked"
PENDING = "Pending"


def _db():
    try:
        return get_db()
    except FirebaseUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


def _collection(name: str) -> List[Dict[str, Any]]:
    return [{**d.to_dict(), "id": d.id} for d in _db().collection(name).stream()]


def _attendance_percentage(records: List[Dict[str, Any]]) -> float:
    present = sum(1 for r in records if r.get("status") == PRESENT)
    counted = sum(
        1 for r in records if r.get("status") in (PRESENT, ABSENT, LATE)
    )
    if counted == 0:
        return 0.0
    return round((present / counted) * 100, 1)


def _csv_response(
    rows: List[Dict[str, Any]], fieldnames: List[str], filename: str
) -> StreamingResponse:
    """Serialise rows to CSV and return them as a download."""
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=fieldnames, extrasaction="ignore")
    writer.writeheader()
    for row in rows:
        writer.writerow(row)
    buffer.seek(0)

    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/summary", dependencies=[Depends(require_coordinator)])
def overall_summary():
    """Headline counts across every collection."""
    users = _collection("users")
    roles = Counter(str(u.get("role", "unknown")) for u in users)

    applications = _collection("applications")
    app_statuses = Counter(
        str(a.get("status", "unknown")) for a in applications
    )

    batches = _collection("batches")
    submissions = _collection("submissions")
    sub_statuses = Counter(
        str(s.get("status", "unknown")) for s in submissions
    )

    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "users": {"total": len(users), "byRole": dict(roles)},
        "applications": {
            "total": len(applications),
            "byStatus": dict(app_statuses),
        },
        "batches": {
            "total": len(batches),
            "active": sum(
                1 for b in batches if str(b.get("status", "Active")) != "Closed"
            ),
        },
        "courses": len(_collection("courses")),
        "campuses": len(_collection("campuses")),
        "assignments": len(_collection("assignments")),
        "submissions": {
            "total": len(submissions),
            "byStatus": dict(sub_statuses),
        },
        "notices": len(_collection("notices")),
    }


@router.get("/campus/{campus_id}", dependencies=[Depends(require_coordinator)])
def campus_report(campus_id: str):
    """Full statistical breakdown for one campus. Pass `all` for everything."""

    def matches(data: Dict[str, Any]) -> bool:
        if campus_id == "all":
            return True
        return (
            str(data.get("campusId", "")) == campus_id
            or str(data.get("campusName", "")) == campus_id
            or str(data.get("campus", "")) == campus_id
        )

    applications = [a for a in _collection("applications") if matches(a)]
    batches = [b for b in _collection("batches") if matches(b)]
    students = [
        u
        for u in _collection("users")
        if u.get("role") == "student" and matches(u)
    ]

    batch_labels = {
        str(b.get("batchCode") or b.get("batchId") or b["id"]) for b in batches
    }
    assignments = [
        a
        for a in _collection("assignments")
        if not batch_labels or str(a.get("batchId", "")) in batch_labels
    ]
    assignment_ids = {a["id"] for a in assignments}
    submissions = [
        s
        for s in _collection("submissions")
        if str(s.get("assignmentId", "")) in assignment_ids
    ]

    attendance = _collection("attendance")
    student_uids = {s["id"] for s in students}
    per_student = [
        r for r in attendance if str(r.get("uid", "")) in student_uids
    ]

    # Attendance distribution, ignoring the batch-level statusMap documents.
    attendance_counts = Counter(
        str(r.get("status")) for r in per_student if r.get("status")
    )

    # Marks distribution across graded work.
    graded = [
        s for s in submissions if s.get("status") == MARKED and s.get("marks")
    ]
    max_by_id = {
        a["id"]: int(a.get("maxMarks") or a.get("maximumMarks") or 0)
        for a in assignments
    }
    percentages = []
    for s in graded:
        max_marks = max_by_id.get(str(s.get("assignmentId", "")), 0)
        if max_marks > 0:
            percentages.append((float(s["marks"]) / max_marks) * 100)

    average_mark = (
        round(sum(percentages) / len(percentages), 1) if percentages else 0.0
    )

    return {
        "campusId": campus_id,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "applications": {
            "total": len(applications),
            "byStatus": dict(
                Counter(str(a.get("status", "unknown")) for a in applications)
            ),
        },
        "batches": {
            "total": len(batches),
            "active": sum(
                1 for b in batches if str(b.get("status", "Active")) != "Closed"
            ),
            "codes": sorted(batch_labels),
        },
        "students": {
            "enrolled": len(students),
            "averageAttendance": _attendance_percentage(per_student),
            "attendanceBreakdown": dict(attendance_counts),
        },
        "coursework": {
            "assignments": len(assignments),
            "submissions": len(submissions),
            "graded": len(graded),
            "ungraded": len(submissions) - len(graded),
            "averageMarkPercentage": average_mark,
        },
    }


# Declared via `dependencies=` rather than a function parameter so that
# export_batch() below can still call this as a plain function.
@router.get("/batch/{batch_id}", dependencies=[Depends(require_staff)])
def batch_report(batch_id: str):
    """Per-student breakdown for one batch."""
    batches = _collection("batches")
    batch = next(
        (
            b
            for b in batches
            if b["id"] == batch_id
            or str(b.get("batchCode", "")) == batch_id
            or str(b.get("batchId", "")) == batch_id
        ),
        None,
    )
    if batch is None:
        raise HTTPException(status_code=404, detail=f"No batch {batch_id}")

    label = str(batch.get("batchCode") or batch.get("batchId") or batch["id"])

    uids = batch.get("studentUids") or []
    users = _collection("users")
    if uids:
        students = [u for u in users if u["id"] in uids]
    else:
        students = [u for u in users if str(u.get("batchId", "")) == label]

    assignments = [
        a for a in _collection("assignments") if str(a.get("batchId", "")) == label
    ]
    max_by_id = {
        a["id"]: int(a.get("maxMarks") or a.get("maximumMarks") or 0)
        for a in assignments
    }
    submissions = _collection("submissions")
    attendance = _collection("attendance")

    rows = []
    for student in students:
        uid = student["id"]
        records = [r for r in attendance if str(r.get("uid", "")) == uid]
        subs = [s for s in submissions if str(s.get("uid", "")) == uid]

        submitted = sum(1 for s in subs if s.get("status") != PENDING)
        graded = [
            s for s in subs if s.get("status") == MARKED and s.get("marks")
        ]

        percentages = []
        for s in graded:
            max_marks = max_by_id.get(str(s.get("assignmentId", "")), 0)
            if max_marks > 0:
                percentages.append((float(s["marks"]) / max_marks) * 100)
        average = (
            round(sum(percentages) / len(percentages), 1) if percentages else 0.0
        )

        rows.append(
            {
                "uid": uid,
                "name": student.get("name", ""),
                "email": student.get("email", ""),
                "attendancePercentage": _attendance_percentage(records),
                "submitted": submitted,
                "totalAssignments": len(assignments),
                "graded": len(graded),
                "averageMarkPercentage": average,
            }
        )

    rows.sort(key=lambda r: r["attendancePercentage"])

    return {
        "batchId": label,
        "courseName": batch.get("courseName", ""),
        "campusName": batch.get("campusName") or batch.get("campus", ""),
        "instructorName": batch.get("instructorName", ""),
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "totalStudents": len(rows),
        "totalAssignments": len(assignments),
        "students": rows,
    }


@router.get(
    "/export/applications.csv",
    dependencies=[Depends(require_coordinator)],
)
def export_applications(
    campus_id: str = Query(default="all", description="Campus id, or 'all'"),
):
    """Download every application as CSV."""
    applications = _collection("applications")
    if campus_id != "all":
        applications = [
            a
            for a in applications
            if str(a.get("campusId", "")) == campus_id
            or str(a.get("campusName", "")) == campus_id
        ]

    rows = [
        {
            "applicationId": a["id"],
            "fullName": a.get("fullName", ""),
            "cnic": a.get("cnic", ""),
            "education": a.get("education", ""),
            "city": a.get("city", ""),
            "course": a.get("courseName") or a.get("selectedCourse", ""),
            "campus": a.get("campusName") or a.get("preferredCampus", ""),
            "status": a.get("status", ""),
            "rejectionReason": a.get("rejectionReason", ""),
        }
        for a in applications
    ]

    return _csv_response(
        rows,
        [
            "applicationId",
            "fullName",
            "cnic",
            "education",
            "city",
            "course",
            "campus",
            "status",
            "rejectionReason",
        ],
        "applications.csv",
    )


@router.get(
    "/export/batch/{batch_id}.csv",
    dependencies=[Depends(require_staff)],
)
def export_batch(batch_id: str):
    """Download one batch's per-student report as CSV."""
    report = batch_report(batch_id)
    return _csv_response(
        report["students"],
        [
            "uid",
            "name",
            "email",
            "attendancePercentage",
            "submitted",
            "totalAssignments",
            "graded",
            "averageMarkPercentage",
        ],
        f"batch_{report['batchId']}.csv",
    )
