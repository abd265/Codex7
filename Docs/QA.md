# Rise & Bake 2.1 validation

## Release evidence — 18 September 2026

- Version 2.1, build 23 uses the Home Screen name **Rise & Bake** and retains `com.risebake.preview` and the existing Application Support data folder.
- All 23 core tests passed, including old-backup compatibility, branding/logo round-trip, invalid profile rejection, agreed prices, correct paid/balance/quote labels and exclusion of private notes. The ARM64 physical-iPhone Release IPA compiled and passed archive, display-name, bundle-ID and platform checks.
- Native iPhone 16 Pro / iOS 18.5 evidence verifies editing/saving the bakery name, relaunching with the logo intact, branded receipt details and the native PDF preview. The existing recipe/timer/background/basket journey also passed.
- The first sharing assertion looked for buttons; the captured accessibility hierarchy showed a working system share sheet with **Save to Files** and **Print** exposed as cells. The test now checks those actual cell elements. The corrected test passed with the baking regression journey (2 tests, 0 failures): [final native/device run](https://github.com/abd265/Codex7/actions/runs/35363417228), commit `2a17e8d`.
- The same UIKit renderer used by the app generated a one-page branded receipt, an unpaid order summary without a logo, and a ten-page / 99-item receipt. PDF text checks confirmed every item and the correct totals/balances. All text stayed within page margins. The exported pages and native profile/receipt screens were visually reviewed.
- Logo checks verify 1600×800 input downsampling to transparent PNG at 1024×512, no change in proportions, rejection of non-images and survival through JSON backup/restore.
- Final IPA SHA-256: `e6657c3898cf7c0d8d4b8d95b6436db22aab16cb316823b11887f91c5ed970cb`.
- CI fixtures are inside `#if DEBUG`. The Release executable was checked to exclude the fixture launch switch.

Printing uses the iPhone system print dialog. A physical AirPrint printer and installation over the user's specific Sideloadly app still require their device; neither is represented as tested by CI. Currency remains CAD and the optional business/tax ID does not add a tax calculation.

## Previous RiseBake 2.0 validation

## Verified release evidence — 18 September 2026

- Build 21: all 19 core tests passed, the Release ARM64 iPhone app compiled, and its unsigned IPA passed archive, platform, bundle-ID and checksum checks. [Device build](https://github.com/abd265/Codex7/actions/runs/35358018001).
- The native interaction journey passed on iPhone 16 Pro / iOS 18.5: recipe navigation, starting a timer, relaunch persistence, pause, background selection/relaunch persistence and adding an item to the basket. [Passing native UI run](https://github.com/abd265/Codex7/actions/runs/35358018001), final build 21, commit `90ef020`.
- The Today, Menu, Backgrounds and baking timer screens were reviewed from actual native screenshots. An iOS 26.5 launch was also verified. The newer simulator image intermittently stalled during Apple's own LaunchServices migration; UI CI now pins the installed Xcode 16.4 / iOS 18.5 combination.
- Build 21 adds notes preservation when switching between tabs and carries production quantities into timed bakes. Its final native UI regression run passed with no failures. The earlier build-20 journey also passed before these fixes.
- Final IPA SHA-256: `3a8f2b928537b0fef7e6b8fa0bc03bde42b3bdcd0e21ca1ccab9674fc976013f`.

## Automated gates

- Core tests cover version-1 migration without losing orders, customers or custom prices; idempotent upgrades; recipe scaling and immutable bake snapshots; persisted timer pause/resume/completion; finishing a bake without inventing completed steps; malformed journal rejection; order capacity; deposit rules; recurring schedules; price snapshots; unpaid checkout; and CSV escaping.
- The physical-device build verifies an ARM64 iPhone binary and packages an unsigned IPA for Sideloadly.
- The native UI test launches the actual app, opens a recipe, starts a step timer, terminates/relaunches and confirms the timer remains active, pauses it, changes the background and verifies its selection survives relaunch, then adds a product to the basket.
- Simulator logs, launch screenshot, UI screenshots and XCTest results are retained as workflow artifacts.

## Device checks

The user installed and used the previous IPA with Sideloadly. The 2.0 update still needs installation on their own iPhone to confirm signing and preservation of that specific installation's records. Use the same Apple Account and bundle-ID settings, and install over the app.

Local notification delivery depends on notification permission and iPhone Focus/settings. Native Mail/SMS delivery requires a configured account or messaging service; simulator tests do not send real messages. These device/service-dependent checks must not be described as passed by CI.

There is no online payment processor or shared cloud datastore. Payment controls record amounts already received. The native app operates without Appetize.
