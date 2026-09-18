import Foundation

/// Optional on Settings so backups from earlier releases decode without a migration.
struct BakeryProfile: Codable, Equatable {
    var contactName = ""
    var address = ""
    var phone = ""
    var email = ""
    var website = ""
    var registrationID = ""
    var footer = "Thank you for supporting our bakery!"
    var logoData: Data? = nil

    func validate() throws {
        try require(contactName.count <= 80 && address.count <= 300 && phone.count <= 40 && email.count <= 120 && website.count <= 160 && registrationID.count <= 80 && footer.count <= 400, "Bakery details are too long. Use up to 300 characters for the address and 400 for the receipt message.")
        try require([contactName, phone, email, website, registrationID].allSatisfy { $0.rangeOfCharacter(from: .newlines) == nil } && address.components(separatedBy: .newlines).count <= 6 && footer.components(separatedBy: .newlines).count <= 6, "Use a single line for contact fields and up to six lines for the address or receipt message.")
        try require(email.isEmpty || email.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil, "Enter a valid bakery email address or leave it empty.")
        if let logoData {
            try require(logoData.count <= 2_000_000 && logoData.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]), "Choose a valid logo image under 2 MB after resizing.")
        }
    }
    var contactLines: [String] {
        [contactName, address, phone, email, website, registrationID.isEmpty ? "" : "Business / tax ID: \(registrationID)"].filter { !$0.isEmpty }
    }
}

struct ReceiptLine: Equatable {
    var name: String
    var quantity: Int
    var unitPrice: Int
    var amount: Int { quantity * unitPrice }
}

/// A snapshot shared by the on-screen, PDF and plain-text receipts.
struct BakeryReceipt {
    var bakery: String
    var profile: BakeryProfile
    var orderID: String
    var customer: String
    var created: String
    var pickup: String
    var status: String
    var lines: [ReceiptLine]
    var paid: Int
    var total: Int { lines.reduce(0) { $0 + $1.amount } }
    var balance: Int { max(0, total - paid) }
    var title: String { status == "Quote requested" ? "Quote" : paid > 0 ? "Receipt" : "Order summary" }
    var paymentStatus: String {
        if status == "Quote requested" { return "Quote - not a payment receipt" }
        if status == "Cancelled" { return "Cancelled - payments shown as recorded" }
        return paid == 0 ? "Unpaid" : balance == 0 ? "Paid in full" : "Part paid"
    }
    var text: String {
        let items = lines.map { "\($0.quantity) × \($0.name) @ \(money($0.unitPrice)) = \(money($0.amount))" }.joined(separator: "\n")
        return ([bakery] + profile.contactLines + ["", "\(title) #RB-\(orderID)", "Customer: \(customer)", "Ordered: \(created)", "Pickup: \(pickup)", "Order status: \(status)", "", items, "", "Total (CAD): \(money(total))", "Payments recorded: \(money(paid))", "Balance: \(money(balance))", paymentStatus, "", profile.footer]).joined(separator: "\n")
    }
}

extension BakeryState {
    func receiptDocument(_ order: Order) -> BakeryReceipt {
        func singleLine(_ text: String) -> String { text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ") }
        return BakeryReceipt(bakery: singleLine(settings.bakery), profile: settings.profile ?? BakeryProfile(), orderID: order.id,
                      customer: singleLine(customer(order.customer)?.name ?? "Customer"), created: String(order.created.prefix(10)),
                      pickup: "\(order.date) at \(order.time)", status: order.status,
                      lines: order.lines.map { ReceiptLine(name: singleLine(product($0.product)?.name ?? "Item"), quantity: $0.qty, unitPrice: $0.price) }, paid: order.paid)
    }
}
