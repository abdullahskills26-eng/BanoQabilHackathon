"""SkillBridge API — FastAPI application entrypoint.

Run from the skillbridge_backend/ directory with:
    uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload

Interactive docs: http://127.0.0.1:8000/docs
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import (
    assignments,
    attendance,
    auth,
    batch,
    coordinator,
    dashboard,
    instructor,
    notices,
    reports,
    seed,
    student,
    students,
)
from app.core.config import API_V1_PREFIX, CORS_ORIGINS, PROJECT_NAME, VERSION

app = FastAPI(
    title=PROJECT_NAME,
    description="Backend API powering SkillBridge (mock in-memory data)",
    version=VERSION,
)

# Allows the Flutter web frontend to call this API from a different origin.
#
# A wildcard origin and allow_credentials=True are mutually exclusive: the
# browser refuses any response that combines `Access-Control-Allow-Origin: *`
# with credentials, which silently breaks every request from Flutter web. This
# API authenticates with a Bearer token rather than cookies, so credentials are
# only enabled when the origins are listed explicitly.
_allow_wildcard = "*" in CORS_ORIGINS

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=not _allow_wildcard,
    allow_methods=["*"],
    allow_headers=["*"],
)

for router in (
    dashboard.router,
    students.router,
    attendance.router,
    assignments.router,
    notices.router,
    batch.router,
    student.router,
    instructor.router,
    coordinator.router,
    seed.router,
    auth.router,
    reports.router,
):
    app.include_router(router, prefix=API_V1_PREFIX)


@app.get("/", tags=["Health"])
def health_check():
    """Basic health check endpoint to confirm the API is running."""
    return {"status": "SkillBridge API online"}
