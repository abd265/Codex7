import Foundation

enum BakeryCatalog {
    static let categories = ["Breads", "Pastries", "Cakes", "Cookies", "Brownies", "Muffins", "Cupcakes", "Tarts", "Macarons"]
    static let photos = ["Sourdough", "Croissant", "Berry cake", "Morning buns", "Baguette", "Chocolate cake", "Cookies", "Brownies", "Muffins", "Cupcakes", "Focaccia", "Bagels", "Strawberry tart", "Macarons", "Banana bread", "Éclairs"]
    static let backgrounds = ["flourGarden", "berryPatisserie", "midnightBakery", "plain"]
}
struct RecipeIngredient: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var amount: Double
    var unit: String = "g"
    static let units = ["g", "kg", "ml", "L", "tsp", "tbsp", "cup", "piece"]
}
struct RecipeStep: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var instruction: String
    var minutes: Int
    var temperatureC: Int?
}
struct BakeRecipe: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var productID: String?
    var name: String
    var yield: Int = 1
    var yieldUnit: String = "pieces"
    var ingredients: [RecipeIngredient]
    var method: [RecipeStep]
    var notes: String = ""
    var totalMinutes: Int { method.reduce(0) { $0 + $1.minutes } }
    func scaledAmount(_ ingredient: RecipeIngredient, quantity: Int) -> Double {
        ingredient.amount * Double(quantity) / Double(max(1, yield))
    }
    func validate() throws {
        try require(!id.isEmpty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 && (1...9999).contains(yield), "Give the recipe a name and a yield from 1 to 9,999.")
        try require(!ingredients.isEmpty && ingredients.count <= 100 && !method.isEmpty && method.count <= 50, "Add ingredients and at least one method step.")
        try require(Set(ingredients.map(\.id)).count == ingredients.count && Set(method.map(\.id)).count == method.count, "Recipe items must have unique IDs.")
        for i in ingredients { try require(!i.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && i.name.count <= 100 && i.amount.isFinite && i.amount > 0 && i.amount <= 1_000_000 && RecipeIngredient.units.contains(i.unit), "Check each ingredient’s name, quantity and unit.") }
        for s in method { try require(!s.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && s.title.count <= 100 && s.instruction.count <= 4000 && (0...10080).contains(s.minutes) && (s.temperatureC == nil || (0...350).contains(s.temperatureC!)), "Check each method step, time and oven temperature.") }
        try require(notes.count <= 10000 && yieldUnit.count <= 30, "Recipe notes or yield unit are too long.")
    }
}
struct BakeStepLog: Codable, Identifiable, Equatable {
    var id: String
    var startedAt: Double?
    var accumulatedSeconds: Double = 0
    var completedAt: Double?
    var deadline: Double?
    func elapsed(at now: Double) -> Double { accumulatedSeconds + (startedAt.map { max(0, now - $0) } ?? 0) }
}
// Keep elapsed time based on timestamps so locking the phone does not stop a bake.
struct BakeSession: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var recipe: BakeRecipe
    var quantity: Int
    var startedAt: Double
    var finishedAt: Double?
    var steps: [BakeStepLog]
    var checkedIngredients: Set<String> = []
    var notes: String = ""
    var rating: Int = 0
    var complete: Bool { finishedAt != nil }
    var completedCount: Int { steps.filter { $0.completedAt != nil }.count }
    func validate() throws {
        try recipe.validate()
        try require(!id.isEmpty && (1...9999).contains(quantity) && startedAt.isFinite && (0..<32_503_680_000).contains(startedAt) && (finishedAt == nil || (finishedAt!.isFinite && finishedAt! >= startedAt && finishedAt! < 32_503_680_000)), "Invalid baking session date or yield.")
        try require(steps.map(\.id) == recipe.method.map(\.id) && steps.count == recipe.method.count && checkedIngredients.isSubset(of: Set(recipe.ingredients.map(\.id))), "Invalid baking checklist.")
        try require(notes.count <= 10000 && (0...5).contains(rating), "Check the bake notes and rating.")
        for s in steps {
            try require(s.accumulatedSeconds.isFinite && (0...1_000_000_000).contains(s.accumulatedSeconds) && [s.startedAt, s.completedAt, s.deadline].compactMap { $0 }.allSatisfy { $0.isFinite && $0 >= startedAt && $0 < 32_503_680_000 }, "Invalid timer data.")
            try require(!(s.completedAt != nil && s.startedAt != nil) && !(s.deadline != nil && s.startedAt == nil) && !(complete && s.startedAt != nil), "Invalid timer state.")
        }
    }
}
extension BakeryState {
    // A v1 file has no recipes or sessions. Decode it without losing any orders.
    private enum CodingKeys: String, CodingKey { case version, day, products, customers, orders, recurring, tasks, cart, settings, nextOrder, recipes, bakeSessions }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version); day = try c.decode(String.self, forKey: .day)
        products = try c.decode([Product].self, forKey: .products); customers = try c.decode([Customer].self, forKey: .customers)
        orders = try c.decode([Order].self, forKey: .orders); recurring = try c.decode([RecurringPlan].self, forKey: .recurring)
        tasks = try c.decode([String: Bool].self, forKey: .tasks); cart = try c.decode([String: Int].self, forKey: .cart)
        settings = try c.decode(Settings.self, forKey: .settings); nextOrder = try c.decode(Int.self, forKey: .nextOrder)
        recipes = try c.decodeIfPresent([BakeRecipe].self, forKey: .recipes) ?? []
        bakeSessions = try c.decodeIfPresent([BakeSession].self, forKey: .bakeSessions) ?? []
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(day, forKey: .day)
        try c.encode(products, forKey: .products)
        try c.encode(customers, forKey: .customers)
        try c.encode(orders, forKey: .orders)
        try c.encode(recurring, forKey: .recurring)
        try c.encode(tasks, forKey: .tasks)
        try c.encode(cart, forKey: .cart)
        try c.encode(settings, forKey: .settings)
        try c.encode(nextOrder, forKey: .nextOrder)
        try c.encode(recipes, forKey: .recipes)
        try c.encode(bakeSessions, forKey: .bakeSessions)
    }
    mutating func upgrade(using catalog: BakeryState, today: String) throws {
        try validate()
        if version == 1 {
            for p in catalog.products where product(p.id) == nil { products.append(p) }
            for r in catalog.recipes where !recipes.contains(where: { $0.id == r.id }) { recipes.append(r) }
            if settings.background == nil { settings.background = "flourGarden" }
            version = 2
        }
        day = today
        try validate()
    }
    mutating func saveRecipe(_ recipe: BakeRecipe) throws {
        try recipe.validate()
        if let i = recipes.firstIndex(where: { $0.id == recipe.id }) { recipes[i] = recipe } else { recipes.append(recipe) }
    }
    @discardableResult mutating func startBake(recipeID: String, quantity: Int, now: Double = Date().timeIntervalSince1970) throws -> String {
        guard let recipe = recipes.first(where: { $0.id == recipeID }) else { throw BakeryError("Recipe not found.") }
        try require((1...9999).contains(quantity) && bakeSessions.filter { !$0.complete }.count < 10, "Choose a yield from 1 to 9,999. Finish an active bake if you already have ten.")
        let session = BakeSession(recipe: recipe, quantity: quantity, startedAt: now, steps: recipe.method.map { BakeStepLog(id: $0.id) })
        try session.validate(); bakeSessions.insert(session, at: 0)
        return session.id
    }
    mutating func changeStep(sessionID: String, stepID: String, action: String, now: Double = Date().timeIntervalSince1970) throws {
        guard let si = bakeSessions.firstIndex(where: { $0.id == sessionID }), !bakeSessions[si].complete,
              let i = bakeSessions[si].steps.firstIndex(where: { $0.id == stepID }) else { throw BakeryError("This bake is already finished or the step is unavailable.") }
        var step = bakeSessions[si].steps[i]
        let duration = Double(bakeSessions[si].recipe.method[i].minutes * 60)
        switch action {
        case "start":
            try require(step.completedAt == nil && step.startedAt == nil, "This step has already started or finished.")
            step.startedAt = now
            step.deadline = duration > 0 ? now + max(0, duration - step.accumulatedSeconds) : nil
        case "pause", "complete":
            step.accumulatedSeconds = step.elapsed(at: now); step.startedAt = nil; step.deadline = nil
            if action == "complete" { step.completedAt = now }
        case "reset": step = BakeStepLog(id: stepID)
        default: throw BakeryError("Unknown timer action.")
        }
        bakeSessions[si].steps[i] = step
    }
    mutating func finishBake(_ id: String, now: Double = Date().timeIntervalSince1970) throws {
        guard let i = bakeSessions.firstIndex(where: { $0.id == id }), !bakeSessions[i].complete else { throw BakeryError("Bake not found or already finished.") }
        for j in bakeSessions[i].steps.indices {
            bakeSessions[i].steps[j].accumulatedSeconds = bakeSessions[i].steps[j].elapsed(at: now)
            bakeSessions[i].steps[j].startedAt = nil; bakeSessions[i].steps[j].deadline = nil
        }
        bakeSessions[i].finishedAt = now
    }
}
