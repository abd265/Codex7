import Foundation

extension BakeryState {
    func validate() throws {
        try require((1...3).contains(version) && Clock.validDay(day), "Unsupported or invalid Rise & Bake backup.")
        try validateCosting()
        try require(products.count <= 1000 && customers.count <= 10000 && orders.count <= 50000, "Backup is too large.")
        try require(Set(products.map(\.id)).count == products.count && Set(customers.map(\.id)).count == customers.count && Set(orders.map(\.id)).count == orders.count && Set(recurring.map(\.id)).count == recurring.count, "Duplicate IDs in backup.")
        try require(nextOrder > (orders.compactMap { Int($0.id) }.max() ?? 0) && nextOrder < 1_000_000_000, "Invalid order counter.")
        try require(recipes.count <= 1000 && bakeSessions.count <= 10000, "Too many recipes or bake records.")
        try require(Set(recipes.map(\.id)).count == recipes.count && Set(bakeSessions.map(\.id)).count == bakeSessions.count, "Duplicate recipe or bake IDs.")
        for r in recipes { try r.validate(); if let id = r.productID { try require(product(id) != nil, "A recipe has a missing product.") } }
        for b in bakeSessions { try b.validate() }
        try require(settings.background == nil || BakeryCatalog.backgrounds.contains(settings.background!), "Unknown background.")
        try validateSettings(settings)
        for p in products { try validateProduct(p) }
        for c in customers { try validateCustomer(c) }
        for o in orders {
            try validateLines(o.lines)
            try require(customer(o.customer) != nil && Clock.validDay(o.date) && Clock.validTime(o.time), "An order has invalid customer or pickup details.")
            try require(Order.statuses.contains(o.status) && o.paid >= 0 && o.paid <= o.total && o.deposit >= 0 && o.deposit <= o.total && (0...5).contains(o.rating) && o.rev >= 0, "Invalid payment, status or rating in backup.")
            try require(o.notes.count <= 1000 && o.allergy.count <= 1000, "Order notes are too long.")
            if let id = o.series { try require(recurring.contains { $0.id == id }, "Missing recurring schedule.") }
        }
        for r in recurring {
            try require(product(r.product) != nil && customer(r.customer) != nil && (1...999).contains(r.qty) && Clock.validDay(r.start) && Clock.validTime(r.time), "Invalid recurring plan.")
        }
        for (id, qty) in cart { try require(product(id) != nil && (1...999).contains(qty), "Invalid basket.") }
    }
    func validateSettings(_ s: Settings) throws {
        try require(!s.bakery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && s.bakery.count <= 60 && !s.owner.isEmpty && s.owner.count <= 30 && (0...100).contains(s.cakeDeposit) && (0...100).contains(s.otherDeposit), "Enter a bakery name, owner and deposit percentages from 0 to 100.")
        try s.profile?.validate()
    }
    func validateProduct(_ p: Product) throws {
        try require(!p.id.isEmpty && !p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && p.name.count <= 80 && (1...1_000_000).contains(p.price) && (0...1_000_000).contains(p.cost) && (1...9999).contains(p.capacity) && BakeryCatalog.photos.indices.contains(p.image) && BakeryCatalog.categories.contains(p.category), "Check the product name, price, cost and daily capacity.")
        try require(p.steps.count <= 20 && p.recipe.values.allSatisfy { (0...1_000_000).contains($0) }, "Invalid recipe.")
    }
    func validateCustomer(_ c: Customer) throws {
        try require(!c.id.isEmpty && !c.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && c.name.count <= 80 && c.email.count <= 120 && (c.email.isEmpty || c.email.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil), "Enter a name and a valid email address, or leave email empty.")
        try require(c.phone.count <= 40 && c.preferred.count <= 120 && c.notes.count <= 1000, "Customer details are too long.")
    }
    func validateLines(_ lines: [OrderLine]) throws {
        try require(!lines.isEmpty && lines.count < 100, "Add at least one item, up to 99 lines.")
        for line in lines {
            try require(product(line.product) != nil && (1...999).contains(line.qty) && (1...1_000_000).contains(line.price), "Check each product, quantity and price.")
        }
    }
    func validatePickup(_ date: String, _ time: String) throws {
        try require(Clock.validDay(date) && date >= day && Clock.validTime(time), "Choose today or a later date and a valid pickup time.")
    }
    func checkCapacity(_ lines: [OrderLine], day: String, ignoring: String = "") throws {
        let requested = Dictionary(grouping: lines, by: \.product).mapValues { $0.reduce(0) { $0 + $1.qty } }
        for (id, qty) in requested {
            guard let p = product(id) else { throw BakeryError("Product not found.") }
            let used = orders.filter { $0.id != ignoring && $0.date == day && $0.reserves }.flatMap(\.lines).filter { $0.product == id }.reduce(0) { $0 + $1.qty }
            try require(used + qty <= p.capacity, "\(p.name): only \(max(0, p.capacity - used)) left on \(day). Choose another day or reduce the quantity.")
        }
    }
    @discardableResult
    mutating func createOrder(customer: String, lines: [OrderLine], date: String, time: String, type: String = "Retail", notes: String = "", allergy: String = "", payment: String = "none", quote: Bool = false) throws -> String {
        try validateLines(lines)
        try validatePickup(date, time)
        try require(self.customer(customer) != nil, "Choose an existing customer.")
        try require(["Retail", "Custom", "Wholesale", "Recurring"].contains(type) && notes.count <= 1000 && allergy.count <= 1000, "Check the order type and notes.")
        if !quote { try checkCapacity(lines, day: date) }
        let required = type == "Recurring" ? 0 : deposit(for: lines)
        let total = lines.reduce(0) { $0 + $1.qty * $1.price }
        let paid = quote ? 0 : payment == "full" ? total : payment == "deposit" ? required : 0
        let status = quote ? "Quote requested" : paid >= required ? "Confirmed" : "Awaiting deposit"
        let id = String(nextOrder)
        orders.append(Order(id: id, customer: customer, lines: lines, date: date, time: time, status: status, paid: paid, deposit: required, type: type, notes: notes, allergy: allergy, created: Clock.timestamp, history: [History(status: status, at: Clock.timestamp)], rating: 0, rev: 0))
        nextOrder += 1
        return id
    }
    mutating func editOrder(_ value: Order) throws {
        guard let i = orders.firstIndex(where: { $0.id == value.id }) else { throw BakeryError("Order not found.") }
        let old = orders[i]
        try require(old.editable, "Only unstarted one-off orders can be edited. Use Manage weeks for recurring orders.")
        try validateLines(value.lines)
        try validatePickup(value.date, value.time)
        try require(value.total >= old.paid && customer(value.customer) != nil && value.notes.count <= 1000 && value.allergy.count <= 1000, "Check the customer and notes. The new total cannot be less than recorded payments.")
        if old.status != "Quote requested" { try checkCapacity(value.lines, day: value.date, ignoring: value.id) }
        var updated = old
        updated.lines = value.lines; updated.customer = value.customer
        updated.date = value.date; updated.time = value.time
        updated.notes = value.notes; updated.allergy = value.allergy; updated.type = value.type
        updated.deposit = min(old.deposit, value.total); updated.rev += 1
        if updated.status == "Awaiting deposit" && updated.paid >= updated.deposit { updated.transition("Confirmed") }
        orders[i] = updated
    }
    mutating func approveQuote(_ id: String) throws {
        guard let i = orders.firstIndex(where: { $0.id == id }) else { throw BakeryError("Order not found.") }
        try require(orders[i].status == "Quote requested", "This quote is already accepted.")
        try checkCapacity(orders[i].lines, day: orders[i].date, ignoring: id)
        orders[i].transition(orders[i].deposit > orders[i].paid ? "Awaiting deposit" : "Confirmed")
        orders[i].rev += 1
    }
    mutating func recordPayment(_ id: String, full: Bool) throws {
        guard let i = orders.firstIndex(where: { $0.id == id }), orders[i].reserves else { throw BakeryError("Payments require an accepted order.") }
        orders[i].paid = full ? orders[i].total : max(orders[i].paid, orders[i].deposit)
        if orders[i].status == "Awaiting deposit" && orders[i].paid >= orders[i].deposit { orders[i].transition("Confirmed") }
    }
    mutating func advance(_ id: String, allowUnpaid: Bool = false) throws {
        guard let i = orders.firstIndex(where: { $0.id == id }), let stage = Order.stages.firstIndex(of: orders[i].status), stage < 3 else { throw BakeryError("This order cannot move forward.") }
        try require(stage != 2 || orders[i].balance == 0 || allowUnpaid, "Confirm pickup without payment, or record the balance first.")
        orders[i].transition(Order.stages[stage + 1])
    }
    mutating func cancel(_ id: String) throws {
        guard let i = orders.firstIndex(where: { $0.id == id }) else { throw BakeryError("Order not found.") }
        try require(!["Picked up", "Cancelled", "Skipped", "Paused"].contains(orders[i].status), "This order cannot be cancelled.")
        orders[i].transition("Cancelled"); orders[i].rev += 1
    }
    func batches(_ day: String) -> [Batch] {
        products.compactMap { p in
            let os = orders.filter { $0.date == day && $0.active && $0.lines.contains { $0.product == p.id } }
            guard !os.isEmpty else { return nil }
            let lines = os.flatMap { $0.lines.filter { $0.product == p.id } }
            let signatures = os.flatMap { o in o.lines.filter { $0.product == p.id }.map { "\(o.id):\($0.qty):\(o.rev)" } }.sorted()
            return Batch(product: p, quantity: lines.reduce(0) { $0 + $1.qty }, orderIDs: os.map(\.id), signature: signatures.joined(separator: ","), day: day)
        }
    }
    mutating func toggleBatch(_ batch: Batch) {
        let all = batch.product.steps.allSatisfy { tasks[batch.taskKey($0)] == true }
        for step in batch.product.steps { tasks[batch.taskKey(step)] = !all }
    }
    mutating func addRecurring(_ plan: RecurringPlan) throws {
        try require(!recurring.contains { $0.id == plan.id } && customer(plan.customer) != nil && (1...999).contains(plan.qty), "Check the customer and quantity.")
        guard let p = product(plan.product) else { throw BakeryError("Choose a product.") }
        try validatePickup(plan.start, plan.time)
        var next = self
        next.recurring.append(plan)
        for week in 0..<4 {
            let day = Clock.adding(plan.start, days: week * 7)
            let id = try next.createOrder(customer: plan.customer, lines: [OrderLine(product: p.id, qty: plan.qty, price: p.price)], date: day, time: plan.time, type: "Recurring", notes: "Standing order · payment at pickup.")
            let i = next.orders.firstIndex { $0.id == id }!
            next.orders[i].series = plan.id
        }
        self = next
    }
    mutating func pauseRecurring(_ id: String) throws {
        guard let i = recurring.firstIndex(where: { $0.id == id }) else { throw BakeryError("Schedule not found.") }
        let resume = recurring[i].paused
        var next = self
        for oi in next.orders.indices where next.orders[oi].series == id && next.orders[oi].date >= day && next.orders[oi].status == (resume ? "Paused" : "Confirmed") {
            if resume { try next.checkCapacity(next.orders[oi].lines, day: next.orders[oi].date, ignoring: next.orders[oi].id) }
            next.orders[oi].transition(resume ? "Confirmed" : "Paused"); next.orders[oi].rev += 1
        }
        next.recurring[i].paused.toggle()
        self = next
    }
    mutating func skipOccurrence(_ id: String) throws {
        guard let i = orders.firstIndex(where: { $0.id == id }), let ri = recurring.firstIndex(where: { $0.id == orders[i].series }) else { throw BakeryError("Recurring order not found.") }
        try require(["Confirmed", "Paused", "Skipped"].contains(orders[i].status), "Only unstarted pickups can be skipped or restored.")
        let restore = orders[i].status == "Skipped"
        if restore && !recurring[ri].paused { try checkCapacity(orders[i].lines, day: orders[i].date, ignoring: id) }
        orders[i].transition(restore ? (recurring[ri].paused ? "Paused" : "Confirmed") : "Skipped")
        orders[i].rev += 1
        var change = recurring[ri].exceptions[orders[i].date] ?? OccurrenceChange()
        change.skipped = !restore
        recurring[ri].exceptions[orders[i].date] = change
    }
    mutating func editOccurrence(_ id: String, quantity: Int, time: String) throws {
        guard let i = orders.firstIndex(where: { $0.id == id }), let ri = recurring.firstIndex(where: { $0.id == orders[i].series }) else { throw BakeryError("Recurring order not found.") }
        try require(["Confirmed", "Paused", "Skipped"].contains(orders[i].status) && (1...999).contains(quantity) && Clock.validTime(time), "Only unstarted pickups can be edited. Check the quantity and time.")
        var lines = orders[i].lines; lines[0].qty = quantity
        try require(quantity * lines[0].price >= orders[i].paid, "A refund is required before reducing this paid order.")
        if orders[i].reserves { try checkCapacity(lines, day: orders[i].date, ignoring: id) }
        orders[i].lines = lines; orders[i].time = time; orders[i].rev += 1
        var change = recurring[ri].exceptions[orders[i].date] ?? OccurrenceChange()
        change.qty = quantity; change.time = time
        recurring[ri].exceptions[orders[i].date] = change
    }
    mutating func saveCustomer(_ value: Customer) throws {
        try validateCustomer(value)
        if let i = customers.firstIndex(where: { $0.id == value.id }) { customers[i] = value } else { customers.append(value) }
    }
    mutating func saveProduct(_ value: Product) throws {
        try validateProduct(value)
        if let i = products.firstIndex(where: { $0.id == value.id }) { products[i] = value } else { products.append(value) }
    }
    @discardableResult
    mutating func checkout(customer: String, date: String, time: String, notes: String) throws -> String {
        let id = try createOrder(customer: customer, lines: cartLines, date: date, time: time, notes: notes, payment: "none")
        cart = [:]
        return id
    }
    func receipt(_ order: Order) -> String {
        receiptDocument(order).text
    }
    func ordersCSV() -> String {
        func cell(_ s: String) -> String {
            let safe = ["=", "+", "-", "@"].contains(s.first.map(String.init) ?? "") ? "'" + s : s
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let rows = orders.sorted { $0.date < $1.date }.map { [$0.id, customer($0.customer)?.name ?? "", $0.date, $0.time, $0.status, String($0.total), String($0.paid), String($0.balance)].map(cell).joined(separator: ",") }
        return "Order,Customer,Date,Time,Status,Total cents,Paid cents,Balance cents\n" + rows.joined(separator: "\n")
    }
}
func money(_ cents: Int) -> String {
    String(format: "$%.2f", Double(cents) / 100)
}
