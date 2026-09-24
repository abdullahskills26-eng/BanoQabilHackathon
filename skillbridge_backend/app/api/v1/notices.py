"""Notice board endpoints."""

from datetime import datetime, timezone

from fastapi import APIRouter

from app.models.schemas import NoticeCreateRequest
from app.services import store

router = APIRouter(prefix="/notices", tags=["Notices"])


@router.post("/create")
def create_notice(payload: NoticeCreateRequest):
    """Post a new announcement/notice for students."""
    new_notice = {
        "id": next(store.notice_id_counter),
        "text": payload.text,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    store.notices_db.append(new_notice)
    return {"message": "Notice posted successfully", "notice": new_notice}
