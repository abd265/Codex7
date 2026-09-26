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
# Boot explicitly so recording covers real gestures, dock effects, and the victory transition.
# Reuse a developer's existing simulator without erasing or shutting it down.
simulator_was_booted="$(python3 - "$simulator_id" <<'PY'
import json, sys
from pathlib import Path
devices = json.loads(Path("build/simulators.json").read_text())["devices"]
print("yes" if any(d["udid"] == sys.argv[1] and d["state"] == "Booted" for group in devices.values() for d in group) else "no")
PY
)"
record_pid=""
stop_recording() {
  if [[ -n "$record_pid" ]]; then
    # SIGINT lets simctl flush the MP4 container instead of leaving a truncated file.
    kill -INT "$record_pid" 2>/dev/null || true
    for attempt in {1..15}; do
      kill -0 "$record_pid" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$record_pid" 2>/dev/null; then
      kill -TERM "$record_pid" 2>/dev/null || true
    fi
    wait "$record_pid" 2>/dev/null || true
    record_pid=""
  fi
}
cleanup() {
  stop_recording
  xcrun simctl status_bar "$simulator_id" clear >/dev/null 2>&1 || true
  if [[ "$simulator_was_booted" != "yes" ]]; then
    xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
if [[ "$simulator_was_booted" != "yes" ]]; then
  xcrun simctl boot "$simulator_id"
fi
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl status_bar "$simulator_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcrun simctl io "$simulator_id" recordVideo --codec=h264 --force artifacts/PrismHarbour-effects.mp4 > artifacts/simulator-recording.log 2>&1 &
record_pid=$!
sleep 2
if ! kill -0 "$record_pid" 2>/dev/null; then
  cat artifacts/simulator-recording.log >&2
  echo "Simulator effects recording did not start." >&2
  exit 1
fi
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
stop_recording
if [[ -d "$result_path" ]]; then
  xcrun xcresulttool export attachments --path "$result_path" --output-path artifacts/ui-screenshots || true
fi
if [[ "$test_status" -ne 0 ]]; then
  exit "$test_status"
fi
test -s artifacts/PrismHarbour-effects.mp4
printf '%s\n' "Native UI interaction tests passed. Result: $result_path; effects recording: artifacts/PrismHarbour-effects.mp4"
