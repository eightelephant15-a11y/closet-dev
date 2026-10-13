# Phase 1 checklist: requirement -> code -> tests

Paths are relative to the repo root. "API" tests are `api/tests/...` (pytest + httpx), "App" tests are
`app/test/...` (flutter_test). Status: **Done** = implemented and covered by an automated test that passes
locally; **Partial** = built, with a stated gap; **Not verified** = needs something only you can provide.

## 1. Foundation

| Item | Status | Code | Tests |
|---|---|---|---|
| Monorepo `/app` `/api` `/infra` `/docs` | Done | repo layout | n/a |
| Flavors dev/staging/prod, configurable name + bundle ID | Partial | `app/android/app/build.gradle.kts`, `app/lib/main_{dev,staging,prod}.dart`, `app/lib/core/app_config.dart` | `app/test/widgets/*` use the dev config; debug + release dev APKs built. **iOS schemes not created** (needs Xcode, see gaps) |
| Lint: very_good_analysis; ruff + mypy strict | Done | `app/analysis_options.yaml`, `api/pyproject.toml` | `make lint` passes |
| Pre-commit hooks, Makefile, README one-command setup | Done | `.pre-commit-config.yaml`, `Makefile`, `README.md` | n/a |
| Docker Compose (API + Postgres + Redis) | **Not verified** | `docker-compose.yml`, `api/Dockerfile` | Docker is not installed on the build machine; never run |
| Structured logging, request IDs | Done | `api/app/core/logging.py`, `api/app/core/middleware.py` | `api/tests/api/test_foundation.py::test_health_and_request_id` |
| Sentry (app + API) | Partial | `api/app/main.py`, `app/lib/bootstrap.dart` | wired and compiled; no DSN available so not exercised |
| Standard error model `{code,message,details}` | Done | `api/app/core/errors.py` | `test_foundation.py::test_error_model_for_unknown_route`, `test_api_error_shape` |
| Pagination convention | Done | `api/app/core/pagination.py`, used by `GET /v1/auth/sessions` | `test_auth.py::test_sessions_are_paginated` |
| Idempotency-Key on mutating endpoints | Done | `api/app/core/idempotency.py` (Redis, per-user scope) | `test_foundation.py::test_idempotency_replay_and_reuse`; the app sends a stable key per outbox op |
| Remote config / flags (`guest_mode_enabled`, `onboarding_variant`), DB table, defaults, admin-ready | Done | `api/app/models/user.py::FeatureFlag`, `api/app/services/flags.py`, `api/app/api/v1/config.py` | `api/tests/api/test_config.py` (defaults, override, cache invalidation, validation) |
| Theme tokens, light + dark, one `theme/` package | Done | `app/lib/theme/` | `app/test/theme_contrast_test.dart` |
| Mock mode / fake repositories by flavor | Done | `app/lib/core/providers.dart`, `app/lib/features/*/data/*` mock classes | all app journeys run on fakes |
| OpenAPI as source of truth | Done | `docs/openapi.json` (CI diffs it), `api/app/export_openapi.py` | `app/test/api_contract_test.dart` |

## 2. Auth and accounts

| Item | Status | Code | Tests |
|---|---|---|---|
| `AuthProvider` interface (Apple/email link can be added later) | Done | `app/lib/features/auth/domain/auth_provider.dart`, `.../application/auth_flow.dart` | `session_controller_test.dart` |
| Google sign-in via Firebase | **Not verified** | `.../data/firebase_auth_provider.dart`, `api/app/core/auth.py::FirebaseTokenVerifier` | needs your Firebase project; fakes cover all flows (`FakeAuthProvider`, `FakeTokenVerifier`) |
| Backend verifies tokens, maps to internal users | Done | `api/app/api/v1/auth.py`, `api/app/services/accounts.py` | `api/tests/api/test_auth.py` |
| Token refresh | Done | one refresh-and-retry on 401 in `app/lib/core/network/api_client.dart` | `session_controller_test.dart::tokens refresh on demand` (fake); interceptor not hit against a live server |
| Sign out; multiple device sessions; server-side revoke | Done | `api/app/models/user.py::DeviceSession`, `auth.py` (`/sessions`, `/sign-out`) | `test_auth.py::test_multi_device_sessions_and_revocation`, `test_sign_out_revokes_current_device`, `test_cannot_revoke_other_users_session`; `privacy_test.dart` sign-out |
| `users` table with the required columns, soft delete + 30-day purge job | Done | `api/app/models/user.py`, `api/app/jobs/__main__.py`, `api/app/services/privacy.py` | `api/tests/api/test_privacy.py::test_purge_removes_all_user_data_after_30_days` |
| Guest mode behind `guest_mode_enabled` (off => straight to sign-in) | Done | `app/lib/router/app_router.dart`, `welcome_screen.dart` | `welcome_age_test.dart::guest mode off goes straight to sign-in`, `session_controller_test.dart` |
| Prompt for sign-in only when saving | Done | `SaveSignInSheet` in `first_outfit_screen.dart` | `flows.dart::guestJourney` |
| **Guest upgrade preserves all data** (link credentials, no data loss) | Done | `SessionController.upgradeGuest`, `api/app/services/accounts.py` (`upgrade_guest`, `merge_users`) | App: `session_controller_test.dart` (3 cases: same id, merge into existing, cancelled), `flows.dart::guestJourney`, `privacy_test.dart::guest can sign in from settings`. API: `test_auth.py::test_upgrade_preserves_user_id_and_data`, `test_merge_guest_into_existing_account`, `test_merge_does_not_overwrite_existing_data`, `test_cannot_merge_a_real_account` |

