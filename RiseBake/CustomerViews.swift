import SwiftUI

struct CustomersView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var query = ""
    @State private var vipOnly = false
    @State private var showingNew = false
    var customers: [Customer] { store.state.customers.filter { (!vipOnly || $0.vip) && (query.isEmpty || "\($0.name) \($0.email)".localizedCaseInsensitiveContains(query)) }.sorted { $0.name < $1.name } }
    var body: some View {
        List {
            Section { Toggle("VIP customers", isOn: $vipOnly) }
            Section { ForEach(customers) { c in NavigationLink { CustomerDetailView(id: c.id) } label: { HStack(spacing: 14) { Text(c.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()).font(.headline).frame(width: 48, height: 48).background(Color.bakeTint, in: Circle()).foregroundStyle(Color.bakeDeep); VStack(alignment: .leading, spacing: 5) { HStack { Text(c.name).font(.headline); if c.vip { Image(systemName: "star.fill").foregroundStyle(.orange).font(.caption) } }; Text(c.email).font(.caption).foregroundStyle(.secondary) } } } } }
        }.navigationTitle("Customers").searchable(text: $query, prompt: "Name or email")
        .toolbar { Button { showingNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("New customer") }
        .sheet(isPresented: $showingNew) { CustomerEditor() }
    }
}
struct CustomerDetailView: View {
    @EnvironmentObject private var store: BakeryStore
    var id: String
    @State private var editing = false
    @State private var newOrder = false
    @State private var message = ""
    @State private var messageError: String?
    var customer: Customer? { store.state.customer(id) }
    var orders: [Order] { store.state.orders.filter { $0.customer == id }.sorted { $0.date > $1.date } }
    var body: some View {
        List {
            if let c = customer {
                Section {
                    VStack(alignment: .leading, spacing: 8) { Text(c.name).font(.title.bold()); if c.vip { Label("VIP regular", systemImage: "star.fill").foregroundStyle(.orange) }; Text(c.email).foregroundStyle(.secondary); if !c.phone.isEmpty { Text(c.phone) } }.padding(.vertical, 8)
                    HStack { Metric(title: "Orders", value: "\(orders.count)"); Metric(title: "Collected", value: money(orders.reduce(0) { $0 + $1.paid })) }
                    Button("Create order") { newOrder = true }
                }
                Section("Preferences") { if !c.preferred.isEmpty { Label(c.preferred, systemImage: "clock") }; Text(c.notes.isEmpty ? "No notes yet." : c.notes) }
                Section("Order history") { ForEach(orders) { o in NavigationLink { OrderDetailView(id: o.id) } label: { OrderRow(order: o) } } }
                Section {
                    ForEach(c.messages) { m in VStack(alignment: .leading, spacing: 5) { Text(m.text); Text(m.at.prefix(10)).font(.caption).foregroundStyle(.secondary) } }
                    TextField("Write a message", text: $message, axis: .vertical)
                    Button("Save demo message") {
                        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        if store.perform({ state in
                            try require(!text.isEmpty && text.count <= 1000, "Enter a message up to 1,000 characters.")
                            if let i = state.customers.firstIndex(where: { $0.id == id }) { state.customers[i].messages.append(Message(text: text, at: Clock.timestamp)) }
                        }) { message = "" } else { messageError = store.error; store.error = nil }
                    }
                    if let messageError { Text(messageError).foregroundStyle(.red) }
                } header: { Text("Messages") } footer: { Text("Saved on this simulator. No email or SMS is sent.") }
            }
        }.navigationTitle("Customer").navigationBarTitleDisplayMode(.inline).toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) { CustomerEditor(customer: customer) }.sheet(isPresented: $newOrder) { OrderEditor(defaultCustomer: id) }
    }
}
struct CustomerEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var customer: Customer?
    @State private var draft = Customer(id: UUID().uuidString, name: "", email: "", phone: "", preferred: "", vip: false, notes: "", created: Clock.day(Date()), messages: [])
    @State private var error: String?
    var body: some View {
        NavigationStack { Form {
            Section("Contact") { TextField("Full name", text: $draft.name).textContentType(.name); TextField("Email", text: $draft.email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled(); TextField("Phone (optional)", text: $draft.phone).keyboardType(.phonePad) }
            Section("Preferences") { Toggle("VIP customer", isOn: $draft.vip); TextField("Preferred pickup", text: $draft.preferred); TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(3...6) }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle(customer == nil ? "New customer" : "Edit customer").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.perform({ try $0.saveCustomer(draft) }) { dismiss() } else { error = store.error; store.error = nil } } }
        }.onAppear { if let customer { draft = customer } } }
    }
}
