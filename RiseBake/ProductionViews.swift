import SwiftUI

struct ProductionView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var date = ""
    var day: String { date.isEmpty ? store.state.day : date }
    var batches: [Batch] { store.state.batches(day) }
    var done: Int { batches.filter { b in b.product.steps.allSatisfy { store.state.tasks[b.taskKey($0)] == true } }.count }
    var body: some View {
        List {
            Section {
                DatePicker("Bake day", selection: Binding(get: { Clock.date(day) }, set: { date = Clock.day($0) }), displayedComponents: .date).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                HStack { Metric(title: "Batches", value: "\(batches.count)"); Metric(title: "Items", value: "\(batches.reduce(0) { $0 + $1.quantity })"); Metric(title: "Complete", value: "\(done)") }.padding(.vertical, 10)
                ProgressView(value: Double(done), total: Double(max(1, batches.count))).accessibilityLabel("\(done) of \(batches.count) batches complete")
            }
            if batches.isEmpty { Section { Text("Accepted orders for this date will appear here.").foregroundStyle(.secondary) } }
            ForEach(batches) { batch in
                Section {
                    HStack { ProductPhoto(product: batch.product, size: 68); VStack(alignment: .leading, spacing: 4) { Text(batch.product.name).font(.headline); Text("\(batch.quantity) items · \(batch.orderIDs.count) orders").foregroundStyle(.secondary) }; Spacer() }
                    ForEach(batch.product.steps, id: \.self) { step in
                        Button { store.perform { $0.tasks[batch.taskKey(step)] = !(store.state.tasks[batch.taskKey(step)] ?? false) } } label: {
                            HStack { Image(systemName: store.state.tasks[batch.taskKey(step)] == true ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(Color.bakeTeal); Text(step).foregroundStyle(.primary); Spacer() }.padding(.vertical, 4)
                        }.accessibilityLabel("\(step), \(store.state.tasks[batch.taskKey(step)] == true ? "complete" : "incomplete")")
                    }
                    if let recipe = store.state.recipes.first(where: { $0.productID == batch.product.id }) {
                        NavigationLink("Recipe & timed bake") { RecipeDetailView(id: recipe.id, initialQuantity: batch.quantity) }
                        DisclosureGroup("Ingredients for \(batch.quantity) items") { ForEach(recipe.ingredients) { ingredient in LabeledContent(ingredient.name, value: "\(recipe.scaledAmount(ingredient, quantity: batch.quantity).formatted(.number.precision(.fractionLength(0...2)))) \(ingredient.unit)") } }
                    }
                    Button(batch.product.steps.allSatisfy { store.state.tasks[batch.taskKey($0)] == true } ? "Clear checklist" : "Complete batch") { store.perform { $0.toggleBatch(batch) } }
                }
            }
            Section { Text("Checklists track baking. Mark each order ready in Orders when it is packed. Changed quantities reset the affected batch checklist.").font(.footnote).foregroundStyle(.secondary) }
        }.bakeryBackground().navigationTitle("Order production")

    }
}
struct RecurringView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var filter = "Active"
    @State private var showingNew = false
    var plans: [RecurringPlan] { store.state.recurring.filter { filter == "All" || $0.paused == (filter == "Paused") } }
    var body: some View {
        List {
            Section { Picker("Schedules", selection: $filter) { Text("Active").tag("Active"); Text("Paused").tag("Paused"); Text("All").tag("All") }.pickerStyle(.segmented) }
            Section { ForEach(plans) { plan in NavigationLink { RecurringDetailView(id: plan.id) } label: {
                HStack { if let p = store.state.product(plan.product) { ProductPhoto(product: p) }; VStack(alignment: .leading, spacing: 5) { Text(store.state.customer(plan.customer)?.name ?? "Customer").font(.headline); Text("\(plan.qty) × \(store.state.product(plan.product)?.name ?? "Item")").font(.subheadline); Text("Weekly · \(plan.time)\(plan.paused ? " · Paused" : "")").font(.caption).foregroundStyle(.secondary) } }
            } } }
            Section { Text("Plan four weekly pickups at a time and record payments when received.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Recurring orders").toolbar { Button { showingNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add recurring order") }.sheet(isPresented: $showingNew) { RecurringEditor() }
    }
}
struct RecurringDetailView: View {
    @EnvironmentObject private var store: BakeryStore
    var id: String
    @State private var edit: Order?
    var plan: RecurringPlan? { store.state.recurring.first { $0.id == id } }
    var body: some View {
        List {
            if let p = plan {
                Section {
                    Text(store.state.customer(p.customer)?.name ?? "Customer").font(.title2.bold())
                    Text("\(p.qty) × \(store.state.product(p.product)?.name ?? "Item") every week")
                    Button(p.paused ? "Resume schedule" : "Pause schedule") { store.perform { try $0.pauseRecurring(id) } }
                }
                Section("Manage weeks") {
                    ForEach(store.state.orders.filter { $0.series == id }.sorted { $0.date < $1.date }) { o in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text(prettyDay(o.date)).font(.headline); Spacer(); StatusBadge(status: o.status) }
                            Text("\(o.lines.first?.qty ?? 0) items · \(o.time) · \(money(o.total))").font(.subheadline).foregroundStyle(.secondary)
                            HStack {
                                NavigationLink("Order details") { OrderDetailView(id: o.id) }
                                Spacer()
                                if ["Confirmed", "Paused", "Skipped"].contains(o.status) {
                                    Button("Edit") { edit = o }.buttonStyle(.borderless)
                                    Button(o.status == "Skipped" ? "Restore" : "Skip") { store.perform { try $0.skipOccurrence(o.id) } }.buttonStyle(.borderless)
                                }
                            }.font(.subheadline.weight(.semibold))
                        }.padding(.vertical, 8)
                    }
                }
                Section { Text("Changes affect only the selected week. Pausing leaves pickups already in production unchanged.").font(.footnote).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Manage weeks").navigationBarTitleDisplayMode(.inline).sheet(item: $edit) { OccurrenceEditor(order: $0) }
    }
}
struct OccurrenceEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var order: Order
    @State private var quantity = 1
    @State private var time = "10:00"
    @State private var error: String?
    var body: some View {
        NavigationStack { Form {
            Section(prettyDay(order.date)) { Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999); DatePicker("Pickup time", selection: Binding(get: { Clock.formatter("HH:mm").date(from: time) ?? Date() }, set: { time = Clock.formatter("HH:mm").string(from: $0) }), displayedComponents: .hourAndMinute).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!) }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Edit this week").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.perform({ try $0.editOccurrence(order.id, quantity: quantity, time: time) }) { dismiss() } else { error = store.error; store.error = nil } } }
        }.onAppear { quantity = order.lines.first?.qty ?? 1; time = order.time } }
    }
}
struct RecurringEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    @State private var customer = ""
    @State private var product = ""
    @State private var quantity = 1
    @State private var date = ""
    @State private var time = "10:00"
    @State private var error: String?
    var body: some View {
        NavigationStack { Form {
            Section {
                Picker("Customer", selection: $customer) { ForEach(store.state.customers) { Text($0.name).tag($0.id) } }
                Picker("Product", selection: $product) { ForEach(store.state.products) { Text($0.name).tag($0.id) } }
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                PickupFields(date: $date, time: $time, earliest: store.state.day)
            } footer: { Text("Creates four weekly pickups. Payment is due at pickup.") }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("New recurring order").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { let plan = RecurringPlan(id: UUID().uuidString, customer: customer, product: product, qty: quantity, start: date, time: time, paused: false, exceptions: [:]); if store.perform({ try $0.addRecurring(plan) }) { dismiss() } else { error = store.error; store.error = nil } } }
        }.onAppear { customer = store.state.customers.first?.id ?? ""; product = store.state.products.first?.id ?? ""; date = store.state.day } }
    }
}
