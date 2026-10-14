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
| Release builds can reach the network | Verified (by test) | found by this pass: the release manifest lacked `INTERNET`; added (`AndroidManifest.xml`); release APK builds locally |
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

---

# Phase 2 checklist: Digital Closet

Same statuses as above. New CI coverage: **api** also runs the arq integration tests against a real Redis service and `make eval-vision`
on the bundled dataset; **smoke** starts the API **and the worker** (fake Redis, local disk storage) and runs 20 checks including the whole
upload -> process -> analyse -> correct -> delete flow and the data-export zip; **app** also diffs the generated taxonomy files.
Counts at the time of writing: 335 API tests, 222 app tests (including a closet accessibility tour at 100/150/200% text, light and dark).
Design: [phase2-plan.md](phase2-plan.md). Decisions 20 to 34: [decisions.md](decisions.md).

## 8. Taxonomy, schema, storage (slice a)

| Item | Status | Code | Evidence |
|---|---|---|---|
| One versioned taxonomy shared by app, API and AI prompt (category+subcategory, 18-colour palette with hex, pattern, formality 1 to 5, seasons, fit, material, brand, notes; department filtering) | Verified (by test) | `taxonomy/garment_taxonomy.v1.json`, `tool/gen_taxonomy.py` | `api/tests/unit/test_taxonomy.py` (generated files match, structure, vocabulary matches the Phase 1 quiz, department filtering, validation, AI schema, prompt built from it); **app** diffs generated files; `app/test/taxonomy_test.dart` |
| Alembic migration + indexes; models match migrations | Verified (by test) | `api/alembic/versions/0005_closet.py` | `api/tests/test_migrations.py` (also on Postgres in CI) |
| `ObjectStorage` interface; local disk with signed URLs (default) | Verified (by test) | `api/app/services/storage.py` | `tests/api/test_storage.py` (round trip, prefix delete, key traversal, signed URL expiry/tamper/method) |
| `S3Storage` (presigned POST pinning size and type) | **Blocked on an AWS bucket** (offline signing verified) | `S3Storage` | `test_storage.py::test_s3_presigned_post_pins_size_and_content_type`. Real bucket: go-live step 13 |
| Private storage, short-lived signed read URLs, local backend refused outside dev/test | Verified (by test) | `api/app/core/config.py`, `storage_local.py` | `test_closet_upload.py::test_signed_urls_are_short_lived`, `tests/api/test_config.py` |

## 9. Capture and upload (2.1, 2.2, 2.3)

| Item | Status | Code | Evidence |
|---|---|---|---|
| Guided capture: outline overlay, live lighting hint, retake, library pick, crop suggestion, camera fallback to library, permission re-check | Verified (by test) with fakes | `app/lib/features/closet/presentation/capture_screen.dart`, `application/image_source.dart` | `app/test/closet/closet_manage_test.dart` (camera problems fall back, lighting hint follows the camera), `image_pipeline_test.dart` (lighting thresholds, crop suggestion) |
| Real camera plugin | **Blocked on a device** (compiled for Android; iOS CI build) | `application/device_camera.dart` | go-live step 14 |
| On-phone compress/resize (<= 2048 px, JPEG 85), EXIF/GPS dropped, HEIC/odd formats handled | Verified (by test) | `application/image_pipeline.dart` | `image_pipeline_test.dart` (resize, EXIF rotation, **no GPS/make left** (this test found a real leak), crop, bad file). HEIC on phone: the OS converts via image_picker; server converts too (`test_heic_photos_are_accepted_and_converted`) |
| Direct phone -> storage upload with signed tickets; the API never carries photo bytes | Verified (by test) | `api/app/api/v1/garments.py`, `http_garment_repository.dart` (`DioUploadTransport`) | `test_closet_upload.py::test_photo_goes_phone_to_storage...`; smoke "upload" steps |
| Resumable, retried, idempotent queue that survives app kill; per-item progress; offline pause | Verified (by test) | `app/lib/features/closet/application/upload_queue.dart` | `upload_queue_test.dart` (backoff, give up + manual retry, offline/resume, restart mid-flight, ticket expiry, limit rejection, progress) |
| Idempotency (`client_id`), complete-twice, upload-before-complete retry | Verified (by test) | | `test_create_is_idempotent_on_client_id`, `test_complete_twice_processes_once`, `test_complete_before_upload_is_a_retryable_conflict` |
| Security: content sniffing (not file names), size/dimension/pixel limits, per-user upload rate limit | Verified (by test) | `api/app/services/images.py`, `core/ratelimit.py` | `test_a_web_page_renamed_to_jpg_is_rejected_and_deleted`, `test_declared_size_over_the_limit...`, `test_huge_dimensions...`, `test_creation_is_rate_limited_per_user`, `tests/unit/test_images.py` |

