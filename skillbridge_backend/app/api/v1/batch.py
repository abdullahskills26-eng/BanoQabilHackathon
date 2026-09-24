"""Batch progress endpoints."""

from fastapi import APIRouter

from app.core.config import ATTENDANCE_RISK_THRESHOLD
from app.services.store import assignments_db, enrich_student, students_db

router = APIRouter(prefix="/batch", tags=["Batch Progress"])


@router.get("/progress")
def batch_progress():
    """Return the students who are falling behind.

    Flags low attendance (< ATTENDANCE_RISK_THRESHOLD). The poor-grades branch
    is a placeholder — there are no per-student grades in the store yet.
    """
    total_assignments = len(assignments_db)
    at_risk_students = []

    for s in students_db:
        low_attendance = s["attendance_percentage"] < ATTENDANCE_RISK_THRESHOLD
        poor_grades_flag = low_attendance and total_assignments > 0

        if low_attendance or poor_grades_flag:
            at_risk_students.append(
                {
                    **enrich_student(s),
                    "reason": "Low Attendance" if low_attendance else "Poor Grades",
                }
            )

    return {
        "at_risk_count": len(at_risk_students),
        "students": at_risk_students,
    }
