# Rise & Bake 2.4 — requested features and actual status

This checklist corrects the earlier gap between the delivered app and the account/pricing discussion. Native UI and account integration source are not proof of a working online service.

| Request | Delivered behavior | Remaining work |
|---|---|---|
| Rise & Bake name; real native app | SwiftUI controls, physical-iPhone IPA, existing bundle identity preserved | User verifies installation on their iPhone |
| More bakery items | 16 editable products and 16 linked recipes across the bakery catalogue | Bakers can customize their own items |
| High-resolution bakery assets | 16 selected product photos at 1254×1254; three themed backgrounds at 1024×1536 | These are the actual asset sizes; no 8K claim |
| Pick a background | Flour Garden, Berry Patisserie, Midnight Bakery, and plain appearance | None for the implemented selector |
| Track baking method, ingredients and time | Recipe book, editable recipe steps, scaled quantities, bake journal and persistent timers | Physical notification behavior depends on device permission |
| Bakery information and logo | Editable business profile and logo import | None for local profile editing |
| Branded receipts | Native receipt preview, PDF export, system sharing and printing | Receipts record payments; they do not charge customers |
| Accurate recipe costs | Enter actual package price/size/store/date; quantity conversions; packaging/labour/overhead/margin | No grocery-price feed or receipt OCR |
| Shopping list | Selected orders, shared ingredients, manually entered stock, package rounding, checkmarks and sharing | Checking a purchase does not automatically change stock |
| Visible sign-in/sign-up | Welcome form on first 2.4 launch; permanent More entries; separate create-account entry | Account service activation below |
| Email, Google, Apple sign-in | Integration source, email verification/reset, provider actions and unavailable-state UI | Supabase project, SMTP, Google credentials/consent and appropriate Apple provisioning remain unconfigured |
| Two-factor authentication | TOTP enrollment/challenges/removal and recovery access policy implemented | Requires live Auth configuration and live acceptance checks |
| User pricing | Native Plans & pricing from welcome, More and account settings | C$9.99/month, C$79.99/year and C$49.99 once are proposals, not approved live offers |
| Purchases and management | StoreKit product loading, verified transaction handling, purchase, restore and App Store management link | Products, legal pages, App Store signing, commercial approval and subscription testing/launch work remain |
| 14-day trial | Proposed in the pricing discussion | Not active or advertised as an available offer; needs App Store offer configuration and eligibility handling |
| Account-specific records | Separate local workspaces after verified sign-in | No cross-device cloud database or automatic cloud backup |
| Online customer storefront and payments | Not implemented | Current menu and customer payment records are local app features |

## Why account options were missing

The 2.3 Release configuration intentionally disabled unconfigured online services, but it also selected the local workspace immediately and conditionally hid the account section. The only way to inspect the full welcome screen was a Debug argument. This made the source/screenshots misleading as evidence of what an installed user could see. Pricing existed only in `Docs/PRICING.md`.

2.4 separates visibility from availability. Account entry points and plan comparisons always exist. Disabled providers are visibly unavailable; email submission cannot fabricate an account. A first welcome screen offers continued access to existing local records. That choice is remembered. No local bakery is deleted, reassigned, or uploaded.

## What must happen before calling this commercially complete

1. Owner-controlled account project and provider/email setup, using `ACCOUNTS-SETUP.md`; live account, MFA, recovery and deletion verification.
2. Approve the pricing model and publish the owner's actual legal pages. Do not sell subscription promises for unfinished cloud services.
3. Create and test App Store products using `MEMBERSHIP-SETUP.md`; test subscriptions, renewals, refunds and cancellation in Apple's sandbox and define/enforce the paid-access policy before public sales.
4. Configure a properly signed Apple Developer build for Sign in with Apple and StoreKit distribution. A free Sideloadly IPA is not an App Store billing release.

The previous Supabase account-access step was not authorized; this update does not enter that dashboard, create a project, or enable billing.
