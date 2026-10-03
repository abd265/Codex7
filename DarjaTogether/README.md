# Darja Together

A native SwiftUI Algerian Arabic learning app for complete beginners. The language starts simply, with pictures, listening, imitation and gradual Arabic-script exposure. The visual style respects a school-age child.

## What is included

- 36 weekly units in six stages, 180 short activities, 180 vocabulary/phrase cards, and 12 original shared-reading stories.
- Nadia, Yacine and Fennec companion avatars with native animation.
- Picture discovery, listen-and-find choices, local speaking practice, and finger tracing.
- Picture pairs, Darja café, story quests, letter building, guided conversations, home treasure hunts, spaced review, and a two-person family game.
- Arabic script, optional pronunciation hints, and English/French meaning support. The interface instructions are in English.
- Bookmarks, persistent progress, stars and passport stamps without loss penalties.
- Parent PIN, six separate practice counters, a shareable practice report, a gentle daily goal, microphone control, and teaching guidance.
- Family vocabulary and a voice studio. A family example overrides synthetic speech for its word. Child recordings are kept separate from pronunciation examples.

## What the app does honestly

The learning pack uses Central/Algiers-style Darja with feminine examples where relevant. Regional usage and spelling vary; a competent family speaker should review the examples and record preferred pronunciation. English and French meanings are helpers, not full interface localizations.

The bundled app uses prepared learning prompts, not a live generative AI chatbot. Speech uses an available iOS Arabic voice, clearly labelled as synthetic and potentially different from Darja. This build does not contain a professionally recorded native-Darja audio course or separate Oran/Constantine voice packs. Family recordings are the preferred model. If no Arabic voice is installed, the app reports that and supports family recordings.

The app does not score speech, certify fluency, or infer mastery from taps. Practice counters record participation; shared reading and guided tracing are not independent reading or handwriting assessments. Parent guidance explains how to observe real-life progress separately.

## Privacy

No account, network client, analytics, advertisements, or backend is required. Progress and family vocabulary are written atomically to local app storage. Voice recording is off by default and requires both the parent setting and iOS permission. Voice clips are limited to 30 seconds, protected by iOS file protection, and excluded from device backup. New recordings replace the corresponding previous clip only after a successful recording. Parents can play or remove both family examples and child practice clips.

The parent PIN is salted and hashed and has a short lockout after repeated incorrect attempts. It is a local child-access gate, not a replacement for iPhone security. Closing/backgrounding the parent panel locks it again. Learning data may be backed up under the device's settings. Removing the app removes local data.

## Build

iOS/iPadOS 17 or later. Build with macOS and Xcode; Windows can inspect/edit the source and install the resulting IPA with Sideloadly.

```sh
python3 scripts/generate_project.py
swift test
bash scripts/build_simulator.sh
bash scripts/test_ui.sh
bash scripts/build_device.sh
```

The generated project includes the Swift app, pure Foundation learning models/rules and the curriculum JSON. It has no third-party application dependency. The build pipeline validates that the IPA contains a physical-device ARM64 Mach-O executable, rather than a simulator binary.

Use the root `darja-together.yml` workflow when this project lives under `DarjaTogether/` in Codex7. A standalone workflow is included under `.github/workflows`.

See [the installation guide](Docs/INSTALL.md) and [curriculum notes](Docs/CURRICULUM-REVIEW.md) for family setup and content scope.
