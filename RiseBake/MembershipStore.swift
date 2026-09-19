import SwiftUI
import StoreKit

@MainActor final class MembershipStore: ObservableObject {
    @Published private(set) var products: [String: StoreKit.Product] = [:]
    @Published private(set) var entitlements: [MembershipEntitlement] = []
    @Published private(set) var busy = false
    @Published private(set) var loaded = false
    @Published var message: String?
    let configuration: MembershipConfiguration?
    let enabled: Bool
    private var listener: Task<Void, Never>?

    var active: [MembershipEntitlement] { entitlements.filter { $0.isActive(at: Date()) } }
    init() {
        let config = Bundle.main.url(forResource: "MembershipConfig", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(MembershipConfiguration.self, from: $0) }
        configuration = config
        #if DEBUG
        let testing = ProcessInfo.processInfo.arguments.contains("--storekit-test")
        #else
        let testing = false
        #endif
        enabled = config != nil && (testing || (config?.enabled == true && (try? config?.validate()) != nil))
        if enabled {
            listener = Task { [weak self] in
                for await result in StoreKit.Transaction.updates {
                    guard let self else { return }
                    guard case .verified(let transaction) = result, self.configuration?.plan(for: transaction.productID) != nil else { continue }
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
    }
    deinit { listener?.cancel() }
    func product(for plan: MembershipPlan) -> StoreKit.Product? {
        guard let id = configuration?.productID(for: plan) else { return nil }
        return products[id]
    }
    func load() async {
        guard enabled, let configuration, !busy else { return }
        busy = true
        defer { busy = false; loaded = true }
        do {
            let values = try await StoreKit.Product.products(for: MembershipPlan.allCases.map { configuration.productID(for: $0) })
            products = Dictionary(uniqueKeysWithValues: values.filter { product in
                guard let plan = configuration.plan(for: product.id) else { return false }
                switch plan {
                case .offline: return product.type == .nonConsumable
                case .monthly: return product.type == .autoRenewable && product.subscription?.subscriptionPeriod.value == 1 && product.subscription?.subscriptionPeriod.unit == .month
                case .annual: return product.type == .autoRenewable && product.subscription?.subscriptionPeriod.value == 1 && product.subscription?.subscriptionPeriod.unit == .year
                }
            }.map { ($0.id, $0) })
            await refreshEntitlements()
        } catch { message = "Couldn’t load App Store prices. Please try again." }
    }
    func refreshEntitlements() async {
        guard enabled, let configuration else { return }
        var current: [MembershipEntitlement] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, let plan = configuration.plan(for: transaction.productID) else { continue }
            // A mismatched product type can never grant a permanent entitlement.
            guard (plan == .offline && transaction.productType == .nonConsumable) || (plan != .offline && transaction.productType == .autoRenewable) else { continue }
            let item = MembershipEntitlement(plan: plan, expiration: transaction.expirationDate, revoked: transaction.revocationDate != nil, upgraded: transaction.isUpgraded)
            if item.isActive(at: Date()) { current.append(item) }
        }
        entitlements = current
    }
    func purchase(_ plan: MembershipPlan) async {
        guard !busy else { return }
        guard enabled, let product = product(for: plan) else { message = "Purchases aren’t available in this installation. You haven’t been charged."; return }
        // Serialize the entire attempt, including the asynchronous entitlement check.
        busy = true; message = nil
        defer { busy = false }
        await refreshEntitlements()
        guard active.isEmpty else { message = "You already have an active purchase. Manage a subscription through the App Store."; return }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result, transaction.productID == product.id else {
                    message = "Apple returned a purchase that couldn’t be verified. Try Restore purchases before purchasing again."; return
                }
                await refreshEntitlements()
                await transaction.finish()
                message = active.contains(where: { $0.plan == plan }) ? "Your purchase is active. Thank you for supporting Rise & Bake." : "Your purchase is being checked. Try Restore purchases shortly."
            case .pending: message = "Your purchase is awaiting approval. It will appear here after Apple confirms it."
            case .userCancelled: break
            @unknown default: message = "Your purchase hasn’t been confirmed. Check your App Store account before trying again."
            }
        } catch { message = "The purchase couldn’t be completed. You can check your App Store purchase history or try Restore purchases." }
    }
    func restore() async {
        guard !busy else { return }
        guard enabled else { message = "App Store purchases aren’t available in this installation. Your existing bakery remains available."; return }
        busy = true; message = nil
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = active.isEmpty ? "No active Rise & Bake purchases were found for this App Store account." : "Your purchases have been restored."
        } catch { message = "Couldn’t restore purchases. Check your App Store account and try again." }
    }
}
