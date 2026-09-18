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
                LabeledContent("Payments recorded", value: money(collected))
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
    @State private var cake = 50
    @State private var other = 100
    @State private var export = false
    @State private var restore = false
    @State private var reset = false
    @State private var document = TextFile("")
    @State private var exportType: UTType = .json
    @State private var filename = "Rise-and-Bake-backup"
    @State private var saved = false
    @State private var notificationStatus = ""
    @State private var pendingRestore: URL?
    @State private var confirmRestore = false
    var body: some View {
        Form {
            Section("Your bakery") {
                NavigationLink { BakeryProfileView(settings: store.state.settings) } label: {
                    HStack { BakeryLogoView(data: store.state.settings.profile?.logoData, size: 48); VStack(alignment: .leading) { Text("Bakery profile & logo"); Text(store.state.settings.bakery).font(.caption).foregroundStyle(.secondary) } }
                }
            }
            Section("Deposit preferences") {
                Stepper("Cake deposit: \(cake)%", value: $cake, in: 0...100)
                Stepper("Other products: \(other)%", value: $other, in: 0...100)
                Button("Save preferences") { if store.perform({ $0.settings.cakeDeposit = cake; $0.settings.otherDeposit = other }) { saved = true } }
            }
            Section { Text("Deposit settings apply to new one-off orders. Existing orders keep their agreed deposits. Recurring orders remain payable at pickup.").font(.footnote).foregroundStyle(.secondary) }
            Section("Make it yours") { NavigationLink { AppearanceView() } label: { Label("Choose a background", systemImage: "paintpalette") } }
            Section("Baking reminders") {
                Button("Enable timer notifications", systemImage: "bell") {
                    Task { do { let allowed = try await BakeNotifications.shared.request(); notificationStatus = allowed ? "Timer reminders are enabled." : "Enable Rise & Bake notifications in iPhone Settings to receive reminders."; BakeNotifications.shared.sync(store.state.bakeSessions) } catch { notificationStatus = error.localizedDescription } }
                }
                if !notificationStatus.isEmpty { Text(notificationStatus).font(.footnote) }
            }
            Section("Your data") {
                Button("Export JSON backup", systemImage: "square.and.arrow.up") {
                    do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; document = TextFile(data: try encoder.encode(store.state)); exportType = .json; filename = "Rise-and-Bake-backup"; export = true } catch { store.error = error.localizedDescription }
                }
                Button("Restore JSON backup", systemImage: "square.and.arrow.down") { restore = true }
                Button("Export orders as CSV", systemImage: "tablecells") { document = TextFile(store.state.ordersCSV()); exportType = .commaSeparatedText; filename = "Rise-and-Bake-orders"; export = true }
                Button("Start a new bakery", role: .destructive) { reset = true }
            }
            Section("About Rise & Bake") {
                LabeledContent("Version", value: "2.2 · Native iOS")
                Text("Your everyday baking companion. Recipes, bake journals, orders and customer records are saved on this iPhone.")
            }.font(.footnote)
        }.bakeryBackground().navigationTitle("Settings")
        .onAppear { cake = store.state.settings.cakeDeposit; other = store.state.settings.otherDeposit }
        .fileExporter(isPresented: $export, document: document, contentType: exportType, defaultFilename: filename) { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
        .fileImporter(isPresented: $restore, allowedContentTypes: [.json]) { result in switch result { case .success(let url): pendingRestore = url; confirmRestore = true; case .failure(let error): store.error = error.localizedDescription } }
        .confirmationDialog("Clear bakery records and start fresh?", isPresented: $reset, titleVisibility: .visible) { Button("Start a new bakery", role: .destructive) { store.reset(); cake = store.state.settings.cakeDeposit; other = store.state.settings.otherDeposit } } message: { Text("Export a backup first if you want to keep your changes.") }
        .confirmationDialog("Replace current records with this file?", isPresented: $confirmRestore, titleVisibility: .visible) { Button("Import and replace records", role: .destructive) { if let url = pendingRestore { store.restore(url); cake = store.state.settings.cakeDeposit; other = store.state.settings.otherDeposit } } } message: { Text("This replaces orders, customers, recipes and bake journals with the selected file.") }
        .alert("Preferences saved", isPresented: $saved) { Button("OK", role: .cancel) {} }
    }
}
