# Rise & Bake — native iPhone baking companion

A component-based SwiftUI app for iOS 17 and later. Its screens use native controls, editable forms and persistent records. No web view, screenshot interface or invisible button overlays.

## Install on iPhone from Windows

The [iPhone build workflow](https://github.com/abd265/Codex7/actions/workflows/ios-sideload.yml) produces an unsigned physical-device IPA. Download the **RiseBake-iPhone** artifact from a successful run and install its IPA with Sideloadly using your Apple Account. See [Windows installation instructions](Docs/WINDOWS-IPHONE.md).

For an update, use the same Apple Account and bundle-ID settings, and install over the existing app. Do not uninstall first. The bundle ID stays `com.risebake.preview` to preserve existing records; the app displays Rise & Bake. Free-account signing still follows Apple's expiry rules.

## Features

- Sixteen menu items and sixteen matching high-resolution product photos, covering breads, pastries, cakes, cookies, brownies, muffins, cupcakes, tarts and macarons.
- Three illustrated backgrounds: Flour Garden, Berry Patisserie and Midnight Bakery, plus a plain option.
- Sixteen editable starter recipes with ingredients, units, yield scaling, method steps, planned times, oven temperatures and notes.
- A baking journal with recipe snapshots, ingredient checklists, pause/resume step timers, local timer alerts, actual elapsed times, tasting notes and ratings. Timers survive closing and reopening the app.
- Customer records, orders, pickup schedules, quotes, production checklists, recurring pickups, editable pricing/capacity, receipts and business insights.
- Manual records of payments already received; optional native Mail/SMS composers and a share sheet for customer messages.
- Atomic on-device storage, version-1 data migration, JSON export/restore and CSV export. Fresh installs start without fictional customer or transaction records.

The app is a local bakery manager. Online customer checkout, card processing, automatic messaging, cloud synchronization and tax accounting require separate integrations. The menu records orders on the device. Insight figures represent contribution after ingredient costs, not net profit.

## Purchase-based costing and shopping (2.3)

- Pantry purchase prices, package quantities, supplier/date notes, manual stock counts and explicit measured ingredient conversions.
- Recipe cost breakdowns covering ingredients, an extra-ingredient allowance, packaging, hands-on labour and overhead; missing prices stay incomplete.
- Current order cost/margin estimates using agreed sales prices, and suggested menu prices based on a target margin.
- Shopping lists from selected pickup orders: combine recipe quantities, optionally round to whole batches, subtract stock, estimate whole-package purchases, add extras, check off and share.
- Version 3 backups preserve these records and safely migrate earlier data. No live grocery feeds, guessed prices or automatic stock consumption are used.

See [costing and shopping instructions](Docs/COSTING-AND-SHOPPING.md) for accuracy assumptions, unit conventions, historical-cost limits and the distinction between recipe cost and package budgets.

## Accounts and launch pricing

Version 2.2 adds native sign-up/sign-in screens and an optional Supabase Auth integration for Google, Apple, email/password, email confirmation/recovery and authenticator-based two-factor authentication. It isolates on-device bakery records by account and includes a server-side account-deletion function with recent authentication and provider revocation.

**Account services are not activated in the default build.** An owner-controlled Supabase project, provider settings, SMTP delivery and legal pages are required. Native Apple sign-in additionally requires an appropriately provisioned Apple Developer build. Existing phone-only records remain usable. Sign-in does not provide cloud sync, and no paywall or billing has been added.

See [account setup and live acceptance checks](Docs/ACCOUNTS-SETUP.md) and the [pricing recommendation](Docs/PRICING.md).

## Development and verification

Open `RiseBake.xcodeproj` and run the shared RiseBake scheme in Xcode. The account integration uses the official Supabase Auth Swift SDK, pinned to 2.55.2. Run `swift test` for core business-logic tests. The iPhone workflow builds the device IPA, runs native simulator UI tests, and saves logs, screenshots and the test result bundle. The UI journeys check account-screen validation, branded receipt generation/sharing, a running bake timer across relaunch, background persistence and adding a menu item to the basket. The server deletion-policy checks cover ownership, recent authentication, MFA, recovery and malformed claims.

Run `python3 scripts/generate_project.py` after adding Swift files. `scripts/expand_catalog.py` regenerates the bundled catalog and test fixture. Preserve existing product and recipe IDs when editing starter content.

[Release notes](Docs/RELEASE-2.0.md) describe upgrade behavior and feature limits. [Artwork prompts](Docs/art-prompts.json) record the generated-asset specifications. Full-resolution artwork is used in the app as optimized JPEGs; product images are 1254 × 1254 and backgrounds 1024 × 1536.

The older Codemagic simulator/Appetize workflow remains available for development, but no external preview service is required to use the installed app.
