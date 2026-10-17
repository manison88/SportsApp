#!/usr/bin/env bash
# Gathers the build log tail, compiler errors, test summary and UI-test screenshots into out/.
set -u
mkdir -p out/shots
grep -E "error:" build/xcodebuild.log | sort -u | head -200 > out/errors.txt || true
tail -n 400 build/xcodebuild.log > out/log-tail.txt || true
if [ -d build/Results.xcresult ]; then
  xcrun xcresulttool get test-results summary --path build/Results.xcresult --format json > out/summary.json 2>/dev/null || true
  xcrun xcresulttool get test-results tests --path build/Results.xcresult --format json > out/tests.json 2>/dev/null || true
  xcrun xcresulttool export attachments --path build/Results.xcresult --output-path out/shots > /dev/null 2>&1 || true
fi
ls -la out out/shots | head -80
