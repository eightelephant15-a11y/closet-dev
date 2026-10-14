# Performance: measuring startup on a real device

Target: **cold start under 2 seconds in a release build**, on a mid-range Android phone and an iPhone 12 or newer.
Nothing here has been measured yet: it needs a device. This page is how to do it in ten minutes.

## What the app measures by itself

`app/lib/core/startup/startup_timer.dart` records `main()` -> first rendered frame, logs
`[startup] main() -> first frame: N ms (budget 2000 ms)` and sends the analytics event `app_first_frame`
`{ms, flavor, within_budget}` (held until the user has consented, like all analytics). This covers Dart start-up only. It excludes
the OS process launch and engine start, which can be a few hundred ms, so also run the process-level measurements below.

What runs before the first frame (kept deliberately small): open `shared_preferences`, build the provider scope, `runApp`.
Everything else (session restore, remote config, onboarding sync, consent sync) runs after the first frame behind the splash screen
(`bootProvider`). Firebase initialises before `runApp` only in non-mock builds; if it shows up in a trace, move it behind the splash.

## Android (mid-range phone, release build)

Prerequisites: USB debugging on, `adb devices` lists the phone.

```bash
app/tool/measure_startup.sh prod 10        # builds release, installs, 10 cold starts via `am start -W`
```

It prints each `TotalTime` (process start to first activity frame as the OS sees it), the median and p90, and exits non-zero if the median
is over 2000 ms. For a flame chart and the engine's own numbers:

```bash
cd app
flutter run --profile --flavor prod -t lib/main_prod.dart --dart-define=USE_MOCK=true --trace-startup
cat build/start_up_info.json     # timeToFirstFrameMicros, timeToFrameworkInitMicros, ...
```

Then open DevTools > Performance for the first frames and look for long frames or jank (>16 ms builds, >700 ms shader compile).
Use a phone that represents your low end (about 3 to 4 GB RAM, Snapdragon 6xx/7xx class or MediaTek Helio G class) and make sure
battery saver is off and the device is cool; discard the very first run after install.

## iPhone (12 or newer)

1. `cd app && flutter build ios --release --flavor prod -t lib/main_prod.dart --dart-define=USE_MOCK=true` (needs a signing team in Xcode)
   and install via Xcode (Product > Run with the **prod** scheme, Release configuration), or archive and use TestFlight.
2. Xcode > Product > Profile > **App Launch** template. Record a cold launch (kill the app first, wait 10 s). The "Time to first frame"
   and the pre-main phases are shown. Aim for under 2 s total on the cold launch.
3. Optional: MetricKit launch histograms from a TestFlight build give the same data from real users.

## Pass / fail

| Check | Pass | If it fails |
|---|---|---|
| Android median `TotalTime` over 10 cold starts | <= 2000 ms | check `--trace-startup`, move work behind the splash, remove plugins initialising eagerly |
| iPhone cold launch (Instruments) | <= 2000 ms | same; check `Firebase.initializeApp` and plugin registration |
| `app_first_frame.within_budget` in PostHog (p90) | >= 90% true | compare devices/OS versions |
| No jank in the first 3 s (DevTools) | no frame > 100 ms | defer work, split big widgets |

## Related checks that run in CI

* Startup timer unit tests: `app/test/startup_timer_test.dart`.
* Release APK builds (`flutter build apk --release`) are exercised locally; CI builds a debug APK plus unsigned iOS builds for every flavor.

# Phase 2: closet budgets

Everything below is a budget with the test or step that checks it. "Measured" numbers come from the developer
machine (Apple silicon laptop) and say nothing about phones: the phone rows are **Blocked on a device**.

| Budget | Target | Measured / checked by | Status |
|---|---|---|---|
| `GET /v1/garments` (40 per page) with 500 items, API p95 | < 300 ms in-process (the test's limit); < 150 ms behind the real stack | `api/tests/api/test_closet_browse.py::test_list_endpoint_p95_with_a_500_item_closet`: p50 4 ms, p95 5 ms on SQLite in-process. Indexes: `(user_id, created_at, id)`, `(user_id, updated_at, id)`, `(user_id, category)`, `(user_id, primary_color)`, `(user_id, formality)` | Verified (by test) for the query; real Postgres + network: Blocked on staging |
| Cursor pagination does not slow down deep in the list | keyset, no OFFSET | `test_closet_browse.py` (pages walk the whole set, stable under inserts) | Verified (by test) |
| Phone image preparation per photo (decode, rotate, strip metadata, resize to 2048, JPEG 85) | < 1.5 s on a mid-range phone | `app/test/closet/image_pipeline_test.dart`: 6 MP noisy photo in ~0.7 s on the dev machine (guard rail 5 s). Runs in an isolate (`compute`), so the UI stays responsive | Dev machine: Verified (by test). Phone: Blocked on a device |
| Worker: processing one photo (validate, orient, strip, 3 thumbnails + full WebP) | < 2 s | `api/tests/api/test_closet_upload.py` (functional); the worker logs `image_processed ms=` per photo (see CloudWatch once deployed) | Functional: Verified (by test). Timing on Fargate: Blocked on AWS |
| End to end "tap Use photo" -> AI details visible | < 20 s | mock mode: processing 0.6 s + analysis 1.2 s (`MockClosetBackend`); real: upload + worker + Claude call (typically 3 to 8 s). Review opens immediately, so the user is working during the wait | Mock: Verified (by test). Real: Blocked on AWS and an API key |
| Upload retry behaviour | exponential backoff 1, 2, 4, 8 s (max 5 tries), offline pauses, kill/restart resumes, ticket expiry refreshes, never duplicates | `app/test/closet/upload_queue_test.dart` (10 tests) and `closet_flow_test.dart::offline...` | Verified (by test) |
| Grid with 500 items stays smooth | lazy `SliverGrid`, thumbnails decoded at cell size (`cacheWidth`), cache key = image id + size (not the changing signed URL), 160-entry in-memory LRU in front of the disk cache | Design + `closet_flow_test.dart`; frame timing on a phone: Blocked on a device (steps below) | Blocked on a device |
| Closet API calls per screen | grid: 1 list + 1 summary; detail: 1 get (polls every 2 s only while the AI is working) | provider design | Verified (by test) |

## Measuring the 500-item grid on a phone

1. Seed 500 garments in a dev account (raise the `closet_item_limit_free` flag on the local API, then bulk-add photos, or insert rows with the helper used in `api/tests/api/test_closet_browse.py`).
2. `flutter run --profile --flavor dev -t lib/main_dev.dart`, open DevTools > Performance, fling-scroll the closet for 10 s.
3. Pass: no more than 1% of frames over 16 ms (60 Hz) and no frame over 100 ms; memory stays under about 250 MB (the LRU holds 160 thumbnails).
4. If it fails: lower `crossAxisCount` density, shrink `_MemoryImages._max`, or request the `s` (200 px) size instead of `m`.

## Upload queue in the field

`closet_item_uploaded` carries `attempts` and `bytes`; `closet_item_analysed` carries `latency_ms` and confidence
summary (see [analytics.md](analytics.md)). A healthy week looks like: p50 `attempts` = 1, p95 `latency_ms` under 15000.
