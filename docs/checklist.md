# Phase 1 checklist: requirement -> code -> evidence

Every item has exactly one status:

* **Verified (by test)**: an automated test that passes locally *and* in CI covers it (the test is named).
* **Verified (by CI)**: proven by a CI job that builds or runs it on a clean machine (job named; green on commit `3e503c0`, run ids in the log of `gh run list`).
* **Blocked on `<what>`**: built, but cannot be proven without an account or device only you have. The step that unblocks it is in
  [go-live-checklist.md](go-live-checklist.md).

Paths are relative to the repo root. `api/tests/...` = pytest, `app/test/...` = flutter_test.
CI jobs: **api** = `api lint + mypy + pytest`, **smoke** = `real local server + smoke test (no Docker)`, **app** = `app format + analyze + test`,
**android** = `android debug build (dev flavor)`, **ios-dev/staging/prod** = `ios build, no code signing (<flavor>)` (also checks the built app's bundle ID and display name),
**tf** = `terraform fmt + validate (staging|prod)`, **scan** = `secret scan (gitleaks)`, **make** = `makefile targets resolve`.
Counts at the time of writing: 85 API tests, 151+ app tests (including the accessibility tours).

## 1. Foundation

| Item | Status | Code | Evidence |
|---|---|---|---|
| Monorepo layout `/app /api /infra /docs` | Verified (by CI) | repo root | all jobs run from it |
| Android flavors dev/staging/prod (name, ID suffix, deep-link scheme in one table) | Verified (by CI) | `app/android/app/build.gradle.kts` | **android**; debug + release dev APKs also built locally |
| **iOS flavors** dev/staging/prod: schemes, configurations, per-flavor name/bundle ID/icon, Firebase plist slot | Verified (by CI) | `app/ios/Flutter/flavors/*.xcconfig`, `app/ios/Runner.xcodeproj` (schemes `dev`/`staging`/`prod`), `app/tool/setup_ios_flavors.rb` | **ios-dev/staging/prod** print `com.example.stylist.dev` / `Stylist Dev`, `.staging` / `Stylist Staging`, `com.example.stylist` / `Stylist`; `app/test/ios_strings_in_sync_test.dart` (files, icons, distinct IDs and schemes) |
| iOS permission strings localised from the ARB | Verified (by test) | `app/tool/gen_ios_strings.py`, `ios/Runner/en.lproj/InfoPlist.strings` | `ios_strings_in_sync_test.dart`; **app** regenerates and diffs them |
| iOS deep-link scheme + associated-domains placeholders | Verified (by CI) | `Info.plist`, `Runner.entitlements`, flavor xcconfigs | **ios-*** builds; universal links need a real domain: Blocked on domain + Apple team |
| Make targets for every flavor x platform | Verified (by CI) | `Makefile` | **make** dry-runs all of them |
| Lint (very_good_analysis; ruff + mypy strict), pre-commit | Verified (by CI) | `app/analysis_options.yaml`, `api/pyproject.toml` | **app**, **api** |
| Docker Compose | **Blocked on Docker** (unverified) | `docker-compose.yml` | marked "unverified" in README; never run |
| Structured logging, request IDs, error model, pagination, idempotency | Verified (by test) | `api/app/core/*` | `api/tests/api/test_foundation.py`, `test_auth.py::test_sessions_are_paginated` |
| Feature flags (`guest_mode_enabled`, `onboarding_variant`) | Verified (by test) | `api/app/services/flags.py` | `api/tests/api/test_config.py`, smoke |
| Theme tokens, light + dark | Verified (by test) | `app/lib/theme/` | `app/test/theme_contrast_test.dart` |
| Mock mode (fake repositories) | Verified (by test) | `app/lib/core/providers.dart` | all `app/test/flows/*`, `widgets/*` |
| **Real API locally without Docker** (`make api-local`: SQLite, fake Redis, migrations, flag seeding) | Verified (by CI) | `api/app/local_server.py` | **smoke** starts the real server and runs the smoke script (17/17) |
| **Dev auth guard**: `AUTH_MODE=dev` impossible unless `APP_ENV` is dev/local/test; `ENV=prod`, staging, typos all refused | Verified (by test) | `api/app/core/config.py`, `api/app/core/auth.py` | `api/tests/api/test_dev_auth_and_smoke.py` (prod, production, staging, empty, `ENV` alias, forged settings, route absent in firebase mode) |
| Smoke script hits every `/v1` endpoint and fails on uncovered ones | Verified (by CI) | `api/app/smoke.py` | **smoke**; `test_smoke_fails_loudly_when_an_operation_is_not_covered` |
| App can target the local API (`make run-app-local-api`) | Verified (by test) | `app/lib/features/auth/data/dev_auth_provider.dart`, `AppConfig.useDevAuth` | `app/test/dev_auth_test.dart` (dev flavor only; staging/prod never use it). Running on a device: Blocked on a device |
| OpenAPI as source of truth | Verified (by CI) | `docs/openapi.json` | **api** diff step; `app/test/api_contract_test.dart` |
| Sentry (app + API) | Blocked on Sentry DSN | `api/app/main.py`, `app/lib/bootstrap.dart` | compiles in release APK + iOS builds |

## 2. Auth and accounts

| Item | Status | Code | Evidence |
|---|---|---|---|
| `AuthProvider` interface; Apple/email-link can be added without touching onboarding | Verified (by test) | `app/lib/features/auth/domain/auth_provider.dart` | `session_controller_test.dart` |
| Google sign-in through Firebase | **Blocked on Firebase project** | `firebase_auth_provider.dart`, `FirebaseTokenVerifier` | compiled (Android + iOS CI builds); runbook steps 2 to 8 |
| Token verification, internal users, token refresh, sessions, sign-out, server revoke | Verified (by test) | `api/app/api/v1/auth.py`, `app/lib/core/network/api_client.dart` | `api/tests/api/test_auth.py` (multi-device, revoke, sign-out, cross-user), smoke |
| `users` table + soft delete + 30-day purge job | Verified (by test) | `api/app/models/user.py`, `api/app/jobs/__main__.py` | `test_privacy.py::test_purge_removes_all_user_data_after_30_days` |
| Guest mode behind `guest_mode_enabled` | Verified (by test) | `app/lib/router/app_router.dart` | `welcome_age_test.dart::guest mode off goes straight to sign-in` |
| Guest -> account upgrade keeps all data (link + merge) | Verified (by test) | `SessionController.upgradeGuest`, `api/app/services/accounts.py` | `session_controller_test.dart`, `flows.dart::guestJourney`, `test_auth.py` (4 upgrade/merge tests), smoke "guest upgrade keeps data" and "merge guest into existing account". Real Firebase link: Blocked on Firebase project |

## 3. Onboarding

| Step | Status | Evidence |
|---|---|---|
| Welcome, age gate (16+, block screen, nothing kept), style quiz, basics, permission priming with fallbacks, first-items shell, first outfit, optional steps | Verified (by test) | `widgets/welcome_age_test.dart`, `quiz_test.dart`, `steps_d_test.dart`, `unlock_and_recommendation_test.dart`; API `test_onboarding.py` |
| Full guest journey and full Google journey (fakes) | Verified (by test) | `app/test/flows/journeys_test.dart`; `integration_test/` re-runs them on a device |
| Resume after kill / second device / deep link | Verified (by test) | `quiz_test.dart`, `steps_d_test.dart::Variants and resume`, `privacy_test.dart::second device`, `router_redirect_test.dart`. Real OS deep link tap: Blocked on a device |
| Preference model (versioned, answers change weights) | Verified (by test) | `api/tests/unit/test_preferences.py`, `app/test/preference_model_test.dart` |
| `onboarding_variant` flag, `closet_first` reorder | Verified (by test) | `steps_d_test.dart`, `test_onboarding.py` |

## 4. Privacy, consent, account controls

| Item | Status | Evidence |
|---|---|---|
| Consent centre (analytics opt-in, no-AI-training ON by default with timestamp + policy version, location explained) | Verified (by test) | `privacy_test.dart`, `api/tests/api/test_privacy.py` |
| Export my data (async JSON), delete my account (30 days, verified by test), restore | Verified (by test) | `test_privacy.py` (time-travel purge incl. files, hooks, Firebase user, audit trail), `privacy_test.dart`, smoke |
| Policy/terms links configurable | Verified (by test) | `privacy_test.dart::policy and terms links...` |
| One user cannot read another's data | Verified (by test) | `test_onboarding.py::test_users_cannot_read_each_others_...`, `test_privacy.py`, smoke "cross-user privacy" |
| Secret scanning | Verified (by CI) | **scan** (gitleaks, `.gitleaks.toml`) |

## 5. Analytics

| Item | Status | Evidence |
|---|---|---|
| Typed taxonomy + docs; every event documented and emitted; property contracts | Verified (by test) | `app/test/analytics_taxonomy_test.dart`, `docs/analytics.md` |
| Consent gating (nothing before opt-in) | Verified (by test) | `analytics_gate_test.dart`, `privacy_test.dart::Analytics consent` |
| Time-to-first-outfit property; `onboarding_abandoned` | Verified (by test) | `flows.dart::expectFunnel`, `analytics_taxonomy_test.dart` |
| Startup timing event `app_first_frame` | Verified (by test) | `app/test/startup_timer_test.dart`. Real numbers: Blocked on a device |
| PostHog live | **Blocked on PostHog key** | `app/lib/core/analytics/posthog_analytics.dart` |

## 6. Quality bar

| Item | Status | Evidence |
|---|---|---|
| Unit, widget, journey tests; API tests; migration test | Verified (by CI) | **app**, **api** (migration test also runs against Postgres in CI via `MIGRATION_TEST_DATABASE_URL`) |
| **Accessibility**: tap targets 48dp (Android) / 44pt (iOS), labelled controls, WCAG AA text contrast, no overflow at 100/150/200% text, light + dark, ~25 screens | Verified (by test) | `app/test/accessibility_test.dart` (found and fixed real overflows on the settings, sign-in, age-gate, blocked, restore and partner screens) |
| Theme token contrast AA (text 4.5:1, outlines 3:1) both modes | Verified (by test) | `app/test/theme_contrast_test.dart` |
| Screen-reader behaviour on a real device (TalkBack / VoiceOver) | **Blocked on a device** | runbook step 11 has the scripted walkthrough |
| Empty/loading/error states, offline queue + sync | Verified (by test) | `shared/widgets/state_views.dart`, `outbox_test.dart`, `offline_sync_test.dart` |
| Cold start < 2 s on a mid-range Android and iPhone 12+ | **Blocked on a device** | `app/tool/measure_startup.sh`, [performance.md](performance.md) |
| Release build works offline-capable network access | Verified (by test) | found by this pass: the release manifest lacked `INTERNET`; added (`AndroidManifest.xml`); release APK builds locally |
| No secrets in repo; `.env.example`; Secrets Manager via Terraform | Verified (by CI) | **scan**, `infra/modules/secrets` |

## 7. Infra and CI

| Item | Status | Evidence |
|---|---|---|
| Terraform staging + prod, never applied | Verified (by CI) for fmt/validate; `plan` **Blocked on AWS credentials** | **tf** (both envs); runbook step 10 |
| Required CI jobs: app lint+test, api ruff+mypy+pytest, iOS no-codesign build (x3 flavors), Android debug build, Terraform fmt+validate | Verified (by CI) | green on `3e503c0`; **branch protection on `main` requires all of them** (admins can still push; force-push and deletion blocked) |
| Dependency scanning | Verified (by CI) | `.github/dependabot.yml` (pub, pip, docker, terraform, actions, gradle) opened its first runs on push |
| Deploy workflow | Blocked on AWS OIDC role | `deploy-staging.yml` stays disabled (`if: false`) |

## What CI caught during this pass (so the checks are real)

1. `dart format` differed between Flutter 3.47 (CI default) and 3.41.9 (local) -> Flutter is now pinned.
2. iOS build failed: `firebase_auth` needs iOS 15, project targeted 13 -> minimum iOS raised to 15 (Podfile, Xcode project, pod post-install).
3. Release Android builds had no `INTERNET` permission (found while adding local-API support).
4. Settings and five other screens overflowed on a phone-size surface at 200% text (found by the new accessibility tour).

## Still blocked, and on what

| Blocked on | Items |
|---|---|
| Firebase project + config files | real Google sign-in and guest-link; runbook 2 to 8 |
| Physical device(s) | cold start, TalkBack/VoiceOver, OS deep link, low-end Android feel |
| AWS account + credentials | `terraform plan/apply`, deploy workflow, Docker-free staging smoke over HTTPS |
| PostHog key / Sentry DSNs | live analytics and crash reports |
| Docker | `docker-compose.yml` run (marked unverified) |
| Final bundle ID, domain, Apple team | store-ready identity, universal links, signed iOS builds |
