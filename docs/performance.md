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
