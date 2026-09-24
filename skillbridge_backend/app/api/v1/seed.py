"""Demo data seeding endpoint."""

from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import require_coordinator, require_demo_mode
from app.core.firebase_admin import FirebaseUnavailable
from app.services import demo_seed

router = APIRouter(tags=["Seed"])


@router.post(
    "/seed-demo-data",
    status_code=201,
    dependencies=[Depends(require_demo_mode), Depends(require_coordinator)],
)
def seed_demo_data():
    """Write the full demo dataset into Firestore.

    Idempotent: documents use fixed ids, so re-running overwrites the demo
    data rather than duplicating it.

    DEMO endpoint. Requires DEMO_MODE=true *and* a coordinator token: it
    overwrites live Firestore documents, so neither an anonymous caller nor a
    deployment that forgot to disable it can clobber real data.
    """
    try:
        summary = demo_seed.seed()
    except FirebaseUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001 - reported verbatim
        raise HTTPException(
            status_code=500, detail=f"Seeding failed: {exc}"
        ) from exc

    return {"message": "Demo data seeded successfully", "created": summary}


@router.get(
    "/seed-demo-data/preview",
    dependencies=[Depends(require_demo_mode)],
)
def preview_demo_data():
    """What the seeder would write, without touching Firestore.

    DEMO endpoint. Read-only and contains no user data, but it is gated with
    the rest of demo mode so the whole feature switches on and off together.
    """
    return {
        "courses": [c[1] for c in demo_seed.COURSES],
        "campuses": [f"{c[1]} Campus" for c in demo_seed.CAMPUSES],
        "batch": demo_seed.BATCH_CODE,
        "students": demo_seed.STUDENT_COUNT,
        "assignments": 4,
        "assignment_statuses": ["Pending", "Pending", "Submitted", "Marked"],
        "applications": [
            {"student": demo_seed.STUDENT_NAMES[i], "status": s, "reason": r}
            for i, (s, r) in enumerate(demo_seed.APPLICATION_STATUSES)
        ],
    }
