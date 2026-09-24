"""End-to-end RBAC tests against the real FastAPI app.

These complement tests/test_auth_dependencies.py, which exercises the auth
module in isolation. The point here is the *wiring*: a route that simply
forgot its guard would still pass the unit tests, and only shows up when the
endpoint itself is called.

Reading the assertions
----------------------
Firebase has no credentials in CI, so any request that gets past
authentication stops at the Firestore layer with 503. That makes the status
code a precise signal:

    401  rejected before identity was established
    403  authenticated, but not allowed (role or ownership)
    503  ALLOWED - the guard passed and the handler reached Firestore

`_ALLOWED` below asserts "not 401 and not 403" rather than a specific code,
so these tests keep working unchanged once real credentials are present.

Run from skillbridge_backend/ with:
    .venv/Scripts/python -m pytest tests/ -v
"""

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.auth import CallerIdentity, get_current_user  # noqa: E402
from app.main import app  # noqa: E402

client = TestClient(app)


@pytest.fixture(autouse=True)
def _firestore_unavailable(monkeypatch):
    """Make the Firestore layer fail instantly instead of hunting for cloud
    credentials.

    Without this, every request that passes authorization tries to resolve
    Application Default Credentials and blocks on network timeouts, which
    made the suite take over a minute and left it dependent on the machine's
    environment. Failing fast keeps 503 meaning exactly "the guard allowed
    this and the handler reached Firestore".
    """
    from app.core import firebase_admin as fb

    def _unavailable(*_args, **_kwargs):
        raise fb.FirebaseUnavailable("Firebase is not configured (test).")

    monkeypatch.setattr(fb, "_build_client", _unavailable)


STUDENT_UID = "student_uid_1"
OTHER_STUDENT_UID = "student_uid_2"
INSTRUCTOR_UID = "instructor_uid_1"
COORDINATOR_UID = "coordinator_uid_1"


def _identity(uid: str, role: str) -> CallerIdentity:
    return CallerIdentity(uid=uid, email=f"{uid}@test.local", role=role)


@pytest.fixture
def as_user():
    """Sign requests in as a given uid/role for the duration of a test."""

    def _use(uid: str, role: str):
        app.dependency_overrides[get_current_user] = lambda: _identity(
            uid, role
        )

    yield _use
    app.dependency_overrides.clear()


def _assert_allowed(response, where: str):
    assert response.status_code not in (401, 403), (
        f"{where} should have been allowed, got "
        f"{response.status_code}: {response.text[:200]}"
    )


def _assert_forbidden(response, where: str):
    assert response.status_code == 403, (
        f"{where} should have been forbidden, got "
        f"{response.status_code}: {response.text[:200]}"
    )


# ------------------------------------------------- 1-3: unauthenticated


UNAUTH_ENDPOINTS = [
    ("get", f"/api/v1/student/dashboard/{STUDENT_UID}"),
    ("get", f"/api/v1/student/progress/{STUDENT_UID}"),
    ("post", "/api/v1/student/applications"),
    ("post", "/api/v1/student/submissions"),
    ("get", f"/api/v1/instructor/dashboard/{INSTRUCTOR_UID}"),
    ("post", "/api/v1/instructor/attendance"),
    ("post", "/api/v1/instructor/grade"),
    ("get", "/api/v1/instructor/batch-progress/B1"),
    ("get", "/api/v1/coordinator/metrics/all"),
    ("post", "/api/v1/coordinator/batches"),
    ("get", "/api/v1/reports/summary"),
    ("get", "/api/v1/reports/campus/all"),
    ("get", "/api/v1/reports/batch/B1"),
    ("get", "/api/v1/reports/export/applications.csv"),
    ("get", "/api/v1/reports/export/batch/B1.csv"),
    ("post", "/api/v1/auth/set-role"),
    ("get", "/api/v1/auth/users/a@b.com"),
    # /seed-demo-data is deliberately absent: demo mode is checked before
    # authentication, so with DEMO_MODE off it answers 403 (disabled) rather
    # than 401. It has dedicated tests below.
]


