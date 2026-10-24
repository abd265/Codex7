#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "The native speech build requires an Apple Silicon Mac with Xcode." >&2
  exit 1
fi
test -f Packages/DarjaF5/Package.swift
mkdir -p artifacts build
python3 scripts/generate_project.py
xcodebuild -version > artifacts/xcode-version-speech.txt
swift --version > artifacts/swift-version-speech.txt
system_profiler SPDisplaysDataType -json > artifacts/speech-gpu.json
xcrun swift -e 'import Metal; import Foundation; let device = MTLCreateSystemDefaultDevice(); let report: [String: Any] = ["available": device != nil, "name": device?.name ?? "none"]; let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]); print(String(decoding: data, as: UTF8.self))' > artifacts/speech-metal-device.json

# An explicit Xcode target compiles and places MLX's Metal resources alongside
# the executable. A plain SwiftPM binary alone is not sufficient evidence.
xcodebuild build \
  -project DarjaTogether.xcodeproj \
  -scheme DarjaF5Smoke \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/speech-macos \
  -clonedSourcePackagesDirPath "$PWD/build/source-packages" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee artifacts/xcodebuild-speech-macos.log
test -x build/speech-macos/Build/Products/Release/DarjaF5Smoke

# This compiles the actual app integration for a physical iPhone, without
# downloading weights or representing the model-free product as a release IPA.
xcodebuild build \
  -project DarjaTogether.xcodeproj \
  -scheme DarjaTogether \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  -clonedSourcePackagesDirPath "$PWD/build/source-packages" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee artifacts/xcodebuild-speech-ios.log
python3 scripts/validate_ipa.py build/device/Build/Products/Release-iphoneos/DarjaTogether.app --require-metal > artifacts/speech-compile-validation.json
resolution="DarjaTogether.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ -f "$resolution" ]]; then cp "$resolution" artifacts/speech-Package.resolved; fi
