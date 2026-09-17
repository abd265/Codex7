#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
xcodebuild -version > artifacts/xcode-version-device.txt
xcodebuild build \
  -project RiseBake.xcodeproj \
  -scheme RiseBake \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee artifacts/xcodebuild-device.log
app_path="$PWD/build/device/Build/Products/Release-iphoneos/RiseBake.app"
test -x "$app_path/RiseBake"
# ARM64 alone is insufficient: Apple Silicon simulator binaries are also ARM64.
xcrun lipo -verify_arch arm64 "$app_path/RiseBake"
xcrun lipo -info "$app_path/RiseBake" | tee artifacts/device-architecture.txt
xcrun vtool -show-build "$app_path/RiseBake" | tee artifacts/device-platform.txt
python3 - "$app_path" <<'PY'
import plistlib
import re
import sys
from pathlib import Path

app = Path(sys.argv[1])
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'Not a physical-device app'
assert info.get('CFBundleExecutable') == 'RiseBake', 'Unexpected executable'
assert info.get('CFBundleIdentifier') == 'com.risebake.preview', 'Unexpected bundle ID'
platform = Path('artifacts/device-platform.txt').read_text()
assert re.search(r'^\s*platform\s+IOS\s*$', platform, re.MULTILINE), 'Missing iOS device platform'
assert 'IOSSIMULATOR' not in platform, 'Simulator binaries cannot run on an iPhone'
PY
# Sideloadly will sign this bundle on Windows using the user's Apple Account.
package_dir="$(mktemp -d "$PWD/build/device-ipa.XXXXXX")"
trap 'rm -rf "$package_dir"' EXIT
mkdir -p "$package_dir/Payload"
ditto "$app_path" "$package_dir/Payload/RiseBake.app"
ditto -c -k --keepParent "$package_dir/Payload" artifacts/RiseBake-unsigned.ipa
python3 - <<'PY'
from zipfile import ZipFile

with ZipFile('artifacts/RiseBake-unsigned.ipa') as ipa:
    assert ipa.testzip() is None, 'IPA archive is corrupted'
    assert 'Payload/RiseBake.app/Info.plist' in ipa.namelist(), 'Missing app manifest'
    assert 'Payload/RiseBake.app/RiseBake' in ipa.namelist(), 'Missing app executable'
print('Unsigned physical-iPhone IPA is ready for Sideloadly.')
PY
shasum -a 256 artifacts/RiseBake-unsigned.ipa > artifacts/RiseBake-unsigned.ipa.sha256
cp Docs/WINDOWS-IPHONE.md artifacts/Windows-iPhone-install.md
