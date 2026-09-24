"""Firebase Admin SDK initialisation.

Credentials are resolved in this order:

1. ``GOOGLE_APPLICATION_CREDENTIALS`` — path to a service-account JSON file
   (the standard Google variable; also what Cloud Run injects).
2. ``FIREBASE_CREDENTIALS`` — same thing under a project-specific name.
3. Application Default Credentials, for when the process already runs with a
   Google identity attached.

Initialisation is lazy and never raises at import time: without credentials the
rest of the API (the in-memory instructor endpoints) still has to start. Call
``get_db()`` and handle ``FirebaseUnavailable`` at the route layer instead.
"""

import os
import threading
from typing import Optional

_lock = threading.Lock()
_app = None
_init_error: Optional[str] = None
_initialised = False


class FirebaseUnavailable(RuntimeError):
    """Raised when Firestore is needed but the Admin SDK could not start."""


def _initialise() -> None:
    global _app, _init_error, _initialised

    if _initialised:
        return

    with _lock:
        if _initialised:
            return
        _initialised = True

        try:
            import firebase_admin
            from firebase_admin import credentials
        except ImportError:
            _init_error = (
                "firebase-admin is not installed. Add it to requirements.txt "
                "and run: pip install -r requirements.txt"
            )
            return

        # Reuse an app if something else already initialised one.
        if firebase_admin._apps:
            _app = firebase_admin.get_app()
            return

        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS") or os.getenv(
            "FIREBASE_CREDENTIALS"
        )

        try:
            if cred_path:
                if not os.path.exists(cred_path):
                    _init_error = f"Service account file not found: {cred_path}"
                    return
                cred = credentials.Certificate(cred_path)
            else:
                cred = credentials.ApplicationDefault()
            _app = firebase_admin.initialize_app(cred)
        except Exception as exc:  # noqa: BLE001 - surfaced to the caller as-is
            _init_error = (
                f"Could not initialise Firebase Admin: {exc}. Set "
                "GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON path."
            )


_client = None


def _build_client():
    """Create the Firestore client, caching it after the first success.

    ApplicationDefault credentials resolve lazily, so `initialize_app` can
    succeed while the credentials are actually missing — the failure only
    surfaces here. Everything is funnelled into FirebaseUnavailable so callers
    have a single exception to handle.
    """
    global _client

    if _client is not None:
        return _client

    _initialise()
    if _app is None:
        raise FirebaseUnavailable(_init_error or "Firebase is not configured.")

    from firebase_admin import firestore

    try:
        _client = firestore.client()
    except Exception as exc:  # noqa: BLE001 - reported verbatim to the caller
        raise FirebaseUnavailable(
            f"Firestore is unreachable: {exc} Set "
            "GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON path, "
            "or run: gcloud auth application-default login"
        ) from exc
    return _client


def is_available() -> bool:
    """True when a Firestore client can actually be created."""
    try:
        _build_client()
        return True
    except FirebaseUnavailable:
        return False


def init_error() -> Optional[str]:
    """Why Firestore is unavailable, or None when it works."""
    try:
        _build_client()
        return None
    except FirebaseUnavailable as exc:
        return str(exc)


def get_db():
    """Firestore client. Raises [FirebaseUnavailable] when unconfigured."""
    return _build_client()


def field_filter(field_path: str, op_string: str, value):
    """Build a Firestore ``FieldFilter`` for use as ``.where(filter=...)``.

    Passing the three arguments positionally to ``.where()`` is deprecated and
    emits a UserWarning on every call. Importing here rather than at module
    scope keeps this module free of import-time Firebase dependencies, which
    is what lets the API start without credentials.
    """
    from google.cloud.firestore_v1.base_query import FieldFilter

    return FieldFilter(field_path, op_string, value)
