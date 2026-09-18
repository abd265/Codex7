import Foundation

// Money is entered as integer CAD cents and calculated as Decimal. Round only
// for display, never each gram or each ingredient before summing a batch.
func costDecimal(_ value: Double) -> Decimal { Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? 0 }
func costRounded(_ value: Decimal, mode: Decimal.RoundingMode = .plain) -> Decimal {
    var source = value, result = Decimal(); NSDecimalRound(&result, &source, 0, mode); return result
}
func costMoney(_ cents: Decimal) -> String {
    let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "CAD"; f.locale = Locale(identifier: "en_CA")
    return f.string(from: NSDecimalNumber(decimal: cents / 100)) ?? "—"
}
func quantityText(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...3))) }

struct PantryItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var packageAmount: Double = 1000
    var unit: String = "g"
    var priceCents: Int? = nil
    var supplier: String = ""
    var priceDate: String = Clock.today
    var stock: Double = 0
    var stockDate: String = Clock.today
    var gramsPerML: Double? = nil
    var gramsPerPiece: Double? = nil
    var notes: String = ""
    func validate() throws {
        try require(!id.isEmpty && id.count <= 100 && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100, "Enter an ingredient name.")
        try require(packageAmount.isFinite && (0.001...1_000_000).contains(packageAmount) && RecipeIngredient.units.contains(unit), "Enter a package quantity from 0.001 to 1,000,000 and its unit.")
        try require(priceCents == nil || (0...100_000_000).contains(priceCents!), "Enter a valid package price, or leave it unpriced.")
        try require(stock.isFinite && (0...1_000_000_000).contains(stock) && Clock.validDay(priceDate) && Clock.validDay(stockDate), "Check stock quantity and dates.")
        for v in [gramsPerML, gramsPerPiece].compactMap({ $0 }) { try require(v.isFinite && (0.000001...1_000_000).contains(v), "Measured conversions must be positive.") }
        try require(supplier.count <= 100 && notes.count <= 1000, "Ingredient supplier or notes are too long.")
    }
    func priceIsOld(on day: String) -> Bool { priceCents != nil && priceDate < Clock.adding(day, days: -90) }
}
struct RecipeCostSettings: Codable, Equatable {
    var packagingPerItemCents: Int = 0
    var labourMinutes: Double = 0
    var hourlyRateCents: Int = 0
    var overheadPerBatchCents: Int = 0
    var wastePercent: Double = 0
    var targetMarginPercent: Double = 30
    func validate() throws {
        try require([packagingPerItemCents, hourlyRateCents, overheadPerBatchCents].allSatisfy { (0...100_000_000).contains($0) }, "Cost amounts must be zero or positive.")
        try require(labourMinutes.isFinite && (0...10080).contains(labourMinutes) && wastePercent.isFinite && (0...100).contains(wastePercent) && targetMarginPercent.isFinite && (0...95).contains(targetMarginPercent), "Check labour time, ingredient allowance (0–100%) and target margin (0–95%).")
    }
}

enum IngredientUnits {
    // Explicit kitchen measures, shown wherever conversions are edited.
    static let note = "Kitchen measures: 1 cup = 240 ml, 1 tbsp = 15 ml, 1 tsp = 5 ml. For other cup sizes, enter ml or weigh in grams. Cups are never treated as grams without your ingredient-specific measurement."
    static func base(_ unit: String) -> (String, Decimal) {
        switch unit {
        case "kg": return ("g", 1000)
        case "L": return ("ml", 1000)
        case "cup": return ("ml", 240)
        case "tbsp": return ("ml", 15)
        case "tsp": return ("ml", 5)
        default: return (unit, 1)
        }
    }
    static func convert(_ amount: Decimal, from: String, to: String, item: PantryItem) -> Decimal? {
        let source = base(from), target = base(to)
        let value = amount * source.1
        if source.0 == target.0 { return value / target.1 }
        func grams(_ dimension: String) -> Decimal? {
            switch dimension {
            case "g": return 1
            case "ml": return item.gramsPerML.map(costDecimal)
            case "piece": return item.gramsPerPiece.map(costDecimal)
            default: return nil
            }
        }
        guard let a = grams(source.0), let b = grams(target.0), b > 0 else { return nil }
        return value * a / b / target.1
    }
}
struct IngredientCostLine: Identifiable {
    var id: String
    var name: String
    var amount: Double
    var unit: String
    var cents: Decimal?
    var issue: String?
    var source: String?
}
struct RecipeCostReport {
    var lines: [IngredientCostLine]
    var ingredientSubtotal: Decimal
    var waste: Decimal
    var packaging: Decimal
    var labour: Decimal
    var overhead: Decimal
    var quantity: Int
    var targetMargin: Double
    var warnings: [String]
    var complete: Bool { lines.allSatisfy { $0.cents != nil } }
    var enteredSubtotal: Decimal { ingredientSubtotal + waste + packaging + labour + overhead }
    var total: Decimal? { complete ? enteredSubtotal : nil }
    var perItem: Decimal? { total.map { $0 / Decimal(max(1, quantity)) } }
    var suggestedPrice: Decimal? { perItem.map { costRounded($0 / (1 - costDecimal(targetMargin) / 100), mode: .up) } }
}
struct OrderCostLine: Identifiable {
    var id: String
    var name: String
    var quantity: Int
    var revenue: Decimal
    var recipeID: String?
    var report: RecipeCostReport?
    var issue: String?
}
struct OrderCostReport {
    var lines: [OrderCostLine]
    var revenue: Decimal { lines.reduce(0) { $0 + $1.revenue } }
    var cost: Decimal? {
        guard lines.allSatisfy({ $0.report?.total != nil }) else { return nil }
        return lines.reduce(0) { $0 + ($1.report?.total ?? 0) }
    }
    var surplus: Decimal? { cost.map { revenue - $0 } }
    var margin: Decimal? { revenue > 0 ? surplus.map { $0 / revenue * 100 } : nil }
}

