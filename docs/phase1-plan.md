# Phase 1 Plan: Account and Onboarding

Status: **awaiting approval. No code written yet.**

## 1. Architecture

```
Flutter app (Riverpod, go_router, dio, freezed)
  presentation (screens, widgets)  ->  application (controllers/notifiers)
  domain (entities, interfaces, pure logic)  <-  data (repos: Mock | Http)
  Interfaces: AuthProvider, AnalyticsService, PlacesService, ClosetRepository,
              RecommendationService, ConfigRepository, OnboardingRepository,
              PreferencesRepository, ConsentRepository, AccountRepository
  Flavor (dev|staging|prod) selects Mock vs Http implementations via Riverpod overrides.
        |
        | HTTPS /v1 (Firebase ID token, Idempotency-Key, X-Request-ID)
        v
FastAPI (async)  routers -> services -> repositories -> SQLAlchemy 2 (asyncpg) -> PostgreSQL
  middleware: request-id, structured logging (structlog), Sentry, error model, idempotency
  deps: Firebase token verifier (interface, fake in tests), Redis (idempotency, rate-limit, flag cache)
  jobs: purge (30d), export (async) -- worker entrypoint `python -m app.jobs`, run by ECS scheduled task
```

Key decisions:
- **Mock mode**: fake repositories selected by flavor/`--dart-define=USE_MOCK=true` (in-memory + local persistence). FastAPI contract is identical, enforced by generating the Dart client models from the OpenAPI schema (`openapi.json` committed; CI fails on drift).
- **Offline queue**: onboarding mutations go to a local outbox (drift/sqlite or Hive; I'll use `drift`), replayed with idempotency keys on reconnect.
- **Auth**: `AuthProvider` (signInWithGoogle, signInAnonymously, linkGoogle, signOut, idToken stream). Implementations: `FirebaseAuthProvider`, `FakeAuthProvider`. Guest upgrade uses `linkWithCredential` so the Firebase UID, and therefore internal user id, is preserved: no data migration. Fallback when the Google credential already belongs to an existing account: server-side merge endpoint (see API), tested.
- **Sessions**: `sessions` table keyed by device + Firebase token `auth_time`/session id; server revocation = `revoked_at` check on each request (cached in Redis) plus Firebase `revokeRefreshTokens`.
- **Flags**: `feature_flags` table, served by `GET /v1/config` with defaults in code, 60s Redis cache. Admin write path = service layer only (no UI/router now).
- **Consent gating**: `AnalyticsService` wrapper drops events until analytics consent is true, except a tiny allow-list of consent-free events documented in `analytics.md` (open question below).
- **Preferences**: quiz answers -> `PreferenceModel` v1 (weights per attribute, pure function in domain, mirrored server-side and validated there).

## 2. Folder structure

```
/app
  lib/
    main_{dev,staging,prod}.dart
    core/ (config, flavors, errors, logging, l10n helpers, network, outbox)
    theme/ (tokens: color, type, spacing, radius, motion; light/dark; ThemeData builder)
    features/
      auth/ onboarding/ quiz/ basics/ permissions/ first_items/ first_outfit/
      consent/ settings/ home/ analytics/ config/
        {domain,data,application,presentation}/
    l10n/app_en.arb
    router/ (go_router, redirect/resume logic, deep links)
  test/ integration_test/ android/ ios/ (flavors: dev/staging/prod)
/api
  app/ (main.py, api/v1/*, core/, models/, schemas/, services/, repositories/, jobs/)
  alembic/ tests/ (unit, api, migration) pyproject.toml Dockerfile .env.example
/infra
  modules/ (network, rds, redis, ecs_api, secrets, ecr, iam, observability)
  envs/staging envs/prod  (plan only)
/docs  phase1-plan.md decisions.md analytics.md api.md checklist.md
/.github/workflows  ci-app.yml ci-api.yml ci-infra.yml deploy-staging.yml (disabled)
docker-compose.yml  Makefile  .pre-commit-config.yaml  README.md
```

## 3. API endpoints (all under `/v1`; OpenAPI is the source of truth)

Conventions: errors `{code, message, details}`; `X-Request-ID` echoed; mutating endpoints accept `Idempotency-Key` (stored 24h in Redis + DB fallback); pagination `?limit=&cursor=` returning `{items, next_cursor}`.

| Method | Path | Purpose |
|---|---|---|
| GET | /health, /ready | liveness/readiness (unversioned) |
| GET | /v1/config | flags (+ policy versions, legal URLs) |
| POST | /v1/auth/session | verify Firebase ID token, upsert user, register device session |
| POST | /v1/auth/upgrade | after client-side link; mark user non-anonymous, copy email/name (merge fallback via `merge_from_token`) |
| GET | /v1/auth/sessions | list device sessions |
| DELETE | /v1/auth/sessions/{id} | revoke a session |
| POST | /v1/auth/sign-out | revoke current session |
| GET / PATCH | /v1/me | profile (display_name, locale, units, city, clothing_department) |
| POST | /v1/me/age-confirmation | 16+ confirmation (stores timestamp only, no DOB) |
| GET | /v1/onboarding | current state (step, completed steps, variant) |
| PUT | /v1/onboarding | idempotent state update (step, answers meta, started_at, completed_at) |
| PUT / GET | /v1/me/preferences | quiz answers in, versioned preference model out |
| GET / PUT | /v1/me/consents | analytics opt-in, no-AI-training (default true), policy version + timestamps |
| POST | /v1/me/export | create export job (202) |
| GET | /v1/me/export/{id} | status + signed download URL |
| DELETE | /v1/me | start deletion (soft delete, revoke sessions, purge in 30d) |
| POST | /v1/me/restore | cancel deletion within window |
| GET | /v1/places/autocomplete | stub, canned US cities (behind `PlacesService`) |
| GET | /v1/sample/closet, /v1/sample/outfits | sample data for guests and first-outfit stub (fake recommender) |
| PUT | /v1/me/notification-preference | daily outfit time (optional step) |

Under-16: client calls nothing; if age gate fails after sign-in, `POST /v1/me/age-confirmation` returns `age_under_minimum` and the server hard-deletes the user immediately.

## 4. DB schema (PostgreSQL, Alembic)

- `users`: id uuid pk, auth_uid unique, email null, display_name null, locale default 'en-US', units enum(imperial,metric) default imperial, age_confirmed_at null, status enum(active,pending_deletion,deleted), is_anonymous bool, city text null, clothing_department enum(menswear,womenswear,both,everything) null, created_at, updated_at, deleted_at null, purge_after null.
- `device_sessions`: id, user_id fk, device_id, platform, app_version, created_at, last_seen_at, revoked_at null.
- `onboarding_state`: user_id pk/fk, variant, current_step, completed_steps jsonb, started_at, completed_at, time_to_first_outfit_ms null, version.
- `preferences`: user_id pk/fk, model_version int, answers jsonb, weights jsonb, updated_at.
- `consents`: user_id pk/fk, analytics_opt_in bool, no_ai_training bool default true, policy_version, analytics_updated_at, ai_training_updated_at, location_explained_at.
- `feature_flags`: key pk, value jsonb, updated_at.
- `export_jobs`: id, user_id, status, file_key, created_at, completed_at, expires_at.
- `idempotency_keys`: key, user_id, request_hash, response jsonb, created_at.
- `audit_log` (minimal): id, user_id, event, at (for deletion/export evidence).

Isolation: every query scoped by authenticated `user_id`; no endpoint takes another user's id (tested). Deletion: soft delete sets `deleted_at` + `purge_after = now+30d`; purge job hard-deletes rows, S3 objects (export files; images from Phase 2 via a registered `PurgeHook` extension point), and Firebase user.

## 5. Screen list

Splash/bootstrap; Welcome (3 value pages, skip); Sign-in; Age gate; Under-16 block; Quiz (6 swipe cards + progress); Basics (name, units, city autocomplete); Permission primers x4 (camera, photos, location, notifications, each with denial fallback); First-items shell (progress ring, unlock rule, "use sample closet"); First outfit reveal (1 + 2 alternatives, why lines); Optional: invite partner (placeholder), daily notification time; Home (stub, revisit optional steps); Settings; Consent centre; Export data; Delete account (confirm); Guest save-prompt sheet; generic Loading/Empty/Error/Offline states.

Flow order `quiz_first`: Welcome -> Age -> Quiz -> Basics -> Permissions (in context) -> First items -> First outfit -> Optional. `closet_first` swaps Quiz and First items using the same screens.

## 6. Testing, CI, infra

- App: unit (quiz->weights, unlock rule, outbox), widget per screen, integration for guest flow and Google flow using `FakeAuthProvider`, analytics event assertions. Golden tests optional.
- API: pytest + httpx AsyncClient, testcontainers Postgres, fake Firebase verifier, migration up/down test, cross-user isolation test, deletion/purge test (time-travel).
- CI: lint (very_good_analysis / ruff + mypy strict), tests, builds, OpenAPI drift check; deploy workflows with `workflow_dispatch` only and `if: false`.
- Terraform: VPC, RDS Postgres, ElastiCache Redis, ECR, ECS Fargate (API + scheduled jobs), S3 (exports), Secrets Manager, ALB, CloudWatch. `terraform validate` + `plan` only; nothing applied.

## 7. Assumptions and open items

Defaults I will take unless you object (also logged in `decisions.md`):
1. Offline store: `drift`. Dart API models generated from OpenAPI (`openapi-generator` dart-dio) vs hand-written freezed: I'll use **hand-written freezed models + a contract test against `openapi.json`** to keep generated code out of the repo.
2. Consent-free events: only `onboarding_started`/`welcome_viewed`-class events are NOT sent pre-consent; **all** PostHog events wait for opt-in. The consent prompt is shown right after the age gate. Funnel data before opt-in is therefore lost (trade-off; flag it for your analytics expectations).
3. Under-16: nothing stored server-side; locally only a non-identifying "blocked" marker to avoid retry loops.
4. Guest data lives on the Firebase anonymous UID server-side (internal user, `is_anonymous=true`); sample closet is read-only server data, so "preserve on upgrade" covers onboarding answers, preferences, consents.
5. Python 3.12, Flutter stable (latest), Postgres 16, Redis 7. Export file stored in S3 (LocalStack in compose).
6. Places autocomplete returns a canned US city list; no third-party provider yet.

Blockers I will need later (not now): Firebase project(s) + `google-services.json` / `GoogleService-Info.plist`, PostHog and Sentry DSNs, final bundle ID, AWS account/region. Until then, everything runs in mock mode / emulator.

## 8. Slice order (commit after each, tests green first)

a Foundation/CI/theme/flavors/mock -> b config/flags/users/auth/guest upgrade -> c welcome/age/quiz/preferences -> d basics/permissions/first-items/first-outfit -> e resume/deep links/consent/export/deletion -> f analytics + funnel docs -> g Terraform plan-only, docs, final checklist.
