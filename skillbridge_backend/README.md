# SkillBridge Backend

FastAPI service for the SkillBridge campus management app. Most endpoints read
and write Cloud Firestore through the Firebase Admin SDK; a small set of legacy
endpoints run on an in-memory store and need no credentials.

## Quick start

```bash
python -m venv .venv
.venv\Scripts\activate            # Windows
# source .venv/bin/activate       # macOS / Linux

pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Interactive docs: <http://127.0.0.1:8000/docs>

## Firebase credentials

Firestore-backed routes return **503 with an explanation** until credentials
are configured — the server still starts, so the in-memory routes keep working.

Either:

```bash
# A service-account key (Firebase console -> Project settings -> Service accounts)
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccountKey.json

# or Application Default Credentials
gcloud auth application-default login
```

Check it worked:

```bash
curl http://127.0.0.1:8000/api/v1/auth/status
```

Copy `.env.example` to `.env` for the full list of settings. The
service-account JSON is a real secret and is gitignored — never commit it.

## Endpoints

All routes are mounted under `/api/v1`.

### Auth — `auth.py`
| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/auth/status` | Whether Firebase is reachable (no auth needed) |
| POST | `/auth/verify` | Verify a Firebase ID token, return uid and role |
| GET | `/auth/me` | Same, reading `Authorization: Bearer <idToken>` |
| POST | `/auth/register` | Create an account plus its `users/{uid}` document |
| POST | `/auth/set-role` | Change a user's role claim and document |
| GET | `/auth/users/{email}` | Look up an Auth record by email |
| POST | `/auth/demo-accounts` | Create the three demo accounts |

Passwords are never verified here — the Admin SDK cannot. Sign-in happens in
the Flutter client; this service verifies the resulting token.

### Student — `student.py`
| Method | Path |
| --- | --- |
| GET | `/student/dashboard/{uid}` |
| GET | `/student/progress/{uid}` |
| POST | `/student/applications` |
| POST | `/student/submissions` |

### Instructor — `instructor.py`
| Method | Path |
| --- | --- |
| GET | `/instructor/dashboard/{instructor_id}` |
| POST | `/instructor/attendance` (bulk, recalculates rates) |
| POST | `/instructor/grade` |
| GET | `/instructor/batch-progress/{batch_id}` |

### Coordinator — `coordinator.py`
| Method | Path |
| --- | --- |
| GET | `/coordinator/metrics/{campus_id}` (`all` for every campus) |
| POST | `/coordinator/batches` |
| PUT | `/coordinator/applications/{app_id}/status` |

### Reports — `reports.py`
| Method | Path |
| --- | --- |
| GET | `/reports/summary` |
| GET | `/reports/campus/{campus_id}` |
| GET | `/reports/batch/{batch_id}` |
| GET | `/reports/export/applications.csv` |
| GET | `/reports/export/batch/{batch_id}.csv` |

### Seeding — `seed.py`
| Method | Path |
| --- | --- |
| POST | `/seed-demo-data` |
| GET | `/seed-demo-data/preview` (no Firebase needed) |

### In-memory demo routes
`dashboard.py`, `students.py`, `attendance.py`, `assignments.py`,
`notices.py`, `batch.py` run on `app/services/store.py` and need no
credentials. They predate the Firestore work and are kept so the API is
demonstrable without a Firebase project.

## Seeding demo data

```bash
python scripts/seed_demo_data.py --dry-run   # show what would be written
python scripts/seed_demo_data.py             # prompts before writing
python scripts/seed_demo_data.py --yes       # no prompt
```

Writes 6 courses, 8 campuses, batch `FL-2026-01` (Lahore Campus, Sir Hamza)
with 12 students, 4 assignments (Pending, Pending, Submitted, Marked 18/20),
5 applications covering every status, 10 weekdays of attendance, and 2 notices.

Every document has a fixed id, so re-running **overwrites** the demo data
rather than duplicating it — and will replace hand-edits to those same
documents.

## Docker

```bash
docker build -t skillbridge-backend .
docker run -p 8000:8000 \
  -v /path/to/serviceAccountKey.json:/secrets/firebase.json:ro \
  skillbridge-backend
```

## Layout

```
app/
├── main.py                 app, CORS, router registration
├── core/
│   ├── config.py           settings
│   └── firebase_admin.py   lazy, non-throwing Admin SDK init
├── api/v1/                 one router per area
├── models/schemas.py       pydantic request schemas
└── services/
    ├── store.py            in-memory data for the legacy routes
    └── demo_seed.py        seeder shared by the endpoint and the script
scripts/seed_demo_data.py   CLI wrapper around demo_seed
```

## Notes

- CORS defaults to `*`, which suits local development. Narrow
  `CORS_ORIGINS` in `app/core/config.py` before deploying.
- No endpoint currently enforces authentication. `/auth/verify` exists to
  check a token, but routes do not require one — add a dependency that calls
  it before this goes anywhere public.
- Attendance percentages are computed differently per role: the student view
  excludes `Leave` from the denominator, the instructor view counts `Late`
  against the student. The same student can therefore show two figures.
