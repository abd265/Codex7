# Prism Harbour

A complete offline native SwiftUI puzzle game for iPhone and iPad, iOS 17 or later. Slide coloured polyominoes to matching docks, clear the board, and explore an illustrated, magical coastal world.

## Included

- Thirty-six solvable campaign levels across three chapters, with rectangular and L-shaped pieces, fixed obstacles, and varied dock positions.
- A deterministic daily puzzle that changes at local midnight.
- Touch dragging, tap-and-arrow controls, and VoiceOver movement actions. Matching symbols support colour recognition.
- Timed play and an optional untimed Calm mode for campaign levels.
- Pause/resume, retry, free undo, hints, and extra time. Pearls are earned in play; there are no purchases, ads, or accounts.
- Stars, best move records, progressive level unlocks, six earned treasures, and daily rewards.
- Atomic on-device saving of progress, settings, remaining time, the active board, and undo history.
- Original illustrated harbour and treasure artwork, a matching app icon, and glossy bevelled jewels.
- Spring movement, dock flights, colour bursts, combo callouts, blocked-move shakes, floating home jewels, and a staged confetti-and-stars victory.
- Four original stereo sound cues with overlapping playback; effects respect Reduce Motion and scene activity.
- Winding chapter maps and dimensional controls, with the same working puzzle rules and save format as version 1.0.
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

Version 2.0 responds to the second reference recording with a richer casual-game presentation. The supplied Genies & Gems promotional video informed the visual energy, jewel materials, and celebratory effects. Prism Harbour keeps its original sliding puzzle mechanics. Generated asset prompts and provenance are recorded in [ART-DIRECTION.md](Docs/ART-DIRECTION.md).

The supplied 7.8-second recording contains promotional cards for **Block Out**, rather than recorded gameplay. The implementation interprets those cards as sliding coloured pieces through matching exits, with a timer and boosters. Prism Harbour's identity, assets, interface, level generator, and source code are original. No screenshots, branding, character artwork, or code from the reference app are bundled in the game.

## Data

All state is stored locally in Application Support/PrismHarbour/voyage.json. The app pauses when it leaves the foreground. A damaged save is preserved as a recovery copy. Deleting the app normally removes its save, so update over the existing installation using the same signing account and bundle identifier when possible.

The app has no network calls, analytics, authentication, advertising, tracking, payments, or server dependency. Preferences include sound, haptics, prism symbols, and Calm mode. Resetting progress requires an explicit in-app confirmation.

## Version 2.0 validation

The [Mac build](https://github.com/abd265/Codex7/actions/runs/36268279900) succeeded on Xcode 26.6: all 20 native puzzle tests and nine packaging tests passed. The iPhone 17 Pro simulator playthrough verified drag, blocked feedback, undo, three dock directions, victory, next level, pause, and resume. Native home, map, gameplay, and victory screenshots were inspected, along with recorded dock flights, particle bursts, and the star/confetti sequence. The Release ARM64 physical-iOS IPA passed platform, structure, and checksum validation. Version 2.0 has not yet been installed on a physical device. See [QA notes](Docs/QA.md).

The app source is stored in `PrismHarbour/` on the `codex/prism-harbour` branch of [abd265/Codex7](https://github.com/abd265/Codex7/tree/codex/prism-harbour/PrismHarbour). The repository-root workflow `.github/workflows/prism-harbour.yml` builds this subfolder without changing the existing app. The workflow template inside this source folder is also suitable for a standalone repository.
