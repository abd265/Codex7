#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The physical-iPhone build requires macOS and Xcode. Use the included macOS CI workflow." >&2
  exit 1
fi
mkdir -p artifacts build
python3 scripts/generate_project.py
xcodebuild -version > artifacts/xcode-version-device.txt
xcodebuild build \
  -project PrismHarbour.xcodeproj \
  -scheme PrismHarbour \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee artifacts/xcodebuild-device.log
app_path="$PWD/build/device/Build/Products/Release-iphoneos/PrismHarbour.app"
test -x "$app_path/PrismHarbour"
xcrun lipo "$app_path/PrismHarbour" -verify_arch arm64
xcrun lipo -info "$app_path/PrismHarbour" | tee artifacts/device-architecture.txt
xcrun vtool -show-build "$app_path/PrismHarbour" | tee artifacts/device-platform.txt
# Validates Info.plist and actual Mach-O load commands. ARM64 by itself also
# describes Apple Silicon simulator apps, so architecture alone is insufficient.
python3 scripts/validate_ipa.py "$app_path" > artifacts/device-validation.json
package_dir="$(mktemp -d "$PWD/build/device-ipa.XXXXXX")"
trap 'rm -rf "$package_dir"' EXIT
mkdir -p "$package_dir/Payload"
ditto "$app_path" "$package_dir/Payload/PrismHarbour.app"
# Remove only this generated output so a previous archive cannot leave stale files.
rm -f artifacts/PrismHarbour-unsigned.ipa
ditto -c -k --keepParent "$package_dir/Payload" artifacts/PrismHarbour-unsigned.ipa
python3 scripts/validate_ipa.py artifacts/PrismHarbour-unsigned.ipa | tee artifacts/ipa-validation.json
shasum -a 256 artifacts/PrismHarbour-unsigned.ipa > artifacts/PrismHarbour-unsigned.ipa.sha256
cp Docs/INSTALL.md artifacts/INSTALL.md
echo "Ready: artifacts/PrismHarbour-unsigned.ipa"