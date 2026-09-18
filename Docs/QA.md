# RiseBake 2.0 validation

## Automated gates

- Core tests cover version-1 migration without losing orders, customers or custom prices; idempotent upgrades; recipe scaling and immutable bake snapshots; persisted timer pause/resume/completion; finishing a bake without inventing completed steps; malformed journal rejection; order capacity; deposit rules; recurring schedules; price snapshots; unpaid checkout; and CSV escaping.
- The physical-device build verifies an ARM64 iPhone binary and packages an unsigned IPA for Sideloadly.
- The native UI test launches the actual app, opens a recipe, starts a step timer, terminates/relaunches and confirms the timer remains active, pauses it, changes the background and verifies its selection survives relaunch, then adds a product to the basket.
- Simulator logs, launch screenshot, UI screenshots and XCTest results are retained as workflow artifacts.

## Device checks

The user installed and used the previous IPA with Sideloadly. The 2.0 update still needs installation on their own iPhone to confirm signing and preservation of that specific installation's records. Use the same Apple Account and bundle-ID settings, and install over the app.

Local notification delivery depends on notification permission and iPhone Focus/settings. Native Mail/SMS delivery requires a configured account or messaging service; simulator tests do not send real messages. These device/service-dependent checks must not be described as passed by CI.

There is no online payment processor or shared cloud datastore. Payment controls record amounts already received. The native app operates without Appetize.
