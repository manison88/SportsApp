#!/bin/bash
# Boots the test simulator and gives it what the E2E tests need: photos with
# stadium GPS/dates, photo + location permission, and a location at Wrigley.
set -x
DEVICE="${DEVICE:-iPhone 16 Pro}"
BUNDLE=app.witness.ios
UDID=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
c=[x for k,v in d.items() if 'iOS' in k for x in v if x['name']=='$DEVICE']
print(c[-1]['udid'])")
echo "UDID=$UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
pip3 install --quiet --break-system-packages pillow piexif || pip3 install --quiet pillow piexif
python3 ci/seed_photos.py build/seed-photos
xcrun simctl addmedia "$UDID" build/seed-photos/*.jpg
xcrun simctl privacy "$UDID" grant photos "$BUNDLE" || true
xcrun simctl privacy "$UDID" grant location "$BUNDLE" || true
xcrun simctl location "$UDID" set 41.9484,-87.6553 || true
echo "SIM_UDID=$UDID" >> "${GITHUB_ENV:-/dev/null}"
