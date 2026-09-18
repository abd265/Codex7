import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var query = ""
    @State private var filter = "All"
    @State private var showingNew = false
    private var orders: [Order] {
        store.state.orders.filter { o in
            (filter == "All" || o.status == filter) && (query.isEmpty || "\(o.id) \(store.state.customer(o.customer)?.name ?? "") \(o.lines.map { store.state.product($0.product)?.name ?? "" }.joined(separator: " "))".localizedCaseInsensitiveContains(query))
        }.sorted { ($0.date, $0.time, $0.id) < ($1.date, $1.time, $1.id) }
    }
    var body: some View {
        List {
            Section {
                Picker("Status", selection: $filter) { Text("All orders").tag("All"); ForEach(Order.statuses, id: \.self) { Text($0).tag($0) } }
                NavigationLink { RecurringView() } label: { Label("Recurring orders", systemImage: "repeat") }
            }
            ForEach(Array(Set(orders.map(\.date))).sorted(), id: \.self) { day in
                Section(prettyDay(day)) { ForEach(orders.filter { $0.date == day }) { order in NavigationLink { OrderDetailView(id: order.id) } label: { OrderRow(order: order) } } }
            }
        }.overlay { if orders.isEmpty { EmptyList(title: "No orders found", symbol: "bag") } }
        .bakeryBackground().navigationTitle("Orders").searchable(text: $query, prompt: "Name, product or order number")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showingNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("New order") } }
        .sheet(isPresented: $showingNew) { OrderEditor() }
    }
}
struct OrderDetailView: View {
    @EnvironmentObject private var store: BakeryStore
    var id: String
    @State private var editing = false
    @State private var confirmPayment = false
    @State private var confirmCancel = false
    @State private var confirmUnpaid = false
    @State private var receipt = false
    var order: Order? { store.state.order(id) }
    var body: some View {
        Group {
            if let o = order {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            StatusBadge(status: o.status)
                            Text(store.state.customer(o.customer)?.name ?? "Customer").font(.title.bold())
                            Label("\(prettyDay(o.date)) at \(o.time)", systemImage: "calendar")
                            Text(o.type + (o.series != nil ? " · Weekly pickup" : "")).font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                        NavigationLink { CustomerDetailView(id: o.customer) } label: { Label("Customer profile", systemImage: "person.crop.circle") }
                    }
                    Section("Order details") {
                        ForEach(Array(o.lines.enumerated()), id: \.offset) { _, line in
                            HStack { if let p = store.state.product(line.product) { ProductPhoto(product: p); VStack(alignment: .leading, spacing: 4) { Text(p.name).font(.headline); Text("\(line.qty) × \(money(line.price))").foregroundStyle(.secondary) } }; Spacer(); Text(money(line.qty * line.price)).fontWeight(.semibold) }
                        }
                        LabeledContent("Total", value: money(o.total))
                        LabeledContent("Payments recorded", value: money(o.paid))
                        LabeledContent("Remaining balance", value: money(o.balance))
                        if o.balance > 0 { LabeledContent("Deposit due", value: money(max(0, o.deposit - o.paid))) }
                    }
                    if !o.notes.isEmpty || !o.allergy.isEmpty {
                        Section("Baker’s notes") { if !o.notes.isEmpty { Text(o.notes) }; if !o.allergy.isEmpty { Label(o.allergy, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
                    }
                    Section {
                        if o.status == "Quote requested" { Button("Approve quote") { store.perform { try $0.approveQuote(id) } } }
                        if o.reserves && o.balance > 0 { Button("Record payment") { confirmPayment = true } }
                        if let stage = Order.stages.firstIndex(of: o.status), stage < 3 {
                            Button { if stage == 2 && o.balance > 0 { confirmUnpaid = true } else { store.perform { try $0.advance(id) } } } label: { Label(["Start production", "Mark ready for pickup", "Complete pickup"][stage], systemImage: "checkmark.circle.fill") }.fontWeight(.semibold)
                        }
                        if o.editable { Button("Edit order") { editing = true } }
                        Button("View receipt") { receipt = true }
                        if !["Picked up", "Cancelled", "Skipped", "Paused"].contains(o.status) { Button("Cancel order", role: .destructive) { confirmCancel = true } }
                    }
                    if o.status == "Picked up" {
                        Section("Pickup complete") {
                            Label("Thank you for baking someone’s day.", systemImage: "checkmark.seal.fill").foregroundStyle(Color.bakeTeal)
                            HStack { Text("Rate this order"); Spacer(); ForEach(1...5, id: \.self) { value in Button { store.perform { s in if let i = s.orders.firstIndex(where: { $0.id == id }) { s.orders[i].rating = value } } } label: { Image(systemName: value <= o.rating ? "star.fill" : "star") }.buttonStyle(.borderless).accessibilityLabel("\(value) stars") } }
                        }
                    }
                    Section("Timeline") { ForEach(Array(o.history.enumerated()), id: \.offset) { _, event in HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.bakeTeal); VStack(alignment: .leading, spacing: 4) { Text(event.status); Text(event.at.replacingOccurrences(of: "T", with: " ").prefix(16)).font(.caption).foregroundStyle(.secondary) } } } }
                }
            } else { EmptyList(title: "Order not found", symbol: "bag") }
        }.navigationTitle("#RB-\(id)").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) { if let o = order { OrderEditor(order: o) } }
        .sheet(isPresented: $receipt) { if let o = order { ReceiptView(order: o) } }
        .confirmationDialog("Record a payment received", isPresented: $confirmPayment, titleVisibility: .visible) {
            Button("Record full balance") { store.perform { try $0.recordPayment(id, full: true) } }
            if let o = order, o.deposit > o.paid { Button("Record required deposit") { store.perform { try $0.recordPayment(id, full: false) } } }
        } message: { Text("Confirm only payments you have already received, such as cash or bank transfer.") }
        .confirmationDialog("Cancel this order?", isPresented: $confirmCancel, titleVisibility: .visible) { Button("Cancel order", role: .destructive) { store.perform { try $0.cancel(id) } } } message: { Text("Capacity is released. Recorded payments remain; no refund is issued.") }
        .confirmationDialog("Complete pickup with an unpaid balance?", isPresented: $confirmUnpaid, titleVisibility: .visible) { Button("Complete pickup without payment") { store.perform { try $0.advance(id, allowUnpaid: true) } } }
    }
}
struct OrderEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var order: Order?
    var defaultCustomer: String?
    var quoteOnly = false
    @State private var customer = ""
    @State private var lines: [OrderLine] = []
    @State private var date = ""
    @State private var time = "10:00"
    @State private var type = "Retail"
    @State private var notes = ""
    @State private var allergy = ""
    @State private var payment = "none"
    @State private var newCustomer = false
    @State private var initialized = false
    @State private var formError: String?
    private var total: Int { lines.reduce(0) { $0 + $1.price * $1.qty } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Customer & pickup") {
                    Picker("Customer", selection: $customer) { Text("Choose customer").tag(""); ForEach(store.state.customers) { Text($0.name).tag($0.id) } }
                    Button("Add customer") { newCustomer = true }
                    PickupFields(date: $date, time: $time, earliest: store.state.day)
                    if !quoteOnly { Picker("Order type", selection: $type) { ForEach(["Retail", "Custom", "Wholesale"], id: \.self) { Text($0).tag($0) } } }
                }
                Section("Items") {
                    ForEach(lines.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Product", selection: $lines[i].product) { ForEach(store.state.products) { Text($0.name).tag($0.id) } }
                                .onChange(of: lines[i].product) { _, id in lines[i].price = store.state.product(id)?.price ?? 0 }
                            Stepper("Quantity: \(lines[i].qty)", value: $lines[i].qty, in: 1...999)
                            HStack { Text(money(lines[i].qty * lines[i].price)).foregroundStyle(.secondary); Spacer(); if lines.count > 1 { Button("Remove", role: .destructive) { lines.remove(at: i) }.buttonStyle(.borderless) } }
                        }.padding(.vertical, 6)
                    }
                    Button("Add item", systemImage: "plus") { if let p = store.state.products.first { lines.append(OrderLine(product: p.id, qty: 1, price: p.price)) } }
                    LabeledContent(quoteOnly ? "Estimated total" : "Total", value: money(total))
                }
                Section("Notes") { TextField("Design or pickup notes", text: $notes, axis: .vertical).lineLimit(3...5); TextField("Allergies or dietary requests", text: $allergy, axis: .vertical) }
                if order == nil && !quoteOnly {
                    Section { Picker("Payment received", selection: $payment) { Text("Not recorded").tag("none"); Text("Deposit recorded").tag("deposit"); Text("Paid in full").tag("full") } } footer: { Text("Record payments you have already received. Production starts once the required deposit is recorded.") }
                }
                if quoteOnly { Section { Text("The baker reviews this request before it reserves capacity. You can review the price before approval.").font(.footnote).foregroundStyle(.secondary) } }
                if let formError { Section { Text(formError).foregroundStyle(.red) } }
            }.navigationTitle(order != nil ? "Edit order" : quoteOnly ? "Custom cake request" : "New order").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(quoteOnly ? "Request" : "Save", action: save).fontWeight(.semibold) } }
            .sheet(isPresented: $newCustomer) { CustomerEditor(onSaved: { customer = $0 }) }
            .onAppear {
                guard !initialized else { return }; initialized = true
                customer = order?.customer ?? defaultCustomer ?? store.state.customers.first?.id ?? ""
                date = order?.date ?? store.state.day; time = order?.time ?? "10:00"
                type = order?.type ?? (quoteOnly ? "Custom" : "Retail"); notes = order?.notes ?? ""; allergy = order?.allergy ?? ""
                if let order { lines = order.lines } else if let p = quoteOnly ? store.state.products.first(where: { $0.id == "p2" }) : store.state.products.first { lines = [OrderLine(product: p.id, qty: 1, price: p.price)] }
            }
        }
    }
    private func save() {
        let ok = store.perform { state in
            if var updated = order {
                updated.customer = customer; updated.lines = lines; updated.date = date; updated.time = time; updated.type = type; updated.notes = notes; updated.allergy = allergy
                try state.editOrder(updated)
            } else { try state.createOrder(customer: customer, lines: lines, date: date, time: time, type: type, notes: notes, allergy: allergy, payment: payment, quote: quoteOnly) }
        }
        if ok { dismiss() } else { formError = store.error; store.error = nil }
    }
}
struct ReceiptView: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var order: Order
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 24) { Label("RiseBake", systemImage: "leaf.fill").font(.largeTitle.bold()).foregroundStyle(Color.bakeTeal); Text(store.state.receipt(order)).font(.body.monospaced()).textSelection(.enabled); ShareLink(item: store.state.receipt(order)) { Label("Share receipt", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent) }.padding(24) }.navigationTitle("Receipt").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } } }
    }
}
