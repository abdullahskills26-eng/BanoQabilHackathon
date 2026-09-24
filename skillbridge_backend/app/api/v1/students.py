"""Student roster endpoints."""

from fastapi import APIRouter

from app.services.store import enrich_student, students_db

router = APIRouter(prefix="/students", tags=["Students"])


@router.get("")
def get_students():
    """Return the full student roster, each enriched with an at-risk flag."""
    return [enrich_student(s) for s in students_db]