## 10. Image processing worker (2.4)

| Item | Status | Evidence |
|---|---|---|
| Orientation fix, metadata/GPS strip, HEIC -> WebP, 3 square thumbnails (200/600/1200) + full <= 2048, raw upload deleted | Verified (by test) | `tests/unit/test_images.py`, `test_closet_upload.py::test_stored_images_have_no_gps_or_exif_and_are_rotated`, `test_raw_upload_is_deleted...` |
| Background removal behind an interface (pass-through default; `rembg` optional) | Verified (by test) for the interface; `rembg` itself **Blocked on installing the optional extra** | `api/app/services/background.py` |
| Queue (arq/Redis) with separate worker entrypoint, retries with backoff, dead-letter, idempotent jobs, eager mode for tests | Verified (by test) and (by CI) | `tests/queue/test_queue.py` (fake + real arq), **api** job with Redis service, **smoke** runs the real worker process |
| `make worker-local` against fake Redis | Verified (by CI) | **smoke** |
| Real Redis in AWS, worker service | **Blocked on AWS** (Terraform validates) | `infra/modules/api_service` (worker), go-live step 13 |

## 11. AI analysis and review (2.5, 2.6)

| Item | Status | Evidence |
|---|---|---|
| `VisionProvider` interface; deterministic fake from filename/metadata; provider chosen by the `vision_provider` flag | Verified (by test) | `tests/api/test_closet_analysis.py` (fills details, deterministic, flag selection, department hint) |
| Schema-validated results, stored once, per-field confidence, provider/model/version recorded, low-confidence flagged | Verified (by test) | `test_results_are_always_valid_taxonomy_values`, `test_a_finished_analysis_is_never_repeated`, `test_invalid_model_output_is_never_stored` |
| Retry then "needs manual entry"; manual entry completes it | Verified (by test) | `test_transient_provider_errors_are_retried`, `test_permanent_provider_errors...`, `test_manual_entry_completes...`, `queue` dead-letter tests |
| Per-user rate limits and cost log line | Verified (by test) | `test_per_user_daily_cap_stops_vision_calls`, `test_reanalyse_is_rate_limited...`, `test_every_vision_call_logs_a_cost_line...`, `test_unknown_pricing_is_logged_as_unknown_not_zero` |
| `ClaudeVisionProvider` (Messages API, image block, JSON-schema output, `VISION_MODEL`, `ANTHROPIC_API_KEY`) | **Blocked on an Anthropic API key** (adapter verified against a faithful fake client) | `tests/unit/test_claude_provider.py` (request shape, schema, downsizing, usage/cost, refusals, truncation, error classification). Real call: go-live step 15 |
| Review/correct screen: editable chips, low-confidence highlight, <= 2 taps (actually 1) per correction, corrections saved as feedback, works while upload/analysis is pending or offline | Verified (by test) | `app/test/closet/closet_flow_test.dart` (camera -> review -> one-tap correct), `closet_manage_test.dart::review keeps corrections made before the garment exists`, `low-confidence fields are flagged`; API `test_correcting_an_ai_value_is_recorded_as_feedback` and 3 more |
| Whole add flow under 20 s | Verified (by test) in mock mode (about 2 s of simulated processing); real timing **Blocked on AWS + API key** | [performance.md](performance.md) |

## 12. Browse, detail, manage (2.7, 2.8, 2.9)

| Item | Status | Evidence |
|---|---|---|
| Filter by category/subcategory/colour/season/formality/availability/favourite/archived; search; 5 sorts; cursor pagination (stable while items are added) | Verified (by test) | `tests/api/test_closet_browse.py` (filters, search, `test_every_sort_pages_without_gaps_or_repeats`, `test_pagination_is_stable...`), `app/test/closet/closet_flow_test.dart::filters, search and sort narrow the grid` |
| 500 items: API p95 and a lazy, cached grid | API Verified (by test) (p95 5 ms in-process); smooth scrolling **Blocked on a device** | [performance.md](performance.md) |
| Cached thumbnails (key = image id + size), empty / loading / error states, pull to refresh | Verified (by test) | `test_list_returns_the_requested_thumbnail_size_and_a_stable_cache_key`, widget tests |
| Item detail: edit every field, favourite, unavailable (laundry/lent/repair) with optional return date, archive, hard delete incl. stored images | Verified (by test) | `closet_manage_test.dart` (detail, delete with confirmation and stored-image check), `test_closet_browse.py` (archive, unavailable, return date, delete removes images, delete failure keeps the row) |
| Unavailable/archived exposed to the API for Phase 3 (`excluded_from_outfits`) | Verified (by test) | `test_archive_hides_items_and_flags_them_for_phase_3`, `test_unavailable_items_are_flagged_and_filterable` |
| Bulk add (<= 20): queue, review queue, "accept all"; behind `closet_bulk_add_enabled` | Verified (by test) | `closet_manage_test.dart` (bulk add, never exceeds room, flag off), `api/tests/api/test_closet_bulk.py` (cap of 20, all-or-nothing against the limit, retried batch is not double counted, flag off, rate limit, per-user client ids) |
| Departments: subcategories filtered by the user's `clothing_department` | Verified (by test) | `test_department_filtering`, editor uses `visibleSubcategories` |

