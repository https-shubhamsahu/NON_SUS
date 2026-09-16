#!/usr/bin/env bash
# Capture Play Store phone screenshots (Linux/macOS/CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FLUTTER="${FLUTTER:-flutter}"
if [[ -x "/c/Users/shubh/AppData/Local/flutter/bin/flutter" ]]; then
  FLUTTER="/c/Users/shubh/AppData/Local/flutter/bin/flutter"
fi

"$FLUTTER" pub get

DEVICE=""
if command -v adb >/dev/null 2>&1; then
  DEVICE="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi

OUT="fastlane/metadata/android/en-IN/images/phoneScreenshots"
mkdir -p "$OUT"

if [[ -n "$DEVICE" ]]; then
  echo "Capturing on Android device $DEVICE"
  "$FLUTTER" drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/store_screenshots_test.dart \
    -d "$DEVICE"
else
  echo "No Android emulator/device; rasterizing widgets via flutter test (VM)"
  "$FLUTTER" test test/widget/store_screenshot_capture_test.dart
fi

python tool/pad_store_screenshots.py
python tool/store_assets/render_feature_graphic.py
python tool/verify_store_images.py
