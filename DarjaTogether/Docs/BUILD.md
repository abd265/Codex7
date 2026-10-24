# Native build and verification

Darja Together is a native SwiftUI app for iOS/iPadOS 17+. `scripts/generate_project.py` creates its Xcode project, shared schemes, UI-test target, and privacy manifest. It compiles app sources and the pure Foundation `Sources/DarjaCore` model directly into the app; Swift Package Manager tests that learning model separately. The app links the local `Packages/DarjaF5` package, whose pinned MLX dependency provides the native speech runtime.

The macOS workflow validates the IPA checker, runs native model tests, compiles and launches the iPhone simulator, runs XCUITest interactions with real screen attachments, and then compiles a Release ARM64 physical-device binary. The simulator and device builds use separate derived-data directories.

The device packaging script checks the executable architecture, Mach-O iOS-device platform, bundle identifier, iOS minimum, and Payload layout. Its unsigned IPA is intended for signing during installation using Sideloadly or AltStore Classic. The workflow also retains Xcode logs, actual simulator screenshots, native UI-test results, and a screen recording of interaction tests.

Build results and release checksums are recorded with the delivered IPA after the workflow completes. A source project or generated Xcode file alone is not evidence of a successful native build.

## Native speech verification

The workflow has two modes. `compile` resolves the pinned package and builds the actual speech implementation for macOS and physical iPhone ARM64. It does not download the large checkpoint or produce a release IPA. `bundled` additionally prepares the model, runs a real native synthesis, exercises the app, and builds an IPA containing the inference assets. The workflow-dispatch input selects the mode; the workflow file records the default for pushes.

On an Apple Silicon Mac with Xcode, run:

```sh
bash scripts/compile_native_speech.sh
bash scripts/prepare_speech_bundle.sh
bash scripts/test_native_speech.sh
bash scripts/build_simulator.sh
bash scripts/test_ui.sh
DARJA_REQUIRE_SPEECH_MODEL=1 bash scripts/build_device.sh
```

Asset preparation uses an isolated Python 3.12 environment with `scripts/speech-requirements.txt`. It downloads the immutable checkpoint, verifies its checksum, prepares the reference/vocoder assets, and exports inference weights. The generated `DarjaTogether/Resources/SpeechModel` directory is copied intact into the app. Neither training checkpoints nor generated model weights are committed to Git. `scripts/prepare_upload.py` excludes that directory and refuses stray checkpoints or oversized files.

The native smoke executable is built by Xcode so MLX's Metal resources accompany it. Its output must be non-silent mono PCM16 at 24 kHz; the workflow retains the WAV, timing/memory output, GPU inventory, and validation report. The package checks the exact exported `vocab.json` token IDs rather than deriving them again from line endings in `vocab.txt`. A successful desktop synthesis does not establish physical-iPhone speed or memory use.

Release packaging validates all required speech assets and streams their SHA-256 checksums through the final IPA. `build-info.json` records the model revision and native synthesis report. A release requiring native speech refuses to package without successful synthesis evidence and a complete model bundle.
