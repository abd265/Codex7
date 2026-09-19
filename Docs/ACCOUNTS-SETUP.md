# Rise & Bake 2.4 — account activation

The native SwiftUI screens and Supabase Auth integration are implemented. Account services are **disabled by default** because no owner-controlled Supabase project, Google OAuth client, Apple configuration, SMTP sender, or public legal pages have been supplied. Version 2.4 opens the welcome screen once and keeps a Continue on this iPhone option for the existing bakery. The local choice is remembered. It does not create pretend accounts, promise cloud backup, or charge a subscription.

## What is included

- Native sign-in/sign-up, email confirmation codes, password reset codes and new-password screen.
- Google OAuth using the official SDK's PKCE and ASWebAuthenticationSession; native Sign in with Apple with a cryptographically random nonce.
- Optional authenticator-based two-factor authentication (TOTP), setup QR/key, verification, additional authenticators and removal requiring a current code.
- MFA checked using the fresh server user, before account records are opened, including during password recovery. Unknown assurance levels fail closed. Authenticator secrets are held only during enrollment; tokens live in the device-only Keychain.
- Separate on-device workspaces keyed by the authenticated user's UUID. A new account starts with an empty customer/order list. The existing phone-only bakery is preserved and never silently assigned to an account. Use Settings' export/import explicitly to move your own records.
- Sign-out, private background snapshot, and account deletion with recent authentication. The deployed delete-account function validates the bearer token with Auth, checks MFA and recent authentication, revokes linked Google and Apple authorization, and deletes the Auth user. Local account records are deleted only after the server confirms deletion.
- No cloud bakery database, Gmail mailbox access or marketing consent is included. Version 2.4 prepares separate StoreKit purchase/restore handling; see MEMBERSHIP-SETUP.md. Account services and purchases remain disabled in the default configuration.

## Activate email and Google (no Mac required to configure)

1. In your own Supabase account, create a project. Keep service-role/secret keys private. The app only needs its **Project URL** and **publishable key** (`sb_publishable_…`).
2. In Authentication, enable email/password, require email confirmation, set a minimum password length of 12, and enable TOTP enrollment/verification. Keep unsupported phone/passkey MFA disabled for this release. Configure rate limits, secure password changes and a real SMTP sender. Test with external email addresses; Supabase's default test mailer is not production delivery.
3. Change the Confirm signup and Reset password email templates to show `{{ .Token }}` as a six-digit code. This client uses in-app OTP verification, not email links. Configure six-digit OTP length and a suitably short expiry. Set the site URL to your real website. Allow exactly `riseandbake://auth/callback` for the native Google OAuth callback, without wildcards.
4. Create a Google OAuth **Web application** client in your Google Cloud project. Set Supabase's exact `/auth/v1/callback` URL as its authorized redirect. Enter that client ID/secret in Supabase's Google provider settings. Request only the normal identity scopes, not Gmail access. Complete Google's consent-screen/publishing steps for external customers.
5. Deploy `supabase/functions/delete-account/index.ts` using the Supabase CLI or dashboard. It uses the platform's server-side service-role environment; never copy that key into the app. Keep gateway JWT verification enabled for legacy JWT signing or configure the documented equivalent for your project's signing-key mode; the function independently calls `auth.getUser(token)` regardless. Test that anonymous/stale/AAL1 deletion attempts fail.
6. Publish your actual privacy policy, terms and support contact. Configure `RiseBake/Resources/AuthConfig.json`: set `enabled` true, the project URL and publishable key, `googleEnabled` true, and the two real HTTPS legal URLs. Leave `appleEnabled` false until the next section is complete. Public URL/key may be committed; Google client secret, SMTP credentials, Apple private key and service-role key must not be.
7. Run `python3 scripts/generate_project.py`, commit the changes, and let GitHub Actions or Codemagic produce the IPA. Install it with your existing method. Do not delete the current app first.

A Google-plus-email configuration can be used for private testing. Do not treat it as an App Store release with Apple sign-in omitted.

## Activate native Apple sign-in

This needs Apple Developer Program access and provisioning with the Sign in with Apple capability. A free personal Sideloadly signature does not provision this capability.

- Configure the existing app identifier with Apple and enable Sign in with Apple. Match the actual signed bundle identifier in Supabase's Apple provider audience configuration. Preserve `com.risebake.preview` for installations where preserving the existing data container is required; changing signing teams or identifiers may prevent an in-place update.
- For a properly provisioned build, set Xcode `CODE_SIGN_ENTITLEMENTS=RiseBake/AppleSignIn.entitlements` and sign with the corresponding profile. The default unsigned Sideloadly build intentionally does not request this entitlement.
- For account-deletion revocation, store `APPLE_CLIENT_ID` (native bundle ID), `APPLE_TEAM_ID`, `APPLE_KEY_ID`, and the `.p8` `APPLE_PRIVATE_KEY` only in Supabase Edge Function secrets. The function generates a short-lived client secret, exchanges a fresh Apple authorization code, verifies Apple's ID token belongs to the linked identity, and revokes Apple's token before deleting the account.
- Set `appleEnabled` true only after sign-in and deletion work on a properly signed physical device. Test private relay email and repeat authorization (Apple returns name/email only on initial approval).

## Required live acceptance checks before public launch

These cannot be certified without your configured services and credentials. Native UI tests and core policy tests are not substitutes for them.

1. New email signup → delivered confirmation code → confirmed session; incorrect/expired code rejected. Duplicate email response does not disclose account existence. Configure anti-abuse controls appropriate to your launch.
2. Email/password sign-in; failed password; network error; Google cancellation and successful return; Apple cancellation, new authorization and returning authorization.
3. Enroll an authenticator; reject incorrect code; finish enrollment; sign out/in and verify bakery data stays unavailable until a correct TOTP code. Confirm relaunch does not bypass MFA. Test enrollment cancellation and backup-factor removal.
4. Password recovery for a 2FA account must still require the enrolled authenticator before password update/account access. Test lost-factor recovery through a documented identity-verification support process, never an email-only bypass. This release does not issue backup recovery codes; users can enroll a second authenticator.
5. Two separate real users: no automatic access to one another's data or the legacy device workspace. Sign-out clears notifications; one account's deletion preserves the other account and phone-only records. A user must explicitly export/import any existing bakery they own.
6. Delete account with stale session, missing MFA and wrong Apple identity: reject. Delete a valid freshly authenticated account: revoke provider authorization and remove the Auth user plus local workspace. Confirm a later sign-in cannot restore deleted access. For a linked Google account, sign in with Google immediately before deletion (and complete MFA if enabled). Its access token is retained in memory for verified server-side consent revocation. If both Google and Apple identities are linked, sign in with Google first and confirm the deletion with Apple. No long-term provider refresh token is requested.
7. SMTP delivery, rate limits, privacy disclosures, terms, support procedures and App Store privacy labels reviewed against your deployed services. If cloud bakery data is added later, enforce owner UUID and conditional AAL2 in every database/storage RLS policy; a client-side screen is never a server authorization boundary.

## Reviewing the screens before activation

In 2.4 the Release app exposes the real SwiftUI sign-in/sign-up screens on its first launch and through permanent entries in More. The Debug-only `--show-welcome` argument resets only the remembered local choice for testing; it does not enable providers or create sessions. Email/password validation works, but unavailable services cannot create accounts. Providers are shown disabled until configured. Existing workspace tests continue to check persistence.

## References

- https://supabase.com/docs/reference/swift/auth-signinwithoauth
- https://supabase.com/docs/guides/auth/auth-mfa
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/guides/auth/social-login/auth-apple
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens
