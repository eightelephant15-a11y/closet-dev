# Decisions

1. **Offline queue** uses `shared_preferences`-backed JSON outbox instead of `drift` (drift/drift_dev version conflict with the current Flutter SDK; payloads are tiny).
2. **API tests** run on SQLite (aiosqlite) for speed with `JSON`->`JSONB` variant; the migration test runs against Postgres when `MIGRATION_TEST_DATABASE_URL` is set (CI sets it). No Docker/Postgres on the dev machine used to build this.
3. **Idempotency** is Redis-only (24h TTL, scoped per Authorization header) rather than a DB table; the `idempotency_keys` table from the plan is dropped.
4. **Android flavors** via Gradle product flavors (`dev` -> `com.example.stylist.dev`, `staging` -> `.staging`, `prod` -> `com.example.stylist`). iOS flavors need Xcode schemes; configured via xcconfig (see README).
5. **Riverpod 2.x** pinned (not 3.x) for stable codegen-free API.
6. **Generated l10n** (`lib/l10n/gen`) is committed so analysis works without a pre-step.
