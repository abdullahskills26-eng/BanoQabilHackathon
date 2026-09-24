#!/usr/bin/env python
"""Seed the SkillBridge demo dataset into Cloud Firestore.

Run from the skillbridge_backend directory:

    python scripts/seed_demo_data.py

Credentials are picked up from GOOGLE_APPLICATION_CREDENTIALS (a
service-account JSON path) or from Application Default Credentials
(`gcloud auth application-default login`).

Writes:
  6 courses, 8 campuses, instructor + coordinator accounts,
  batch FL-2026-01 (Lahore Campus, Sir Hamza) with 12 students,
  4 assignments (Pending, Pending, Submitted, Marked 18/20),
  5 applications covering all five statuses,
  10 weekdays of attendance, and 2 notices.

Idempotent: every document has a fixed id, so re-running overwrites the demo
data rather than duplicating it.
"""

import argparse
import os
import sys

# Make `app` importable when the script is run directly.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.firebase_admin import (  # noqa: E402
    FirebaseUnavailable,
    init_error,
    is_available,
)
from app.services import demo_seed  # noqa: E402


def _print_progress(step: str, fraction: float) -> None:
    bar_width = 28
    filled = int(bar_width * fraction)
    bar = "#" * filled + "." * (bar_width - filled)
    print(f"  [{bar}] {fraction * 100:5.1f}%  {step}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Seed SkillBridge demo data into Firestore."
    )
    parser.add_argument(
        "--yes",
        "-y",
        action="store_true",
        help="Skip the confirmation prompt.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be written without touching Firestore.",
    )
    args = parser.parse_args()

    print("SkillBridge demo data seeder")
    print("=" * 46)

    if args.dry_run:
        print("\nDry run - nothing will be written.\n")
        print(f"  Courses   ({len(demo_seed.COURSES)}): "
              f"{', '.join(c[1] for c in demo_seed.COURSES)}")
        print(f"  Campuses  ({len(demo_seed.CAMPUSES)}): "
              f"{', '.join(c[1] for c in demo_seed.CAMPUSES)}")
        print(f"  Batch        : {demo_seed.BATCH_CODE} "
              f"({demo_seed.CAMPUS_NAME}, {demo_seed.INSTRUCTOR_NAME})")
        print(f"  Students     : {demo_seed.STUDENT_COUNT}")
        print("  Assignments  : 4 (Pending, Pending, Submitted, Marked 18/20)")
        print("  Applications : " + ", ".join(
            s for s, _ in demo_seed.APPLICATION_STATUSES))
        return 0

    if not is_available():
        print("\nFirebase is not configured.\n")
        print(f"  {init_error()}\n")
        print("Fix it with either:")
        print("  set GOOGLE_APPLICATION_CREDENTIALS="
              "path\\to\\service-account.json")
        print("  gcloud auth application-default login")
        return 1

    if not args.yes:
        print(
            "\nThis writes the demo dataset into Firestore, overwriting any "
            "existing\ndocuments with the same demo ids."
        )
        answer = input("Continue? [y/N] ").strip().lower()
        if answer not in ("y", "yes"):
            print("Cancelled.")
            return 0

    print("\nSeeding...\n")
    try:
        summary = demo_seed.seed(on_progress=_print_progress)
    except FirebaseUnavailable as exc:
        print(f"\nFirebase unavailable: {exc}")
        return 1
    except Exception as exc:  # noqa: BLE001 - surfaced to the operator
        print(f"\nSeeding failed: {exc}")
        return 1

    print("\nDone.\n")
    for key, value in summary.items():
        print(f"  {key:<14}: {value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
