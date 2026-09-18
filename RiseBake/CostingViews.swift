import SwiftUI

struct CostingHomeView: View {
    @EnvironmentObject private var store: BakeryStore
    var body: some View {
        List {
            Section {
                Label("Know what every bake costs", systemImage: "scalemass").font(.title3.bold()).padding(.vertical, 6)
                Text("Use your purchase prices, then add packaging and your time. All amounts are in CAD.").foregroundStyle(.secondary)
                NavigationLink { PantryView() } label: { Label("Ingredients & purchase prices", systemImage: "cabinet") }.accessibilityIdentifier("costing.pantry")
                NavigationLink { ShoppingListView() } label: { Label("Shopping list", systemImage: "cart") }.accessibilityIdentifier("costing.shopping")
            }
            Section("Recipes") {
                ForEach(store.state.recipes.sorted { $0.name < $1.name }) { recipe in
                    NavigationLink { RecipeCostView(id: recipe.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) { Text(recipe.name).font(.headline); Text("Per \(recipe.yieldUnit == "loaves" ? "loaf" : "item") · yield \(recipe.yield)").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            let report = store.state.recipeCost(recipe, quantity: recipe.yield)
                            if let amount = report.perItem { Text(costMoney(amount)).fontWeight(.semibold) }
                            else { Text("Set up costs").font(.caption).foregroundStyle(.orange) }
                        }.padding(.vertical, 4)
                    }.accessibilityIdentifier("cost.recipe.\(recipe.id)")
                }
            }
        }.bakeryBackground().navigationTitle("Recipe costing")
    }
}
struct PantryView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var adding = false
    @State private var editing: PantryItem?
    @State private var query = ""
    var body: some View {
        List {
            Section {
                Text("Enter what you actually paid and how much was in the package. Use the same brand or ingredient specification as your recipes.").foregroundStyle(.secondary)
                Text("Stock is a manual count. Update it after shopping and baking.").font(.footnote).foregroundStyle(.secondary)
            }
            if store.state.pantry.isEmpty { ContentUnavailableView("Start with your ingredients", systemImage: "cabinet", description: Text("Add flour, butter, eggs and the ingredients you use. No sample prices are assumed.")) }
            ForEach(store.state.pantry.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }.sorted { $0.name < $1.name }) { item in
                Button { editing = item } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text(item.name).font(.headline).foregroundStyle(.primary); Spacer(); Text(item.priceCents.map(money) ?? "Unpriced").foregroundStyle(item.priceCents == nil ? Color.orange : Color.bakeTeal) }
                        Text("Package: \(quantityText(item.packageAmount)) \(item.unit) · In stock: \(quantityText(item.stock)) \(item.unit)").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(item.supplier.isEmpty ? "Purchase price" : item.supplier) · \(item.priceDate)").font(.caption).foregroundStyle(.secondary)
                        if item.priceIsOld(on: store.state.day) { Label("Check this price · over 90 days old", systemImage: "clock.badge.exclamationmark").font(.caption).foregroundStyle(.orange) }
                    }.padding(.vertical, 5)
                }.accessibilityIdentifier("pantry.item.\(item.id)")
            }
        }.bakeryBackground().navigationTitle("Ingredients & prices").searchable(text: $query, prompt: "Find an ingredient")
        .toolbar { Button { adding = true } label: { Label("Add ingredient", systemImage: "plus") }.accessibilityIdentifier("pantry.add") }
        .sheet(isPresented: $adding) { PantryEditor() }.sheet(item: $editing) { PantryEditor(item: $0) }
    }
}
struct CostAmountField: View {
    var title: String
    @Binding var text: String
    var identifier: String = ""
    var body: some View {
        LabeledContent(title) { TextField("0.00", text: $text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(minWidth: 70).accessibilityIdentifier(identifier).accessibilityLabel(title) }
    }
}
struct CostQuantityField: View {
    var title: String
    @Binding var value: Double
    var identifier: String = ""
    var body: some View {
        LabeledContent(title) { TextField(title, value: $value, format: .number.grouping(.never)).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(minWidth: 70).accessibilityIdentifier(identifier).accessibilityLabel(title) }
    }
}
struct CostDayField: View {
    var title: String
    @Binding var day: String
    var body: some View {
        DatePicker(title, selection: Binding(get: { Clock.date(day) }, set: { day = Clock.day($0) }), displayedComponents: .date).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
    }
}
struct PantryEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var item: PantryItem? = nil
    var onSave: ((String) -> Void)? = nil
    @State private var draft = PantryItem(name: "")
    @State private var price = ""
    @State private var loaded = false
    @State private var error: String?
    @State private var unitChanged = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    TextField("Ingredient name", text: $draft.name).accessibilityIdentifier("pantry.name")
                    TextField("Store or supplier (optional)", text: $draft.supplier)
                }
                Section {
                    CostQuantityField(title: "Package quantity", value: $draft.packageAmount, identifier: "pantry.package")
                    Picker("Package unit", selection: $draft.unit) { ForEach(RecipeIngredient.units, id: \.self) { Text($0).tag($0) } }
                    CostAmountField(title: "Package price (CAD)", text: $price, identifier: "pantry.price")
                    CostDayField(title: "Price checked", day: $draft.priceDate)
                } header: { Text("Your purchase") } footer: { Text("Enter the total package price after discounts, including any costs you want allocated. Leave the price blank if unknown; enter 0 only when genuinely free. A 2 kg bag uses quantity 2 and unit kg.") }
                Section {
                    CostQuantityField(title: "In stock (\(draft.unit))", value: $draft.stock, identifier: "pantry.stock")
                    CostDayField(title: "Stock checked", day: $draft.stockDate)
                    if unitChanged { Text("The unit changed. Re-enter the package quantity and stock in the new unit; stock has been cleared.").font(.footnote).foregroundStyle(.orange) }
                } header: { Text("Pantry count") } footer: { Text("Available amount, not number of packages. Checking off a shopping item does not change this count.") }
                Section {
                    Toggle("I measured grams per ml", isOn: Binding(get: { draft.gramsPerML != nil }, set: { draft.gramsPerML = $0 ? 0 : nil }))
                    if draft.gramsPerML != nil { CostQuantityField(title: "Grams per ml", value: Binding(get: { draft.gramsPerML ?? 1 }, set: { draft.gramsPerML = $0 })) }
                    Toggle("I measured grams per piece", isOn: Binding(get: { draft.gramsPerPiece != nil }, set: { draft.gramsPerPiece = $0 ? 0 : nil }))
                    if draft.gramsPerPiece != nil { CostQuantityField(title: "Grams per piece", value: Binding(get: { draft.gramsPerPiece ?? 1 }, set: { draft.gramsPerPiece = $0 })) }
                    Text(IngredientUnits.note).font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Measured conversions · optional") } footer: { Text("For example, if your 240 ml cup of flour weighs 120 g, enter 0.5 grams per ml. Use edible weight for eggs sold by the piece. Different ingredients need different measurements.") }
                Section("Notes") { TextField("Brand, receipt reference, measurement notes…", text: $draft.notes, axis: .vertical).lineLimit(2...5) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle(item == nil ? "Add ingredient" : "Ingredient details").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("pantry.save") }
            }
            .onAppear { if !loaded { if let item { draft = item; price = item.priceCents.map { String(format: "%.2f", Double($0) / 100) } ?? "" }; loaded = true } }
            .onChange(of: draft.unit) { old, new in if loaded && old != new { draft.stock = 0; draft.stockDate = Clock.today; unitChanged = true } }
        }
    }
    private func save() {
        do {
            draft.priceCents = price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try PurchaseInput.cents(price)
            try draft.validate()
            if store.perform({ try $0.savePantryItem(draft) }) { onSave?(draft.id); dismiss() } else { error = store.error; store.error = nil }
        } catch { self.error = error.localizedDescription }
    }
}
struct RecipeCostView: View {
    @EnvironmentObject private var store: BakeryStore
    var id: String
    @State private var quantity = 1
    @State private var loaded = false
    @State private var editing = false
    private var recipe: BakeRecipe? { store.state.recipes.first { $0.id == id } }
    var body: some View {
        List {
            if let recipe {
                let report = store.state.recipeCost(recipe, quantity: quantity)
                Section {
                    RecipeRow(recipe: recipe)
                    Stepper("Estimate for \(quantity) \(recipe.yieldUnit)", value: $quantity, in: 1...9999)
                    Button("Set up ingredient links & costs") { editing = true }.accessibilityIdentifier("costing.setup")
                    NavigationLink { PantryView() } label: { Label("Edit purchase prices & stock", systemImage: "cabinet") }
                }
                Section("Cost estimate · CAD") {
                    if let total = report.total {
                        LabeledContent("Estimated total", value: costMoney(total)).font(.title3.bold()).foregroundStyle(Color.bakeTeal).accessibilityIdentifier("costing.total")
                        LabeledContent("Per item", value: costMoney(report.perItem ?? 0))
                    } else {
                        Label("Incomplete · ingredient costs needed", systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                        LabeledContent("Entered costs so far", value: costMoney(report.enteredSubtotal))
                    }
                    LabeledContent("Ingredients", value: costMoney(report.ingredientSubtotal))
                    LabeledContent("Ingredient allowance", value: costMoney(report.waste))
                    LabeledContent("Packaging", value: costMoney(report.packaging))
                    LabeledContent("Labour", value: costMoney(report.labour))
                    LabeledContent("Overhead allocation", value: costMoney(report.overhead))
                }
                Section("Ingredient detail") {
                    ForEach(report.lines) { line in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(line.name).fontWeight(.medium); Spacer(); Text(line.cents.map(costMoney) ?? "Not costed").foregroundStyle(line.cents == nil ? Color.orange : Color.primary) }
                            Text("\(quantityText(line.amount)) \(line.unit)").font(.caption).foregroundStyle(.secondary)
                            if let issue = line.issue { Text(issue).font(.caption).foregroundStyle(.orange) }
                            if let source = line.source { Text(source).font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 3)
                    }
                }
                if let suggested = report.suggestedPrice {
                    Section {
                        LabeledContent("Suggested price per item", value: costMoney(suggested)).fontWeight(.semibold)
                        LabeledContent("Target margin", value: "\(quantityText(report.targetMargin))%")
                        Text("Price = entered cost ÷ (1 − margin). This is margin, not markup. Review it before changing your menu prices.").font(.footnote).foregroundStyle(.secondary)
                    } header: { Text("Pricing guide") }
                }
                if !report.warnings.isEmpty { Section("Review") { ForEach(report.warnings, id: \.self) { Text($0).font(.footnote).foregroundStyle(.orange) } } }
                Section { Text("Estimate based on your saved prices. Labour and overhead scale with yield; fixed setup time may differ for smaller batches. Include all relevant costs. This is not net profit or a tax calculation.").font(.footnote).foregroundStyle(.secondary) }
            }
        }.bakeryBackground().navigationTitle("Recipe costing").navigationBarTitleDisplayMode(.inline)
        .onAppear { if !loaded { quantity = recipe?.yield ?? 1; loaded = true } }
        .sheet(isPresented: $editing) { if let recipe { RecipeCostEditor(recipe: recipe) } }
    }
}
struct RecipeCostEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var recipe: BakeRecipe
    @State private var draft = BakeRecipe(name: "", ingredients: [], method: [])
    @State private var options = RecipeCostSettings()
    @State private var packaging = "0.00"
    @State private var hourly = "0.00"
    @State private var overhead = "0.00"
    @State private var forOrders = false
    @State private var loaded = false
    @State private var error: String?
    @State private var addingIngredient: RecipeIngredient?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(recipe.name).font(.headline)
                    Text("Amounts below apply to one recipe batch: \(recipe.yield) \(recipe.yieldUnit). One product quantity must match one recipe yield item.").font(.footnote).foregroundStyle(.secondary)
                    if recipe.productID != nil && store.state.recipes.filter({ $0.productID == recipe.productID }).count > 1 { Toggle("Use this recipe for orders", isOn: $forOrders) }
                }
                Section("Match ingredients to your pantry") {
                    ForEach($draft.ingredients) { $ingredient in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(ingredient.name) · \(quantityText(ingredient.amount)) \(ingredient.unit)").font(.subheadline.bold())
                            Picker("Purchase ingredient", selection: Binding(get: { ingredient.pantryID ?? "" }, set: { ingredient.pantryID = $0.isEmpty ? nil : $0 })) {
                                Text("Not linked").tag("")
                                ForEach(store.state.pantry.sorted { $0.name < $1.name }) { Text($0.name).tag($0.id) }
                            }
                            Button("Add \(ingredient.name) to pantry") { addingIngredient = ingredient }.font(.caption)
                        }.padding(.vertical, 4)
                    }
                }
                Section {
                    CostAmountField(title: "Packaging per item (CAD)", text: $packaging)
                    CostQuantityField(title: "Hands-on minutes per batch", value: $options.labourMinutes)
                    CostAmountField(title: "Labour per hour (CAD)", text: $hourly)
                    CostAmountField(title: "Overhead per batch (CAD)", text: $overhead)
                    CostQuantityField(title: "Extra ingredients (%)", value: $options.wastePercent)
                    CostQuantityField(title: "Target margin (%)", value: $options.targetMarginPercent)
                } header: { Text("Your time & other costs") } footer: { Text("Extra ingredients is a purchasing allowance added to recipe amounts, e.g. 10% adds 10% more. It also applies to shopping lists. Overhead can cover your chosen share of utilities and equipment; it is an estimate. Zero means no amount included.") }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("Set up costs").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("costing.save") }
            }
            .onAppear { if !loaded { draft = recipe; options = recipe.costing ?? RecipeCostSettings(); packaging = moneyText(options.packagingPerItemCents); hourly = moneyText(options.hourlyRateCents); overhead = moneyText(options.overheadPerBatchCents); forOrders = recipe.productID.flatMap { store.state.costingRecipe(for: $0)?.id } == recipe.id; loaded = true } }
            .sheet(item: $addingIngredient) { ingredient in
                PantryEditor(item: PantryItem(name: ingredient.name, packageAmount: ingredient.unit == "piece" ? 12 : 1000, unit: ingredient.unit)) { id in
                    if let i = draft.ingredients.firstIndex(where: { $0.id == ingredient.id }) { draft.ingredients[i].pantryID = id }
                }
            }
        }
    }
    private func moneyText(_ cents: Int) -> String { String(format: "%.2f", Double(cents) / 100) }
    private func save() {
        do {
            options.packagingPerItemCents = try PurchaseInput.cents(packaging)
            options.hourlyRateCents = try PurchaseInput.cents(hourly)
            options.overheadPerBatchCents = try PurchaseInput.cents(overhead)
            draft.costing = options
            if store.perform({ state in
                try state.saveRecipe(draft)
                if let i = state.products.firstIndex(where: { $0.id == draft.productID }) {
                    if forOrders { state.products[i].costingRecipeID = draft.id }
                    else if state.products[i].costingRecipeID == draft.id { state.products[i].costingRecipeID = nil }
                }
            }) { dismiss() } else { error = store.error; store.error = nil }
        } catch { self.error = error.localizedDescription }
    }
}
struct OrderCostView: View {
    @EnvironmentObject private var store: BakeryStore
    var id: String
    var body: some View {
        List {
            if let order = store.state.order(id) {
                let report = store.state.orderCost(order)
                Section("Current estimate · CAD") {
                    LabeledContent("Agreed order total", value: costMoney(report.revenue))
                    if let cost = report.cost, let surplus = report.surplus {
                        LabeledContent("Estimated costs", value: costMoney(cost))
                        LabeledContent("After entered costs", value: costMoney(surplus)).foregroundStyle(surplus < 0 ? Color.red : Color.bakeTeal)
                        if let margin = report.margin { LabeledContent("Estimated margin", value: "\(quantityText(NSDecimalNumber(decimal: margin).doubleValue))%") }
                    } else { Label("Complete recipe costs to see the margin", systemImage: "exclamationmark.circle").foregroundStyle(.orange) }
                }
                ForEach(report.lines) { line in
                    Section("\(line.quantity) × \(line.name)") {
                        LabeledContent("Sales", value: costMoney(line.revenue))
                        LabeledContent("Estimated costs", value: line.report?.total.map(costMoney) ?? "Incomplete")
                        if let recipeID = line.recipeID { NavigationLink("Review recipe costs") { RecipeCostView(id: recipeID) } }
                        else { Text(line.issue ?? "Recipe needed").font(.footnote).foregroundStyle(.orange); NavigationLink("Choose a recipe") { CostingHomeView() } }
                    }
                }
                Section { Text("Uses current purchase prices and proportional recipe yields, including entered labour and overhead. Historical costs are not frozen. Agreed order prices and receipts stay unchanged. Check whole-batch shopping quantities separately.").font(.footnote).foregroundStyle(.secondary) }
            }
        }.bakeryBackground().navigationTitle("Order cost estimate").navigationBarTitleDisplayMode(.inline)
    }
}
