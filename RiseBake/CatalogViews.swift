import SwiftUI

struct ProductsView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var editing: Product?
    @State private var adding = false
    var body: some View {
        List {
            ForEach(BakeryCatalog.categories, id: \.self) { category in
                Section(category) { ForEach(store.state.products.filter { $0.category == category }) { p in Button { editing = p } label: {
                    HStack { ProductPhoto(product: p); VStack(alignment: .leading, spacing: 5) { Text(p.name).font(.headline).foregroundStyle(.primary); Text("\(p.capacity) / day · Manual ingredient estimate \(money(p.cost))").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(money(p.price)).fontWeight(.semibold) }
                } } }
            }
        }.bakeryBackground().navigationTitle("Products & pricing").toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("New product") }
        .sheet(item: $editing) { ProductEditor(product: $0) }.sheet(isPresented: $adding) { ProductEditor() }
    }
}
struct ProductEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var product: Product?
    @State private var draft = Product(id: UUID().uuidString, name: "", category: "Breads", price: 600, cost: 150, capacity: 48, image: 0, unit: "piece", description: "", allergens: "", recipe: [:], steps: ["Mix", "Shape", "Bake"])
    @State private var price = "6.00"
    @State private var cost = "1.50"
    @State private var error: String?
    var body: some View {
        NavigationStack { Form {
            Section { TextField("Product name", text: $draft.name); Picker("Category", selection: $draft.category) { ForEach(BakeryCatalog.categories, id: \.self) { Text($0).tag($0) } }; LabeledContent("Price ($)") { TextField("6.00", text: $price).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }; LabeledContent("Manual ingredient estimate ($)") { TextField("1.50", text: $cost).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }; Stepper("Daily capacity: \(draft.capacity)", value: $draft.capacity, in: 1...9999) }
            Section { TextField("Description", text: $draft.description, axis: .vertical); TextField("Allergens", text: $draft.allergens); TextField("Unit", text: $draft.unit); Picker("Photo", selection: $draft.image) { ForEach(BakeryCatalog.photos.indices, id: \.self) { Text(BakeryCatalog.photos[$0]).tag($0) } }; ProductPhoto(product: draft, size: 130) }
            Section { Text("The manual ingredient estimate is used in Insights. Detailed recipe costing is available from More and does not overwrite this field.").font(.footnote).foregroundStyle(.secondary) }
            Section { Text("Price changes apply to new orders. Existing orders keep their agreed prices.").font(.footnote).foregroundStyle(.secondary) }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle(product == nil ? "New product" : "Edit product").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }.onAppear { if let product { draft = product; price = String(format: "%.2f", Double(product.price) / 100); cost = String(format: "%.2f", Double(product.cost) / 100) } } }
    }
    private func save() {
        guard let p = Decimal(string: price.replacingOccurrences(of: ",", with: ".")), let c = Decimal(string: cost.replacingOccurrences(of: ",", with: ".")), p > 0, p <= 10000, c >= 0, c <= 10000 else { error = "Enter valid prices from $0.01 to $10,000."; return }
        draft.price = NSDecimalNumber(decimal: p * 100).intValue; draft.cost = NSDecimalNumber(decimal: c * 100).intValue
        if product == nil { draft.steps = draft.category == "Cakes" ? ["Bake", "Decorate", "Pack"] : ["Mix", "Shape", "Bake"] }
        if store.perform({ try $0.saveProduct(draft) }) { dismiss() } else { error = store.error; store.error = nil }
    }
}
struct StorefrontView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var category = "All"
    @State private var cake = false
    @State private var favoritesOnly = false
    @AppStorage("favoriteProducts") private var favoriteIDs = ""
    private func favorite(_ id: String) -> Bool { favoriteIDs.split(separator: ",").contains(Substring(id)) }
    var products: [Product] { store.state.products.filter { (category == "All" || $0.category == category) && (!favoritesOnly || favorite($0.id)) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BakeryHero(title: "Small batches.\nBig-hearted baking.", subtitle: "Fresh from our oven, made for your table.")
                Picker("Category", selection: $category) { ForEach((["All"] + BakeryCatalog.categories), id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                Toggle("Favorites only", isOn: $favoritesOnly).font(.subheadline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    ForEach(products) { p in
                        VStack(alignment: .leading, spacing: 10) {
                            GeometryReader { proxy in Image("bake\(p.image)").resizable().scaledToFill().frame(width: proxy.size.width, height: 150).clipped() }.frame(height: 150).overlay(alignment: .topTrailing) { Button { var ids = Set(favoriteIDs.split(separator: ",").map(String.init)); if favorite(p.id) { ids.remove(p.id) } else { ids.insert(p.id) }; favoriteIDs = ids.sorted().joined(separator: ",") } label: { Image(systemName: favorite(p.id) ? "heart.fill" : "heart").foregroundStyle(Color.bakeTeal).padding(9).background(.regularMaterial, in: Circle()) }.padding(8).accessibilityLabel(favorite(p.id) ? "Remove \(p.name) from favorites" : "Favorite \(p.name)") }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(p.name).font(.headline).lineLimit(2)
                                Text(p.description).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                                Text(p.allergens).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                                HStack { Text(money(p.price)).fontWeight(.semibold); Spacer(); Button { store.perform { $0.cart[p.id] = min(999, ($0.cart[p.id] ?? 0) + 1) } } label: { Image(systemName: "plus").font(.headline).padding(9) }.buttonStyle(.borderedProminent).buttonBorderShape(.circle).accessibilityLabel("Add \(p.name) to basket") }
                            }.padding([.horizontal, .bottom], 12)
                        }.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)).clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
                Button { cake = true } label: { BakeCard { HStack { Image(systemName: "birthday.cake").font(.title); VStack(alignment: .leading, spacing: 5) { Text("Something to celebrate?").font(.headline); Text("Request a custom cake").font(.subheadline) }; Spacer(); Image(systemName: "chevron.right") } } }.buttonStyle(.plain)
            }.padding(20)
        }.bakeryBackground().navigationTitle("Menu")
        .toolbar { NavigationLink { BasketView() } label: { Label("Basket (\(store.state.cart.values.reduce(0, +)))", systemImage: "basket") } }
        .sheet(isPresented: $cake) { OrderEditor(quoteOnly: true) }
    }
}
struct BasketView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var customer = ""
    @State private var date = ""
    @State private var time = "10:00"
    @State private var notes = ""
    @State private var confirm = false
    @State private var newCustomer = false
    @State private var createdOrder: String?
    var body: some View {
        Group {
            if let id = createdOrder { OrderDetailView(id: id) }
            else if store.state.cartLines.isEmpty { ContentUnavailableView("Your basket is empty", systemImage: "basket", description: Text("Add something lovely from the storefront.")) }
            else { Form {
                Section("Your basket") { ForEach(store.state.cartLines, id: \.product) { line in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(store.state.product(line.product)?.name ?? "Item").font(.headline); Spacer(); Text(money(line.price * line.qty)) }
                        Stepper("Quantity: \(line.qty)", value: Binding(get: { store.state.cart[line.product] ?? 0 }, set: { value in store.perform { if value == 0 { $0.cart.removeValue(forKey: line.product) } else { $0.cart[line.product] = value } } }), in: 0...999)
                    }
                }; LabeledContent("Total", value: money(store.state.cartLines.reduce(0) { $0 + $1.qty * $1.price })) }
                Section("Pickup") {
                    Picker("Customer", selection: $customer) { Text("Choose customer").tag(""); ForEach(store.state.customers) { Text($0.name).tag($0.id) } }
                    Button("Add customer") { newCustomer = true }
                    PickupFields(date: $date, time: $time, earliest: store.state.day)
                    TextField("Pickup notes", text: $notes, axis: .vertical)
                }
                Section { Button("Place order") { confirm = true }.fontWeight(.semibold) } footer: { Text("Record the order now, then record payment when you receive it.") }
            } }
        }.navigationTitle(createdOrder == nil ? "Basket" : "Order placed").navigationBarTitleDisplayMode(.inline)
        .onAppear { if customer.isEmpty { customer = store.state.customers.first?.id ?? "" }; if date.isEmpty { date = store.state.day } }
        .sheet(isPresented: $newCustomer) { CustomerEditor(onSaved: { customer = $0 }) }
        .confirmationDialog("Place this order?", isPresented: $confirm, titleVisibility: .visible) { Button("Place order") { var id = ""; if store.perform({ id = try $0.checkout(customer: customer, date: date, time: time, notes: notes) }) { createdOrder = id } } } message: { Text("The order is saved with payment outstanding.") }
    }
}
