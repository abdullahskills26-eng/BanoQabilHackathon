"""Tests for token verification and the authorization guards.

Firebase is stubbed out, so these run with no credentials and no network.
That is the point: it lets the 401/403 paths be exercised, which a machine
without a service-account key could otherwise never reach (every request
stops at the 503 "Firebase is not configured" check first).

Run from skillbridge_backend/ with:
    .venv/Scripts/python -m pytest tests/ -v
"""

import sys
import types
from pathlib import Path

import pytest
from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core import auth as auth_module  # noqa: E402


# Stand-ins for the firebase_admin.auth exception classes.
class ExpiredIdTokenError(Exception):
    pass


class RevokedIdTokenError(Exception):
    pass


class UserDisabledError(Exception):
    pass


class CertificateFetchError(Exception):
    pass


class InvalidIdTokenError(Exception):
    pass


def _fake_fb_auth(verify):
    """A stub of the firebase_admin.auth module with the exception classes
    the production code catches."""
    mod = types.SimpleNamespace(
        verify_id_token=verify,
        ExpiredIdTokenError=ExpiredIdTokenError,
        RevokedIdTokenError=RevokedIdTokenError,
        UserDisabledError=UserDisabledError,
        CertificateFetchError=CertificateFetchError,
        InvalidIdTokenError=InvalidIdTokenError,
    )
    return mod


@pytest.fixture
def stub_firebase(monkeypatch):
    """Install a fake Firebase and stop role lookups hitting Firestore."""

    def _install(verify):
        monkeypatch.setattr(
            auth_module, "_firebase_auth", lambda: _fake_fb_auth(verify)
        )
        monkeypatch.setattr(
            auth_module, "_role_from_firestore", lambda uid: None
        )

    return _install


# ------------------------------------------------------- header parsing


@pytest.mark.parametrize(
    "header",
    [None, "", "   ", "Basic abc", "Bearer", "Bearer   ", "token abc"],
)
def test_bad_authorization_header_is_401(header):
    with pytest.raises(HTTPException) as exc:
        auth_module._extract_bearer(header)
    assert exc.value.status_code == 401
    assert exc.value.headers["WWW-Authenticate"] == "Bearer"


def test_bearer_token_is_extracted_and_trimmed():
    assert auth_module._extract_bearer("Bearer  abc123 \n") == "abc123"


# --------------------------------------------------- token verification


def test_valid_token_yields_identity(stub_firebase):
    stub_firebase(
        lambda t: {"uid": "u1", "email": "a@b.com", "role": "instructor"}
    )
    caller = auth_module.verify_id_token("good")
    assert caller.uid == "u1"
    assert caller.email == "a@b.com"
    assert caller.role == "instructor"
    assert caller.is_staff is True
    assert caller.is_coordinator is False


def test_unknown_claim_role_falls_back_to_student(stub_firebase):
    stub_firebase(lambda t: {"uid": "u1", "role": "superadmin"})
    assert auth_module.verify_id_token("good").role == "student"


def test_token_without_uid_is_401(stub_firebase):
    stub_firebase(lambda t: {"email": "a@b.com"})
    with pytest.raises(HTTPException) as exc:
        auth_module.verify_id_token("nouid")
    assert exc.value.status_code == 401


@pytest.mark.parametrize(
    "error,expected",
    [
        (ExpiredIdTokenError("expired"), 401),
        (RevokedIdTokenError("revoked"), 401),
        (InvalidIdTokenError("bad"), 401),
        (ValueError("malformed"), 401),
        (UserDisabledError("disabled"), 403),
        (CertificateFetchError("no keys"), 503),
    ],
)
def test_firebase_errors_map_to_correct_status(stub_firebase, error, expected):
    def _raise(_token):
        raise error

    stub_firebase(_raise)
    with pytest.raises(HTTPException) as exc:
        auth_module.verify_id_token("whatever")
    assert exc.value.status_code == expected


# ----------------------------------------------------- role enforcement


def _identity(uid="u1", role="student"):
    return auth_module.CallerIdentity(uid=uid, email=None, role=role)


def test_require_roles_allows_and_rejects():
    dep = auth_module.require_roles("coordinator")
    allowed = _identity(role="coordinator")
    assert dep(allowed) is allowed

    with pytest.raises(HTTPException) as exc:
        dep(_identity(role="student"))
    assert exc.value.status_code == 403


# ------------------------------------------------------- IDOR guard


def test_caller_may_access_own_record():
    auth_module.assert_self_or_roles(_identity(uid="me"), "me")


def test_student_cannot_access_another_uid():
    with pytest.raises(HTTPException) as exc:
        auth_module.assert_self_or_roles(_identity(uid="me"), "someone_else")
    assert exc.value.status_code == 403


def test_staff_may_access_another_uid():
    auth_module.assert_self_or_roles(
        _identity(uid="teacher", role="instructor"), "student_uid"
    )


def test_strict_self_only_blocks_even_staff():
    """roles=() is how submissions stay impersonation-proof."""
    with pytest.raises(HTTPException) as exc:
        auth_module.assert_self_or_roles(
            _identity(uid="teacher", role="instructor"),
            "student_uid",
            roles=(),
        )
    assert exc.value.status_code == 403
