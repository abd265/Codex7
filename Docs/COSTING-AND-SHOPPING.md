# Rise & Bake 2.3 — purchase-based costing and shopping

Open **More → Recipe costing**. All cost and selling-price amounts use CAD, matching the app's existing receipts.

## 1. Enter purchase prices

Open **Ingredients & purchase prices** and add each ingredient. Enter the net quantity in one package, the unit, the price actually paid, optional supplier, and the date that price was checked. A $12 bag of flour containing 2 kg uses quantity **2**, unit **kg**, price **12.00**. A dozen eggs uses quantity **12**, unit **piece**. Leave an unknown price blank. Zero is an explicit free ingredient, never an assumed price.

Enter available stock in the same unit as the package quantity, not a package count. Record when you checked it. These are manual stock counts: update them after purchases and bakes. Changing an ingredient's unit clears the editor's stock count so a number cannot silently acquire a different meaning.

This release does not connect to grocery stores or claim live shelf prices. Purchase prices can come from supermarkets, wholesalers, online suppliers or your own receipts. No sample prices are populated in a normal build. Debug-only QA fixtures use clearly labelled examples for verification.

## 2. Match recipe ingredients

Open a recipe's **Set up ingredient links & costs** and explicitly match every ingredient to a pantry item. You can add a pantry item from this screen. Match brands and ingredient specifications as appropriate. Several recipes can use the same pantry item.

Conversions within mass (g/kg), volume (ml/L) or count are automatic. Kitchen measures explicitly use **cup = 240 ml, tablespoon = 15 ml, teaspoon = 5 ml**. For a different cup standard, enter ml or weigh the ingredient. Mass/volume conversions require the baker's measured grams per ml; piece/mass conversions require edible grams per piece. No density is guessed. Missing prices, links or conversions prevent a complete recipe total or suggested selling price.

When multiple recipes are linked to one product, select which recipe to use for orders. A product with exactly one linked recipe uses that recipe automatically. One ordered product unit must correspond to one recipe yield item; a box of six needs a recipe yield defined in boxes, or an appropriately adjusted product/recipe.

## 3. Include your other costs

Enter packaging per finished item, hands-on minutes per recipe batch, an hourly labour rate, and an overhead allocation per batch. These start at zero, not estimated market values. Use the overhead field for costs you choose to allocate, and avoid counting an expense twice.

The ingredient allowance is an **additive percentage**: 10% means purchasing 10% more ingredients than the recipe requires. It is not a yield-loss formula. The same allowance is used in the shopping list.

The estimate scales recipe ingredients, hands-on time and overhead proportionally to the requested yield. This assumes those amounts scale; fixed setup work may differ. The suggested item price is **entered cost per item / (1 − target margin)**, rounded upward to the next cent. This is margin, not markup. Calculations use Decimal cents and retain sub-cent ingredient amounts until display. They do not automatically change menu or agreed order prices.

Open an order's **Recipe cost & margin** to compare current entered costs with its agreed sales total. These are current estimates, not frozen historical costs, net profit or tax accounting. The existing Insights screen still uses its separately labelled manual ingredient estimate.

Prices over 90 days old are flagged for review. This is a reminder, not proof that newer prices match a particular store today.

## 4. Generate a shopping list

Open **More → Shopping list → Choose orders**. Choose pickup dates and orders. Confirmed orders are selected by default. Awaiting-deposit and in-production orders are optional; ready, picked-up, cancelled, skipped, paused and quote-only orders are excluded. No purchases or messages are sent.

By default the planner combines selected orders for each product, then rounds up to whole recipe batches. Switch this off for exact proportional quantities. Whole-batch shopping can therefore cost more than the order's proportional cost estimate.

The planner combines shared pantry ingredients, applies the ingredient allowance, subtracts stock once, and rounds shortages upward to whole purchase packages. The package budget differs from the ingredient amount consumed. Ingredients without a pantry link remain visible and unpriced; incompatible conversions cannot use stock. Products without a selected recipe generate a prominent warning that their ingredients are missing. Packaging and other supplies can be added as manual extra items.

Check off items and share the list through the native share sheet. Checkmarks persist after relaunch. They do **not** add stock or deduct ingredients. Manually update pantry counts after shopping and baking. This prevents a checkmark from being treated as a verified receipt or stock transaction.

The saved list is a snapshot. Changed orders, pantry entries or recipes trigger an update notice. Rebuilding requires confirmation and replaces the old list, extra items and checks. Share an old list before replacing it if you need a copy. Stock counts older than a week are flagged on generated lists.

## Data compatibility

App version 2.3, build 25 retains the existing bundle ID. Backup schema 3 stores pantry entries, ingredient links, recipe cost settings and the saved list with its checks. Version 1 and 2 backups migrate without discarding customers, orders, recipes, sessions or logos. Older app versions intentionally reject version 3 backups. Export a backup before installing the update and install over the existing app using the same Sideloadly account and bundle-ID settings.
