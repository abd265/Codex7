import XCTest
@testable import RiseBakeCore

final class CostingTests: XCTestCase {
    private func fixture() throws -> BakeryState {
        var s = try JSONDecoder().decode(BakeryState.self, from: Data(contentsOf: Bundle.module.url(forResource: "catalog", withExtension: "json")!))
        s.day = Clock.today; s.orders = []; s.recurring = []; s.shopping = nil
        s.pantry = [PantryItem(id: "flour", name: "Bread flour", packageAmount: 2, unit: "kg", priceCents: 1200, stock: 0.25), PantryItem(id: "eggs", name: "Eggs", packageAmount: 12, unit: "piece", priceCents: 600, stock: 0)]
        s.recipes = [BakeRecipe(id: "bread", productID: "p0", name: "Test bread", yield: 4, yieldUnit: "loaves", ingredients: [RecipeIngredient(id: "f", name: "Flour", amount: 500, pantryID: "flour"), RecipeIngredient(id: "e", name: "Eggs", amount: 2, unit: "piece", pantryID: "eggs")], method: [RecipeStep(title: "Mix", instruction: "Mix", minutes: 10)], costing: RecipeCostSettings(packagingPerItemCents: 50, labourMinutes: 30, hourlyRateCents: 2000, overheadPerBatchCents: 100, wastePercent: 10, targetMarginPercent: 30))]
        return s
    }
    private func addOrder(_ s: inout BakeryState, quantity: Int, payment: String = "full") throws -> String {
        try s.createOrder(customer: s.customers[0].id, lines: [OrderLine(product: "p0", qty: quantity, price: 1000)], date: s.day, time: "10:00", payment: payment)
    }
    func testPurchasePriceYieldLabourAllowanceAndMargin() throws {
        let s = try fixture(), r = s.recipeCost(s.recipes[0], quantity: 4)
        XCTAssertEqual(r.lines[0].cents, 300) // 500 g from a $12 / 2 kg bag
        XCTAssertEqual(r.lines[1].cents, 100)
        XCTAssertEqual(r.ingredientSubtotal, 400); XCTAssertEqual(r.waste, 40)
        XCTAssertEqual(r.packaging, 200); XCTAssertEqual(r.labour, 1000); XCTAssertEqual(r.overhead, 100)
        XCTAssertEqual(r.total, 1740); XCTAssertEqual(r.perItem, 435)
        XCTAssertEqual(r.suggestedPrice, 622) // $4.35 / .70, rounded UP to the cent
        XCTAssertEqual(s.recipeCost(s.recipes[0], quantity: 8).total, 3480)
    }
    func testMissingPriceIsIncompleteButExplicitFreeIsZero() throws {
        var s = try fixture(); s.pantry[0].priceCents = nil
        XCTAssertNil(s.recipeCost(s.recipes[0], quantity: 4).total)
        XCTAssertNil(s.recipeCost(s.recipes[0], quantity: 4).suggestedPrice)
        s.pantry[0].priceCents = 0
        XCTAssertEqual(s.recipeCost(s.recipes[0], quantity: 4).lines[0].cents, 0)
        XCTAssertNotNil(s.recipeCost(s.recipes[0], quantity: 4).total)
    }
    func testVolumeToMassNeedsIngredientSpecificMeasurement() throws {
        var item = PantryItem(name: "Flour", packageAmount: 1000, unit: "g", priceCents: 500)
        XCTAssertNil(IngredientUnits.convert(1, from: "cup", to: "g", item: item))
        item.gramsPerML = 0.5
        XCTAssertEqual(IngredientUnits.convert(1, from: "cup", to: "g", item: item), 120)
        XCTAssertEqual(IngredientUnits.convert(2, from: "tbsp", to: "g", item: item), 15)
        XCTAssertEqual(IngredientUnits.convert(1, from: "L", to: "ml", item: item), 1000)
        XCTAssertEqual(IngredientUnits.convert(1, from: "kg", to: "g", item: item), 1000)
        XCTAssertNil(IngredientUnits.convert(1, from: "piece", to: "g", item: item))
        item.gramsPerPiece = 50
        XCTAssertEqual(IngredientUnits.convert(2, from: "piece", to: "g", item: item), 100)
        XCTAssertEqual(IngredientUnits.convert(100, from: "g", to: "piece", item: item), 2)
    }
    func testTinyCostsAreSummedBeforeRounding() throws {
        var s = try fixture(); s.pantry = [PantryItem(id: "salt", name: "Salt", packageAmount: 1000, priceCents: 100)]
        var recipe = s.recipes[0]; recipe.costing = RecipeCostSettings(); recipe.yield = 1
        recipe.ingredients = (0..<10).map { RecipeIngredient(id: String($0), name: "Salt \($0)", amount: 1, pantryID: "salt") }
        let r = s.recipeCost(recipe, quantity: 1)
        XCTAssertEqual(r.total, 1) // Ten tenths of one cent must not vanish.
    }
    func testOrderEstimateUsesAgreedSellingPriceAndDoesNotMutateCatalog() throws {
        var s = try fixture(); let id = try addOrder(&s, quantity: 4)
        s.products[0].price = 20000
        let saved = s
        let report = s.orderCost(s.order(id)!)
        XCTAssertEqual(report.revenue, 4000); XCTAssertEqual(report.cost, 1740); XCTAssertEqual(report.surplus, 2260)
        XCTAssertEqual(s, saved)
        s.recipes[0].ingredients[0].pantryID = nil
        XCTAssertNil(s.orderCost(s.order(id)!).cost)
    }
    func testAmbiguousRecipeRequiresSelection() throws {
        var s = try fixture(); var second = s.recipes[0]; second.id = "alternative"; s.recipes.append(second)
        XCTAssertNil(s.costingRecipe(for: "p0"))
        let i = s.products.firstIndex { $0.id == "p0" }!
        s.products[i].costingRecipeID = "alternative"
        XCTAssertEqual(s.costingRecipe(for: "p0")?.id, "alternative")
        second.productID = "p1"; try s.saveRecipe(second)
        XCTAssertNil(s.products[i].costingRecipeID)
        try s.validate()
    }
    func testShoppingCombinesOrdersBeforeRoundingAndSubtractsStockOnce() throws {
        var s = try fixture(); let a = try addOrder(&s, quantity: 1), b = try addOrder(&s, quantity: 1)
        let list = try s.makeShoppingList(orderIDs: [a, b], from: s.day, through: s.day, wholeBatches: true)
        let flour = try XCTUnwrap(list.items.first { $0.pantryID == "flour" })
        XCTAssertEqual(flour.required, 0.55, accuracy: 0.0000001) // One 4-loaf batch + 10%
        XCTAssertEqual(flour.toBuy, 0.30, accuracy: 0.0000001) // .55 kg - .25 kg stock
        XCTAssertEqual(flour.packages, 1); XCTAssertEqual(flour.budgetCents, 1200)
        let exact = try s.makeShoppingList(orderIDs: [a, b], from: s.day, through: s.day, wholeBatches: false)
        XCTAssertEqual(try XCTUnwrap(exact.items.first { $0.pantryID == "flour" }).required, 0.275, accuracy: 0.0000001)
    }
    func testShoppingUsesSharedPantryAcrossRecipesAndRoundsPackagesUp() throws {
        var s = try fixture(); var other = s.recipes[0]; other.id = "other"; other.productID = "p1"; s.recipes.append(other)
        let a = try addOrder(&s, quantity: 4)
        let b = try s.createOrder(customer: s.customers[0].id, lines: [OrderLine(product: "p1", qty: 4, price: 1000)], date: s.day, time: "10:00", payment: "full")
        s.pantry[0].packageAmount = 0.5
        let list = try s.makeShoppingList(orderIDs: [a, b], from: s.day, through: s.day, wholeBatches: false)
        XCTAssertEqual(list.items.filter { $0.pantryID == "flour" }.count, 1)
        let flour = try XCTUnwrap(list.items.first { $0.pantryID == "flour" })
        XCTAssertEqual(flour.toBuy, 0.85, accuracy: 0.000001)
        XCTAssertEqual(flour.packages, 2); XCTAssertEqual(flour.budgetCents, 2400)
    }
    func testMissingMappingsStayVisibleAndDoNotInventStockOrPrices() throws {
        var s = try fixture(); s.recipes[0].ingredients[0].pantryID = nil
        let id = try addOrder(&s, quantity: 4)
        let list = try s.makeShoppingList(orderIDs: [id], from: s.day, through: s.day, wholeBatches: false)
        let flour = try XCTUnwrap(list.items.first { $0.name == "Flour" })
        XCTAssertEqual(flour.stock, 0); XCTAssertNil(flour.budgetCents); XCTAssertEqual(flour.toBuy, 550)
        XCTAssertFalse(list.warnings.isEmpty); XCTAssertEqual(list.unpricedCount, 1)
        s.recipes = []
        let missing = try s.makeShoppingList(orderIDs: [id], from: s.day, through: s.day, wholeBatches: false)
        XCTAssertTrue(missing.items.isEmpty); XCTAssertTrue(missing.warnings[0].contains("missing from this list"))
    }
    func testShoppingRejectsCancelledReadyAndOutOfRangeOrders() throws {
        var s = try fixture(); let id = try addOrder(&s, quantity: 1)
        for status in ["Cancelled", "Picked up", "Ready for pickup", "Quote requested", "Paused", "Skipped"] {
            s.orders[0].status = status
            XCTAssertThrowsError(try s.makeShoppingList(orderIDs: [id], from: s.day, through: s.day, wholeBatches: false))
        }
        s.orders[0].status = "Confirmed"
        XCTAssertThrowsError(try s.makeShoppingList(orderIDs: [id], from: Clock.adding(s.day, days: 1), through: Clock.adding(s.day, days: 2), wholeBatches: false))
        XCTAssertThrowsError(try s.makeShoppingList(orderIDs: [], from: s.day, through: s.day, wholeBatches: false))
        s.orders[0].status = "In production"
        XCTAssertTrue(try s.makeShoppingList(orderIDs: [id], from: s.day, through: s.day, wholeBatches: false).warnings.contains { $0.contains("production") })
    }
    func testShoppingChecksPersistWithoutChangingStockAndChangesAreDetected() throws {
        var s = try fixture(); let id = try addOrder(&s, quantity: 4)
        s.shopping = try s.makeShoppingList(orderIDs: [id], from: s.day, through: s.day, wholeBatches: false)
        let originalStock = s.pantry[0].stock, signature = s.shopping!.sourceSignature
        s.shopping!.items[0].checked = true
        let restored = try JSONDecoder().decode(BakeryState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(restored, s); XCTAssertTrue(restored.shopping!.items[0].checked)
        XCTAssertEqual(s.pantry[0].stock, originalStock)
        XCTAssertEqual(s.shoppingSignature(orderIDs: [id]), signature)
        s.orders[0].lines[0].qty += 1
        XCTAssertNotEqual(s.shoppingSignature(orderIDs: [id]), signature)
        let newList = try s.makeShoppingList(orderIDs: [id], from: s.day, through: s.day, wholeBatches: false)
        XCTAssertEqual(newList.checkedCount, 0)
    }
    func testEnoughStockHasNoPurchaseCostAndOldPricesAreFlagged() throws {
        var s = try fixture(); s.pantry[0].stock = 10; s.pantry[0].priceDate = Clock.adding(s.day, days: -91)
        XCTAssertTrue(s.recipeCost(s.recipes[0], quantity: 4).warnings.contains { $0.contains("90 days") })
        let id = try addOrder(&s, quantity: 4)
        let list = try s.makeShoppingList(orderIDs: [id], from: s.day, through: s.day, wholeBatches: false)
        let flour = try XCTUnwrap(list.items.first { $0.pantryID == "flour" })
        XCTAssertEqual(flour.toBuy, 0); XCTAssertEqual(flour.packages, 0); XCTAssertEqual(flour.budgetCents, 0)
        XCTAssertFalse(list.text.contains("Bread flour:"))
    }
    func testLegacyMigrationDoesNotInventPurchasePricesOrLoseOrders() throws {
        let catalog = try JSONDecoder().decode(BakeryState.self, from: Data(contentsOf: Bundle.module.url(forResource: "catalog", withExtension: "json")!))
        var s = catalog; let orders = s.orders, customers = s.customers
        try s.upgrade(using: catalog, today: Clock.today)
        XCTAssertEqual(s.version, 3); XCTAssertEqual(s.orders, orders); XCTAssertEqual(s.customers, customers)
        XCTAssertTrue(s.pantry.isEmpty); XCTAssertNil(s.shopping)
        XCTAssertTrue(s.recipes.allSatisfy { $0.ingredients.allSatisfy { $0.pantryID == nil } })
    }
    func testInputValidationRejectsPartialMoneyAndInvalidConversions() throws {
        XCTAssertEqual(try PurchaseInput.cents("12,50"), 1250); XCTAssertEqual(try PurchaseInput.cents("0"), 0)
        for input in ["", "12abc", "-1", "nan", "1.234", "2.5.1", "1e4", "1000001"] { XCTAssertThrowsError(try PurchaseInput.cents(input)) }
        var item = PantryItem(name: "Test"); item.packageAmount = 0; XCTAssertThrowsError(try item.validate())
        item.packageAmount = 100; item.gramsPerML = 0; XCTAssertThrowsError(try item.validate())
        item.gramsPerML = nil; item.stock = .infinity; XCTAssertThrowsError(try item.validate())
        var options = RecipeCostSettings(); options.targetMarginPercent = 100; XCTAssertThrowsError(try options.validate())
    }
}
