# Challenge Voyage — version 3.0

The original 36-level campaign made it too easy to route each prism out separately. Challenge Voyage adds 20 fixed, interlocking boards while preserving that campaign and all existing progress.

## What makes these boards different

Every starting board defeats the solo-routing strategy: no piece can reach an exit while every other piece stays fixed. Clearing space and moving blockers is mandatory. The selected boards require between two and six distinct pieces to move before the first exit, and their shortest complete solutions take 20–38 gestures. Each straight drag counts once regardless of its distance, exactly as in the app.

Four five-level tiers — Crosscurrents, Tight Waters, Deep Strategy, and Master Harbour — increase the amount of planning, with different shapes, shore openings, walls, and occasional shorter relief puzzles. A locally quick exit can make the remaining solution longer; Challenge 12 is a useful example. Raw solver state count is not treated as a measure of human difficulty.

Challenges are untimed. A completed board always earns a star; three stars require the verified minimum move count, and two stars allow up to 50% more moves (minimum two extra). Free undo and retry make experimentation practical. Hints follow the recorded optimal route when possible; after a detour, a bounded search finds a legal route toward the next exit. That off-route hint is not a promise of an optimal complete solution.

## Reproducible evidence

- `Data/challenges.json` contains all shipped boards and complete solution certificates.
- `challenge-metrics.json` records exact move counts and minimum first-exit depth.
- `challenge-independent-audit.json` records independent replay, exhaustive movable-piece subset checks, and cooperation stages on the selected solutions.
- `scripts/ChallengeSolver/Program.cs` implements exhaustive A* with an admissible lower bound: sum of each remaining piece's minimum gesture distance to an exit with other pieces removed. Fixed walls remain. An immediately legal exit can be forced because removing a piece cannot block another move.
- `scripts/challenge_lab.py` supplies an independent bitboard model and candidate generation; `scripts/audit_campaign.py` supplies a second, direct geometry model. Every selected certificate was replayed through both.
- Native `ChallengeCatalogTests` replay every certificate in the production Swift engine and independently try routing each piece out with all other pieces fixed. Progress tests decode legacy saves and check independent challenge rewards and unlocks. Native UI tests drag through Challenge 1, unlock Challenge 2, resume it, and verify all 108 original campaign stars remain.

To regenerate Swift data and the UI gesture fixture after an intentional catalog change:

```sh
python3 scripts/generate_challenges.py
python3 scripts/generate_project.py
swift test
```

The offline Windows solver can be compiled with the .NET Framework C# compiler and `System.Web.Extensions.dll`, then run with an input array, an output JSON path, and a distinct-state budget. It is a development tool and is not shipped in the IPA. Its search results only claim optimality when the goal is reached before budget exhaustion.

## Progress and remaining tuning

Stable challenge IDs 101–120 use separate stars, best-move records, and unlocks. Original IDs 1–36, daily completions, coins, settings, the save location, and the bundle identifier remain unchanged. Players who finished the original voyage get Challenge Voyage on the main Play button. The original voyage remains available in the map selector.

These structural checks demonstrate a substantial increase in required interaction. They do not establish a particular number of minutes per level or a human completion rate. Real-player attempts, retries, hint use, and completion times should inform the next balancing pass; this release contains no analytics or network collection.
