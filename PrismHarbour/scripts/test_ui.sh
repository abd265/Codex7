#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "UI tests require macOS and Xcode." >&2
  exit 1
fi
mkdir -p artifacts build
python3 scripts/generate_project.py
# Refresh this inventory so the standalone script also works after a simulator build.
xcrun simctl list devices available --json > build/simulators.json
simulator_id="$(python3 - <<'PY'
import json
from pathlib import Path
devices = json.loads(Path("build/simulators.json").read_text())["devices"]
phones = [
    device
    for runtime, group in sorted(devices.items(), reverse=True)
    if "iOS" in runtime
    for device in group
    if device.get("isAvailable") and device["name"].startswith("iPhone")
]
if not phones:
    raise SystemExit("No available iPhone simulator installed in Xcode")
print(phones[0]["udid"])
PY
)"
# Xcode will boot the destination if needed. Never erase a developer's simulator.
result_path="artifacts/PrismHarbour-ui.xcresult"
if [[ -e "$result_path" ]]; then
  mv "$result_path" "artifacts/PrismHarbour-ui-$(date +%Y%m%d-%H%M%S).xcresult"
fi
set +e
xcodebuild test \
  -project PrismHarbour.xcodeproj \
  -scheme PrismHarbour \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -destination-timeout 120 \
  -derivedDataPath build/simulator \
  -resultBundlePath "$result_path" \
  -only-testing:PrismHarbourUITests \
  -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee artifacts/xcodebuild-ui-tests.log
test_status=${PIPESTATUS[0]}
set -e
if [[ -d "$result_path" ]]; then
  xcrun xcresulttool export attachments --path "$result_path" --output-path artifacts/ui-screenshots || true
fi
if [[ "$test_status" -ne 0 ]]; then
  exit "$test_status"
fi
printf '%s\n' "Native UI interaction tests passed. Result: $result_path"
