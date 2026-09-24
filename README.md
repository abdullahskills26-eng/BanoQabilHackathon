# SkillBridge — Student & Campus Management App

A Flutter + Firebase campus management app for students, instructors, and coordinators to manage courses, applications, attendance, assignments, progress, and career readiness.

Students apply for free IT courses, attend classes, submit work, track progress, and see whether they are job-ready.

Roles: **Student**, **Instructor**, **Campus Coordinator**.
Stack: **Flutter + Dart** frontend, **FastAPI + Firebase Admin** backend, **Firebase** (Auth, Cloud Firestore), **Supabase Storage** for file uploads.

Firebase Storage needs the Blaze plan, so uploads go to a private Supabase
bucket instead. The Supabase client is handed the caller's Firebase ID token,
so storage policies match on the Firebase UID — Firebase remains the only
identity provider.

## Structure

```
skillbridge/
├── skillbridge_app/                 # Flutter Frontend
│   ├── assets/
│   │   ├── images/
│   │   └── icons/
│   └── lib/
│       ├── main.dart
│       ├── app.dart
│       ├── core/
│       │   ├── constants/           # app_colors, firestore_collections, demo_credentials
│       │   ├── theme/               # app_theme
│       │   ├── utils/               # state_renderers (Loading/Empty/Error)
│       │   └── widgets/             # custom_button, custom_textfield
│       ├── models/                  # 10 Firestore data models
│       ├── services/                # auth, firestore, storage, seed
│       └── features/                # Feature-first modules (13 screens)
│           ├── auth/                # Screen 1: Login / Demo Roles
│           ├── student/             # Screens 2-9
│           ├── instructor/          # Screens 10-11
│           ├── coordinator/         # Screens 12-13
│           └── shared/              # notifications, profile
└── skillbridge_backend/             # FastAPI + Firebase Admin
    ├── app/
    │   ├── main.py
    │   ├── core/                    # config, firebase_admin
    │   ├── api/v1/                  # auth, reports, seed
    │   ├── models/
    │   └── services/
    ├── scripts/seed_demo_data.py
    ├── requirements.txt
    ├── .env.example
    └── Dockerfile
```

## Firestore collections

`users` · `courses` · `campuses` · `batches` · `applications` · `attendance` · `assignments` · `submissions` · `notices` · `notifications`

## Supabase Storage paths

Private bucket `skillbridge-files`; access is always through a short-lived
signed URL, and only the path is stored in Firestore.

- `profile_pictures/{uid}/{fileName}`
- `assignments/{uid}/{assignmentId}_{fileName}`

## Demo accounts

| Role | Email | Description |
| --- | --- | --- |
| Student | student@skillbridge.org | Abdullah — Flutter student |
| Instructor | instructor@skillbridge.org | Sir Hamza — Flutter instructor |
| Coordinator | admin@skillbridge.org | Campus Coordinator — Lahore |

Sign-up always creates a **student**. Instructor and coordinator roles are
assigned by a coordinator (`POST /api/v1/auth/set-role`); a role picked on the
sign-up form is stored as `users/{uid}.requestedRole` and grants nothing. The
Firestore rules enforce this, so it holds for direct client writes too.

## Running it

```bash
# Backend
cd skillbridge_backend
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python -m uvicorn app.main:app --port 8000 --reload
.venv/Scripts/python -m pytest tests/ -q

# Flutter
cd skillbridge_app
flutter pub get
flutter analyze && flutter test
flutter run -d chrome
```

Backend configuration lives in `skillbridge_backend/.env` (see `.env.example`).
`GOOGLE_APPLICATION_CREDENTIALS` must point at a Firebase service-account JSON
or every Firestore-backed route answers 503.

### Demo mode

The seed and demo-account endpoints are disabled unless `DEMO_MODE=true` is set
in the backend environment. They overwrite fixed Firestore documents and
provision the demo logins, so they stay off by default.

## Platform support

The Firebase project currently registers a **web app only**, so `flutter run -d
chrome` works out of the box and Android reports itself unconfigured rather
than silently using the web credentials.

To add Android:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=skillbridge-32f45
```

That registers the Android app, writes `android/app/google-services.json`, adds
the google-services Gradle plugin and regenerates `lib/firebase_options.dart`.

Pick the `applicationId` before running it — it is currently the placeholder
`com.example.bano_qabil_app` (in `android/app/build.gradle.kts`), and a Firebase
Android app is permanently bound to the package name it is registered with.

## Status

Implemented. Backend and Flutter test suites pass; see the test directories for
what is covered.
