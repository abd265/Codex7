# RiseBake 2.0 — native iPhone baking companion

A component-based SwiftUI app for iOS 17 and later. Its screens use native controls, editable forms and persistent records. No web view, screenshot interface or invisible button overlays.

## Install on iPhone from Windows

The [iPhone build workflow](https://github.com/abd265/Codex7/actions/workflows/ios-sideload.yml) produces an unsigned physical-device IPA. Download the **RiseBake-iPhone** artifact from a successful run and install its IPA with Sideloadly using your Apple Account. See [Windows installation instructions](Docs/WINDOWS-IPHONE.md).

For an update, use the same Apple Account and bundle-ID settings, and install over the existing app. Do not uninstall first. The bundle ID stays `com.risebake.preview` to preserve existing records; the app displays RiseBake 2.0. Free-account signing still follows Apple's expiry rules.

## Features

- Sixteen menu items and sixteen matching high-resolution product photos, covering breads, pastries, cakes, cookies, brownies, muffins, cupcakes, tarts and macarons.
- Three illustrated backgrounds: Flour Garden, Berry Patisserie and Midnight Bakery, plus a plain option.
- Sixteen editable starter recipes with ingredients, units, yield scaling, method steps, planned times, oven temperatures and notes.
- A baking journal with recipe snapshots, ingredient checklists, pause/resume step timers, local timer alerts, actual elapsed times, tasting notes and ratings. Timers survive closing and reopening the app.
- Customer records, orders, pickup schedules, quotes, production checklists, recurring pickups, editable pricing/capacity, receipts and business insights.
- Manual records of payments already received; optional native Mail/SMS composers and a share sheet for customer messages.
- Atomic on-device storage, version-1 data migration, JSON export/restore and CSV export. Fresh installs start without fictional customer or transaction records.

The app is a local bakery manager. Online customer checkout, card processing, automatic messaging, cloud synchronization and tax accounting require separate integrations. The menu records orders on the device. Insight figures represent contribution after ingredient costs, not net profit.

## Development and verification

Open `RiseBake.xcodeproj` and run the shared RiseBake scheme in Xcode. No external Swift dependencies are needed. Run `swift test` for core business-logic tests. The iPhone workflow builds the device IPA, runs the native simulator UI test, and saves logs, screenshots and the test result bundle. The UI journey checks a running bake timer across relaunch, background persistence and adding a menu item to the basket.

Run `python3 scripts/generate_project.py` after adding Swift files. `scripts/expand_catalog.py` regenerates the bundled catalog and test fixture. Preserve existing product and recipe IDs when editing starter content.

[Release notes](Docs/RELEASE-2.0.md) describe upgrade behavior and feature limits. [Artwork prompts](Docs/art-prompts.json) record the generated-asset specifications. Full-resolution artwork is used in the app as optimized JPEGs; product images are 1254 × 1254 and backgrounds 1024 × 1536.

The older Codemagic simulator/Appetize workflow remains available for development, but no external preview service is required to use the installed app.
