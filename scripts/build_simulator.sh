#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
xcodebuild -version > artifacts/xcode-version.txt
xcodebuild build \
  -project RiseBake.xcodeproj \
  -scheme RiseBake \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee artifacts/xcodebuild.log
app_path="$PWD/build/Build/Products/Debug-iphonesimulator/RiseBake.app"
test -x "$app_path/RiseBake"
# Verify architecture and platform before uploading anything.
lipo -info "$app_path/RiseBake" | tee artifacts/architecture.txt
xcrun vtool -show-build "$app_path/RiseBake" | tee artifacts/platform.txt
python3 - <<'PY'
from pathlib import Path
assert 'arm64' in Path('artifacts/architecture.txt').read_text(), 'Missing ARM simulator binary'
assert 'IOSSIMULATOR' in Path('artifacts/platform.txt').read_text(), 'This is not a simulator build'
PY
# Boot an available iPhone, launch the actual app and keep a real screenshot artifact.
xcrun simctl list devices available --json > build/simulators.json
simulator_id="$(python3 - <<'PY'
import json
s=json.load(open('build/simulators.json'))
phones=[d for key,devices in sorted(s['devices'].items(),reverse=True) if 'iOS' in key for d in devices if d.get('isAvailable') and d['name'].startswith('iPhone')]
if not phones:raise SystemExit('No iPhone simulator is installed on this Xcode image')
print(phones[0]['udid'])
PY
)"
trap 'xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$simulator_id" || true
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" "$app_path"
xcrun simctl launch "$simulator_id" com.risebake.preview | tee artifacts/simulator-launch.txt
sleep 4
# A second launch terminates the app only if still running; check the process first.
xcrun simctl spawn "$simulator_id" launchctl list > build/processes.txt
if ! grep -q 'com.risebake.preview' build/processes.txt; then
  echo 'RiseBake did not remain running after launch.'
  exit 1
fi
xcrun simctl io "$simulator_id" screenshot artifacts/RiseBake-iPhone.png
# Appetize expects a zip whose root contains RiseBake.app (not an .ipa or source zip).
ditto -c -k --sequesterRsrc --keepParent "$app_path" artifacts/RiseBake-simulator.zip
python3 - <<'PY'
from zipfile import ZipFile
with ZipFile('artifacts/RiseBake-simulator.zip') as z:
    assert 'RiseBake.app/Info.plist' in z.namelist()
    assert 'RiseBake.app/RiseBake' in z.namelist()
print('Native simulator bundle is ready.')
PY
