# Rise & Bake — suggested launch pricing

Recommendation, 18 September 2026. Prices below are **Canadian dollars**, before applicable taxes. This is a starting hypothesis to test with real home bakers, not a revenue forecast.

| Offer | Suggested price | When it makes sense |
|---|---:|---|
| Pro monthly | C$9.99/month | A service with ongoing value, support and substantive updates |
| Pro annual | C$79.99/year | Same features; about 33% less than 12 monthly payments |
| Offline edition, if sold separately | C$49.99 once | Phone-only features; no promise of lifetime hosted services |

Start with one Pro tier and a 14-day trial when recurring value is ready. Keep 2FA and account security available to everyone, not behind a paid tier. Avoid ads and a confusing set of feature tiers. Do not offer a lifetime price that includes indefinite cloud costs.

**The app today stores bakery records on the phone. Authentication does not add cloud sync.** If selling that version as-is, the one-time option is easier to justify. My preferred longer-term model is monthly plus annual once cloud sync/recovery or a reliable cadence of substantial improvements is actually delivered. Version 2.4 shows these proposals in a native Plans & pricing screen and prepares StoreKit integration. Purchases remain disabled, and the owner installation has no paid feature lock. See [membership activation and verification requirements](MEMBERSHIP-SETUP.md).

For context, Bakesy lists Standard at $9.99/month and Premium at $17.99/month with a 30-day trial (its page does not explicitly label the currency). Its offering includes a website and customer-order features that Rise & Bake does not yet provide. CakeBoss lists US$149 for the first year and US$36/year afterward. These are reference points, not proof that customers will pay the same for a different product.

Test the proposal with 10–20 active home bakers. Watch weekly usage, trial-to-paid conversion, cancellations and support time. Ask which jobs actually save them time: receipts, repeat orders, ingredient planning, bake records. Consider an introductory annual offer only after measuring willingness to pay; show the renewal price clearly.

Supabase Pro starts at US$25/month before extras; email delivery/support and Apple fees also affect the margin. Apple's eligible Small Business Program commission is 15% if enrolled. The Apple Developer Program currently costs US$99/year or the local equivalent. These are business costs, not charges this work has activated.

For an App Store release in Canada, plan StoreKit in-app purchases for paid app features/subscriptions, restore purchases and manage-subscription access. Customer payments for physical baked goods are a separate flow. App Review also requires ongoing subscription value and in-app account deletion for apps offering account creation. Recheck the relevant storefront rules at launch.

Sources checked:
- https://www.bakesy.app/pricing
- https://cakeboss.com/buy/
- https://supabase.com/pricing
- https://developer.apple.com/programs/enroll/
- https://developer.apple.com/app-store/small-business-program/
- https://developer.apple.com/app-store/review/guidelines/
