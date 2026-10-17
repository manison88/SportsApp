#!/usr/bin/env bash
# Builds Witness, boots an iPhone 16 Pro simulator, launches each screen with
# `-screen <n>`, and saves PNGs to mockups/, plus a contact sheet.
#
#   Tools/export_screenshots.sh            # all built screens
#   Tools/export_screenshots.sh 3 6 7      # specific screens
#
# Requires Xcode 16+. The contact sheet uses ImageMagick (`brew install imagemagick`) when present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/mockups"
DEVICE_NAME="${DEVICE_NAME:-iPhone 16 Pro}"
BUNDLE_ID="app.witness.mockups"
SCREENS=("$@")
[ ${#SCREENS[@]} -eq 0 ] && SCREENS=(3 6 7)

NAMES=([1]=welcome [2]=discovery [3]=life-globe [4]=passport [5]=timeline [6]=game-memory
       [7]=you-were-there [8]=recap-player [9]=venue [10]=lifetime-stats [11]=season-wrapped
       [12]=live-checkin [13]=shared-passport [14]=trip [15]=print-shop)

mkdir -p "$OUT"
UDID="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
name = sys.argv[1]
devs = [d for rt in json.load(sys.stdin)['devices'].values() for d in rt if d['name'] == name]
print(devs[-1]['udid'] if devs else '')" "$DEVICE_NAME")"
[ -z "$UDID" ] && { echo "No simulator named '$DEVICE_NAME'"; exit 1; }

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
# App Store screenshot conventions: 9:41, full bars, no carrier.
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true
xcrun simctl ui "$UDID" appearance dark

xcodebuild -project "$ROOT/Witness.xcodeproj" -scheme Witness -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$ROOT/build" -quiet build
xcrun simctl install "$UDID" "$ROOT/build/Build/Products/Debug-iphonesimulator/Witness.app"

FILES=()
for n in "${SCREENS[@]}"; do
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -screen "$n" >/dev/null
  # map tiles and the globe settle animation need a moment
  if [ "$n" = "3" ] || [ "$n" = "9" ] || [ "$n" = "14" ]; then sleep 8; else sleep 3; fi
  file="$OUT/$(printf '%02d' "$n")-${NAMES[$n]}.png"
  xcrun simctl io "$UDID" screenshot --type=png "$file"
  FILES+=("$file")
  echo "saved $file"
done

if command -v magick >/dev/null; then
  magick montage "${FILES[@]}" -tile 5x -geometry 590x1278+40+40 -background '#050506' "$OUT/contact-sheet.png"
  echo "saved $OUT/contact-sheet.png"
else
  echo "ImageMagick not found; skipped the contact sheet."
fi