## 13. Meter, entitlements, analytics (2.10, 2.11)

| Item | Status | Evidence |
|---|---|---|
| Completeness meter as a pure function; nudge only when it increases the possible outfit count | Verified (by test) | `app/test/closet/closet_meter_test.dart` (incl. an exhaustive "nudge always adds outfits" sweep) |
| `Entitlements` service: Free = 30, server-side, clear `item_limit_reached` code, limits from remote config; friendly stop screen | Verified (by test) | `test_free_item_limit_is_enforced_by_the_server_and_comes_from_remote_config`, `test_entitlements_endpoint`, `closet_manage_test.dart::free limit` |
| Analytics events (capture started, uploaded, analysed with latency + confidence, corrected (field only), deleted, bulk started/completed, filter used, limit reached, meter nudge shown), consent-gated | Verified (by test) | `app/test/analytics_taxonomy_test.dart` (every event documented and emitted; property contracts), [analytics.md](analytics.md) |
| Flags `closet_bulk_add_enabled`, `closet_item_limit_free`, `vision_provider` | Verified (by test) | `api/tests/api/test_config.py`, `api_contract_test.dart` |

## 14. Cross-cutting

| Item | Status | Evidence |
|---|---|---|
| User A cannot read, edit, delete, complete, re-analyse or get signed URLs for user B's garments/images | Verified (by test) | `test_other_users_cannot_see_touch_or_complete_my_garments`, `test_a_user_never_sees_anyone_elses_closet`, `test_deleting_someone_elses_garment_is_a_404...`, `test_other_users_cannot_edit_my_garment`, `test_reanalyse_of_someone_elses_garment_is_a_404`, smoke "cross-user" steps |
| Account export includes garments, corrections and the photos (zip) | Verified (by test) | `test_privacy.py::test_export_includes_garments_corrections_and_the_photos`, smoke |
| Account deletion / purge / under-16 removal delete every stored image | Verified (by test) | `test_deleting_the_account_removes_garments_and_every_stored_image`, `test_under_16_rejection_also_removes_garments_and_photos`, purge test |
| Guest -> account merge carries the closet | Verified (by test) | `test_guest_closet_follows_the_guest_into_the_account` |
| Phase 1 first-items shell and "use sample closet" use the real closet flow; sample closet = seeded garments with bundled pictures, no upload | Verified (by test) | `steps_d_test.dart`, `journeys_test.dart`, `closet_flow_test.dart::sample closet...`, `test_sample_closet_is_seeded_once_and_does_not_use_item_slots` |
| Accessibility on every new screen: 100/150/200% text, light/dark, 48dp targets, labels, contrast; strings only in ARB | Verified (by test) | `app/test/accessibility_test.dart` (closet tours: grid, filters, search, detail, bulk, capture, preview, review); the tour found and fixed a contrast problem on grid tiles and two overflows |
| Contract: mock closet returns the same fields as the API; every endpoint/param the app uses exists in `docs/openapi.json` | Verified (by test) | `app/test/api_contract_test.dart` (closet group) |
| Performance budgets documented and checked | Verified (by test) where possible | [performance.md](performance.md) |
| AI accuracy harness (`make eval-vision`): per-field accuracy, confusion, confidence calibration, cost; targets category 92% / colour 85% / formality within 1 point 80% | Verified (by test) and (by CI) on the synthetic set; real accuracy **Blocked on your 300 labelled photos + API key** | `tests/unit/test_vision_eval.py`, **api** CI step, [vision-eval.md](vision-eval.md) |
| Terraform: photos bucket, worker service, Anthropic secret container, dead-job alarm | Verified (by CI) for fmt/validate; plan/apply **Blocked on AWS** | **tf**, `infra/README.md` |

## Phase 2: still blocked, and on what

| Blocked on | Items |
|---|---|
| Physical phone(s) | real camera preview and lighting hint, shutter, photo library picker, 500-item scroll smoothness, on-phone image preparation timing, TalkBack/VoiceOver on the new screens |
| AWS account | `S3Storage` against a real bucket, worker service, real Redis, real timings |
| Anthropic API key | `ClaudeVisionProvider` end to end |
| Your 300 labelled photos | the real accuracy numbers (category 92 / colour 85 / formality 80) |
| Optional: `rembg` extra | real background removal (default stays pass-through) |
