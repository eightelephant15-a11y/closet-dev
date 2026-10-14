# Stylist: AI personal & couple stylist (Phase 1: onboarding, Phase 2: digital closet)

A wardrobe-based stylist. **Phase 1** ships the foundation, sign-in, guest mode, the preference quiz,
the full onboarding journey, permissions, consent/privacy controls, data export/deletion and onboarding
analytics. **Phase 2** adds the digital closet: take or pick a photo, it uploads in the background, an AI fills in
the details, you correct with one tap, then browse, filter, edit, mark unavailable, archive or delete. Recommendations,
couples and payments are later phases and only have extension points (`RecommendationService`, `excluded_from_outfits`, entitlements).

Everything that needs an outside account sits behind an interface with a fake that works with none (storage, queue, vision,
background removal, camera). The real implementations are built and marked **unverified** until run with real keys
([docs/checklist.md](docs/checklist.md), [docs/go-live-checklist.md](docs/go-live-checklist.md) steps 13 to 16).

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
resuming works), canned city autocomplete, and a pretend closet backend (`MockClosetBackend`) that runs the whole add flow: signed-ticket upload,
processing, a deterministic fake AI that reads hints from the file name (`navy_jeans_f2.jpg`), the 30-item limit. The same interfaces are implemented over
HTTP for the real API, selected with `USE_MOCK=false` and `--dart-define=API_BASE_URL=...`.

### Run the real API locally, no Docker

```bash
make api-local          # FastAPI + SQLite + in-process fake Redis; migrates, seeds flags; http://127.0.0.1:8000
make api-smoke          # hits every /v1 endpoint on that server, prints PASS/FAIL (20 checks, incl. the closet flow)
make run-app-local-api  # Flutter dev flavor talking to it (no mock, no Firebase)
make eval-vision        # AI accuracy report on the bundled synthetic photos (free, no network)
```

`make api-local` also starts the **job worker** (image processing + AI analysis) against the in-process fake Redis and stores photos
on local disk with signed URLs. To run the pieces separately: `make redis-local` and `make worker-local` (`make api-local WORKER=external`).

`make api-local` uses `AUTH_MODE=dev`: instead of Firebase, the server accepts HMAC-signed dev tokens that
the app gets from `POST /dev/token`. **This mode cannot be enabled outside `APP_ENV` in `dev|local|test`**:
the settings refuse to load (tests in `api/tests/api/test_dev_auth_and_smoke.py` cover prod, staging, `ENV=prod`,
typos and empty values), the `/dev/token` route is only mounted in dev mode, and the Flutter app only honours it
in the `dev` flavor. Set `DATABASE_URL` to use a local Postgres instead of SQLite and `REDIS_URL` for a real Redis.
On an Android emulator `localhost` is mapped to `10.0.2.2` automatically; on a physical phone pass
`API_BASE_URL=http://<your-LAN-IP>:8000`. Details: [docs/local-api.md](docs/local-api.md).

### Docker Compose (**unverified**)

`make up` starts the API with Postgres and Redis in containers. The compose file has **not been run yet**
(Docker is not installed on the machine this was built on). Treat it as a draft until someone has run it
and removed this note.

```bash
cp api/.env.example api/.env && make up && curl localhost:8000/health
```

Real Firebase auth (non-dev) needs the Firebase Auth emulator or a dev project; see
[docs/firebase-setup.md](docs/firebase-setup.md).

## Architecture in one screen

```
Flutter  presentation -> application (Riverpod controllers) -> domain (pure Dart) <- data (Mock | Http)
   local-first: every change is saved to disk and queued in an outbox (idempotency keys) -> syncs when online
FastAPI  routers -> services -> SQLAlchemy models -> Postgres ; Redis for idempotency keys + flag cache
   /v1/*, error model {error:{code,message,details}}, X-Request-ID, Idempotency-Key, Page{items,next_cursor}
Auth     Firebase (Google, anonymous guest) behind AuthProvider / TokenVerifier interfaces
Closet   phone -> POST /v1/garments -> signed upload straight to ObjectStorage (local disk | S3) -> /complete
         -> Redis queue (arq) -> worker: validate, rotate, strip EXIF/GPS, WebP thumbnails -> VisionProvider (fake | Claude)
         -> fields + confidence stored once; the app shows the review screen while this happens
```

Details: [docs/phase1-plan.md](docs/phase1-plan.md) (original plan), [docs/decisions.md](docs/decisions.md)
(every choice made along the way), [docs/analytics.md](docs/analytics.md), [infra/README.md](infra/README.md).

* **Flags**: `GET /v1/config` returns server-driven flags from the `feature_flags` table (defaults in code):
  `guest_mode_enabled` (true), `onboarding_variant` (`quiz_first` | `closet_first`), `closet_bulk_add_enabled` (true),
  `closet_item_limit_free` (30) and `vision_provider` (`fake` | `claude`, default `fake`). `set_flag()` in
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

## More docs

| Doc | What it is |
|---|---|
| [docs/go-live-checklist.md](docs/go-live-checklist.md) | ordered runbook for when you have Firebase / AWS / PostHog / Sentry accounts and a real device |
| [docs/placeholders.md](docs/placeholders.md) | every placeholder value and the file to change it in |
| [docs/rename-app.md](docs/rename-app.md) | app name, bundle ID, icons, Firebase files, iOS + Android flavors |
| [docs/local-api.md](docs/local-api.md) | running the real API without Docker; dev tokens and their safety rules |
| [docs/phase2-plan.md](docs/phase2-plan.md) | Phase 2 design: architecture, job flow, schema, endpoints, risks |
| [docs/vision-eval.md](docs/vision-eval.md) | measuring AI tagging accuracy, including on your own 300 labelled photos |
| [docs/performance.md](docs/performance.md) | cold start on a device; closet budgets (API p95, image pipeline, 500-item grid) |
| [docs/checklist.md](docs/checklist.md) | requirement -> code -> test mapping with an honest status per item |

## Tooling notes

* **macOS + Xcode**: `make`, `pod install` and Flutter native-asset builds all stop with "You have not agreed to the Xcode license" until you run
  `sudo xcodebuild -license accept` once.
* **Flutter version** is pinned in CI (`FLUTTER_VERSION` in `.github/workflows/ci-app.yml`); `dart format` output changes between SDK releases, so use
  the same version locally (3.41.9 at the time of writing).
* iOS flavors are defined by `app/ios/Flutter/flavors/*.xcconfig`; `make ios-flavors-setup` re-applies them to the Xcode project.

## Known gaps and things only you can supply

See the end of [docs/checklist.md](docs/checklist.md) for the honest list (Firebase project and config files, real-device performance numbers,
Docker/compose not exercised, ...).
