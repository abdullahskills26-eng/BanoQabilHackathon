"""Firebase ID token verification and the authorization dependencies.

The flow this implements is the one the Flutter client already produces:

    Flutter -> Firebase Auth -> ID token
            -> Authorization: Bearer <token>
            -> Firebase Admin SDK verify_id_token()
            -> CallerIdentity (uid + role)
            -> ownership / role check
            -> Firestore

Authentication ("who is this?") lives in :func:`get_current_user`.
Authorization ("what may they do?") lives in :func:`require_roles` and
:func:`assert_self_or_roles`, deliberately kept separate so a route can
require one without silently getting the other.

Roles are read from the Firebase custom claim first and fall back to the
``users/{uid}`` Firestore document, because accounts created by the Flutter
client set only the document while :mod:`app.api.v1.auth` sets both.
"""

from dataclasses import dataclass, field
from typing import Any, Callable, Dict, Optional, Sequence

from fastapi import Depends, Header, HTTPException, status

from app.core.firebase_admin import get_db, is_available

STUDENT = "student"
INSTRUCTOR = "instructor"
COORDINATOR = "coordinator"
VALID_ROLES = (STUDENT, INSTRUCTOR, COORDINATOR)

# Roles allowed to read across other users' records.
STAFF_ROLES = (INSTRUCTOR, COORDINATOR)


@dataclass(frozen=True)
class CallerIdentity:
    """The verified caller behind a request."""

    uid: str
    email: Optional[str]
    role: str
    claims: Dict[str, Any] = field(default_factory=dict)

    @property
    def is_coordinator(self) -> bool:
        return self.role == COORDINATOR

    @property
    def is_staff(self) -> bool:
        return self.role in STAFF_ROLES


def _firebase_auth():
    """The firebase_admin.auth module, or 503 when the SDK cannot start.

    503 rather than 500: the request was well-formed, the server just has no
    credentials configured yet. The detail explains exactly how to fix it.
    """
    if not is_available():
        from app.core.firebase_admin import init_error

        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=init_error() or "Firebase is not configured.",
        )
    from firebase_admin import auth as fb_auth

    return fb_auth


def _unauthenticated(detail: str) -> HTTPException:
    """401 with the WWW-Authenticate header the Bearer scheme requires."""
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _extract_bearer(authorization: Optional[str]) -> str:
    """Pull the token out of an Authorization header, or raise 401.

    Tolerates extra internal whitespace and a stray trailing newline, both of
    which turn up when a token is pasted by hand into a REST client.
    """
    if not authorization or not authorization.strip():
        raise _unauthenticated(
            "Missing 'Authorization: Bearer <idToken>' header"
        )

    parts = authorization.strip().split(None, 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise _unauthenticated(
            "Authorization header must use the form 'Bearer <idToken>'"
        )

    token = parts[1].strip()
    if not token:
        raise _unauthenticated("Bearer token is empty")
    return token


def _role_from_firestore(uid: str) -> Optional[str]:
    """Role from ``users/{uid}``, or None if it cannot be read.

    A missing document or an unreachable Firestore must not turn a valid token
    into a 500 — the caller simply ends up with the default role.
    """
    try:
        doc = get_db().collection("users").document(uid).get()
    except Exception:  # noqa: BLE001 - best effort; covers FirebaseUnavailable
        return None
    if not doc.exists:
        return None
    role = (doc.to_dict() or {}).get("role")
    return role if role in VALID_ROLES else None


def verify_id_token(token: str) -> CallerIdentity:
    """Verify a Firebase ID token and resolve the caller's role.

    Each Firebase failure mode is mapped to the status code that describes it,
    so the client can tell "sign in again" apart from "server misconfigured".
    """
    fb_auth = _firebase_auth()

    try:
        decoded = fb_auth.verify_id_token(token)
    except fb_auth.ExpiredIdTokenError as exc:
        raise _unauthenticated("ID token has expired. Sign in again.") from exc
    except fb_auth.RevokedIdTokenError as exc:
        raise _unauthenticated(
            "ID token has been revoked. Sign in again."
        ) from exc
    except fb_auth.UserDisabledError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been disabled.",
        ) from exc
    except fb_auth.CertificateFetchError as exc:
        # Google's public keys could not be fetched — a server-side problem,
        # not a bad token, so it must not read as "your credentials failed".
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Could not fetch Firebase signing keys: {exc}",
        ) from exc
    except (fb_auth.InvalidIdTokenError, ValueError) as exc:
        raise _unauthenticated(f"Invalid ID token: {exc}") from exc

    uid = decoded.get("uid") or decoded.get("sub") or ""
    if not uid:
        raise _unauthenticated("ID token carries no uid")

    claim_role = decoded.get("role")
    role = (
        claim_role
        if claim_role in VALID_ROLES
        else _role_from_firestore(uid)
    )

    return CallerIdentity(
        uid=uid,
        email=decoded.get("email"),
        role=role or STUDENT,
        claims=decoded,
    )


def get_current_user(
    authorization: Optional[str] = Header(default=None),
) -> CallerIdentity:
    """FastAPI dependency: the verified caller, or 401.

    Use as ``caller: CallerIdentity = Depends(get_current_user)``.
    """
    return verify_id_token(_extract_bearer(authorization))


def require_roles(*roles: str) -> Callable[..., CallerIdentity]:
    """Dependency factory restricting a route to the given roles.

    Authorization only — it assumes authentication already happened, and
    returns the same identity so a route can use both from one parameter.
    """
    allowed = tuple(roles)

    def _dependency(
        caller: CallerIdentity = Depends(get_current_user),
    ) -> CallerIdentity:
        if caller.role not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"This endpoint requires the role "
                    f"{' or '.join(allowed)}; you are '{caller.role}'."
                ),
            )
        return caller

    return _dependency


def assert_self_or_roles(
    caller: CallerIdentity,
    target_uid: str,
    roles: Sequence[str] = STAFF_ROLES,
) -> None:
    """Allow a caller to act on ``target_uid`` only when it is their own record
    or their role permits acting on others.

    This is the IDOR guard: without it, swapping the uid in the path is enough
    to read somebody else's data.
    """
    if caller.uid == target_uid:
        return
    if caller.role in roles:
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You may only access your own records.",
    )


def require_demo_mode() -> None:
    """Dependency gating the demo/seed endpoints behind DEMO_MODE.

    These endpoints overwrite fixed Firestore documents and provision the
    demo accounts, so they must be switched on deliberately rather than
    being reachable on any deployment that happens to have credentials.
    """
    from app.core.config import DEMO_MODE

    if not DEMO_MODE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Demo endpoints are disabled. Set DEMO_MODE=true in the "
                "backend environment to enable them."
            ),
        )


# Convenience dependencies for the common cases.
require_staff = require_roles(INSTRUCTOR, COORDINATOR)
require_coordinator = require_roles(COORDINATOR)
