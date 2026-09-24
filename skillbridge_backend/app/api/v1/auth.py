"""Authentication endpoints backed by the Firebase Admin SDK.

The Admin SDK cannot verify a password — sign-in happens in the Flutter client
against Firebase Auth. What the backend does is verify the ID token the client
produces, manage accounts, and keep the `users/{uid}` Firestore document in
step with the Auth record.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException

from app.core.auth import require_coordinator, require_demo_mode
from app.core.firebase_admin import FirebaseUnavailable, get_db, is_available
from app.models.schemas import (
    RegisterUserRequest,
    SetRoleRequest,
    VerifyTokenRequest,
)

router = APIRouter(prefix="/auth", tags=["Auth"])

# The three demo accounts the spec requires to exist in Firebase Auth.
DEMO_ACCOUNTS: List[Dict[str, str]] = [
    {
        "email": "student@skillbridge.org",
        "name": "Ayesha Khan",
        "role": "student",
        "uid": "demo_flutter_student_1",
        "campus": "Lahore Campus",
        "campusId": "lahore-campus",
    },
    {
        "email": "instructor@skillbridge.org",
        "name": "Sir Hamza",
        "role": "instructor",
        "uid": "demo_instructor_hamza",
        "campus": "Lahore Campus",
        "campusId": "lahore-campus",
    },
    {
        "email": "admin@skillbridge.org",
        "name": "Campus Coordinator",
        "role": "coordinator",
        "uid": "demo_coordinator_lahore",
        "campus": "Lahore Campus",
        "campusId": "lahore-campus",
    },
]

DEMO_PASSWORD = "skillbridge123"
VALID_ROLES = ("student", "instructor", "coordinator")


def _auth():
    """Firebase Auth client, or a 503 the client can act on."""
    if not is_available():
        from app.core.firebase_admin import init_error

        raise HTTPException(status_code=503, detail=init_error() or
                            "Firebase is not configured.")
    from firebase_admin import auth as fb_auth

    return fb_auth


def _db():
    try:
        return get_db()
    except FirebaseUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


def _user_record_to_dict(user: Any) -> Dict[str, Any]:
    return {
        "uid": user.uid,
        "email": user.email,
        "displayName": user.display_name,
        "disabled": user.disabled,
        "emailVerified": user.email_verified,
        "claims": user.custom_claims or {},
    }


@router.get("/status")
def auth_status():
    """Whether the backend can talk to Firebase at all.

    Safe to call unauthenticated — useful as a health probe from the client.
    """
    from app.core.firebase_admin import init_error

    available = is_available()
    return {
        "firebase_configured": available,
        "detail": None if available else init_error(),
        "demo_accounts": [a["email"] for a in DEMO_ACCOUNTS],
    }


@router.post("/verify")
def verify_token(payload: VerifyTokenRequest):
    """Verify a Firebase ID token and return the caller's identity and role."""
    fb_auth = _auth()

    try:
        decoded = fb_auth.verify_id_token(payload.idToken)
    except Exception as exc:  # noqa: BLE001 - any failure means "not valid"
        raise HTTPException(
            status_code=401, detail=f"Invalid ID token: {exc}"
        ) from exc

    uid = decoded.get("uid", "")
    db = _db()
    doc = db.collection("users").document(uid).get()
    profile = doc.to_dict() if doc.exists else {}

    return {
        "uid": uid,
        "email": decoded.get("email"),
        "role": (profile or {}).get("role")
        or decoded.get("role")
        or "student",
        "profile": profile,
    }


