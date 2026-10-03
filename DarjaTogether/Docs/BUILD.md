# Native build and verification

Darja Together is a native SwiftUI app for iOS/iPadOS 17+. `scripts/generate_project.py` creates its dependency-free Xcode project, shared scheme, UI-test target, and privacy manifest. It compiles app sources and the pure Foundation `Sources/DarjaCore` model directly into the app; Swift Package Manager tests that model separately.

The macOS workflow validates the IPA checker, runs native model tests, compiles and launches the iPhone simulator, runs XCUITest interactions with real screen attachments, and then compiles a Release ARM64 physical-device binary. The simulator and device builds use separate derived-data directories.

The device packaging script checks the executable architecture, Mach-O iOS-device platform, bundle identifier, iOS minimum, and Payload layout. Its unsigned IPA is intended for signing during installation using Sideloadly or AltStore Classic. The workflow also retains Xcode logs, actual simulator screenshots, native UI-test results, and a screen recording of interaction tests.

Build results and release checksums are recorded with the delivered IPA after the workflow completes. A source project or generated Xcode file alone is not evidence of a successful native build.
