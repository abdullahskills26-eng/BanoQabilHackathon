"""Attendance marking endpoints."""

from fastapi import APIRouter

from app.models.schemas import AttendanceMarkRequest
from app.services.store import enrich_student, find_student

router = APIRouter(prefix="/attendance", tags=["Attendance"])


@router.post("/mark")
def mark_attendance(payload: AttendanceMarkRequest):
    """Update a student's attendance status for the day.

    NOTE: this mock implementation only toggles Present/Absent status; it does
    not recalculate the running attendance_percentage.
    """
    student = find_student(payload.student_id)
    student["status"] = payload.status
    return {
        "message": f"Attendance updated for student {payload.student_id}",
        "student": enrich_student(student),
    }
