# Install Darja Together

Darja Together supports iPhone and iPad with iOS/iPadOS 17 or later. Version 1.1's native speech model is intended for recent devices with ample memory, with iPhone 17 Pro Max as the development target. The release file is **DarjaTogether-1.1.ipa**. The build artifact has the equivalent name **DarjaTogether-unsigned.ipa**.

## Install with Sideloadly

1. Open [Sideloadly](https://sideloadly.io/) on your Windows PC or Mac and follow its device setup instructions.
2. Connect and unlock your iPhone or iPad. Accept the computer trust prompt if it appears.
3. Select your device in Sideloadly and drag **DarjaTogether-1.1.ipa** into it.
4. Sign in with your own Apple Account inside Sideloadly and start installation.
5. Follow any developer trust or Developer Mode prompts on the device, then open **Darja Together**.

The build is a native physical-device IPA. Sideloadly signs it during installation. With a free Apple Account, Sideloadly's official FAQ currently describes a seven-day signing period and a limit of three sideloaded apps on the device. Enable its automatic refresh or refresh when needed. Keep the same signing account and bundle identifier when updating to preserve progress. Deleting the app removes its local data. See [Sideloadly's official FAQ](https://sideloadly.io/faq).

## First family setup

1. Open the app, enter an optional explorer nickname, and choose **Let's begin**.
2. Open the shield icon on Today and set your parent PIN.
3. Keep the default gentle eight-minute goal, or adjust it. Choose Nadia, Yacine or Fennec and English/French meanings.
4. If you want recordings, enable **Allow local voice recording**. In **Family voice studio**, record a few first-week examples in your family's Darja. Approve the iOS microphone request when it appears.
5. Return to Today and begin the first adventure together. Start with the picture and listening; script work can stay exploratory.

Family examples replace the synthetic model for their word. Otherwise the offline Algerian F5 model generates words, story lines and conversation prompts on the device. The first phrase can take a while; a progress indicator and Stop button are shown. Generated phrases are cached for faster replay. No speech or lesson text is uploaded.

Open **Parent space → Algerian voice** to try a sample or clear generated audio. Family recordings are kept when clearing this cache. Parents can explicitly switch to approximate iOS Arabic speech if needed. A model error is reported and does not silently switch voices. Pronunciation still needs family review; this build does not ship a professionally recorded native-speaker audio library. The reference voice supplied with the model is the Arabic base author's published example.

## AltStore Classic

You can also install the IPA with AltStore Classic and AltServer. Follow the [official AltStore instructions](https://faq.altstore.io/altstore-classic/your-altstore). Complete signing and refreshes inside AltStore.

## Build from source

On an Apple Silicon Mac with Xcode and an installed iOS simulator runtime, open **DarjaTogether.xcodeproj**, select the shared **DarjaTogether** scheme, and run on a simulator. The project resolves its pinned MLX Swift package. Prepare the verified model assets using [BUILD.md](BUILD.md) before testing native speech.

To reproduce the verification and device build:

```sh
python3 -m unittest discover -s scripts -p 'test_*.py'
swift test
bash scripts/build_simulator.sh
bash scripts/test_ui.sh
bash scripts/build_device.sh
```

The final file is `artifacts/DarjaTogether-unsigned.ipa`, accompanied by a SHA-256 checksum and platform validation JSON. The script verifies actual Mach-O load commands to reject simulator binaries even when they are ARM64. No Apple signing secret is required to compile the unsigned package. The separate simulator ZIP is for development and cannot be installed on an iPhone.

The standalone GitHub Actions workflow is `.github/workflows/build-ios.yml`. In the existing Codex7 repository, put this project in `DarjaTogether/` and use `scripts/codex7-workflow.yml` as the repository-root `.github/workflows/darja-together.yml`. Regenerate the project after adding Swift files or resources with `python3 scripts/generate_project.py`.

The app uses bundle identifier `com.darjatogether.learn` and version 1.1. This package does not include an App Store or TestFlight distribution signature. Use the same signing account and bundle identifier as version 1.0 to retain learning progress.
