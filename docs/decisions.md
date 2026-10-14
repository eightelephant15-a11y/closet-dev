# Decisions

1. **Offline queue** uses `shared_preferences`-backed JSON outbox instead of `drift` (drift/drift_dev version conflict with the current Flutter SDK; payloads are tiny).
2. **API tests** run on SQLite (aiosqlite) for speed with `JSON`->`JSONB` variant; the migration test runs against Postgres when `MIGRATION_TEST_DATABASE_URL` is set (CI sets it). No Docker/Postgres on the dev machine used to build this.
3. **Idempotency** is Redis-only (24h TTL, scoped per Authorization header) rather than a DB table; the `idempotency_keys` table from the plan is dropped.
4. **Android flavors** via Gradle product flavors (`dev` -> `com.example.stylist.dev`, `staging` -> `.staging`, `prod` -> `com.example.stylist`). iOS flavors need Xcode schemes; configured via xcconfig (see README).
5. **Riverpod 2.x** pinned (not 3.x) for stable codegen-free API.
6. **Generated l10n** (`lib/l10n/gen`) is committed so analysis works without a pre-step.
7. **Analytics consent**: events are buffered in memory (cap 200) until the consent decision; opt-in flushes, opt-out discards. Nothing leaves the device before opt-in, but the onboarding funnel before the consent prompt is kept when users opt in. (Supersedes the plan's "drop everything pre-consent".)
8. **closet_first** order: welcome, age, basics, permissions, first_items, quiz, first_outfit, optional. Quiz moves after first items; permissions stay directly before first items because priming is shown in context.
9. **Signing in / starting as guest completes the welcome step**; the age gate follows. Under-16 hard-deletes the server account and wipes local data; a non-identifying `age_blocked` marker stays on the device.
10. **Idempotent PUT semantics**: `PUT /v1/onboarding` only grows `completed_steps`; first `time_to_first_outfit_ms` wins, so replays from stale offline devices are safe.
11. Quiz uses Dart/Python mirrored preference models (v1); the server value is authoritative, the Dart one lets the mock/offline app rank locally.
12. **Idempotency table dropped; consents are created with the user** (default: analytics undecided, no-AI-training ON with timestamp + policy version). Guest-to-account merge keeps the existing account's consents.
13. **Export** runs as a FastAPI background task and, as a safety net, via `python -m app.jobs exports`; files live in S3 (SSE) in AWS and on local disk in dev/tests; download requires auth and expires after 24h.
14. **Deletion** is a soft delete (`pending_deletion`, sessions revoked, Firebase refresh tokens revoked). `python -m app.jobs purge` (daily scheduled task) hard-deletes every row, export file, registered purge hooks (Phase 2 images) and the Firebase user, leaving only a hashed audit-log entry. Signing in during the window shows a restore screen.
15. **Sign-out wipes this device's user data** (onboarding, closet, consent cache); progress returns from the server on next sign-in.
16. **First-items step has no separate Skip**: the "Use sample closet" shortcut is the skip path since the first outfit needs a closet.
17. **Places**: `/v1/places/autocomplete` and the app's `PlacesService` return city names only from a canned list; no coordinates anywhere.
18. **Crash reporting** (Sentry app + API) is not behind the analytics opt-in: it carries errors and traces only (`sendDefaultPii = false`), no user identifiers beyond the request id. Revisit with counsel before launch.
19. **PostHog** is initialised lazily on first (consented) event, so a user who never opts in never starts the SDK. Native auto-init is disabled in the Android manifest and iOS Info.plist.

## Phase 2: closet

20. **One taxonomy file** (`taxonomy/garment_taxonomy.v1.json`) generates the API constants, the Dart data, the ARB label keys and the AI prompt/schema (`tool/gen_taxonomy.py`; CI fails on drift). A change is a new version file, never an edit in place.
21. **Storage keys are `g/<garment_id>/<image_id>/<variant>`**, not user-id based, so merging a guest into an account only re-points rows. Deleting a garment (or account) deletes its prefix; the photos bucket has no versioning.
22. **Phones upload straight to storage** with short-lived signed tickets (PUT for local disk, presigned POST with a size limit for S3). The API never proxies photo bytes; it only checks the object (size, magic bytes) when the phone says "complete".
23. **Job queue = arq on Redis**, run by a separate worker process (`python -m app.worker`). Locally it runs against an in-process fake Redis (TCP) so `make worker-local` needs no install; tests run jobs inline (`EagerQueue`). Jobs are idempotent (state checked first), retry with backoff, then dead-letter (`dlq:closet`) and the garment shows "add the details yourself".
24. **Analysis is stored once.** The AI result is written when the garment is first analysed; user edits are never overwritten. "Analyse again" is an explicit, rate-limited action that fills only fields the user has not edited.
25. **Confidence under 0.7 is flagged** in the review UI; every field the AI fills carries a confidence, the provider/model/version, and the taxonomy version.
26. **Vision provider by flag** (`vision_provider`: `fake` default, `claude`). The Claude adapter uses the Messages API with an image block and a JSON-schema output; `VISION_MODEL` (default `claude-opus-5-5`) and `ANTHROPIC_API_KEY` come from the environment. It is marked unverified until run with a real key. Costs are logged per call (`vision_call ...`); unknown prices are reported as unknown.
27. **Per-user caps** on analysis (200/day), re-analysis (10/day) and uploads (120/hour) so a bug or abuse cannot run up the bill.
28. **Free plan = 30 items**, enforced on the server (`item_limit_reached`, 403, with limit/used). The number is a remote-config flag. Sample garments and archived items do not count; un-archiving re-checks the limit. The app pre-checks and shows a friendly stop screen; payments are Phase 6.
29. **Sample closet = real garments** (`is_sample`) with bundled pictures and no upload, so the first-items step, the grid and the first outfit all use the one code path.
30. **Archived or unavailable (laundry, lent, repair) garments are excluded from outfits** and the API says so (`excluded_from_outfits`) so Phase 3 does not have to re-derive it.
31. **Phase 1 recommender keeps its `ClosetItem` input** through a small adapter (`closet_item_adapter.dart`); Phase 3 replaces both.
32. **Metadata is stripped twice**: on the phone before upload (a test caught that `bakeOrientation` alone leaves GPS in the JPEG) and again on the server for every stored image.
33. **No generated image bytes in git**: sample closet pictures are drawn by `tool/make_sample_images.py` (flat illustrations) and committed as small WebP files; the eval dataset is generated by `eval/make_sample_dataset.py`.
34. **Mock mode runs the whole pipeline** in the app (`MockClosetBackend`: idempotent create, signed-ticket upload, processing, analysis with a Dart twin of the fake provider, same error codes), persisted so a restart resumes mid-flight. A contract test keeps its JSON keys equal to the OpenAPI schema.