struct ShoppingItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var pantryID: String?
    var name: String
    var unit: String
    var required: Double
    var stock: Double
    var toBuy: Double
    var packages: Double?
    var budgetCents: Decimal?
    var checked: Bool = false
    var manual: Bool = false
    var note: String = ""
    func validate() throws {
        try require(!id.isEmpty && id.count <= 100 && !name.isEmpty && name.count <= 150 && RecipeIngredient.units.contains(unit), "Invalid shopping item.")
        try require([required, stock, toBuy].allSatisfy { $0.isFinite && (0...1_000_000_000_000).contains($0) }, "Shopping quantities are too large or invalid.")
        try require(packages == nil || (packages!.isFinite && (0...1_000_000_000_000_000).contains(packages!)), "Invalid package count.")
        if let budgetCents { try require(!budgetCents.isNaN && budgetCents >= 0 && budgetCents <= Decimal(string: "100000000000000000000000")!, "Invalid shopping budget.") }
        try require(note.count <= 2000, "Shopping note is too long.")
    }
}
struct ShoppingList: Codable, Equatable {
    var createdAt: String = Clock.timestamp
    var fromDay: String
    var throughDay: String
    var orderIDs: [String]
    var sourceSignature: String
    var wholeBatches: Bool
    var items: [ShoppingItem]
    var warnings: [String]
    var checkedCount: Int { items.filter { $0.toBuy > 0 && $0.checked }.count }
    var buyCount: Int { items.filter { $0.toBuy > 0 }.count }
    var pricedBudget: Decimal { items.filter { $0.toBuy > 0 }.reduce(0) { $0 + ($1.budgetCents ?? 0) } }
    var unpricedCount: Int { items.filter { $0.toBuy > 0 && $0.budgetCents == nil }.count }
    func validate() throws {
        try require(Clock.validDay(fromDay) && Clock.validDay(throughDay) && fromDay <= throughDay && ISO8601DateFormatter().date(from: createdAt) != nil, "Invalid shopping-list dates.")
        try require(orderIDs.count <= 50000 && Set(orderIDs).count == orderIDs.count && items.count <= 10000 && warnings.count <= 10000 && sourceSignature.count <= 10_000_000, "Shopping list is too large.")
        try require(Set(items.map(\.id)).count == items.count && warnings.allSatisfy { $0.count <= 2000 }, "Invalid shopping-list entries.")
        for item in items { try item.validate() }
    }
    var text: String {
        var rows = ["Rise & Bake · Shopping list", "Pickups: \(fromDay) to \(throughDay)", "Saved: \(createdAt)", "\(orderIDs.count) selected orders · \(wholeBatches ? "whole recipe batches" : "exact recipe quantities")", ""]
        for i in items where i.toBuy > 0 {
            rows.append("\(i.checked ? "✓" : "☐") \(i.name): \(quantityText(i.toBuy)) \(i.unit)" + (i.packages.map { " · \(quantityText($0)) package(s)" } ?? "") + (i.budgetCents.map { " · \(costMoney($0))" } ?? " · price needed"))
            if !i.note.isEmpty { rows.append("  \(i.note)") }
        }
        rows += ["", "Priced items: \(costMoney(pricedBudget)) CAD · \(unpricedCount) unpriced", "Package budget uses saved purchase prices. Confirm current shelf prices.", "Checks do not change pantry stock. Update stock after shopping and baking."]
        if !warnings.isEmpty { rows += ["", "Needs attention:"] + warnings }
        return rows.joined(separator: "\n")
    }
}

