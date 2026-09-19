# Rise & Bake — prepared Supabase account changes

Target project: `pvrrqcaujofdqknjeqsr`. These files are prepared for review and application; they are **not deployed**. The installed Supabase plugin was confirmed on 19 September 2026, but its management operations were not exposed in that assistant session. No authenticated project configuration was read or changed through that connection.

## Prepared settings

`supabase/auth-settings.json` describes email/password accounts with required email confirmation, 12-character minimum passwords, six-digit email codes lasting 10 minutes, secure email-address changes and authenticator (TOTP) enrollment/verification. The two templates in `supabase/templates/` provide branded confirmation and password-reset emails for the native in-app code flow. They contain no external images, tracking links or user-supplied content.

**Email-provider prerequisite:** Supabase's [3 June 2026 change](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier) prevents new Free projects using the default email provider from changing Auth templates. Configure custom SMTP before applying the prepared templates. Custom SMTP allows template customization on the Free plan; buying a paid plan is not required for that option. The project's actual SMTP configuration still needs inspection.

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
5. Inspect the project's JWT signing mode and function list. Deploy the existing `supabase/functions/delete-account/` source with a gateway configuration compatible with that signing mode. Its handler independently verifies the bearer token with Supabase Auth and enforces recent authentication and MFA. Do not weaken those checks to make deployment succeed.
6. Leave Google and Apple disabled until their owner-controlled provider credentials and required provisioning are configured. Do not disable any authentication factor already used by existing accounts without reviewing recovery implications.
7. Complete the live acceptance checks in `ACCOUNTS-SETUP.md`, including verified signup, recovery, TOTP and deletion using owner-authorized test accounts. Configure real privacy/terms URLs before enabling accounts in the app and rebuilding the IPA.

Creating these files does not activate cloud bakery storage, billing, social providers, account deletion or email delivery. Current release account activation remains disabled pending configuration and live verification.
