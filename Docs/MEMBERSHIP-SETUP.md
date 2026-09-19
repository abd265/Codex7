# Rise & Bake — plans and purchase activation

Version 2.4 adds a real SwiftUI plans screen and StoreKit 2 integration. **The default IPA cannot charge users.** `MembershipConfig.json` has `enabled: false`; proposed prices are explicitly labelled. Selecting a plan does not create an entitlement. Restore explains availability without opening an Apple purchase prompt in this installation. Existing bakery features stay accessible without payment.

## Proposed offers

- Pro monthly: C$9.99/month.
- Pro annual: C$79.99/year.
- Offline edition: C$49.99 once, for phone-based features.

These retain the earlier recommendation; they are not a user-approved commercial launch. The proposed 14-day trial is not advertised or enabled. Do not enable an introductory offer until its exact terms and eligibility UI are implemented. Cloud sync and a customer website are not included in these screens' claims. Account security must remain free.

## Prepared integration

- Product identifiers: `com.risebake.pro.monthly`, `com.risebake.pro.annual`, `com.risebake.offline`.
- Monthly/annual require auto-renewable products of exactly one month/one year. Offline requires a non-consumable. Unexpected products/types are ignored.
- The live screen displays Apple's localized price, never charges using the proposed CAD label, and leaves missing products unavailable.
- Only verified StoreKit transactions grant an active purchase status. Expired, revoked, upgraded, wrong-type and unknown-product transactions are ignored. Nothing in a bakery JSON backup can grant a purchase.
- Purchase cancellation leaves status unchanged; pending approvals are explained. Transaction updates and relaunch refresh status. Verified handled transactions are finished.
- Restore calls `AppStore.sync()` only after an explicit tap. Manage subscriptions opens Apple's account subscription management.
- An active purchase prevents an accidental second purchase through this screen; subscription changes use Apple's management page.

## Before enabling public sales

1. Obtain Apple Developer Program access, agree to required commercial terms, and set up the app and products in App Store Connect with the actual signed bundle identifier. Keep monthly/annual products in the same subscription group.
2. Approve which offers will actually be sold and their prices. The configuration currently describes all three proposals; remove offers not selected for launch.
3. Publish actual privacy and terms pages and put their HTTPS URLs in `MembershipConfig.json`. Validate the configuration and enable it only in a suitably provisioned distribution build. Do not enable it in the unsigned/free Sideloadly package.
4. Define and implement the commercial paid-access policy before launch. The delivered owner installation intentionally has no feature lock. Purchase status is not server authorization and is not currently tied to a Supabase user. If a future service sells cross-device features, implement server verification and ownership mapping first.
5. Verify live sandbox purchase/restore for all offers, cancellation, pending approval, renewal, expiration, refund/revocation, subscription changes, billing retry/grace-period behavior and App Store-account changes. Current conservative entitlement expiry logic does not extend access for billing grace periods.
6. Before App Review, complete legal, pricing, subscription disclosures, App Store privacy details and account deletion checks. No trial, cloud backup or permanent hosted-service promise should be advertised unless implemented and verified.

## Local verification

`UITests/RiseBakePlans.storekit` is available to the Debug app and UI-test target, and explicitly excluded from the Release app. The Debug scheme selects that local configuration so the app's transaction queries use the same environment as `SKTestSession`. The Debug-only `--storekit-test` switch initializes a local `SKTestSession` in the app process as well as enabling StoreKit access. Its transactions are controlled by the UI-test runner; relaunch never clears them. StoreKitTest imports and session setup are compiled out of Release. It does not mock successful transactions and is unavailable in Release. The native test buys the offline non-consumable with Apple's StoreKit test framework, relaunches, restores it, and checks that another purchase is prevented. This is not a production App Store transaction.

**Current result:** the local purchase test has not passed. Product loading succeeds, but the entitlement check does not complete before the test's timeout. Purchase, persistence of a purchased entitlement and restore are therefore unverified. Keep `MembershipConfig.json` disabled; see [the feature checklist's verification evidence](FEATURE-STATUS.md#verification-for-the-24-installation-update). The test's intended steps above are not a claim that those steps passed.

References: https://developer.apple.com/documentation/storekit ; https://developer.apple.com/documentation/storekittest ; https://developer.apple.com/app-store/review/guidelines/