extension BakeryState {
    func validateCosting() throws {
        try require(pantry.count <= 2000 && Set(pantry.map(\.id)).count == pantry.count, "Too many or duplicate pantry ingredients.")
        for item in pantry { try item.validate() }
        for recipe in recipes {
            for ingredient in recipe.ingredients {
                if let id = ingredient.pantryID { try require(pantry.contains { $0.id == id }, "A recipe links to a missing pantry ingredient.") }
            }
        }
        for p in products {
            if let id = p.costingRecipeID { try require(recipes.contains { $0.id == id && $0.productID == p.id }, "An order-costing recipe is missing or linked to another product.") }
        }
        try shopping?.validate()
    }
    mutating func savePantryItem(_ value: PantryItem) throws {
        try value.validate()
        if let index = pantry.firstIndex(where: { $0.id == value.id }) { pantry[index] = value } else { pantry.append(value) }
    }
    func costingRecipe(for productID: String) -> BakeRecipe? {
        let candidates = recipes.filter { $0.productID == productID }
        if let id = product(productID)?.costingRecipeID { return candidates.first { $0.id == id } }
        return candidates.count == 1 ? candidates[0] : nil
    }
    func recipeCost(_ recipe: BakeRecipe, quantity: Int) -> RecipeCostReport {
        let count = max(1, quantity), options = recipe.costing ?? RecipeCostSettings()
        let scale = Decimal(count) / Decimal(max(1, recipe.yield))
        var warnings: [String] = []
        let lines: [IngredientCostLine] = recipe.ingredients.map { ingredient in
            let required = costDecimal(ingredient.amount) * scale
            var line = IngredientCostLine(id: ingredient.id, name: ingredient.name, amount: NSDecimalNumber(decimal: required).doubleValue, unit: ingredient.unit)
            guard let item = pantry.first(where: { $0.id == ingredient.pantryID }) else { line.issue = "Link a pantry ingredient"; return line }
            guard let amount = IngredientUnits.convert(required, from: ingredient.unit, to: item.unit, item: item) else { line.issue = "Add a measured conversion or use matching units"; return line }
            guard let price = item.priceCents else { line.issue = "Enter the package price"; return line }
            line.cents = amount / costDecimal(item.packageAmount) * Decimal(price)
            line.source = "\(item.supplier.isEmpty ? "Purchase price" : item.supplier) · \(item.priceDate)"
            if item.priceIsOld(on: day) { warnings.append("\(item.name): price is more than 90 days old.") }
            return line
        }
        if recipe.costing == nil { warnings.append("Packaging, labour and overhead have not been set up; their entered amounts are zero.") }
        let subtotal = lines.reduce(Decimal(0)) { $0 + ($1.cents ?? 0) }
        return RecipeCostReport(lines: lines, ingredientSubtotal: subtotal, waste: subtotal * costDecimal(options.wastePercent) / 100,
            packaging: Decimal(options.packagingPerItemCents) * Decimal(count),
            labour: costDecimal(options.labourMinutes) / 60 * Decimal(options.hourlyRateCents) * scale,
            overhead: Decimal(options.overheadPerBatchCents) * scale, quantity: count, targetMargin: options.targetMarginPercent, warnings: Array(Set(warnings)).sorted())
    }
    func orderCost(_ order: Order) -> OrderCostReport {
        OrderCostReport(lines: order.lines.enumerated().map { index, line in
            let recipe = costingRecipe(for: line.product)
            return OrderCostLine(id: String(index), name: product(line.product)?.name ?? "Product", quantity: line.qty,
                revenue: Decimal(line.qty) * Decimal(line.price), recipeID: recipe?.id,
                report: recipe.map { recipeCost($0, quantity: line.qty) },
                issue: recipe == nil ? "Choose one linked recipe for order costing." : nil)
        })
    }
    func shoppingSignature(orderIDs: [String]) -> String {
        // Include all inputs that affect quantities and budgets, so saved checkmarks
        // can never imply a changed order has already been shopped for.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let selected = Set(orderIDs)
        let chunks: [Data] = [
            (try? encoder.encode(orders.filter { selected.contains($0.id) }.sorted { $0.id < $1.id })) ?? Data(),
            (try? encoder.encode(recipes.sorted { $0.id < $1.id })) ?? Data(),
            (try? encoder.encode(pantry.sorted { $0.id < $1.id })) ?? Data(),
            (try? encoder.encode(products.sorted { $0.id < $1.id }.map { [$0.id, $0.costingRecipeID ?? ""] })) ?? Data()
        ]
        // Compact stable FNV-1a fingerprint for change detection, not cryptography.
        var hash: UInt64 = 14695981039346656037
        for chunk in chunks { for byte in chunk { hash = (hash ^ UInt64(byte)) &* 1099511628211 }; hash = (hash ^ 255) &* 1099511628211 }
        return String(hash, radix: 16)
    }
    func makeShoppingList(orderIDs: Set<String>, from: String, through: String, wholeBatches: Bool) throws -> ShoppingList {
        try require(!orderIDs.isEmpty && Clock.validDay(from) && Clock.validDay(through) && from <= through, "Select at least one order and a valid date range.")
        let selected = orders.filter { orderIDs.contains($0.id) }
        try require(selected.count == orderIDs.count && selected.allSatisfy { ["Confirmed", "In production", "Awaiting deposit"].contains($0.status) && $0.date >= from && $0.date <= through }, "The selected orders changed. Review the selection.")
        var warnings: [String] = []
        if selected.contains(where: { $0.status == "In production" }) { warnings.append("Includes orders in production. Full recipe ingredients are counted; adjust pantry stock for anything already used.") }
        if selected.contains(where: { $0.status == "Awaiting deposit" }) { warnings.append("Includes orders still awaiting a deposit.") }
        var totals: [String: Decimal] = [:]
        for order in selected { for line in order.lines { totals[line.product, default: 0] += Decimal(line.qty) } }
        var quantities: [String: Decimal] = [:], records: [String: ShoppingItem] = [:]
        for productID in totals.keys.sorted() {
            guard let recipe = costingRecipe(for: productID) else { warnings.append("\(product(productID)?.name ?? "Product"): no single costing recipe selected. Ingredients are missing from this list."); continue }
            let exact = totals[productID, default: 0] / Decimal(max(1, recipe.yield))
            let scale = wholeBatches ? costRounded(exact, mode: .up) : exact
            let allowance = 1 + costDecimal(recipe.costing?.wastePercent ?? 0) / 100
            for ingredient in recipe.ingredients {
                let required = costDecimal(ingredient.amount) * scale * allowance
                let item = pantry.first { $0.id == ingredient.pantryID }
                if let item, let converted = IngredientUnits.convert(required, from: ingredient.unit, to: item.unit, item: item) {
                    let key = "pantry|\(item.id)"
                    quantities[key, default: 0] += converted
                    records[key] = ShoppingItem(pantryID: item.id, name: item.name, unit: item.unit, required: 0, stock: item.stock, toBuy: 0)
                } else {
                    let base = IngredientUnits.base(ingredient.unit)
                    let key = "unlinked|\(ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(base.0)|\(ingredient.pantryID ?? "")"
                    quantities[key, default: 0] += required * base.1
                    let issue = item == nil ? "Link this ingredient to use pantry stock and package prices." : "Measured conversion needed. Pantry stock could not be subtracted."
                    records[key] = ShoppingItem(name: ingredient.name, unit: base.0, required: 0, stock: 0, toBuy: 0, note: issue)
                    warnings.append("\(ingredient.name): \(issue)")
                }
            }
        }
        var items: [ShoppingItem] = []
        for key in records.keys.sorted() {
            var record = records[key]!
            let required = quantities[key, default: 0]
            record.required = NSDecimalNumber(decimal: required).doubleValue
            let shortage = max(Decimal(0), required - costDecimal(record.stock))
            record.toBuy = NSDecimalNumber(decimal: shortage).doubleValue
            if let item = pantry.first(where: { $0.id == record.pantryID }) {
                let packages = costRounded(shortage / costDecimal(item.packageAmount), mode: .up)
                record.packages = NSDecimalNumber(decimal: packages).doubleValue
                record.budgetCents = item.priceCents.map { packages * Decimal($0) }
                record.note = "Stock checked \(item.stockDate). " + (item.supplier.isEmpty ? "" : "\(item.supplier). ") + "Package: \(quantityText(item.packageAmount)) \(item.unit)."
                if item.priceCents != nil { record.note += " Price dated \(item.priceDate)." }
                if item.priceIsOld(on: day) { warnings.append("\(item.name): check the price; it is more than 90 days old.") }
                if item.stockDate < Clock.adding(day, days: -7) { warnings.append("\(item.name): stock count is over a week old. Check what is left.") }
            }
            try record.validate(); items.append(record)
        }
        let list = ShoppingList(fromDay: from, throughDay: through, orderIDs: orderIDs.sorted(), sourceSignature: shoppingSignature(orderIDs: orderIDs.sorted()), wholeBatches: wholeBatches, items: items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, warnings: Array(Set(warnings)).sorted())
        try list.validate(); return list
    }
}

enum PurchaseInput {
    static func cents(_ input: String) throws -> Int {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        try require(clean.range(of: #"\A[0-9]+(?:\.[0-9]{1,2})?\z"#, options: .regularExpression) != nil, "Enter a price with up to two decimal places, such as 12.50.")
        guard let amount = Decimal(string: clean, locale: Locale(identifier: "en_US_POSIX")), amount >= 0, amount <= 1_000_000 else { throw BakeryError("Enter an amount from $0 to $1,000,000.") }
        return NSDecimalNumber(decimal: amount * 100).intValue
    }
}
