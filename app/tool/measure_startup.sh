#!/usr/bin/env bash
# Cold-start measurement on a real Android device (release build). See docs/performance.md.
#   tool/measure_startup.sh [flavor=prod] [runs=10] [device-serial]
# Prints every run plus median / p90 and exits 1 if the median exceeds the 2000 ms budget.
set -euo pipefail

FLAVOR="${1:-prod}"
RUNS="${2:-10}"
SERIAL="${3:-}"
BUDGET_MS=2000
ADB=(adb)
[ -n "$SERIAL" ] && ADB=(adb -s "$SERIAL")

case "$FLAVOR" in
  dev) PKG="com.example.stylist.dev" ;;
  staging) PKG="com.example.stylist.staging" ;;
  prod) PKG="com.example.stylist" ;;
  *) echo "flavor must be dev|staging|prod" >&2; exit 2 ;;
esac
# NOTE: if you changed the application ID (docs/rename-app.md) update PKG above.

cd "$(dirname "$0")/.."
echo "== Building release APK ($FLAVOR, mock data so no backend is needed)"
flutter build apk --release --flavor "$FLAVOR" -t "lib/main_${FLAVOR}.dart" --dart-define=USE_MOCK=true
APK="build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"

echo "== Installing on $("${ADB[@]}" get-serialno) ($("${ADB[@]}" shell getprop ro.product.model | tr -d '\r'))"
"${ADB[@]}" install -r "$APK" >/dev/null
# Start from a known state: first-run onboarding, not a resumed session.
"${ADB[@]}" shell pm clear "$PKG" >/dev/null

# Resolve the launcher activity instead of hard-coding it.
ACTIVITY=$("${ADB[@]}" shell cmd package resolve-activity --brief "$PKG" | tail -1 | tr -d '\r')

times=()
for i in $(seq 1 "$RUNS"); do
  "${ADB[@]}" shell am force-stop "$PKG"
  # Drop the page cache so every run is a true cold start (needs a rooted/userdebug device; otherwise ignored).
  "${ADB[@]}" shell "echo 3 > /proc/sys/vm/drop_caches" >/dev/null 2>&1 || true
  sleep 2
  ms=$("${ADB[@]}" shell am start -W -n "$ACTIVITY" | tr -d '\r' | awk '/TotalTime/ {print $2}')
  times+=("$ms")
  printf 'run %2d: %s ms\n' "$i" "$ms"
  sleep 3
done

sorted=($(printf '%s\n' "${times[@]}" | sort -n))
median=${sorted[$((RUNS / 2))]}
p90=${sorted[$(( (RUNS * 9 + 9) / 10 - 1 ))]}
echo "---------------------------------------------"
echo "median: ${median} ms   p90: ${p90} ms   budget: ${BUDGET_MS} ms"
echo "(also check the app's own 'app_first_frame' analytics event / '[startup]' log line for main() -> first frame)"
if [ "$median" -gt "$BUDGET_MS" ]; then
  echo "FAIL: median cold start exceeds budget"; exit 1
fi
echo "PASS"
