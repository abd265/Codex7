# Rise & Bake — Supabase account setup status

Target project: `pvrrqcaujofdqknjeqsr`, in the owner's Rise & Bake organization. On 19 September 2026, the owner completed dashboard sign-in and approved browser configuration. The installed Supabase plugin did not expose management operations, so the authenticated dashboard was used.

## Applied and verified in the dashboard

- Email/password signups and required email confirmation remain enabled.
- Minimum password length is 12 (verified visually after reopening the saved settings).
- Email OTP length is 6 and expiry is 600 seconds (verified after reopening).
- Secure email changes remain enabled; secure password changes now require a recent sign-in. Requiring the old password during recovery remains off.
- Authenticator TOTP is enabled. The existing 15-minute AAL1 session limit for MFA accounts remains enabled; SMS MFA remains disabled.
- Added the exact redirect `riseandbake://auth/callback`; the redirect list now contains that one entry. The default site URL remains `http://localhost:3000` pending the owner's real website.
- Deployed `delete-account` with the repository's `index.ts` and `policy.ts`. Both editor contents matched the local source before deployment. The function's gateway JWT verification switch remains enabled. The handler independently verifies the token with Auth, enforces recent authentication/MFA, revokes provider authorization and all refresh sessions, then deletes the Auth user. Access JWTs may persist until expiry; other sensitive endpoints must check current user/session state.

The deletion handler passed a Deno type check against the exact pinned npm dependencies; all five authorization-policy tests passed. Deployment was verified through dashboard state, **not** an account-deletion request. No users were created/deleted and no emails were sent. End-to-end signup, recovery, MFA and deletion remain unverified.

## Free private testing selected

The owner selected an entirely free private test. Version 2.4.1 enables email accounts using the default confirmation/reset links and the exact native callback already allowed. Pending link intent and recovery state survive relaunch in Keychain; the SDK verifies PKCE codes. Privacy and testing notes are hosted in this public repository. See [PRIVATE-TEST-NOTES.md](PRIVATE-TEST-NOTES.md). No domain or custom email provider is required for owner-only testing. The Supabase connector confirms the organization is on the Free plan and the deletion function is ACTIVE with JWT verification enabled.

## Public release blockers

Custom SMTP is off. The Templates page explicitly requires custom SMTP before editing subjects/bodies, so the branded templates below have **not** been applied. Customer email delivery, the operator’s final public privacy/terms/support details, provider credentials and live acceptance checks are still needed for launch. Google and Apple remain disabled. The previously installed 2.4 IPA stays unchanged; install the 2.4.1 private build for email-link testing. The default mailer only sends to project-team addresses, currently two emails per hour; do not grant organization access to ordinary testers as a workaround.

## Prepared settings

`supabase/auth-settings.json` describes email/password accounts with required email confirmation, 12-character minimum passwords, six-digit email codes lasting 10 minutes, secure email-address and password changes, and authenticator (TOTP) enrollment/verification. The two templates in `supabase/templates/` provide branded confirmation and password-reset emails for the native in-app code flow. They contain no external images, tracking links or user-supplied content.

**Email-provider prerequisite:** Supabase's [3 June 2026 change](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier) prevents new Free projects using the default email provider from changing Auth templates. Configure custom SMTP before applying the prepared templates. Custom SMTP allows template customization on the Free plan; buying a paid plan is not required for that option. This restriction was confirmed in the project's Templates page.

Generate the complete non-secret Management API request body locally:

```sh
python3 scripts/render_auth_setup.py
```

This command only prints JSON. It does not read credentials, contact Supabase, change project settings or send email. The field names were checked against Supabase's [current Auth configuration reference](https://supabase.com/docs/reference/api/v1-update-auth-service-config) and the token placeholder against its [email template documentation](https://supabase.com/docs/guides/auth/auth-email-templates).

## Apply through authenticated project management

1. Verify the selected project reference and read the current Auth settings. Review the prepared fields before applying the partial update; preserve all unrelated settings. Do not replace or print the project's SMTP credentials or provider secrets.
2. Confirm that template customization is available (custom SMTP is required for a new Free project), then apply the two templates together with six-digit OTP length and 600-second expiry. Template copy and server expiry must agree. Keep email confirmation required. Do not submit the combined payload while template customization is unavailable.
3. Add exactly `riseandbake://auth/callback` to the existing redirect allowlist, preserving other approved entries. Set the site URL only after the owner's actual website URL is known.
4. Inspect SMTP configuration and arrange real email delivery. The default Supabase mailer is limited to project-team addresses; it cannot be treated as customer-ready delivery. Enter any SMTP credentials directly in the authenticated service, not in this repository or chat. See [Supabase's SMTP requirements](https://supabase.com/docs/guides/auth/auth-smtp).
5. Preserve and verify the deployed `supabase/functions/delete-account/` source. Keep gateway JWT verification enabled: current [Supabase documentation](https://supabase.com/docs/guides/functions/auth-headers) supports legacy and asymmetric user JWTs. The dashboard still labels its switch "Verify JWT with legacy secret"; confirm compatibility during the authenticated acceptance test. The handler independently verifies the bearer token with Supabase Auth and enforces recent authentication and MFA. Do not weaken those checks to make testing succeed.
6. Leave Google and Apple disabled until their owner-controlled provider credentials and required provisioning are configured. Do not disable any authentication factor already used by existing accounts without reviewing recovery implications.
7. Complete the live acceptance checks in `ACCOUNTS-SETUP.md`, including verified signup, recovery, TOTP and deletion using owner-authorized test accounts. Configure real privacy/terms URLs before enabling accounts in the app and rebuilding the IPA.

These changes do not activate cloud bakery storage, billing, social providers or customer email delivery. Account deletion is deployed but not live-tested. Version 2.4.1 enables private email-link testing. Public availability, social providers and payments remain pending configuration and live verification.
