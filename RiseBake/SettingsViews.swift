import SwiftUI
import UniformTypeIdentifiers

struct InsightsView: View {
    @EnvironmentObject private var store: BakeryStore
    var orders: [Order] { store.state.orders.filter { $0.reserves } }
    var booked: Int { orders.reduce(0) { $0 + $1.total } }
    var collected: Int { orders.reduce(0) { $0 + $1.paid } }
    var cost: Int { orders.flatMap(\.lines).reduce(0) { $0 + $1.qty * (store.state.product($1.product)?.cost ?? 0) } }
    var body: some View {
        List {
            Section("All accepted orders") {
                LabeledContent("Booked revenue", value: money(booked))
                LabeledContent("Collected (simulated)", value: money(collected))
                LabeledContent("Outstanding", value: money(booked - collected))
                LabeledContent("Estimated ingredient cost", value: money(cost))
                LabeledContent("Estimated contribution", value: money(booked - cost))
            }
            Section("Products by booked value") {
                ForEach(store.state.products.sorted { value($0) > value($1) }) { p in VStack(alignment: .leading, spacing: 8) { HStack { Text(p.name); Spacer(); Text(money(value(p))).fontWeight(.semibold) }; ProgressView(value: Double(value(p)), total: Double(max(1, booked))) }.padding(.vertical, 6) }
            }
            Section { Text("Contribution subtracts current ingredient estimates from booked value. It is not net profit: labor, rent, refunds, taxes and fees are excluded. Quotes, paused, skipped and cancelled orders are excluded.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Insights")
    }
    func value(_ p: Product) -> Int { orders.flatMap(\.lines).filter { $0.product == p.id }.reduce(0) { $0 + $1.qty * $1.price } }
}
struct SettingsView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var bakery = ""
    @State private var owner = ""
    @State private var cake = 50
    @State private var other = 100
    @State private var export = false
    @State private var restore = false
    @State private var reset = false
    @State private var document = TextFile("")
    @State private var exportType: UTType = .json
    @State private var filename = "RiseBake-backup"
    @State private var saved = false
    var body: some View {
        Form {
            Section("Bakery preferences") {
                TextField("Bakery name", text: $bakery)
                TextField("Your first name", text: $owner)
                Stepper("Cake deposit: \(cake)%", value: $cake, in: 0...100)
                Stepper("Other products: \(other)%", value: $other, in: 0...100)
                Button("Save preferences") { if store.perform({ $0.settings = Settings(bakery: bakery, owner: owner, cakeDeposit: cake, otherDeposit: other) }) { saved = true } }
            }
            Section { Text("Deposit settings apply to new one-off orders. Existing orders keep their agreed deposits. Recurring orders remain payable at pickup.").font(.footnote).foregroundStyle(.secondary) }
            Section("Your data") {
                Button("Export JSON backup", systemImage: "square.and.arrow.up") {
                    do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; document = TextFile(data: try encoder.encode(store.state)); exportType = .json; filename = "RiseBake-backup"; export = true } catch { store.error = error.localizedDescription }
                }
                Button("Restore JSON backup", systemImage: "square.and.arrow.down") { restore = true }
                Button("Export orders as CSV", systemImage: "tablecells") { document = TextFile(store.state.ordersCSV()); exportType = .commaSeparatedText; filename = "RiseBake-orders"; export = true }
                Button("Reset sample data", role: .destructive) { reset = true }
            }
            Section("About RiseBake") {
                LabeledContent("Version", value: "1.2 · Native iOS")
                Text("Built with SwiftUI. Orders, checklists, products, customers and preferences save on this simulator. An Appetize session may reset its storage; export a backup to keep changes.")
                Text("Payments and messages are simulated. This preview has no authentication, cloud sync, card processing or tax calculation.").foregroundStyle(.secondary)
            }.font(.footnote)
        }.navigationTitle("Settings")
        .onAppear { bakery = store.state.settings.bakery; owner = store.state.settings.owner; cake = store.state.settings.cakeDeposit; other = store.state.settings.otherDeposit }
        .fileExporter(isPresented: $export, document: document, contentType: exportType, defaultFilename: filename) { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
        .fileImporter(isPresented: $restore, allowedContentTypes: [.json]) { result in switch result { case .success(let url): store.restore(url); bakery = store.state.settings.bakery; owner = store.state.settings.owner; cake = store.state.settings.cakeDeposit; other = store.state.settings.otherDeposit; case .failure(let error): store.error = error.localizedDescription } }
        .confirmationDialog("Replace all changes with sample data?", isPresented: $reset, titleVisibility: .visible) { Button("Reset sample data", role: .destructive) { store.reset(); bakery = store.state.settings.bakery; owner = store.state.settings.owner; cake = store.state.settings.cakeDeposit; other = store.state.settings.otherDeposit } } message: { Text("Export a backup first if you want to keep your changes.") }
        .alert("Preferences saved", isPresented: $saved) { Button("OK", role: .cancel) {} }
    }
}
