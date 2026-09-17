# RiseBake — native iOS

A SwiftUI iOS 17+ app converted from the latest available RiseBake deployment: `risebake-s4otbp`, source version `1789473015082` (15 September 2026). The Xcode target contains Swift, an asset catalog, sample JSON and a privacy manifest. It has no web view, HTML app, screenshot UI or invisible button overlays.

The actual native project has now passed its first Codemagic build: all 14 tests passed, Xcode compiled the app, and it installed and launched in an iPhone simulator. `RiseBake-simulator.zip` is available in the [successful build's artifacts](https://codemagic.io/app/6aaa9d3dd3d3257933be7676/build/6aab44aa259504239f650740?open-step=build-step-3). The compiled bundle is now deployed to Appetize. [Launch the native RiseBake preview](https://appetize.io/app/b_u7avwqivgfdqgcodbz6cl3wooy?device=iphone14pro&osVersion=17.2&toolbar=true), then choose **Tap to Start**. This upload was made from the Codemagic artifact through Appetize's upload UI; API credentials for automatic future publishing have not been configured.

## Open the app

Open `RiseBake.xcodeproj` in current Xcode, select the shared **RiseBake** scheme, choose an iPhone simulator and Run. No external Swift dependencies or project generator installation is required. The checked-in project is ready for Xcode; `scripts/generate_project.py` can regenerate it if files are added.

## Codemagic → Appetize

1. Put the **contents of this folder** in your GitHub, GitLab or Bitbucket repository. `codemagic.yaml` must be at the repository root.
2. In Codemagic, add that repository as an iOS app using YAML configuration.
3. In your Appetize organization, obtain an API token. Add it directly to Codemagic as a **Secret** named `APPETIZE_API_TOKEN` in the group `appetize_credentials`. Never commit a token or paste it into chat.
4. Select the `ios-appetize` workflow and start a build. It runs domain tests, builds an unsigned ARM iOS Simulator app on a Mac, installs and launches it in an iPhone simulator, captures a real screenshot, packages `RiseBake.app`, and uploads it to Appetize.
5. Open `Appetize-preview.txt` in the build artifacts for the interactive native preview link. The publishing log also prints the link.
6. After the first successful upload, set `APPETIZE_APP_PUBLIC_KEY` in the same group to the returned public key. Subsequent builds update the same preview instead of creating a new app.

The separate `ios-build` workflow compiles and produces `RiseBake-simulator.zip` without Appetize credentials. This is also useful for diagnosing the native build before publishing. The source ZIP itself cannot run in Appetize: Appetize requires the compiled simulator `.app` bundle.

The pipeline sets the Appetize app's **run** permission to public so anyone with the returned link can try this fictional-data preview. It does not grant public debugging or network-inspection permissions. Your Codemagic and Appetize account limits still apply. This simulator route does not require Apple distribution signing. Physical-device installation, TestFlight and the App Store require a separate signing/release setup.

## Native screens and workflows

| Area | Implemented behavior |
|---|---|
| Today | Latest native-style dashboard, sample-day counts, collected value, pickup list and shortcuts |
| Orders | Search and status filters, create/edit, timeline, quote approval, simulated deposits/payments, production/pickup transitions and cancellation |
| Order details | Items, agreed prices, allergy/design notes, balances, customer link, receipt share sheet and completed-pickup rating |
| Bake | Date selection, quantities derived from accepted orders, per-batch ingredients and persistent production checklists |
| Recurring | Four weekly occurrences, pause/resume, skip/restore and quantity/time changes for one week |
| Customers | Search, VIP filter, create/edit, preferences, history, demo messages and order creation |
| Storefront | Product photos, category/favorite filters, quantity basket, simulated checkout and custom cake requests |
| Products & pricing | Create/edit products, prices, costs, daily capacity, description, allergens and photo selection |
| More / insights / settings | Native navigation, booked/collected/contribution figures, preferences, JSON backup/restore, CSV export and sample reset |

The five system tabs are Today, Orders, Bake, Customers and More. Navigation stacks, large titles, SF Symbols, forms, date pickers, sheets, alerts, search, share sheets and file pickers are native SwiftUI. Colors and product imagery follow the latest native-styled web revision. System controls adapt to the iOS version running the simulator.

## Data and limits

The same 35 sample orders, six products, eight customers and four schedules are included. The sample clock stays on **10 April 2025**, matching the source app; future pickups use that sample clock. The sample data is bundled, not extracted from the user's browser storage.

Money uses integer cents. Duplicate order lines count toward daily capacity. Quotes do not enter production before approval and required deposits. Cancellation retains the order and recorded payments. Existing orders retain agreed prices/deposits after catalog/preferences change. Unpaid pickup requires an explicit confirmation. Pausing a recurring plan leaves started and skipped pickups intact. Quantity changes invalidate related production checklists. Failed state mutations are not persisted.

Changes save atomically to Application Support on the device/simulator. Invalid saved data is retained as a recovery copy. Appetize sessions may reset local storage: use the JSON export to keep changes. JSON backups use the existing version-1 web schema for the common data fields; native message records include IDs. There is no automatic cloud migration or sync.

This remains a functional preview with **simulated payments and messages**. No authentication, real card processing, delivery, email/SMS, push notifications, tax calculation or shared backend has been added. Insights show contribution after current ingredient cost, not net profit. Customer email addresses in the sample use `example.test`.

## Validation

`swift test` runs the Foundation domain tests. All 14 tests passed locally and on Codemagic. Xcode compilation and simulator launch succeeded. The uploaded app also launched on Appetize's iPhone 14 Pro running iOS 17.2. Native tab navigation, order details and a production checklist toggle were checked interactively. Full visual matching to the eight design references and the remaining end-to-end acceptance checks are still pending.

See `Docs/QA.md` for simulator acceptance checks and `Docs/SOURCE.md` for provenance and official deployment documentation.
