# Prism Harbour

A complete offline native SwiftUI puzzle game for iPhone and iPad, iOS 17 or later. Slide coloured polyominoes to matching docks, clear the board, and explore a quiet, original coastal world.

## Included

- Thirty-six solvable campaign levels across three chapters, with rectangular and L-shaped pieces, fixed obstacles, and varied dock positions.
- A deterministic daily puzzle that changes at local midnight.
- Touch dragging, tap-and-arrow controls, and VoiceOver movement actions. Matching symbols support colour recognition.
- Timed play and an optional untimed Calm mode for campaign levels.
- Pause/resume, retry, free undo, hints, and extra time. Pearls are earned in play; there are no purchases, ads, or accounts.
- Stars, best move records, progressive level unlocks, six earned treasures, and daily rewards.
- Atomic on-device saving of progress, settings, remaining time, the active board, and undo history.
- Original vector harbour scenes, faceted pieces, an original app icon, and three gentle synthesized sound effects.
- Self-contained Xcode project, Foundation game library, XCTest suite, GitHub Actions and Codemagic build workflows, and IPA validation.

## Play

Drag a prism horizontally or vertically. Its entire shape moves together; pieces cannot rotate or overlap. A piece leaves the board only through a dock with the same colour and symbol, wide enough for its full shape. Once the leading edge reaches a valid dock, the game checks the whole exit path before removing the piece.

A gesture counts as one move even when travelling multiple squares. A blocked gesture does not count. Match the level's move target for three stars. Undo restores the previous board and move count but does not restore elapsed time. Hints cost 15 pearls, and 30 extra seconds costs 30 pearls. Restarting and undoing are free. Repeating a completed level cannot repeatedly farm its first-clear reward.

## Build and install

Open `PrismHarbour.xcodeproj` on a Mac with current Xcode, select the shared **PrismHarbour** scheme, and run on an iPhone simulator. No third-party packages are needed.

```sh
swift test
bash scripts/build_simulator.sh
bash scripts/build_device.sh
```

The device script creates `artifacts/PrismHarbour-unsigned.ipa`. It compiles a genuine physical-iPhone ARM64 executable, checks the Mach-O iOS device platform, verifies the IPA structure, and writes a SHA-256 checksum. The simulator ZIP is a separate artifact and cannot be installed on an iPhone.

Use **Sideloadly or AltStore** to sign the unsigned IPA with your Apple account during installation. No signing certificate or Apple password belongs in this project. See [the installation guide](Docs/INSTALL.md). This project does not provide an App Store or TestFlight distribution signature.

`.github/workflows/build-ios.yml` runs the tests and both builds on a Mac runner when used at a repository root. `codemagic.yaml` offers equivalent workflows. Regenerate the project after adding or removing Swift or resource files with `python3 scripts/generate_project.py`.

## Design and reference

The supplied 7.8-second recording contains promotional cards for **Block Out**, rather than recorded gameplay. The implementation interprets those cards as sliding coloured pieces through matching exits, with a timer and boosters. Prism Harbour's identity, assets, interface, level generator, and source code are original. No screenshots, branding, character artwork, or code from the reference app are bundled in the game.

## Data

All state is stored locally in Application Support/PrismHarbour/voyage.json. The app pauses when it leaves the foreground. A damaged save is preserved as a recovery copy. Deleting the app normally removes its save, so update over the existing installation using the same signing account and bundle identifier when possible.

The app has no network calls, analytics, authentication, advertising, tracking, payments, or server dependency. Preferences include sound, haptics, prism symbols, and Calm mode. Resetting progress requires an explicit in-app confirmation.

## Validation status

The [Mac build](https://github.com/abd265/Codex7/actions/runs/36265079805) succeeded on Xcode 26.6: 20 native rule tests passed, the app launched on an iPhone simulator, and the automated real-drag/dock/victory/next-level/pause/continue playthrough passed. The Release physical-iPhone ARM64 IPA passed format, architecture, platform, and checksum validation. Home, gameplay, map, victory, and next-level screenshots were inspected. Physical-device installation remains the user's signing step. See [QA notes](Docs/QA.md).

The app source is stored in `PrismHarbour/` on the `codex/prism-harbour` branch of [abd265/Codex7](https://github.com/abd265/Codex7/tree/codex/prism-harbour/PrismHarbour). The repository-root workflow `.github/workflows/prism-harbour.yml` builds this subfolder without changing the existing app. The workflow template inside this source folder is also suitable for a standalone repository.
