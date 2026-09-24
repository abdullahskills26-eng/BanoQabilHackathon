"""Assignment and quiz endpoints."""

from fastapi import APIRouter

from app.models.schemas import AssignmentCreateRequest
from app.services import store

router = APIRouter(prefix="/assignments", tags=["Assignments"])


@router.get("")
def get_assignments():
    """Return all created assignments."""
    return store.assignments_db


@router.post("/create")
def create_assignment(payload: AssignmentCreateRequest):
    """Create a new assignment record and add it to the in-memory store."""
    new_assignment = {
        "id": next(store.assignment_id_counter),
        "title": payload.title,
        "due_date": payload.due_date.isoformat(),
        "max_marks": payload.max_marks,
        "submissions_count": 0,
    }
    store.assignments_db.append(new_assignment)
    return {
        "message": "Assignment created successfully",
        "assignment": new_assignment,
    }
