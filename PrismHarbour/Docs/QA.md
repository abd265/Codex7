# Prism Harbour verification record

## Current result — 26 September 2026

The source and deterministic puzzle construction have been reviewed locally. Native Swift compilation, simulator interaction, visual screenshots, physical-device launch, and the IPA binary remain **unverified until the macOS workflow runs successfully**. A source ZIP or independent model result is not an installable or tested iOS binary.

Local verification completed:

- An independent Python implementation replayed all 36 campaign solutions and 365 daily puzzles, covering 26 September 2026 through 25 September 2027. It also replayed the full reverse-construction history before testing its shortened solution, checked piece/obstacle overlap, unique IDs, board bounds, gate spans, and that no partially exited piece remains. All passed in 27.5 seconds.
- The campaign produced 36 distinct board fingerprints, 3–9 pieces per puzzle, and solution lengths of 3–47 gestures. Daily puzzles contained 8–9 pieces. The Python audit is a second implementation of the algorithm; the Swift test suite must independently confirm the actual app code.
- Static review checked full-path collisions, wrong-colour/side/span gate rejection, multi-cell gesture clamping, atomic exits for concave shapes, completion reward monotonicity, undo snapshots, atomic save writes, background pausing, and hint concurrency. The hint result now rechecks session identity, board identity, active gameplay, pause/expiry status, and available pearls before charging.
- Project generation, property lists, shared scheme XML, Bash syntax, and nine IPA validator unit tests passed locally, as recorded by the scaffold verification. The validator checks actual Mach-O device platform and architecture rather than accepting an ARM64 simulator executable.

Reproduce the independent audit from the project root:

```powershell
python scripts/audit_campaign.py --days 365
```

The result is written to `artifacts/campaign-audit.json`. Campaign boards and fingerprints are included so the model output can be cross-checked with native Swift. Do not rerun this automatically for every build unless generation changes; the native test suite already replays every campaign solution and selected daily dates.

## Required native verification

Run `swift test` on the macOS runner, followed by `scripts/build_device.sh` and `scripts/build_simulator.sh`. Retain test/build logs, device validation JSON, the IPA checksum, and the actual simulator screenshots. Inspect the home, gameplay, and level chart screenshots for clipping, readable gates and symbols, and legible controls. Simulator launch alone does not prove gesture behavior.

The Swift tests cover collisions with movable/fixed pieces; all four exits; wrong colour, side, and opening span; concave swept collisions; gesture clamping and move counts; invalid requests; all campaign solutions; deterministic daily puzzles; hints that require an alignment move; mid-game serialization; replay rewards; streak expiry; and progress migration defaults.

## Interactive acceptance checks

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