@router.get("/me")
def current_user(authorization: Optional[str] = Header(default=None)):
    """Identity for the bearer token in the Authorization header."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=401,
            detail="Missing 'Authorization: Bearer <idToken>' header",
        )
    token = authorization.split(" ", 1)[1].strip()
    return verify_token(VerifyTokenRequest(idToken=token))


@router.post("/register", status_code=201)
def register_user(payload: RegisterUserRequest):
    """Create a Firebase Auth account plus its `users/{uid}` document.

    Public sign-up always produces a **student**. A requested instructor or
    coordinator role is recorded as `requestedRole` for a coordinator to
    approve through /auth/set-role; it grants nothing on its own.

    Self-assigned roles would otherwise make every coordinator-only guard in
    this API worthless — anyone could register as a coordinator and read every
    campus. The Firestore rules enforce the same restriction on the client's
    direct writes, so the two paths agree.
    """
    fb_auth = _auth()
    db = _db()

    if payload.role not in VALID_ROLES:
        raise HTTPException(
            status_code=422,
            detail=f"role must be one of {', '.join(VALID_ROLES)}",
        )

    granted_role = "student"
    requested_role = payload.role if payload.role != granted_role else None

    try:
        user = fb_auth.create_user(
            email=payload.email,
            password=payload.password,
            display_name=payload.name,
        )
    except Exception as exc:  # noqa: BLE001
        message = str(exc)
        if "EMAIL_EXISTS" in message or "already exists" in message:
            raise HTTPException(
                status_code=409,
                detail=f"An account already exists for {payload.email}",
            ) from exc
        raise HTTPException(
            status_code=400, detail=f"Could not create user: {exc}"
        ) from exc

    # Role in a custom claim so security rules can read it without a lookup.
    fb_auth.set_custom_user_claims(user.uid, {"role": granted_role})

    profile = {
        "name": payload.name,
        "email": payload.email,
        "phone": payload.phone,
        "role": granted_role,
        "city": payload.city,
        "campus": payload.campus,
        "createdAt": datetime.now(timezone.utc),
    }
    if requested_role:
        profile["requestedRole"] = requested_role

    db.collection("users").document(user.uid).set(profile, merge=True)

    return {
        "message": "User registered successfully",
        "uid": user.uid,
        "email": payload.email,
        "role": granted_role,
        "requestedRole": requested_role,
        "note": (
            f"Registered as student. The requested '{requested_role}' role "
            "needs a coordinator to approve it via /auth/set-role."
        )
        if requested_role
        else None,
    }


@router.post("/set-role", dependencies=[Depends(require_coordinator)])
def set_role(payload: SetRoleRequest):
    """Change a user's role, updating both the claim and the document.

    Coordinator-only. Without this guard the endpoint is a straight privilege
    escalation: anyone who could reach the API could promote themselves to
    coordinator and then read every campus's data.
    """
    fb_auth = _auth()
    db = _db()

    if payload.role not in VALID_ROLES:
        raise HTTPException(
            status_code=422,
            detail=f"role must be one of {', '.join(VALID_ROLES)}",
        )

    try:
        fb_auth.get_user(payload.uid)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=404, detail=f"No user with uid {payload.uid}"
        ) from exc

    fb_auth.set_custom_user_claims(payload.uid, {"role": payload.role})
    db.collection("users").document(payload.uid).set(
        {"role": payload.role}, merge=True
    )

    return {
        "message": "Role updated",
        "uid": payload.uid,
        "role": payload.role,
    }


@router.get("/users/{email}", dependencies=[Depends(require_coordinator)])
def get_user_by_email(email: str):
    """Look up an Auth record by email.

    Coordinator-only: open to the world this is a user-enumeration oracle.
    """
    fb_auth = _auth()
    try:
        user = fb_auth.get_user_by_email(email)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=404, detail=f"No user with email {email}"
        ) from exc
    return _user_record_to_dict(user)


@router.post(
    "/demo-accounts",
    status_code=201,
    dependencies=[Depends(require_demo_mode)],
)
def create_demo_accounts():
    """Create (or repair) the three demo accounts in Firebase Auth.

    The spec requires these to really exist so the quick-login buttons work.
    Existing accounts are updated rather than duplicated, so this is safe to
    run more than once.

    DEMO endpoint, gated on DEMO_MODE. Unauthenticated it is a privilege
    escalation: it resets admin@skillbridge.org to a password published in
    the source and grants it the coordinator claim, so anyone who could reach
    it could then sign in as a coordinator. It is intentionally not
    coordinator-gated as well, because it is what bootstraps the first
    coordinator on an empty project — DEMO_MODE is the control.
    """
    fb_auth = _auth()
    db = _db()

    created: List[str] = []
    updated: List[str] = []
    failed: List[Dict[str, str]] = []

    for account in DEMO_ACCOUNTS:
        try:
            try:
                user = fb_auth.get_user_by_email(account["email"])
                fb_auth.update_user(
                    user.uid,
                    password=DEMO_PASSWORD,
                    display_name=account["name"],
                )
                uid = user.uid
                updated.append(account["email"])
            except Exception:  # noqa: BLE001 - not found, so create it
                user = fb_auth.create_user(
                    uid=account["uid"],
                    email=account["email"],
                    password=DEMO_PASSWORD,
                    display_name=account["name"],
                )
                uid = user.uid
                created.append(account["email"])

            fb_auth.set_custom_user_claims(uid, {"role": account["role"]})

            db.collection("users").document(uid).set(
                {
                    "name": account["name"],
                    "email": account["email"],
                    "role": account["role"],
                    "city": "Lahore",
                    "campus": account["campus"],
                    "campusId": account["campusId"],
                    "createdAt": datetime.now(timezone.utc),
                },
                merge=True,
            )
        except Exception as exc:  # noqa: BLE001
            failed.append({"email": account["email"], "error": str(exc)})

    if failed and not created and not updated:
        raise HTTPException(
            status_code=500,
            detail={"message": "Could not create demo accounts",
                    "failures": failed},
        )

    return {
        "message": "Demo accounts ready",
        "password": DEMO_PASSWORD,
        "created": created,
        "updated": updated,
        "failed": failed,
    }
