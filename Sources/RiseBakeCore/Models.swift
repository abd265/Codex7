import Foundation

struct Product: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var category: String
    var price: Int
    var cost: Int
    var capacity: Int
    var image: Int
    var unit: String
    var description: String
    var allergens: String
    var recipe: [String: Int]
    var steps: [String]
}
struct Message: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var text: String
    var at: String
}
struct Customer: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var email: String
    var phone: String
    var preferred: String
    var vip: Bool
    var notes: String
    var created: String
    var messages: [Message]
}
struct OrderLine: Codable, Equatable {
    var product: String
    var qty: Int
    var price: Int
}
struct History: Codable, Equatable {
    var status: String
    var at: String
}
struct Order: Codable, Identifiable, Equatable {
    var id: String
    var customer: String
    var lines: [OrderLine]
    var date: String
    var time: String
    var status: String
    var paid: Int
    var deposit: Int
    var type: String
    var series: String?
    var notes: String
    var allergy: String
    var created: String
    var history: [History]
    var rating: Int
    var rev: Int
    var total: Int { lines.reduce(0) { $0 + $1.qty * $1.price } }
    var balance: Int { max(0, total - paid) }
    var active: Bool { Self.stages.contains(status) }
    var reserves: Bool { active || status == "Awaiting deposit" }
    var editable: Bool { ["Confirmed", "Awaiting deposit", "Quote requested"].contains(status) && series == nil }
    static let stages = ["Confirmed", "In production", "Ready for pickup", "Picked up"]
    static let statuses = stages + ["Awaiting deposit", "Quote requested", "Cancelled", "Skipped", "Paused"]
    mutating func transition(_ value: String) {
        status = value
        history.append(History(status: value, at: Clock.timestamp))
    }
}
struct OccurrenceChange: Codable, Equatable {
    var skipped: Bool?
    var qty: Int?
    var time: String?
}
struct RecurringPlan: Codable, Identifiable, Equatable {
    var id: String
    var customer: String
    var product: String
    var qty: Int
    var start: String
    var time: String
    var paused: Bool
    var exceptions: [String: OccurrenceChange]
}
struct Settings: Codable, Equatable {
    var bakery: String
    var owner: String
    var cakeDeposit: Int
    var otherDeposit: Int
    var background: String? = "flourGarden"
}
struct BakeryState: Codable, Equatable {
    var version: Int
    var day: String
    var products: [Product]
    var customers: [Customer]
    var orders: [Order]
    var recurring: [RecurringPlan]
    var tasks: [String: Bool]
    var cart: [String: Int]
    var settings: Settings
    var nextOrder: Int
    var recipes: [BakeRecipe] = []
    var bakeSessions: [BakeSession] = []
    func product(_ id: String) -> Product? { products.first { $0.id == id } }
    func customer(_ id: String) -> Customer? { customers.first { $0.id == id } }
    func order(_ id: String) -> Order? { orders.first { $0.id == id } }
    var cartLines: [OrderLine] {
        products.compactMap { p in
            guard let qty = cart[p.id], qty > 0 else { return nil }
            return OrderLine(product: p.id, qty: qty, price: p.price)
        }
    }
    func deposit(for lines: [OrderLine]) -> Int {
        lines.reduce(0) { sum, line in
            let percent = product(line.product)?.category == "Cakes" ? settings.cakeDeposit : settings.otherDeposit
            return sum + (line.price * line.qty * percent + 50) / 100
        }
    }
}
struct Batch: Identifiable {
    var product: Product
    var quantity: Int
    var orderIDs: [String]
    var signature: String
    var day: String
    var id: String { product.id }
    func taskKey(_ step: String) -> String { "\(day)|\(id)|\(signature)|\(step)" }
}
struct BakeryError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw BakeryError(message) }
}
enum Clock {
    static var today: String {
        let f = formatter("yyyy-MM-dd"); f.timeZone = .current
        return f.string(from: Date())
    }
    static var timestamp: String { ISO8601DateFormatter().string(from: Date()) }
    static func formatter(_ format: String) -> DateFormatter {
        let result = DateFormatter()
        result.locale = Locale(identifier: "en_US_POSIX")
        result.calendar = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)
        result.dateFormat = format
        result.isLenient = false
        return result
    }
    static func day(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }
    static func date(_ day: String) -> Date { formatter("yyyy-MM-dd").date(from: day) ?? Date(timeIntervalSince1970: 0) }
    static func adding(_ day: String, days: Int) -> String { self.day(date(day).addingTimeInterval(Double(days) * 86400)) }
    static func validDay(_ day: String) -> Bool {
        guard let date = formatter("yyyy-MM-dd").date(from: day) else { return false }
        return self.day(date) == day
    }
    static func validTime(_ time: String) -> Bool {
        time.range(of: "^([01][0-9]|2[0-3]):[0-5][0-9]$", options: .regularExpression) != nil
    }
}
