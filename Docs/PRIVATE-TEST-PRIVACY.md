# Rise & Bake — private testing privacy

Applies to version 2.4.1's owner-only account test, configured for Supabase project `pvrrqcaujofdqknjeqsr`. Updated 19 September 2026.

## Account information

When you choose Create an account or Sign in, the app sends the email address and password you enter over HTTPS to the owner's Supabase authentication service. That service handles email verification, password recovery, user identifiers, authentication sessions and any authenticator factors you enroll. Authentication requests also expose network information such as IP address to the service. The project owner controls this project and its access. Supabase's [privacy policy](https://supabase.com/privacy) describes its processing.

The app stores session credentials and pending verification state in the device-only iOS Keychain. Authenticator setup material is displayed during enrollment. The app does not log passwords, tokens, email links or authenticator secrets. Optional copying of an authenticator setup key uses a local clipboard entry with a one-minute expiry.

## Bakery information

Orders, customer details, recipes, ingredient prices, baking records, bakery information and imported logos are stored in the app's on-device workspace. This version does not upload those records to Supabase. A newly authenticated account uses a separate local workspace; your existing phone-only bakery remains separate. Exports, PDF receipts, printing and sharing transfer the information you explicitly choose through the selected iOS destination.

## Your controls

You can continue using the phone-only bakery without creating an account. After signing in, More → Account & security provides authenticator management, sign-out and account deletion. Deletion requires recent authentication and any enrolled authenticator. The app removes that account's local workspace after the server confirms deletion. Copies you previously exported or shared are separate.

## Scope of this test

Use your own email and sample bakery records. The free test mailer currently accepts project-team email addresses only. Google, Apple sign-in, purchases, advertising and analytics SDKs are disabled in this build. There is no paid subscription in this test. This notice describes the private configuration; public customer release needs the operator's final contact information and policies.
