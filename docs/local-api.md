# Running the real API locally (no Docker, no Firebase)

```bash
make setup           # once: venv, deps, Flutter packages
make api-local       # terminal 1: serves http://127.0.0.1:8000  (docs at /docs)
make api-smoke       # terminal 2: PASS/FAIL for every /v1 endpoint
make run-app-local-api   # terminal 2: Flutter dev flavor against it (simulator / emulator / device)
```

What `make api-local` does (`api/app/local_server.py`):

1. Sets `APP_ENV=dev`, `AUTH_MODE=dev` and a local-only `DEV_AUTH_SECRET` (override by exporting your own).
2. Uses `sqlite+aiosqlite:///api/local.db` unless `DATABASE_URL` is set (a local Postgres works too), and runs
   Alembic migrations.
3. Seeds the `feature_flags` rows from the code defaults (`guest_mode_enabled`, `onboarding_variant`) so you can edit them with SQL:
   `sqlite3 api/local.db "update feature_flags set value='\"closet_first\"' where key='onboarding_variant'"` (the flag cache lasts 60 s).
4. Uses an in-process fake Redis unless `REDIS_URL` is set.
5. Mounts `POST /dev/token`, the stand-in for Google / anonymous sign-in.

## Dev tokens

`POST /dev/token {"uid": "...", "email": "...", "name": "..."}` returns a signed token. No email means a guest
(anonymous) identity. Re-minting with the **same uid and an email** is the dev equivalent of "link Google to the guest",
so `POST /v1/auth/upgrade` keeps all data.

```bash
TOKEN=$(curl -s localhost:8000/dev/token -H 'content-type: application/json' -d '{"uid":"me","email":"me@example.com"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s localhost:8000/v1/me -H "Authorization: Bearer $TOKEN" -H 'X-Device-Id: laptop'   # 401 until POST /v1/auth/session
```

## Safety

* `Settings` refuses `AUTH_MODE=dev` unless `APP_ENV` is `dev`, `local` or `test` (case-insensitive); `ENV` is accepted as an alias of `APP_ENV`.
* `DevTokenVerifier` re-checks this itself, so bypassing `Settings` still fails.
* The `/dev` routes exist only when the mode is on, and are hidden from OpenAPI.
* Tokens are HMAC-SHA256 signed with `DEV_AUTH_SECRET` and expire after 24 h.
* The Flutter app only uses dev auth for the `dev` flavor (`AppConfig.useDevAuth`).

## The smoke test

`python -m app.smoke [base_url]` walks the whole Phase 1 journey (guest start, quiz data, upgrade without data loss,
privacy between users, idempotency replay, export, sign-out revocation, delete/restore, under-16 removal, guest merge).
It reads the server's `/openapi.json` and **fails with UNCOVERED if any `/v1` operation was not called**, so a new endpoint cannot
slip past it. The same script runs in pytest against an in-process app, and in CI against the real local server.
