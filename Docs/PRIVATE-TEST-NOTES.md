# Rise & Bake — free private testing

Version 2.4.1 enables owner-only email account testing against the existing Free Supabase project. No domain, paid email provider, paid hosting, subscription purchase or Apple Developer membership is required for this private sideload workflow.

1. Export your existing bakery backup, then install the new IPA over the existing app with the same Sideloadly Apple Account and bundle-ID settings.
2. Open More → Create an account. Use the **email associated with your Supabase account**, and choose a new app password of at least 12 characters. Signing into Supabase's dashboard does not itself create an account inside Rise & Bake.
3. Open the confirmation email **on the same iPhone** and tap its link. Accept the prompt to open Rise & Bake. Complete this within ten minutes. The device that requested the email holds the PKCE verifier; opening the link on a PC or another phone cannot complete that session.
4. After signing in, use More → Account & security → Set up authenticator to test 2FA. Keep the authenticator available for subsequent sign-ins and password recovery.
5. To test recovery, sign out, enter the same email and tap Forgot password. Open the newest reset link on the same iPhone. Complete authenticator verification if enabled, then choose a new password.

The [default test mailer](https://supabase.com/docs/guides/auth/auth-smtp) currently allows **two emails per hour** for the project. Signup and recovery can use the whole allowance; repeated resends may need to wait. It only delivers to project-team email addresses. Do not invite ordinary app testers into the Supabase organization to expand this limit: organization access is administration access.

The app uses Supabase's standard email links, so no custom SMTP or branded template is needed for this test. The backend still enforces email confirmation, strong passwords, PKCE and enrolled MFA. Link errors never accept a session from URL fragments or skip authentication.

Bakery features remain available with Continue on this iPhone. A signed-in account starts a separate workspace; use explicit export/import to move your own records if desired. Pricing remains illustrative and purchase buttons remain unavailable. Google/Apple sign-in and public customer registration are not part of this test.

This is a private test build for checking the real services. Compilation, automated UI checks and policy tests do not establish that email delivery, MFA enrollment, recovery or deletion has completed on your physical iPhone. Report the specific step and error if one fails; never share your password, verification link, code or authenticator key in chat.
