"""Dashboard summary endpoints."""

from fastapi import APIRouter

from app.services.store import assignments_db, classes_db, notices_db, students_db

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/summary")
def dashboard_summary():
    """Aggregate counters for the instructor dashboard homepage."""
    return {
        "total_classes": len(classes_db),
        "total_students": len(students_db),
        "active_notices": len(notices_db),
        "pending_assignments": len(assignments_db),
    }
