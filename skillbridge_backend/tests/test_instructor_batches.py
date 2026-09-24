"""Regression tests for instructor -> batch scoping.

`_instructor_batches()` used to end with `return all_batches` when nothing
matched, so an instructor with no assigned batch silently received every
batch on the campus. /instructor/dashboard then reported another cohort's
students and /instructor/batch-progress their marks and attendance.

The supported ways to match a batch — by instructorId, and by instructorName
for seeded data — are kept; only the "return everything" fallback is gone.

Run from skillbridge_backend/ with:
    .venv/Scripts/python -m pytest tests/ -v
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.api.v1 import instructor as instructor_module  # noqa: E402
from app.core.auth import CallerIdentity  # noqa: E402


class _FakeDoc:
    def __init__(self, doc_id, data, exists=True):
        self.id = doc_id
        self._data = data
        self.exists = exists

    def to_dict(self):
        return dict(self._data)


class _FakeDocRef:
    def __init__(self, doc):
        self._doc = doc

    def get(self):
        return self._doc


class _FakeCollection:
    def __init__(self, docs):
        self._docs = docs

    def stream(self):
        return list(self._docs)

    def document(self, doc_id):
        for d in self._docs:
            if d.id == doc_id:
                return _FakeDocRef(d)
        return _FakeDocRef(_FakeDoc(doc_id, {}, exists=False))

    def where(self, *, filter=None):  # noqa: A002 - matches the real API
        """Equality filtering, matching how the routers call `.where()`.

        Reads the field and value off the FieldFilter so the fake actually
        filters rather than quietly returning everything — which is the very
        bug this file exists to catch.
        """
        field = getattr(filter, "field_path", None)
        value = getattr(filter, "value", None)
        if field is None:
            return _FakeCollection([])
        return _FakeCollection(
            [d for d in self._docs if d.to_dict().get(field) == value]
        )


class _FakeDb:
    """Just enough Firestore for the instructor routes."""

    def __init__(self, batches, users, assignments=(), submissions=()):
        self._collections = {
            "batches": _FakeCollection(batches),
            "users": _FakeCollection(users),
            "assignments": _FakeCollection(list(assignments)),
            "submissions": _FakeCollection(list(submissions)),
        }

    def collection(self, name):
        return self._collections[name]


BATCH_A = _FakeDoc("FL-2026-01", {"batchCode": "FL-2026-01",
                                  "instructorId": "teacher_a",
                                  "instructorName": "Teacher A"})
BATCH_B = _FakeDoc("FL-2026-02", {"batchCode": "FL-2026-02",
                                  "instructorId": "teacher_b",
                                  "instructorName": "Teacher B"})
BATCH_SEEDED = _FakeDoc("FL-2026-03", {"batchCode": "FL-2026-03",
                                       "instructorName": "Sir Hamza"})

ALL_BATCHES = [BATCH_A, BATCH_B, BATCH_SEEDED]

USERS = [
    _FakeDoc("teacher_a", {"name": "Teacher A", "role": "instructor"}),
    _FakeDoc("teacher_b", {"name": "Teacher B", "role": "instructor"}),
    _FakeDoc("hamza_uid", {"name": "Sir Hamza", "role": "instructor"}),
    _FakeDoc("stranger", {"name": "Nobody's Teacher", "role": "instructor"}),
]


@pytest.fixture(autouse=True)
def fake_db(monkeypatch):
    monkeypatch.setattr(
        instructor_module, "_db", lambda: _FakeDb(ALL_BATCHES, USERS)
    )


def _codes(batches):
    return sorted(b["batchCode"] for b in batches)


def test_matches_by_instructor_id():
    assert _codes(instructor_module._instructor_batches("teacher_a")) == [
        "FL-2026-01"
    ]


def test_matches_seeded_batch_by_instructor_name():
    """Seed data records the teacher by name — this path must keep working."""
    assert _codes(instructor_module._instructor_batches("hamza_uid")) == [
        "FL-2026-03"
    ]


def test_unassigned_instructor_gets_nothing_not_everything():
    """The regression: an instructor with no batches must receive an empty
    list, never the whole campus."""
    result = instructor_module._instructor_batches("stranger")
    assert result == [], (
        "unassigned instructor received batches they do not own: "
        f"{_codes(result)}"
    )


def test_unknown_uid_gets_nothing():
    """A uid with no user document must not fall through to every batch."""
    assert instructor_module._instructor_batches("does_not_exist") == []


def test_an_instructor_never_sees_another_instructors_batch():
    for uid, owned in (("teacher_a", "FL-2026-01"),
                       ("teacher_b", "FL-2026-02")):
        codes = _codes(instructor_module._instructor_batches(uid))
        assert codes == [owned]


def test_dashboard_reports_empty_for_unassigned_instructor():
    """The endpoint must degrade to an empty dashboard, not leak a cohort."""
    caller = CallerIdentity(
        uid="stranger", email="stranger@test.local", role="instructor"
    )
    result = instructor_module.instructor_dashboard("stranger", caller=caller)

    assert result["active_batch"] is None
    assert result["total_batches"] == 0
    assert result["total_students"] == 0
    assert result["schedule"] == []


def test_dashboard_scopes_to_the_instructors_own_batch():
    """The positive case, so the empty result above is not a false pass."""
    caller = CallerIdentity(
        uid="teacher_a", email="a@test.local", role="instructor"
    )
    result = instructor_module.instructor_dashboard("teacher_a", caller=caller)

    assert result["active_batch"]["batchCode"] == "FL-2026-01"
    assert result["total_batches"] == 1
