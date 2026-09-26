# Install Prism Harbour on your iPhone

Prism Harbour supports iPhone and iPad running iOS/iPadOS 17 or later.
The installable build is **PrismHarbour-unsigned.ipa**. Sideloadly or AltStore Classic
signs this IPA using your own Apple Account as part of installation.

## Sideloadly on Windows or macOS

1. Install [Sideloadly](https://sideloadly.io/) and follow its current setup
   instructions for the Apple device drivers on your computer.
2. Connect and unlock your iPhone, and accept **Trust This Computer** if prompted.
3. Open Sideloadly, choose your connected iPhone, and drag
   **PrismHarbour-unsigned.ipa** into the app.
4. Enter your Apple Account in Sideloadly and choose **Start**. Complete any
   authentication prompts inside Sideloadly.
5. If iOS asks, trust the developer profile under **Settings > General >
   VPN & Device Management**. Enable **Developer Mode** under **Settings >
   Privacy & Security**, then follow the restart prompts.
6. Open **Prism Harbour** from your Home Screen.

Sideloadly signs the unsigned app during this process. Its
[official FAQ](https://sideloadly.io/faq) covers account expiry, refreshes,
connection problems, and Developer Mode. Keep the same bundle/account identity
when installing updates to preserve saved progress. Removing the app deletes
its local game data.

## AltStore Classic

Install AltServer on your computer and AltStore Classic on the iPhone using the
[official AltStore instructions](https://faq.altstore.io/).
Keep AltServer available, copy the IPA into Files on your iPhone, then import
the IPA using the plus button in AltStore's **My Apps** tab. Complete its
authentication and signing prompts. Use AltStore's refresh function as required
by your Apple Account.

## Produce the IPA from the source

The source archive and Xcode project are not themselves an IPA. The native
SwiftUI app must be compiled with Apple's iOS SDK on macOS with Xcode 16 or later.
No Apple signing certificate or provisioning profile is required to produce the
unsigned artifact.

On a Mac, open Terminal in this project and run:

    swift test
    bash scripts/build_simulator.sh
    bash scripts/build_device.sh

The final output is:

    artifacts/PrismHarbour-unsigned.ipa

The scripts regenerate the Xcode project, compile the native app, verify the
ARM64 Mach-O binary is built for physical iOS devices, create the Payload
archive, and validate the finished IPA. They also produce a SHA-256 checksum
and real simulator screenshots. Simulator binaries are packaged separately
and cannot be installed on a physical iPhone.

For a hosted Mac build, use the included **.github/workflows/build-ios.yml**
workflow in your own GitHub repository, or the **codemagic.yaml** workflow in your
own Codemagic project. Download the **PrismHarbour-iPhone-IPA** artifact after a
successful GitHub Actions run and extract the IPA. These configurations do not
publish to the App Store, connect an Apple Account, or send anyone messages.

For development in Xcode, open **PrismHarbour.xcodeproj**, choose the
**PrismHarbour** scheme, and select an iPhone simulator. To install directly
from Xcode, choose your own signing team in the target's Signing & Capabilities.
Regenerate the project after adding new source or resource files:

    python3 scripts/generate_project.py

**Sources/PrismCore** is also a Swift package for unit testing. The generated iOS
project compiles those files directly, so it has no package-download dependency.