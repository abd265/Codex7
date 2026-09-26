#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The simulator build requires macOS and Xcode. Use the included macOS CI workflow." >&2
  exit 1
fi
mkdir -p artifacts build
python3 scripts/generate_project.py
xcodebuild -version > artifacts/xcode-version-simulator.txt
simulator_arch="$(uname -m)"
xcodebuild build \
  -project PrismHarbour.xcodeproj \
  -scheme PrismHarbour \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/simulator \
  ARCHS="$simulator_arch" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee artifacts/xcodebuild-simulator.log
app_path="$PWD/build/simulator/Build/Products/Debug-iphonesimulator/PrismHarbour.app"
test -x "$app_path/PrismHarbour"
xcrun vtool -show-build "$app_path/PrismHarbour" | tee artifacts/simulator-platform.txt
python3 - <<'PY'
from pathlib import Path
assert "IOSSIMULATOR" in Path("artifacts/simulator-platform.txt").read_text(), "Not a simulator binary"
PY
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
# Reuse a booted simulator without shutting down a developer's existing session.
simulator_was_booted="$(python3 - "$simulator_id" <<'PY'
import json, sys
from pathlib import Path
devices = json.loads(Path("build/simulators.json").read_text())["devices"]
print("yes" if any(d["udid"] == sys.argv[1] and d["state"] == "Booted" for group in devices.values() for d in group) else "no")
PY
)"
if [[ "$simulator_was_booted" != "yes" ]]; then
  xcrun simctl boot "$simulator_id"
  trap 'xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true' EXIT
fi
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl status_bar "$simulator_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcrun simctl install "$simulator_id" "$app_path"
for screen in home play library; do
  xcrun simctl terminate "$simulator_id" com.prismharbour.game >/dev/null 2>&1 || true
  xcrun simctl launch "$simulator_id" com.prismharbour.game "--screenshot-$screen" | tee "artifacts/launch-$screen.txt"
  sleep 3
  xcrun simctl spawn "$simulator_id" launchctl list > build/processes.txt
  if ! grep -q 'com.prismharbour.game' build/processes.txt; then
    echo "Prism Harbour exited unexpectedly on $screen." >&2
    exit 1
  fi
  xcrun simctl io "$simulator_id" screenshot "artifacts/PrismHarbour-$screen.png"
done
xcrun simctl status_bar "$simulator_id" clear
rm -f artifacts/PrismHarbour-simulator.zip
ditto -c -k --sequesterRsrc --keepParent "$app_path" artifacts/PrismHarbour-simulator.zip
echo "Native simulator launch and screenshots complete."