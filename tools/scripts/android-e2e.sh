#!/usr/bin/env bash
# On-device E2E for reminders (apps/mobile/patrol_test) on a running emulator.
# Called by .github/workflows/android-e2e.yml inside android-emulator-runner.
# Evidence lands in $OUT: per-test videos, native screenshots, logcat, JUnit.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${E2E_OUT:-$ROOT/e2e-evidence}"
mkdir -p "$OUT"
cd "$ROOT/apps/mobile"

adb wait-for-device
# Let the cold-booted emulator settle: a busy first boot makes Pixel Launcher
# ANR, and its dialog covers the app under test.
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
adb shell settings put global hide_error_dialogs 1 || true
adb shell settings put secure anr_show_background 0 || true
sleep 45
adb shell input keyevent KEYCODE_HOME || true
adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS >/dev/null 2>&1 || true
adb shell getprop ro.build.version.release | sed 's/^/android=/' | tee "$OUT/device.txt"
adb shell getprop ro.build.version.sdk | sed 's/^/sdk=/' | tee -a "$OUT/device.txt"
adb shell getprop ro.product.model | sed 's/^/model=/' | tee -a "$OUT/device.txt"
adb shell settings put global heads_up_notifications_enabled 1 || true
adb logcat -c || true
adb logcat -v threadtime > "$OUT/logcat-full.txt" 2>&1 &
LOGCAT=$!

set +e
patrol test \
  --target patrol_test/reminders_device_test.dart \
  --record-video --video-output-dir "$OUT/videos" \
  --screenshots-output-dir "$OUT/screenshots" \
  --verbose 2>&1 | tee "$OUT/patrol.log"
STATUS=${PIPESTATUS[0]}
set -e

kill "$LOGCAT" 2>/dev/null || true
# Fallback pull in case the CLI did not (failure screenshots, on-demand ones).
adb pull /sdcard/Download/screenshots "$OUT/screenshots-device" >/dev/null 2>&1 || true
adb exec-out screencap -p > "$OUT/final-screen.png" 2>/dev/null || true
grep -E "notify-e2e|flutter|PatrolJUnitRunner|TestRunner|AlarmManager.*cocenglish|NotificationService.*cocenglish" \
  "$OUT/logcat-full.txt" > "$OUT/logcat-excerpt.txt" 2>/dev/null || true
cp -r build/app/outputs/androidTest-results "$OUT/" 2>/dev/null || true
cp -r build/app/reports/androidTests "$OUT/android-test-report" 2>/dev/null || true
echo "patrol exit status: $STATUS"
exit "$STATUS"
