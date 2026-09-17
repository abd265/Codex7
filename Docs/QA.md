# Native simulator acceptance checks

Automated gates in Codemagic: domain tests → Xcode simulator build → verify ARM simulator platform → install/launch on an available iPhone → verify process → capture screenshot → package actual .app → publish to Appetize. These are build and launch gates, not full visual or interaction tests.

Before treating the native conversion as release-ready, run the resulting simulator app:

- Open all five tabs and supporting screens, including landscape and a larger accessibility text size. Check for clipping in order rows and segmented controls.
- Create a customer and an order; verify it appears after terminating/relaunching the app.
- Check duplicate-line capacity rejection and save-error feedback in the order form.
- Request and approve a custom cake quote, record the deposit, advance to ready, and confirm the unpaid-balance warning at pickup.
- Change a product price and deposit setting; ensure existing orders preserve their agreed values.
- Complete a production step, edit the corresponding unstarted order quantity and verify the batch checklist resets.
- Skip a recurring week, pause/resume the plan and verify the skipped week remains skipped. Edit one week and verify the other three remain unchanged.
- Add products to the storefront basket, change quantities and place a simulated order; verify capacity and basket clearing.
- Add a demo message, share a receipt, export JSON/CSV, then restore a valid backup. Invalid backups must leave current data unchanged.
- Open the Appetize link in a second browser and interact with real native controls. Export any changes you want to keep before ending a session.

## Verified native build — 17 September 2026

Codemagic build `6aab44aa259504239f650740` finished successfully in 2m 40s on a Mac mini M2, using source commit `4da568d84764e9a575685a7267a5943965802e89`.

- All 14 domain tests passed on macOS with zero failures.
- Xcode 26.6 compiled the SwiftUI app for the ARM iOS Simulator.
- The build script verified the binary architecture and simulator platform, installed the app, launched `com.risebake.preview`, and verified that it remained running.
- Codemagic produced `RiseBake-simulator.zip` (1.28 MB) plus an artifact archive containing the real launch screenshot and logs.

[Open the verified Codemagic build](https://codemagic.io/app/6aaa9d3dd3d3257933be7676/build/6aab44aa259504239f650740?open-step=build-step-3).

Remaining validation: interactive and visual acceptance checks above, including matching the eight design references. The launch screenshot has been generated but has not yet been inspected. Appetize upload remains pending authenticated account access; no Appetize preview URL is claimed.
