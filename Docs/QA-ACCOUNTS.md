# Rise & Bake 2.2 account integration — verification

Verified source: `ecd93c52312024960732abdea5f0a37ef726e7a1` (app implementation matches `00f7cef79d204774ef6f99251d630e3c08a64b2a`; subsequent changes align simulator architecture and capture the screen).

[Passing build and native tests](https://github.com/abd265/Codex7/actions/runs/35398912011), 18 September 2026:

- 28 core tests passed, including account access, email/code/password validation, configuration safeguards, separate account folders and clean account initialization.
- Server account-deletion function passed Deno type checking; all 5 deletion-policy tests passed. These cover account ownership, recent authentication, mandatory fresh TOTP for enrolled users, malformed authentication claims, and password-recovery restrictions.
- All 3 native UI journeys passed on iPhone 16 Pro / iOS 18.5, Xcode 16.4. Account sign-in/sign-up and invalid-input handling: 32.121 seconds; bakery profile/logo/receipt/PDF sharing: 48.265 seconds; recipe journal, timer persistence, backgrounds and basket: 46.254 seconds. Total 126.640 seconds.
- Native sign-in and sign-up screenshots were captured from the real SwiftUI app and visually reviewed. The signup capture revealed a blank native Apple label during the mode change. A subsequent label-only fix keeps the existing `.signIn` Apple label stable in both modes; all authentication actions and email-mode behavior are unchanged. The passing run above predates that label-only adjustment. No screenshot-based controls or fake successful sign-in are used.
- Physical iPhone release archive: iPhoneOS ARM64; bundle identifier `com.risebake.preview`; display name `Rise & Bake`; version 2.2, build 24. IPA 10,964,121 bytes; SHA-256 `aff1d7b4c1e53bcdf4d7e692b8ec04c8714ff2f5c41324ac8e2b1fec96feb05a`.

## Scope of verification

Account services remain disabled in the shipped default configuration. The existing phone-only workspace remains available. There are no embedded provider credentials, fake accounts, cloud bakery synchronization or subscription charges.

The policy and UI tests do **not** certify live authentication. Supabase provisioning, SMTP delivery, Google/Apple configuration, live email confirmation/recovery, live MFA enrollment/challenges, and real provider revocation/account deletion still require the owner's service configuration and the acceptance checks in [ACCOUNTS-SETUP.md](ACCOUNTS-SETUP.md). Native Apple sign-in additionally requires an appropriately provisioned Apple Developer build.

The simulator test script now builds test products once for the host architecture and runs them without rebuilding. This resolves the earlier mismatch where Auth was built for ARM64 but the test invocation selected x86_64.