@pytest.mark.parametrize("method,path", UNAUTH_ENDPOINTS)
def test_1_no_authorization_header_is_401(method, path):
    """Scenario 1: no Authorization header -> 401."""
    assert getattr(client, method)(path).status_code == 401


@pytest.mark.parametrize("method,path", UNAUTH_ENDPOINTS)
def test_2_malformed_authorization_header_is_401(method, path):
    """Scenario 2/3: a malformed or non-Bearer header -> 401.

    A structurally invalid header is rejected before Firebase is consulted,
    so this holds with or without credentials configured.
    """
    res = getattr(client, method)(
        path, headers={"Authorization": "Basic Zm9vOmJhcg=="}
    )
    assert res.status_code == 401


def test_2b_empty_bearer_token_is_401():
    res = client.get(
        f"/api/v1/student/dashboard/{STUDENT_UID}",
        headers={"Authorization": "Bearer   "},
    )
    assert res.status_code == 401


# --------------------------------------- 4-5: student, own resources


def test_4_5_student_may_read_own_dashboard(as_user):
    as_user(STUDENT_UID, "student")
    _assert_allowed(
        client.get(f"/api/v1/student/dashboard/{STUDENT_UID}"),
        "student reading own dashboard",
    )


def test_5_student_may_read_own_progress(as_user):
    as_user(STUDENT_UID, "student")
    _assert_allowed(
        client.get(f"/api/v1/student/progress/{STUDENT_UID}"),
        "student reading own progress",
    )


# -------------------------------- 9: IDOR - another user's resource


def test_9_student_cannot_read_another_students_dashboard(as_user):
    as_user(STUDENT_UID, "student")
    _assert_forbidden(
        client.get(f"/api/v1/student/dashboard/{OTHER_STUDENT_UID}"),
        "student reading another student's dashboard",
    )


def test_9_student_cannot_read_another_students_progress(as_user):
    as_user(STUDENT_UID, "student")
    _assert_forbidden(
        client.get(f"/api/v1/student/progress/{OTHER_STUDENT_UID}"),
        "student reading another student's progress",
    )


def test_9_student_cannot_submit_as_another_student(as_user):
    as_user(STUDENT_UID, "student")
    _assert_forbidden(
        client.post(
            "/api/v1/student/submissions",
            json={
                "assignmentId": "A1",
                "uid": OTHER_STUDENT_UID,
                "textAnswer": "not my work",
            },
        ),
        "student submitting as another student",
    )


def test_9_staff_cannot_submit_on_a_students_behalf(as_user):
    """Submissions are strictly self-only - even staff cannot impersonate."""
    as_user(INSTRUCTOR_UID, "instructor")
    _assert_forbidden(
        client.post(
            "/api/v1/student/submissions",
            json={
                "assignmentId": "A1",
                "uid": STUDENT_UID,
                "textAnswer": "submitted by instructor",
            },
        ),
        "instructor submitting for a student",
    )


def test_9_student_cannot_apply_as_another_student(as_user):
    as_user(STUDENT_UID, "student")
    _assert_forbidden(
        client.post(
            "/api/v1/student/applications",
            json={
                "uid": OTHER_STUDENT_UID,
                "fullName": "Someone Else",
                "cnic": "1234567890123",
                "education": "FSc",
                "city": "Lahore",
                "courseId": "c1",
                "courseName": "Flutter",
                "campusId": "lhr",
                "campusName": "Lahore Campus",
                "motivation": "x" * 40,
            },
        ),
        "student applying as another student",
    )


# ------------------------------ 6: student -> staff/coordinator routes


STAFF_ONLY = [
    ("get", f"/api/v1/instructor/dashboard/{INSTRUCTOR_UID}"),
    ("get", "/api/v1/instructor/batch-progress/B1"),
    ("get", "/api/v1/reports/batch/B1"),
    ("get", "/api/v1/reports/export/batch/B1.csv"),
]

COORDINATOR_ONLY = [
    ("get", "/api/v1/coordinator/metrics/all"),
    ("get", "/api/v1/reports/summary"),
    ("get", "/api/v1/reports/campus/all"),
    ("get", "/api/v1/reports/export/applications.csv"),
    ("get", "/api/v1/auth/users/a@b.com"),
]


@pytest.mark.parametrize("method,path", STAFF_ONLY + COORDINATOR_ONLY)
def test_6_student_is_forbidden_from_staff_routes(as_user, method, path):
    """Scenario 6: a student reaching a staff/coordinator route -> 403."""
    as_user(STUDENT_UID, "student")
    _assert_forbidden(getattr(client, method)(path), f"student -> {path}")


def test_6_student_cannot_change_roles(as_user):
    """The privilege-escalation route: a student must never set a role."""
    as_user(STUDENT_UID, "student")
    _assert_forbidden(
        client.post(
            "/api/v1/auth/set-role",
            json={"uid": STUDENT_UID, "role": "coordinator"},
        ),
        "student promoting themselves to coordinator",
    )


def test_6_instructor_cannot_change_roles(as_user):
    """Role management is coordinator-only, not merely staff-only."""
    as_user(INSTRUCTOR_UID, "instructor")
    _assert_forbidden(
        client.post(
            "/api/v1/auth/set-role",
            json={"uid": INSTRUCTOR_UID, "role": "coordinator"},
        ),
        "instructor promoting themselves",
    )


def test_6_student_cannot_mark_attendance(as_user):
    as_user(STUDENT_UID, "student")
    _assert_forbidden(
        client.post(
            "/api/v1/instructor/attendance",
            json={
                "batchId": "B1",
                "date": "2026-09-18",
                "statusMap": {STUDENT_UID: "Present"},
            },
        ),
        "student marking attendance",
    )


def test_6_student_cannot_grade_submissions(as_user):
    as_user(STUDENT_UID, "student")
    _assert_forbidden(
        client.post(
            "/api/v1/instructor/grade",
            json={"submissionId": "s1", "marks": 100, "feedback": "A+"},
        ),
        "student grading their own work",
    )


# ---------------------------------- 7-8: instructor and coordinator


@pytest.mark.parametrize("method,path", STAFF_ONLY)
def test_7_instructor_may_use_staff_routes(as_user, method, path):
    """Scenario 7: instructor accessing instructor resources -> allowed."""
    as_user(INSTRUCTOR_UID, "instructor")
    _assert_allowed(getattr(client, method)(path), f"instructor -> {path}")


def test_7_instructor_may_mark_attendance_and_grade(as_user):
    as_user(INSTRUCTOR_UID, "instructor")
    _assert_allowed(
        client.post(
            "/api/v1/instructor/attendance",
            json={
                "batchId": "B1",
                "date": "2026-09-18",
                "statusMap": {STUDENT_UID: "Present"},
            },
        ),
        "instructor marking attendance",
    )
    _assert_allowed(
        client.post(
            "/api/v1/instructor/grade",
            json={"submissionId": "s1", "marks": 80, "feedback": "Good"},
        ),
        "instructor grading",
    )


def test_7_instructor_cannot_open_another_instructors_dashboard(as_user):
    """Ownership still applies within a role."""
    as_user(INSTRUCTOR_UID, "instructor")
    _assert_forbidden(
        client.get("/api/v1/instructor/dashboard/some_other_instructor"),
        "instructor opening a colleague's dashboard",
    )


