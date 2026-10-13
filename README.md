# Stylist: AI personal & couple stylist (Phase 1: account + onboarding)

A wardrobe-based stylist. **This phase** ships the foundation, sign-in, guest mode, the preference quiz,
the full onboarding journey, permissions, consent/privacy controls, data export/deletion and onboarding
analytics. Closet capture, recommendations, couples and payments are later phases and only have
extension points (`ClosetRepository`, `RecommendationService`, purge hooks).

| Path | What |
|---|---|
| [app/](app) | Flutter app (Riverpod, go_router, dio, freezed). Flavors `dev` / `staging` / `prod` |
| [api/](api) | FastAPI + SQLAlchemy 2 + Alembic + Pydantic v2, Postgres, Redis |
| [infra/](infra) | Terraform for AWS (validated, **never applied**) |
| [docs/](docs) | plan, decisions, analytics taxonomy, OpenAPI, requirement checklist |

## One-command setup

```bash
make setup      # python venv + API deps, flutter pub get, l10n + codegen, pre-commit hooks
make test       # API (pytest) + app (flutter test)
make run-mock   # run the app with NO cloud: fake auth, fake API, local persistence
```

Prerequisites: Python 3.12, Flutter (stable, 3.41+), optionally Docker and pre-commit.

### Run the app without any cloud (mock mode)

`flutter run --flavor dev -t lib/main_dev.dart --dart-define=USE_MOCK=true` (what `make run-mock` does).
In mock mode the repositories are in-process fakes selected in `app/lib/core/providers.dart`: a fake Google
sign-in (account "Ada Lovelace"), a fake backend that persists in local storage (so killing the app and
resuming works), canned city autocomplete and the sample closet. The same interfaces are implemented over
HTTP for the real API, selected with `USE_MOCK=false` and `--dart-define=API_BASE_URL=...`.

### Run the real API locally

```bash
cp api/.env.example api/.env      # edit as needed; no secrets are committed
make up                           # docker compose: api + postgres + redis (applies migrations)
curl localhost:8000/health
curl localhost:8000/v1/config
open localhost:8000/docs          # Swagger UI
```

Authenticated endpoints verify Firebase ID tokens. Locally use the Firebase Auth emulator
(`FIREBASE_AUTH_EMULATOR_HOST`) or a dev project; see [docs/firebase-setup.md](docs/firebase-setup.md).

## Architecture in one screen

```
Flutter  presentation -> application (Riverpod controllers) -> domain (pure Dart) <- data (Mock | Http)
   local-first: every change is saved to disk and queued in an outbox (idempotency keys) -> syncs when online
FastAPI  routers -> services -> SQLAlchemy models -> Postgres ; Redis for idempotency keys + flag cache
   /v1/*, error model {error:{code,message,details}}, X-Request-ID, Idempotency-Key, Page{items,next_cursor}
Auth     Firebase (Google, anonymous guest) behind AuthProvider / TokenVerifier interfaces
```

Details: [docs/phase1-plan.md](docs/phase1-plan.md) (original plan), [docs/decisions.md](docs/decisions.md)
(every choice made along the way), [docs/analytics.md](docs/analytics.md), [infra/README.md](infra/README.md).

* **Flags**: `GET /v1/config` returns server-driven flags from the `feature_flags` table (defaults in code):
  `guest_mode_enabled` (true) and `onboarding_variant` (`quiz_first` | `closet_first`). `set_flag()` in
  `api/app/services/flags.py` is the write path a future admin panel will call.
* **Onboarding** is a local-first state machine (`OnboardingController`), resumable after a kill, across
  devices (server copy) and via the deep link `stylist://onboarding/resume`.
* **Preferences** are a versioned model (`preferences` table, JSONB + `model_version`), computed from quiz
  answers by `api/app/domain/preferences.py` and mirrored in `app/lib/features/onboarding/domain/`.
* **Privacy**: private by default (no endpoint addresses another user), consent centre, export job, 30-day
  deletion with a purge job; see the checklist for the tests.

## Configuration

* Flavors: `dev` -> `com.example.stylist.dev`, `staging` -> `.staging`, `prod` -> `com.example.stylist`
  (placeholder). App display name per flavor is set in `android/app/build.gradle.kts` and
  `app/lib/core/app_config.dart`.
* Build-time: `--dart-define=USE_MOCK=true|false`, `API_BASE_URL`, `SENTRY_DSN`, `POSTHOG_KEY`.
* Legal links come from the API (`PRIVACY_POLICY_URL`, `TERMS_URL`) with app-side fallbacks (placeholders).
* Theme: swap brand colours/fonts in one place: `app/lib/theme/tokens.dart`.
* Strings: all user-facing text is in `app/lib/l10n/app_en.arb` (US English only).

## Quality gates

`make lint` (ruff + mypy --strict, `dart format` + `flutter analyze` with very_good_analysis), `make test`.
CI (GitHub Actions): `ci-api`, `ci-app`, `ci-infra`; `deploy-staging` exists but is **disabled**.
`integration_test/` re-runs the two full journeys on a device/emulator:
`flutter test integration_test --flavor dev`.

## Known gaps and things only you can supply

See the end of [docs/checklist.md](docs/checklist.md) for the honest list (Firebase project and config files,
real-device performance numbers, iOS flavor schemes, Docker/compose not exercised on the build machine, ...).
