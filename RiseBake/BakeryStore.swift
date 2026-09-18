import SwiftUI
import UniformTypeIdentifiers

@MainActor final class BakeryStore: ObservableObject {
    @Published private(set) var state: BakeryState
    @Published var error: String?
    private let fileURL: URL
    private let accountID: UUID?
    static var rootFolder: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("RiseBake", isDirectory: true) }
    static func deleteWorkspace(accountID: UUID) throws {
        let folder = AccountPolicy.folder(root: rootFolder, accountID: accountID)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }
    init(accountID: UUID? = nil) {
        self.accountID = accountID
        let folder = AccountPolicy.folder(root: Self.rootFolder, accountID: accountID)
        fileURL = folder.appendingPathComponent("bakery.json")
        let seedURL = Bundle.main.url(forResource: "seed", withExtension: "json")!
        let catalog = try! JSONDecoder().decode(BakeryState.self, from: Data(contentsOf: seedURL))
        let seed = accountID == nil ? catalog : AccountPolicy.cleanBakery(from: catalog)
        state = seed
        do {
            try seed.validate()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            #if DEBUG
            if accountID == nil && ProcessInfo.processInfo.arguments.contains("--receipt-fixture") {
                var fixture = seed
                try ReceiptQA.prepare(&fixture)
                try JSONEncoder().encode(fixture).write(to: fileURL, options: [.atomic, .completeFileProtection])
            }
            if accountID == nil && ProcessInfo.processInfo.arguments.contains("--costing-fixture") {
                var fixture = seed
                try CostingQA.prepare(&fixture)
                try JSONEncoder().encode(fixture).write(to: fileURL, options: [.atomic, .completeFileProtection])
            }
            #endif
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let saved = try JSONDecoder().decode(BakeryState.self, from: Data(contentsOf: fileURL))
                    try saved.validate(); state = saved
                } catch {
                    let backup = folder.appendingPathComponent("recovery-\(UUID().uuidString).json")
                    try FileManager.default.copyItem(at: fileURL, to: backup)
                    self.error = "Saved data could not be opened. A recovery copy was preserved in Rise & Bake’s files."
                }
            }
            try state.upgrade(using: seed, today: Clock.today)
            try JSONEncoder().encode(state).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch { self.error = "Storage could not be opened: \(error.localizedDescription)" }
    }
    @discardableResult func perform(_ action: (inout BakeryState) throws -> Void) -> Bool {
        do {
            var next = state
            next.version = 3
            next.day = Clock.today
            try action(&next)
            next.day = Clock.today
            try next.validate()
            let data = try JSONEncoder().encode(next)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            state = next
            BakeNotifications.shared.sync(next.bakeSessions)
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func restore(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try require(data.count < 10_000_000, "Backup is too large.")
            var next = try JSONDecoder().decode(BakeryState.self, from: data)
            let catalog = try JSONDecoder().decode(BakeryState.self, from: Data(contentsOf: Bundle.main.url(forResource: "seed", withExtension: "json")!))
            try next.upgrade(using: catalog, today: Clock.today)
            perform { $0 = next }
        } catch { self.error = error.localizedDescription }
    }
    func reset() {
        do {
            let next = try JSONDecoder().decode(BakeryState.self, from: Data(contentsOf: Bundle.main.url(forResource: "seed", withExtension: "json")!))
            perform { $0 = accountID == nil ? next : AccountPolicy.cleanBakery(from: next) }
        } catch { self.error = error.localizedDescription }
    }
    func refreshDay() {
        if state.day != Clock.today { perform { $0.day = Clock.today } }
        BakeNotifications.shared.sync(state.bakeSessions)
    }
}
struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data
    init(_ text: String) { data = Data(text.utf8) }
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

extension Color {
    static let bakeTeal = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.30, green: 0.80, blue: 0.68, alpha: 1) : UIColor(red: 0.025, green: 0.50, blue: 0.45, alpha: 1) })
    static let bakeDeep = Color(red: 0.028, green: 0.37, blue: 0.34)
    static let bakeTint = Color(red: 0.905, green: 0.957, blue: 0.934)
}
struct BakeCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)) }
}
struct ProductPhoto: View {
    var product: Product
    var size: CGFloat = 58
    var body: some View { Image("bake\(product.image)").resizable().scaledToFill().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true) }
}
struct StatusBadge: View {
    var status: String
    var color: Color { status == "Cancelled" ? .red : ["Awaiting deposit", "Quote requested"].contains(status) ? .orange : .bakeTeal }
    var body: some View { Text(status).font(.caption.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 9).padding(.vertical, 5).background(color.opacity(0.1), in: Capsule()) }
}
struct Metric: View {
    var title: String
    var value: String
    var body: some View { VStack(alignment: .leading, spacing: 6) { Text(value).font(.title2.bold()).monospacedDigit(); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct EmptyList: View {
    var title: String
    var symbol: String
    var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text("Try another search or add a new record.")) }
}
func prettyDay(_ day: String) -> String { Clock.formatter("EEE, MMM d").string(from: Clock.date(day)) }
struct PickupFields: View {
    @Binding var date: String
    @Binding var time: String
    var earliest: String
    var body: some View {
        DatePicker("Pickup date", selection: Binding(get: { Clock.date(date) }, set: { date = Clock.day($0) }), in: Clock.date(earliest)..., displayedComponents: .date).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        DatePicker("Pickup time", selection: Binding(get: { Clock.formatter("HH:mm").date(from: time) ?? Date() }, set: { time = Clock.formatter("HH:mm").string(from: $0) }), displayedComponents: .hourAndMinute).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
    }
}
