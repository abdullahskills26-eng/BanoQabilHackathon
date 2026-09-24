"""Application settings.

Values come from the environment, falling back to development-safe defaults.
A local `.env` file (see .env.example) is loaded on import when python-dotenv
is installed, so `uvicorn app.main:app` picks it up without extra wiring.

Nothing secret lives here: the Firebase service-account path arrives via
GOOGLE_APPLICATION_CREDENTIALS and is read by app.core.firebase_admin.
"""

import os
from typing import List

try:  # python-dotenv is in requirements.txt, but must not be a hard dependency
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:  # pragma: no cover - only hit in a stripped environment
    pass


def _bool_env(name: str, default: bool = False) -> bool:
    """Read a boolean setting. Only an explicit affirmative turns it on, so a
    typo or an empty value fails closed."""
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _float_env(name: str, default: float) -> float:
    """Read a float setting, ignoring an unparseable value rather than crashing
    the whole app at import time."""
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    try:
        return float(raw)
    except ValueError:
        return default


# API
API_V1_PREFIX: str = "/api/v1"
PROJECT_NAME: str = "SkillBridge API"
VERSION: str = "1.0.0"

# Server (read by run instructions / deployment, not by FastAPI itself)
HOST: str = os.getenv("HOST", "127.0.0.1")
PORT: int = int(os.getenv("PORT", "8000") or 8000)

# CORS — comma-separated origins. "*" is fine for local dev and demos; narrow
# it to the deployed frontend origin before exposing the API publicly.
CORS_ORIGINS: List[str] = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "*").split(",")
    if origin.strip()
] or ["*"]

# Attendance percentage below this marks a student as at-risk.
ATTENDANCE_RISK_THRESHOLD: float = _float_env("ATTENDANCE_RISK_THRESHOLD", 75.0)

# ------------------------------------------------------------------- Demo
# Demo/seed endpoints write fixed records into the live Firestore project and
# provision the demo accounts, so they stay switched off unless deliberately
# enabled. Off by default: a deployment that forgets this setting cannot have
# its data overwritten, and /auth/demo-accounts cannot be used to reset the
# demo coordinator's password and sign in as staff.
#
# Enable for a demo with:  DEMO_MODE=true
DEMO_MODE: bool = _bool_env("DEMO_MODE", False)
