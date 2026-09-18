#if DEBUG
import Foundation

enum CostingQA {
    static func prepare(_ state: inout BakeryState) throws {
        state.day = Clock.today; state.orders = []; state.recurring = []; state.shopping = nil; state.nextOrder = 1201
        state.customers = [Customer(id: "costing-customer", name: "Jamie Lee", email: "", phone: "", preferred: "", vip: false, notes: "", created: Clock.today, messages: [])]
        state.settings.background = "flourGarden"
        state.pantry = [PantryItem(id: "qa-flour", name: "Bread flour", packageAmount: 2, unit: "kg", priceCents: 1200, supplier: "Purchase example", stock: 0.25), PantryItem(id: "qa-eggs", name: "Eggs", packageAmount: 12, unit: "piece", priceCents: 600, supplier: "Purchase example", stock: 0)]
        let recipe = BakeRecipe(id: "recipe-p0", productID: "p0", name: "Everyday test loaf", yield: 4, yieldUnit: "loaves", ingredients: [RecipeIngredient(id: "qa-f", name: "Bread flour", amount: 500, pantryID: "qa-flour"), RecipeIngredient(id: "qa-e", name: "Eggs", amount: 2, unit: "piece", pantryID: "qa-eggs")], method: [RecipeStep(title: "Mix", instruction: "Combine the ingredients.", minutes: 10)], costing: RecipeCostSettings(packagingPerItemCents: 50, labourMinutes: 30, hourlyRateCents: 2000, overheadPerBatchCents: 100, wastePercent: 10, targetMarginPercent: 30))
        try state.saveRecipe(recipe)
        _ = try state.createOrder(customer: state.customers[0].id, lines: [OrderLine(product: "p0", qty: 4, price: 1000)], date: state.day, time: "10:00", payment: "full")
    }
}
#endif