@pytest.mark.parametrize("method,path", STAFF_ONLY + COORDINATOR_ONLY)
def test_8_coordinator_may_use_every_staff_route(as_user, method, path):
    """Scenario 8: coordinator accessing coordinator resources -> allowed."""
    as_user(COORDINATOR_UID, "coordinator")
    _assert_allowed(getattr(client, method)(path), f"coordinator -> {path}")


def test_8_coordinator_may_open_any_instructor_dashboard(as_user):
    as_user(COORDINATOR_UID, "coordinator")
    _assert_allowed(
        client.get(f"/api/v1/instructor/dashboard/{INSTRUCTOR_UID}"),
        "coordinator opening an instructor dashboard",
    )


def test_8_coordinator_may_read_any_students_data(as_user):
    as_user(COORDINATOR_UID, "coordinator")
    _assert_allowed(
        client.get(f"/api/v1/student/dashboard/{STUDENT_UID}"),
        "coordinator reading a student dashboard",
    )


def test_8_coordinator_may_change_roles(as_user):
    as_user(COORDINATOR_UID, "coordinator")
    _assert_allowed(
        client.post(
            "/api/v1/auth/set-role",
            json={"uid": STUDENT_UID, "role": "instructor"},
        ),
        "coordinator assigning a role",
    )


def test_instructor_may_read_a_students_record(as_user):
    """Staff legitimately need cross-user reads for rosters and grading."""
    as_user(INSTRUCTOR_UID, "instructor")
    _assert_allowed(
        client.get(f"/api/v1/student/dashboard/{STUDENT_UID}"),
        "instructor reading a student dashboard",
    )


# ------------------------------------------- public / health endpoints


@pytest.mark.parametrize(
    "path",
    [
        "/",
        "/api/v1/auth/status",
        "/api/v1/dashboard/summary",
        "/api/v1/students",
        "/api/v1/assignments",
        "/api/v1/batch/progress",
    ],
)
def test_public_endpoints_remain_reachable(path):
    """The in-memory demo endpoints carry no user data and stay open; this
    guards against over-tightening them by accident."""
    assert client.get(path).status_code == 200


# ------------------------------------------------ demo / seed endpoints


DEMO_ENDPOINTS = [
    ("post", "/api/v1/seed-demo-data"),
    ("get", "/api/v1/seed-demo-data/preview"),
    ("post", "/api/v1/auth/demo-accounts"),
]


@pytest.mark.parametrize("method,path", DEMO_ENDPOINTS)
def test_demo_endpoints_disabled_by_default(method, path):
    """DEMO_MODE is off unless set, so these are unreachable even for a
    coordinator — a deployment cannot have its data seeded over by accident."""
    assert getattr(client, method)(path).status_code == 403


def test_demo_accounts_is_not_anonymously_usable(monkeypatch):
    """Unauthenticated, this endpoint would reset the demo coordinator's
    password to a value published in the source and grant it the coordinator
    claim. DEMO_MODE is what stops that."""
    res = client.post("/api/v1/auth/demo-accounts")
    assert res.status_code == 403
    assert "DEMO_MODE" in res.text


def test_seed_still_requires_a_coordinator_when_demo_mode_is_on(
    monkeypatch, as_user
):
    """With demo mode enabled the coordinator check must still apply."""
    monkeypatch.setattr("app.core.config.DEMO_MODE", True)

    assert client.post("/api/v1/seed-demo-data").status_code == 401

    as_user(STUDENT_UID, "student")
    _assert_forbidden(
        client.post("/api/v1/seed-demo-data"),
        "student seeding demo data with DEMO_MODE on",
    )

    as_user(COORDINATOR_UID, "coordinator")
    _assert_allowed(
        client.post("/api/v1/seed-demo-data"),
        "coordinator seeding demo data with DEMO_MODE on",
    )


def test_preview_is_readable_when_demo_mode_is_on(monkeypatch):
    monkeypatch.setattr("app.core.config.DEMO_MODE", True)
    assert client.get("/api/v1/seed-demo-data/preview").status_code == 200