## 3. Onboarding flow

| Step | Status | Code | Tests |
|---|---|---|---|
| 1 Welcome (3 skippable screens, "Try it first" / "Sign in with Google") | Done | `onboarding/presentation/welcome_screen.dart` | `widgets/welcome_age_test.dart` |
| 2 Age confirmation 16+, under-16 block, no data kept | Done | `age_gate_screen.dart`, `blocked_screen.dart`, `OnboardingController.rejectAge`, `POST /v1/me/age-confirmation` | `welcome_age_test.dart` (block, survives restart, no local data); API `test_onboarding.py::test_under_16_deletes_account_data` |
| 3 Style quiz: 6 swipe cards, `clothing_department` first, adaptive never-wear | Done | `quiz_screen.dart`, `domain/quiz.dart` | `widgets/quiz_test.dart` (full quiz, men vs women options, back, swipe gating, resume, offline) |
| 4 Basics: name, units (imperial default), city via `PlacesService`, no GPS | Done | `basics_screen.dart`, `features/places/places_service.dart`, `GET /v1/places/autocomplete` | `widgets/steps_d_test.dart::Basics`, API `test_sample.py` |
| 5 Permission priming in context with working fallbacks | Done | `features/permissions/`, `core/permissions/permissions_service.dart`, notifications primed in `optional_screens.dart` | `steps_d_test.dart::Permission priming` (incl. all-denied still unlocks via sample closet) |
| 6 "Add first 10 items" shell: ring + unlock rule + sample closet shortcut | Done | `first_items_screen.dart`, `closet/domain/unlock_rule.dart`, `StubClosetRepository` | `unlock_and_recommendation_test.dart`, `steps_d_test.dart::First items shell` |
| 7 First outfit + 2 alternatives with "why", behind `RecommendationService` | Done | `first_outfit_screen.dart`, `recommendation/domain/recommendation.dart` (fake) | `unlock_and_recommendation_test.dart`, `steps_d_test.dart::First outfit` |
| 8 Optional: invite partner (placeholder), daily outfit time; revisitable from Home | Done | `optional/optional_screens.dart`, `home_screen.dart` | `steps_d_test.dart::Optional steps` |
| Progress persisted locally + server; resume after kill; deep link | Done | `OnboardingController`, `router/app_router.dart` (`/onboarding/resume`, `/resume`), Android intent filter + iOS URL scheme `stylist://` | `quiz_test.dart` (kill mid-quiz), `steps_d_test.dart::Variants and resume`, `privacy_test.dart::second device`, `router_redirect_test.dart`; API `test_onboarding.py` |
| Quiz -> versioned preference model (`preferences`, JSONB + version); test that answers change weights | Done | `api/app/domain/preferences.py`, `api/app/models/onboarding.py`, `app/.../preference_model.dart` | `api/tests/unit/test_preferences.py`, `app/test/preference_model_test.dart` |
| `onboarding_variant` flag: `quiz_first` full, `closet_first` reorders 3 and 6 | Done | `onboarding_step.dart::stepsFor`, variant pinned server-side on first read | `steps_d_test.dart::closet_first...`, `router_redirect_test.dart`, API `test_onboarding_state_defaults_and_pins_variant` |

## 4. Privacy, consent, account controls

| Item | Status | Code | Tests |
|---|---|---|---|
| Consent centre: analytics opt-in; no-AI-training ON by default with timestamp + policy version; location explained | Done | `features/consent/`, `api/app/api/v1/privacy.py`, `consents` table | `privacy_test.dart::Consent centre`, API `test_privacy.py` (defaults, timestamps, privacy) |
| Settings: sign out | Done | `settings/settings_screen.dart` | `privacy_test.dart::Settings` |
| Export my data (async job -> JSON file) | Done | `data_rights/`, `POST/GET /v1/me/export`, `python -m app.jobs exports` | `privacy_test.dart::Export my data`, API `test_export_*`, `test_worker_processes_pending_exports` |
| Delete my account (confirmation; data + images removed within 30 days; verified by test) | Done | `delete_account_screen.dart`, `DELETE /v1/me`, `purge_due_users` + `PURGE_HOOKS` (images in Phase 2) | API `test_purge_removes_all_user_data_after_30_days` (time travel: rows, export files, hook, Firebase user, audit log without PII), `test_delete_signs_out_everywhere...`, `test_restore_within_window`; App `privacy_test.dart::Delete my account` |
| Privacy policy / terms links (placeholder, configurable) | Done | `GET /v1/config` -> settings screen | `privacy_test.dart::policy and terms links open the configured URLs` |
| Private by default; one user cannot read another's profile/preferences | Done | every route is scoped to the token's user; no endpoint takes a foreign id | API `test_onboarding.py::test_users_cannot_read_each_others_onboarding_or_preferences`, `test_privacy.py` (consents, exports) |

