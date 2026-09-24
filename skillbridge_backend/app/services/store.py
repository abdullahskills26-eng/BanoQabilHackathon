"""In-memory mock data store.

Simulates a database with plain Python lists/dicts so the API runs with no
external dependencies. Replace these with Firestore queries (via
app.core.firebase_admin) when the Firebase backend lands.

State is per-process: restarting the server resets everything to seed data.
"""

from itertools import count

from fastapi import HTTPException

from app.core.config import ATTENDANCE_RISK_THRESHOLD

students_db = [
    {"id": 1, "name": "Aisha Khan", "attendance_percentage": 92.0, "status": "Present"},
    {"id": 2, "name": "Bilal Ahmed", "attendance_percentage": 68.5, "status": "Absent"},
    {"id": 3, "name": "Sara Malik", "attendance_percentage": 74.0, "status": "Present"},
    {"id": 4, "name": "Hamza Raza", "attendance_percentage": 88.0, "status": "Present"},
    {"id": 5, "name": "Fatima Noor", "attendance_percentage": 55.0, "status": "Absent"},
]

assignments_db = [
    {
        "id": 1,
        "title": "Data Structures - Assignment 1",
        "due_date": "2026-09-20",
        "max_marks": 100,
        "submissions_count": 18,
    },
    {
        "id": 2,
        "title": "Algorithms - Midterm Project",
        "due_date": "2026-09-30",
        "max_marks": 50,
        "submissions_count": 5,
    },
]

notices_db = [
    {
        "id": 1,
        "text": "Class rescheduled to 3 PM on Friday.",
        "created_at": "2026-09-08T10:00:00",
    },
]

classes_db = [
    {"id": 1, "name": "CS-101 Data Structures"},
    {"id": 2, "name": "CS-201 Algorithms"},
]

# Auto-incrementing ID generators for new records
assignment_id_counter = count(start=len(assignments_db) + 1)
notice_id_counter = count(start=len(notices_db) + 1)


def enrich_student(student: dict) -> dict:
    """Add computed field `is_at_risk` based on the attendance threshold."""
    return {
        **student,
        "is_at_risk": student["attendance_percentage"] < ATTENDANCE_RISK_THRESHOLD,
    }


def find_student(student_id: int) -> dict:
    for s in students_db:
        if s["id"] == student_id:
            return s
    raise HTTPException(
        status_code=404, detail=f"Student with id {student_id} not found"
    )
