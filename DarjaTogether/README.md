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
- Version 1.1 adds local Algerian F5-TTS generation for vocabulary, stories and guided conversations, with a bounded generated-audio cache and visible progress/stop controls.

## What the app does honestly

The learning pack uses Central/Algiers-style Darja with feminine examples where relevant. Regional usage and spelling vary; a competent family speaker should review the examples and record preferred pronunciation. English and French meanings are helpers, not full interface localizations.

The bundled app uses prepared learning prompts, not a live generative AI chatbot. Version 1.1 includes a native MLX Swift port of the Algerian F5-TTS checkpoint by Kamel Touati, derived from Ibrahim Salah's Arabic F5-TTS. Approximately 760 MB of converted inference assets are bundled, including a Vocos decoder. The original 3.54 GB PyTorch training checkpoint is downloaded and verified during preparation, but is not copied into the app.

Generated speech is synthetic and still needs a fluent family speaker's pronunciation review. The supplied six-second reference voice is the Arabic base model author's published inference example; it is not a recording of the learner or a family member. No professionally recorded native-Darja course or separate Oran/Constantine voice packs are included. Family recordings override generated speech for their word. Parents can explicitly select approximate iOS Arabic speech instead; a model error never silently selects that fallback.

The app does not score speech, certify fluency, or infer mastery from taps. Practice counters record participation; shared reading and guided tracing are not independent reading or handwriting assessments. Parent guidance explains how to observe real-life progress separately.

## Privacy

No account, network client, analytics, advertisements, or backend is required. Model inference runs locally. Generated audio is cached in the app's cache directory, capped at 256 MB; parents can clear it independently of family recordings. Progress and family vocabulary are written atomically to local app storage. Voice recording is off by default and requires both the parent setting and iOS permission. Voice clips are limited to 30 seconds, protected by iOS file protection, and excluded from device backup. New recordings replace the corresponding previous clip only after an explicit successful save. Interruptions discard an unfinished take. Parents can play or remove both family examples and child practice clips.

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

The generated project includes the Swift app, pure Foundation learning models/rules, curriculum JSON and local DarjaF5 Swift package. The native speech backend pins MLX Swift 0.21.2 and vendors adapted MIT-licensed F5/Vocos code. See [the build guide](Docs/BUILD.md) for model preparation and native synthesis verification before packaging a complete IPA. The pipeline validates the physical-device ARM64 executable and hashes the actual model assets inside the IPA. UI automation disables speech generation explicitly; a separate native synthesis check exercises the real checkpoint.

Use the root `darja-together.yml` workflow when this project lives under `DarjaTogether/` in Codex7. A standalone workflow is included under `.github/workflows`.

See [the installation guide](Docs/INSTALL.md) and [curriculum notes](Docs/CURRICULUM-REVIEW.md) for family setup and content scope.

Model provenance, inherited noncommercial restrictions and reference-voice details are recorded in [model notices](Docs/MODEL-NOTICES.md). The source archive excludes large weights; pinned preparation scripts reproduce the inference bundle.