## 5. Analytics

| Item | Status | Code | Tests |
|---|---|---|---|
| Taxonomy doc + typed enum | Done | `docs/analytics.md`, `app/lib/core/analytics/analytics_event.dart` | `analytics_taxonomy_test.dart` (every event documented and emitted, property contracts) |
| Consent respected (nothing before opt-in) | Done | `ConsentGatedAnalytics`, consent prompt after age gate | `analytics_gate_test.dart`, `privacy_test.dart::Analytics consent` |
| PostHog behind `AnalyticsService` | Partial | `posthog_analytics.dart` | compiled into the release APK; not run against a live project |
| Time-to-first-outfit as event property | Done | `OnboardingController.firstOutfitViewed` | `flows.dart::expectFunnel`, `steps_d_test.dart::First outfit` |
| `onboarding_abandoned` with last step | Done | `core/analytics/abandonment_tracker.dart` | `analytics_taxonomy_test.dart` |

## 6. Quality bar

| Item | Status | Evidence |
|---|---|---|
| Unit tests for domain logic | Done | `preference_model_test`, `unlock_and_recommendation_test`, `outbox_test`, `router_redirect_test`, `api/tests/unit` |
| Widget tests for each onboarding screen | Done | `widgets/welcome_age_test` (welcome, sign-in, age, blocked), `quiz_test`, `steps_d_test` (basics, permissions, first items, first outfit, optional, partner, notification time), `privacy_test` (settings, consent, export, delete, restore) |
| Integration tests: full guest flow and full Google flow (fakes) | Done | `test/flows/flows.dart` run by `test/flows/journeys_test.dart` (CI) and `integration_test/onboarding_flow_test.dart` (device) |
| API tests (pytest + httpx), migration test | Done | `api/tests/` (56 tests), `tests/test_migrations.py` (up, no model drift, down). SQLite locally; Postgres when `MIGRATION_TEST_DATABASE_URL` is set (CI does) |
| Accessibility | Partial | 48dp targets and AA contrast enforced by `theme_contrast_test`; semantic labels/selected state on quiz options, progress, ring, headings; 2x text scale smoke test. **Not tested with TalkBack/VoiceOver** |
| Empty/loading/error states | Done | `shared/widgets/state_views.dart`, used by splash, first items, first outfit (empty), export (failed), places (no matches) |
| Offline-tolerant, queue + sync | Done | `core/sync/outbox.dart`, `sync_triggers.dart` | `outbox_test.dart`, `quiz_test.dart::offline`, `offline_sync_test.dart` |
| Mid-range Android / iPhone 12+; cold start < 2 s release | **Not verified** | debug and release dev APKs build; no device/emulator available here, so no startup numbers. Startup work is minimal (prefs open, runApp, async boot) |
| No secrets in repo, `.env.example`, secrets via Secrets Manager | Done | `api/.env.example`, `infra/modules/secrets`, `infra/modules/database` |
| Each feature behind flags or isolated | Done | guest mode + onboarding variant flags; feature folders; interfaces for closet/recommendations |

## 7. Infra and CI

| Item | Status | Evidence |
|---|---|---|
| Terraform staging + prod modules, plan-ready, nothing applied | Partial | `infra/`; `terraform fmt` + `terraform validate` pass for both envs (CI job `ci-infra`). **No `plan` was run (needs AWS credentials)** and nothing was applied |
| GitHub Actions: lint/test/build app + API; deploy workflows disabled | Partial | `.github/workflows/ci-{api,app,infra}.yml`, `deploy-staging.yml` (jobs `if: false`). No GitHub remote exists yet, so CI has not run; the same commands pass locally |

## Known gaps and what I need from you

1. **Firebase project(s)** and config files for Google sign-in (see `docs/firebase-setup.md`); the Firebase
   implementations were compiled, never run.
2. **Final bundle ID**, signing keys, and **iOS flavor schemes** (Android flavors are done; iOS needs schemes
   and xcconfigs created in Xcode; no simulator runtime is installed here, so no iOS build was attempted).
3. **Sentry DSN, PostHog key, AWS account/region**; the domain + ACM certificate for prod.
4. Docker was unavailable, so `docker-compose.yml` was not run and the API was tested on SQLite (migrations
   are exercised on SQLite locally and Postgres in CI).
5. Real-device checks: cold start time, TalkBack/VoiceOver, low-end Android performance.
6. Sentry crash reporting is not tied to the analytics opt-in (decision 18); confirm with counsel.
7. `google_sign_in` 7.x needs the server client ID (`--dart-define=GOOGLE_SERVER_CLIENT_ID=...`).
