# Prism Harbour artwork

The 2.0 visual refresh uses original generated world and reward illustrations alongside native, interactive SwiftUI game elements. The direction is a luminous storybook harbour with purple, turquoise and warm gold; rounded, dimensional materials; clear silhouettes; and a welcoming casual-game finish. No UI text, buttons, or gameplay boards are baked into the artwork.

## Production assets

| Asset name | File | Dimensions | Intended use |
| --- | --- | --- | --- |
| `HarbourWorld` | `PrismHarbour/Assets.xcassets/HarbourWorld.imageset/HarbourWorld.jpg` | 1024 Ã— 1536 | Home and voyage world backdrop |
| `PrizeChest` | `PrismHarbour/Assets.xcassets/PrizeChest.imageset/PrizeChest.jpg` | 768 Ã— 768 | Treasure and victory illustration |

All three images were created on 2026-09-26 with the **built-in image generation tool**, not the fallback CLI/API. Each was generated from the text prompt below without image inputs. The originals remain in the tool's generated-images directory; the project contains production copies so the game has no dependency on those external files. Production copies use JPEG quality 92 with 4:4:4 chroma. PrizeChest was downscaled from 1254 Ã— 1254 using Lanczos; HarbourWorld retains its original dimensions. No generated image was substantively retouched.

All three output illustrations were visually inspected for subject, composition, clean rendering, absence of text, and coherence with the purple/teal/gold direction. The world places the lighthouse above the central island, leaves indigo sky for the separately rendered wordmark, and leaves the lower water open for controls. The prize chest reads as a single bright dimensional reward against an uncluttered purple field.

## Final generation prompts

### HarbourWorld

```text
Use case: stylized-concept
Asset type: premium casual mobile puzzle game home-screen background, portrait 2:3 aspect ratio, 1024x1536 pixels.
Primary request: Create an original, exceptionally polished storybook 3D magical harbour illustration for Prism Harbour. A beautiful small jewel island in a serene luminous turquoise bay, central whimsical white lighthouse with a rich violet roof and gold rim, tiny curved bridge and cosy pastel harbour buildings nestled on a lush island. A few gemlike rocky islands recede into the distance. High-end pre-rendered casual game art with dimensional shapes, beautiful soft material rendering, rounded sculpted forms, crisp detail, eye-catching depth, and enchanting luminous water.
Composition/framing: Portrait. The main lighthouse and island occupy the middle 45% of the canvas, lighthouse light at roughly 43% from the top. Leave the upper 24% as richly graded dark indigo-blue sky with subtle stars and wisps for a separately rendered title. Leave lower 27% relatively uncluttered deep teal-blue water for separately rendered game controls. Small foreground crystals can frame the extreme bottom corners. Avoid cropping the lighthouse.
Lighting/mood: Magical blue-hour twilight, warm gold light from the lighthouse and windows, aqua water reflections, soft atmospheric haze, vibrant but cohesive saturation. Purple, teal, turquoise, sapphire and warm gold, gentle rose accents.
Materials/textures: Smooth lovingly rendered 3D game illustration, glossy gemstones, soft rounded foliage, stone island edges, sparkling water highlights; premium production quality, readable large shapes, never flat vector.
Constraints: Original world art only. No text, lettering, logo, border, UI, buttons, watermark, characters or people. Full bleed illustration. No candy or existing intellectual property. Keep critical art within middle vertical section.
```

### PrizeChest

```text
Use case: stylized-concept
Asset type: Square 1024x1024 premium casual mobile puzzle-game reward illustration for Prism Harbour.
Primary request: Create an original polished 3D storybook treasure chest overflowing with glossy luminous gems. A beautiful chunky golden treasure chest with rich purple enamel panels, rounded gold hardware, tiny central faceted turquoise jewel emblem, open lid, brimful of oversized exquisitely faceted sapphire, turquoise, violet, coral and golden jewels. A few gems and coins spill in front. This is a joyful, precious game reward, with gorgeous painterly 3D production quality and clean easily readable sculpted forms.
Composition/framing: Square illustration. Single hero chest centered, occupies central 70% width and roughly 62% height, viewed slightly above and from the front so gems and open lid read clearly. Generous negative-space margin. Soft starbursts and restrained magical sparkles around the chest, no more than a few distinct points.
Scene/backdrop: Seamless deep royal purple-indigo background with a subtle soft circular violet illumination behind the chest, and soft grounding shadow, suitable for clipping into a rounded rectangle in a game UI. No scenery or room.
Lighting/mood: Radiant warm gold light shining from within the chest, bright cyan and violet gem reflections, premium theatrical rim lighting, saturated jewel colours and playful inviting mood. Smooth dimensional render, polished precious metals, beautifully crisp gem facets. Match a magical twilight harbour game.
Constraints: No text, lettering, logo, watermark, borders, UI or buttons. No characters or hands. Original assets only. Avoid flat vector, generic stock icon, excessive small clutter, muddy dark rendering.
```

## Original generation files

- HarbourWorld: `C:\Users\abdel\.codex\generated_images\01a0df43-0293-7d93-9701-fe181d52d004\exec-214b0a64-4ca2-474e-b33f-52d775212698.png`
- PrizeChest: `C:\Users\abdel\.codex\generated_images\01a0df43-0293-7d93-9701-fe181d52d004\exec-cf88feac-a69c-4f22-8b01-2ddf068dc1a5.png`


### AppIcon

The matching icon replaces the original simple lighthouse icon. It is opaque RGB PNG in all sizes already listed by the app icon catalog, derived from the 1254 × 1254 generated master using Lanczos. No border or rounded corners are baked in. The luminous central prism lantern and lighthouse silhouette remain recognizable at small sizes.

```text
Use case: stylized-concept
Asset type: Finished iOS app icon illustration, square 1024x1024 pixels, full bleed opaque image. Prism Harbour original casual puzzle game.
Primary request: One beautiful magical lighthouse topped by an oversized luminous faceted turquoise prism lantern, on a tiny rounded stone island above deep teal water, against rich royal purple twilight sky. The lighthouse has creamy ivory sculpted walls, gold trim, a violet pointed roof and warm glowing window. Jewel lantern emits a restrained aqua halo. A single tiny coral-pink crystal at the island base ties in the jewel puzzle theme.
Composition/framing: Make a very strong simple centred silhouette readable at 60px. Lighthouse occupies about 75% of image height and the small rounded island occupies lower quarter. Few large readable shapes; no intricate scenery, extra islands, buildings, boats or trees. Three-quarter view just enough to show depth. Leave clean purple air around the lantern silhouette. Bright cheerful palette with exceptional polish.
Style/medium: Premium casual-game 3D rendered illustration with rounded toy-like sculpted forms, glossy jewel, soft polished materials, crisp edge lighting, warm gold highlights, convincing shadows and depth. A dimensional app icon, never a flat vector.
Lighting/mood: Luminous turquoise lantern, warm gold window, saturated violet backdrop, teal-blue base. Inviting, magical, joyful.
Constraints: No text, letters, numbers, logo, watermark, UI, frame, outer border or rounded corners (iOS clips the icon itself). Opaque full-bleed square. Original asset, no existing branded characters. Avoid photographic realism, excessive tiny details, dark muddy image.
```

Original generation file: `C:\Users\abdel\.codex\generated_images\01a0df43-0293-7d93-9701-fe181d52d004\exec-af04a3c1-0f6f-43db-ad2f-d7f98ac0d9ff.png`
