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
  -project DarjaTogether.xcodeproj \
  -scheme DarjaTogether \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee artifacts/xcodebuild-device.log
app_path="$PWD/build/device/Build/Products/Release-iphoneos/DarjaTogether.app"
test -x "$app_path/DarjaTogether"
xcrun lipo "$app_path/DarjaTogether" -verify_arch arm64
xcrun lipo -info "$app_path/DarjaTogether" | tee artifacts/device-architecture.txt
xcrun vtool -show-build "$app_path/DarjaTogether" | tee artifacts/device-platform.txt
# Validates Info.plist and actual Mach-O load commands. ARM64 by itself also
# describes Apple Silicon simulator apps, so architecture alone is insufficient.
python3 scripts/validate_ipa.py "$app_path" > artifacts/device-validation.json
package_dir="$(mktemp -d "$PWD/build/device-ipa.XXXXXX")"
trap 'rm -rf "$package_dir"' EXIT
mkdir -p "$package_dir/Payload"
ditto "$app_path" "$package_dir/Payload/DarjaTogether.app"
# Remove only this generated output so a previous archive cannot leave stale files.
rm -f artifacts/DarjaTogether-unsigned.ipa
ditto -c -k --keepParent "$package_dir/Payload" artifacts/DarjaTogether-unsigned.ipa
python3 scripts/validate_ipa.py artifacts/DarjaTogether-unsigned.ipa | tee artifacts/ipa-validation.json
shasum -a 256 artifacts/DarjaTogether-unsigned.ipa > artifacts/DarjaTogether-unsigned.ipa.sha256
cp Docs/INSTALL.md artifacts/INSTALL.md
python3 - <<'PY'
from pathlib import Path
import datetime, hashlib, json, os
ipa = Path("artifacts/DarjaTogether-unsigned.ipa")
repository, run_id = os.getenv("GITHUB_REPOSITORY"), os.getenv("GITHUB_RUN_ID")
metadata = {
    "app": "Darja Together", "version": "1.0", "bundle": "com.darjatogether.learn",
    "architecture": "arm64", "platform": "iOS device", "minimumIOS": "17.0",
    "sourceCommit": os.getenv("GITHUB_SHA"),
    "buildURL": f"https://github.com/{repository}/actions/runs/{run_id}" if repository and run_id else None,
    "createdUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "ipa": ipa.name, "sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(), "bytes": ipa.stat().st_size,
    "signing": "Unsigned; sign during installation with Sideloadly or AltStore Classic",
    "physicalDeviceTested": False,
}
Path("artifacts/build-info.json").write_text(json.dumps(metadata, indent=2) + "\n")
PY
echo "Ready: artifacts/DarjaTogether-unsigned.ipa"