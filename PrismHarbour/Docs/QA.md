# Prism Harbour verification record

## Current result â€” 26 September 2026

The native build and automated playthrough passed on Xcode 26.6. [Successful build](https://github.com/abd265/Codex7/actions/runs/36265079805), source commit `c0e13c0056b38e8d40dc9a599a59bef96a4cba05`.

- All **20 native Swift tests** passed with zero failures.
- The native app compiled and launched on the iPhone 17 Pro simulator.
- The **XCUITest playthrough passed**: a real vertical drag, all three introductory dock directions through native controls, the victory screen, next-level progression, pause, return home, and continue.
- Home, level-map, gameplay, victory, and next-level screenshots were visually inspected. Controls and content fit the tested iPhone display.
- The Release **ARM64 physical-iOS IPA** was compiled, downloaded, and validated locally. The downloaded artifact and inner IPA checksums matched the build outputs.
- Device support: iOS/iPadOS 17+. Bundle: `com.prismharbour.game`, version 1.0.
- IPA SHA-256: `2f56144d6664d77283be88627ed727128f3216870ce5651de8209d981115ebe7`.

The delivered IPA is unsigned for Sideloadly or AltStore to sign during installation. **Installation and launch on a physical iPhone have not been performed**; the user completes signing on their own device.

Local verification completed:

- An independent Python implementation replayed all 36 campaign solutions and 365 daily puzzles, covering 26 September 2026 through 25 September 2027. It also replayed the full reverse-construction history before testing its shortened solution, checked piece/obstacle overlap, unique IDs, board bounds, gate spans, and that no partially exited piece remains. All passed in 27.5 seconds.
- The campaign produced 36 distinct board fingerprints, 3â€“9 pieces per puzzle, and solution lengths of 3â€“47 gestures. Daily puzzles contained 8â€“9 pieces. The Python audit is a second implementation of the algorithm; the Swift test suite must independently confirm the actual app code.
- Static review checked full-path collisions, wrong-colour/side/span gate rejection, multi-cell gesture clamping, atomic exits for concave shapes, completion reward monotonicity, undo snapshots, atomic save writes, background pausing, and hint concurrency. The hint result now rechecks session identity, board identity, active gameplay, pause/expiry status, and available pearls before charging.
- Project generation, property lists, shared scheme XML, Bash syntax, and nine IPA validator unit tests passed locally, as recorded by the scaffold verification. The validator checks actual Mach-O device platform and architecture rather than accepting an ARM64 simulator executable.

Reproduce the independent audit from the project root:

```powershell
python scripts/audit_campaign.py --days 365
```

The result is written to `artifacts/campaign-audit.json`. Campaign boards and fingerprints are included so the model output can be cross-checked with native Swift. Do not rerun this automatically for every build unless generation changes; the native test suite already replays every campaign solution and selected daily dates.

## Reproduce native verification

Run `swift test`, `bash scripts/build_simulator.sh`, `bash scripts/test_ui.sh`, and `bash scripts/build_device.sh` on macOS. The successful workflow retains logs, device validation JSON, IPA checksums, simulator screenshots, and the native UI XCResult bundle. The Codex7 workflow lives at `.github/workflows/prism-harbour.yml` and runs from the `PrismHarbour/` subfolder.

The Swift tests cover collisions with movable/fixed pieces; all four exits; wrong colour, side, and opening span; concave swept collisions; gesture clamping and move counts; invalid requests; all campaign solutions; deterministic daily puzzles; hints that require an alignment move; mid-game serialization; replay rewards; streak expiry; and progress migration defaults.

## Extended manual acceptance checklist

The opening drag/dock/victory/next-level/pause/continue flow is covered by the passing automated UI test. The remaining scenarios below are additional manual coverage, not claims of completed physical-device testing.

1. Launch a fresh installation offline. Open Help, Settings, Voyage, and Treasures. Level 1 is unlocked and later levels are locked. Home reports 120 pearls and no completed levels.
2. Complete level 1 using three drag gestures: coral upward, mint downward, amber rightward. Confirm three stars, 55 earned pearls, level 2 unlocked, and a playable next-level action. Replay the same result and confirm no duplicate reward.
3. On level 2, test blocked movement against another piece and the border; neither should increment the move counter. Move a piece across several cells and confirm a single gesture counts once. Check that a piece only exits the dock matching its colour and symbol, with its complete width fitting the opening.
4. Tap a piece, then use the arrow controls. Check vertical dragging inside the scroll view, L-shaped hit regions, two pieces sharing one colour, and each VoiceOver movement action. The selected piece must remain the intended ID.
5. Use Undo after a translation and after a dock exit. Board positions and move count should restore, while spent time and pearls stay spent. Restart must ask for confirmation and restore the original board/time without refunding boosters.
6. Request a hint, then immediately move, restart, pause, leave, or spend pearls on time before the calculation returns. A stale result must never charge pearls, apply to another session, or produce a negative balance. A successful hint charges exactly 15 pearls and highlights a legal direction.
7. Leave and continue an unfinished puzzle. Force-close and relaunch after several moves. Verify board, move count, remaining time, undo history, pearls, settings, stars, and unlocks survive. Background the app while dragging; on return it must be paused with no stale piece offset.
8. Pause for at least ten seconds, view Help/Settings, then resume. The countdown must not lose the paused interval. Expire a short remaining timer, verify movement is blocked, then buy 30 seconds or retry. Calm mode has no countdown and affects newly started campaign levels only.
9. Complete the daily challenge, replay it, and confirm its 75-pearl reward is awarded only once. Daily completion must not unlock campaign levels. Verify a new puzzle at the player's next local calendar day; an already-started puzzle keeps its original daily key.
10. Test portrait layouts on a compact iPhone and a large iPhone/iPad, increased text size, Reduce Motion, colour symbols, VoiceOver, silent mode, and disabled sound/haptics. Confirm all controls remain reachable and overlays cannot execute hidden board moves.
11. Complete the final campaign level and confirm the return/replay actions work. Reset progress through the confirmation dialog and verify a fresh campaign after relaunch.
12. Validate the produced IPA with `python scripts/validate_ipa.py artifacts/PrismHarbour-unsigned.ipa`. Install with Sideloadly/AltStore on a real supported iPhone, launch offline, and complete at least one level before describing the IPA as device-tested.

## Known scope

The app is a standalone offline game with original branding and vector artwork, 36 campaign puzzles, and deterministic daily puzzles. No App Store/TestFlight distribution, account system, online leaderboard, backend sync, ads, or purchases are implemented. The build is unsigned for later signing by the user's sideloading tool. Real installation verification requires the user's iPhone and signing step.
