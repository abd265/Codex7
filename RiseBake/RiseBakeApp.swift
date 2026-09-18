import SwiftUI

@main struct RiseBakeApp: App {
    @StateObject private var store = BakeryStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(store).tint(.bakeTeal) } }
}
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: BakeryStore
    var body: some View {
        TabView {
            NavigationStack { TodayView() }.tabItem { Label("Today", systemImage: "sun.max") }
            NavigationStack { OrdersView() }.tabItem { Label("Orders", systemImage: "bag") }
            NavigationStack { BakingWorkspaceView() }.tabItem { Label("Bake", systemImage: "oven") }
            NavigationStack { CustomersView() }.tabItem { Label("Customers", systemImage: "person.2") }
            NavigationStack { MoreView() }.tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .preferredColorScheme(store.state.settings.background == "midnightBakery" ? .dark : nil)
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshDay() } }
        .task { store.refreshDay() }
        .alert("Please check", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK", role: .cancel) { store.error = nil } } message: { Text(store.error ?? "") }
    }
}
struct TodayView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var newOrder = false
    private var orders: [Order] { store.state.orders.filter { $0.date == store.state.day && $0.reserves }.sorted { $0.time < $1.time } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BakeryHero(title: "Hello, \(store.state.settings.owner)!", subtitle: "A little planning. A lovely day of baking.")
                Text(prettyDay(store.state.day).uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                NavigationLink { BakeJournalView() } label: { BakeCard { HStack { Label("Baking journal", systemImage: "book.closed"); Spacer(); Text("\(store.state.bakeSessions.filter { !$0.complete }.count) active").foregroundStyle(.secondary); Image(systemName: "chevron.right") } } }.buttonStyle(.plain)
                BakeCard { HStack { Metric(title: "Orders", value: "\(orders.count)"); Metric(title: "To bake", value: "\(orders.filter { $0.status == "Confirmed" || $0.status == "In production" }.count)"); Metric(title: "Ready", value: "\(orders.filter { $0.status == "Ready for pickup" }.count)") } }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Collected on today’s orders", systemImage: "chart.line.uptrend.xyaxis").font(.subheadline)
                    Text(money(orders.reduce(0) { $0 + $1.paid })).font(.system(size: 38, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("Payments recorded").font(.caption).opacity(0.8)
                }.padding(22).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).background(Color.bakeDeep, in: RoundedRectangle(cornerRadius: 24))
                HStack { Text("Coming up").font(.title2.bold()); Spacer(); NavigationLink("View all") { OrdersView() }.font(.subheadline.weight(.semibold)) }
                BakeCard {
                    VStack(spacing: 0) {
                        if orders.isEmpty { Text("No pickups scheduled for today.").foregroundStyle(.secondary) }
                        ForEach(Array(orders.prefix(4).enumerated()), id: \.element.id) { index, order in
                            NavigationLink { OrderDetailView(id: order.id) } label: { OrderRow(order: order) }.buttonStyle(.plain)
                            if index < min(orders.count, 4) - 1 { Divider().padding(.vertical, 14) }
                        }
                    }
                }
                HStack {
                    NavigationLink { ProductionView() } label: { Label("Today’s bake", systemImage: "oven").frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.borderedProminent)
                    Button { newOrder = true } label: { Label("New order", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.bordered)
                }
                NavigationLink { RecurringView() } label: { BakeCard { HStack { Image(systemName: "repeat").font(.title2); VStack(alignment: .leading, spacing: 4) { Text("Your regulars").font(.headline); Text("Manage recurring pickups").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right") } } }.buttonStyle(.plain)
            }.padding(20)
        }.bakeryBackground().navigationTitle("Today")
        .sheet(isPresented: $newOrder) { OrderEditor() }
    }
}
struct OrderRow: View {
    @EnvironmentObject private var store: BakeryStore
    var order: Order
    var body: some View {
        HStack(spacing: 12) {
            if let p = order.lines.first.flatMap({ store.state.product($0.product) }) { ProductPhoto(product: p) }
            VStack(alignment: .leading, spacing: 5) {
                Text(store.state.customer(order.customer)?.name ?? "Customer").font(.headline)
                Text(order.lines.map { "\($0.qty) × \(store.state.product($0.product)?.name ?? "Item")" }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text("#RB-\(order.id) · \(order.time)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) { Text(money(order.total)).font(.subheadline.bold()); StatusBadge(status: order.status) }
        }.padding(.vertical, 3).accessibilityElement(children: .combine)
    }
}
struct MoreView: View {
    @EnvironmentObject private var store: BakeryStore
    var body: some View {
        List {
            Section { HStack(spacing: 14) { BakeryLogoView(data: store.state.settings.profile?.logoData, size: 60); VStack(alignment: .leading, spacing: 4) { Text("RiseBake").font(.title2.bold()); Text(store.state.settings.bakery).foregroundStyle(.secondary) } }.padding(.vertical, 8) }
            Section("Your bakery") {
                NavigationLink { BakeryProfileView(settings: store.state.settings) } label: { Label("Bakery profile & logo", systemImage: "building.2.crop.circle") }.accessibilityIdentifier("bakery.profile")
                NavigationLink { RecipeBookView() } label: { Label("Recipe book", systemImage: "book.closed") }
                NavigationLink { AppearanceView() } label: { Label("Backgrounds", systemImage: "paintpalette") }
                NavigationLink { RecurringView() } label: { Label("Recurring orders", systemImage: "repeat") }
                NavigationLink { ProductsView() } label: { Label("Products & pricing", systemImage: "birthday.cake") }
                NavigationLink { StorefrontView() } label: { Label("Menu", systemImage: "storefront") }
                NavigationLink { InsightsView() } label: { Label("Insights", systemImage: "chart.bar") }
            }
            Section { NavigationLink { SettingsView() } label: { Label("Settings & backups", systemImage: "gearshape") } }
        }.bakeryBackground().navigationTitle("More")
    }
}
