import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var planning = false
    @State private var adding = false
    var body: some View {
        List {
            if let list = store.state.shopping {
                Section {
                    Label("Ready for your next bake", systemImage: "cart").font(.title3.bold())
                    Text("Pickups \(prettyDay(list.fromDay)) – \(prettyDay(list.throughDay))").font(.subheadline)
                    Text("\(list.orderIDs.count) orders · \(list.wholeBatches ? "Whole recipe batches" : "Exact recipe quantities")").font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: Double(list.checkedCount), total: Double(max(1, list.buyCount)))
                    Text("\(list.checkedCount) of \(list.buyCount) items checked").font(.caption).accessibilityIdentifier("shopping.progress")
                    LabeledContent("Priced packages (CAD)", value: costMoney(list.pricedBudget)).fontWeight(.semibold)
                    if list.unpricedCount > 0 { Text("\(list.unpricedCount) items still need prices; the budget is incomplete.").font(.footnote).foregroundStyle(.orange) }
                    Text("Saved \(list.createdAt.prefix(10)). Prices are estimates from your pantry entries.").font(.caption).foregroundStyle(.secondary)
                }
                if list.sourceSignature != store.state.shoppingSignature(orderIDs: list.orderIDs) {
                    Section { Label("Orders, recipes or pantry entries have changed. This saved list has not been updated.", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.orange); Button("Review orders & rebuild") { planning = true } }
                }
                if !list.warnings.isEmpty {
                    Section("Needs attention · check before shopping") { ForEach(list.warnings, id: \.self) { Text($0).font(.footnote).foregroundStyle(.orange) } }
                }
                Section("To buy") {
                    if list.buyCount == 0 { Text(list.warnings.isEmpty ? "Your entered stock covers these ingredients." : "Review the missing ingredients above before relying on this list.").foregroundStyle(.secondary) }
                    ForEach(list.items.filter { $0.toBuy > 0 }) { item in
                        Button { toggle(item.id) } label: { ShoppingItemRow(item: item) }.buttonStyle(.plain).accessibilityIdentifier("shopping.item.\(item.id)")
                        .swipeActions { if item.manual { Button("Remove", role: .destructive) { store.perform { $0.shopping?.items.removeAll { $0.id == item.id } } } } }
                    }
                    Button("Add an extra item", systemImage: "plus") { adding = true }.accessibilityIdentifier("shopping.extra")
                }
                if list.items.contains(where: { $0.toBuy == 0 }) {
                    Section { DisclosureGroup("Already in stock") { ForEach(list.items.filter { $0.toBuy == 0 }) { item in VStack(alignment: .leading, spacing: 4) { Text(item.name); Text("Need \(quantityText(item.required)) \(item.unit) · Stock \(quantityText(item.stock)) \(item.unit)").font(.caption).foregroundStyle(.secondary) } } } }
                }
                Section {
                    ShareLink(item: list.text) { Label("Share shopping list", systemImage: "square.and.arrow.up") }.accessibilityIdentifier("shopping.share")
                    NavigationLink { PantryView() } label: { Label("Update pantry stock", systemImage: "cabinet") }
                    Text("Checking items does not change stock. Update pantry quantities after shopping and baking. A new list replaces this list and its checks; share a copy first if you want to keep it.").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ContentUnavailableView("A shopping list from your orders", systemImage: "basket", description: Text("Combine recipe ingredients, subtract your pantry stock and see the packages you need."))
                    Button("Choose orders", systemImage: "checklist") { planning = true }.accessibilityIdentifier("shopping.create")
                    NavigationLink("Set up ingredients & prices") { PantryView() }
                }
            }
        }.bakeryBackground().navigationTitle("Shopping list")
        .toolbar { Button("Choose orders") { planning = true }.accessibilityIdentifier("shopping.plan") }
        .sheet(isPresented: $planning) { ShoppingPlanEditor() }
        .sheet(isPresented: $adding) { ShoppingExtraEditor() }
    }
    private func toggle(_ id: String) {
        store.perform { state in if let i = state.shopping?.items.firstIndex(where: { $0.id == id }) { state.shopping?.items[i].checked.toggle() } }
    }
}
struct ShoppingItemRow: View {
    var item: ShoppingItem
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(Color.bakeTeal)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name).font(.headline).strikethrough(item.checked)
                Text("Buy \(quantityText(item.toBuy)) \(item.unit)").font(.subheadline).foregroundStyle(Color.bakeTeal)
                if let packages = item.packages { Text("\(quantityText(packages)) package(s) · \(item.budgetCents.map(costMoney) ?? "Price needed")").font(.subheadline) }
                if !item.manual { Text("Need \(quantityText(item.required)) · stock \(quantityText(item.stock)) \(item.unit)").font(.caption).foregroundStyle(.secondary) }
                if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 5).accessibilityElement(children: .combine).accessibilityLabel("\(item.name), buy \(quantityText(item.toBuy)) \(item.unit), \(item.checked ? "checked" : "not checked")")
    }
}
struct ShoppingPlanEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    @State private var from = Clock.today
    @State private var through = Clock.adding(Clock.today, days: 7)
    @State private var includeUnpaid = false
    @State private var includeStarted = false
    @State private var wholeBatches = true
    @State private var selected: Set<String> = []
    @State private var loaded = false
    @State private var confirm = false
    @State private var error: String?
    var orders: [Order] {
        store.state.orders.filter { $0.date >= from && $0.date <= through && ($0.status == "Confirmed" || (includeUnpaid && $0.status == "Awaiting deposit") || (includeStarted && $0.status == "In production")) }.sorted { ($0.date, $0.time, $0.id) < ($1.date, $1.time, $1.id) }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Pickup dates") { CostDayField(title: "From", day: $from); CostDayField(title: "Through", day: $through) }
                Section {
                    Toggle("Include orders awaiting deposits", isOn: $includeUnpaid)
                    Toggle("Include orders in production", isOn: $includeStarted)
                    Toggle("Round up to whole recipe batches", isOn: $wholeBatches)
                } footer: { Text("Confirmed orders are included by default. Finished, cancelled, paused and skipped orders are excluded. Ingredients already used in started orders are not tracked automatically. Whole batches are rounded after combining each product’s selected orders. Packaging is not generated; add it as an extra item.") }
                Section {
                    HStack { Text("\(selected.count) selected").fontWeight(.semibold); Spacer(); Button(selected.count == orders.count ? "Clear" : "Select all") { selected = selected.count == orders.count ? [] : Set(orders.map(\.id)) }.buttonStyle(.borderless) }
                    if orders.isEmpty { Text("No matching orders. Choose different dates, or add an order first.").foregroundStyle(.secondary) }
                    ForEach(orders) { order in
                        Button {
                            if selected.contains(order.id) { selected.remove(order.id) } else { selected.insert(order.id) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selected.contains(order.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(Color.bakeTeal)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("#RB-\(order.id) · \(store.state.customer(order.customer)?.name ?? "Customer")").foregroundStyle(.primary)
                                    Text("\(prettyDay(order.date)) · \(order.status)").font(.caption).foregroundStyle(.secondary)
                                    Text(order.lines.map { "\($0.qty) × \(store.state.product($0.product)?.name ?? "Item")" }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.accessibilityIdentifier("shopping.order.\(order.id)")
                    }
                } header: { Text("Orders to shop for") }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Plan shopping").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create list") { if store.state.shopping != nil { confirm = true } else { save() } }.disabled(selected.isEmpty || from > through).accessibilityIdentifier("shopping.generate") }
            }
            .onAppear { if !loaded { selected = Set(orders.map(\.id)); loaded = true } }
            .onChange(of: from) { _, _ in resetSelection() }.onChange(of: through) { _, _ in resetSelection() }
            .onChange(of: includeUnpaid) { _, _ in resetSelection() }.onChange(of: includeStarted) { _, _ in resetSelection() }
            .confirmationDialog("Replace the saved shopping list?", isPresented: $confirm, titleVisibility: .visible) { Button("Replace list and reset checks", role: .destructive, action: save) } message: { Text("The new list uses current orders and pantry stock. Extra items and checkmarks from the old list will be removed.") }
        }
    }
    private func resetSelection() { selected = Set(orders.map(\.id)) }
    private func save() {
        if store.perform({ state in state.shopping = try state.makeShoppingList(orderIDs: selected, from: from, through: through, wholeBatches: wholeBatches) }) { dismiss() }
        else { error = store.error; store.error = nil }
    }
}
struct ShoppingExtraEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = 1.0
    @State private var unit = "piece"
    @State private var notes = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $name).accessibilityIdentifier("shopping.extra.name")
                CostQuantityField(title: "Quantity to buy", value: $amount)
                Picker("Unit", selection: $unit) { ForEach(RecipeIngredient.units, id: \.self) { Text($0).tag($0) } }
                TextField("Notes (size, shop, brand…)", text: $notes, axis: .vertical)
                Text("Extras are unpriced and stay separate from recipe ingredients.").font(.footnote).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Extra shopping item").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") {
                    if store.perform({ state in
                        try require(state.shopping != nil && amount.isFinite && amount > 0, "Enter a positive quantity.")
                        let item = ShoppingItem(name: name.trimmingCharacters(in: .whitespacesAndNewlines), unit: unit, required: amount, stock: 0, toBuy: amount, manual: true, note: notes)
                        try item.validate(); state.shopping?.items.append(item)
                    }) { dismiss() } else { error = store.error; store.error = nil }
                }.accessibilityIdentifier("shopping.extra.save") }
            }
        }
    }
}
