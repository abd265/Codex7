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

Known validation boundary at preparation: native SwiftUI has not yet been compiled by Xcode or visually reviewed on an iPhone simulator. Codemagic access is required for that gate in this Linux workspace.
