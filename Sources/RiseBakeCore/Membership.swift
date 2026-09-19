import Foundation

enum MembershipPlan: String, CaseIterable, Identifiable, Codable {
    case monthly, annual, offline
    var id: String { rawValue }
    var title: String {
        switch self { case .monthly: return "Pro monthly"; case .annual: return "Pro annual"; case .offline: return "Offline edition" }
    }
    var proposedPrice: String {
        switch self { case .monthly: return "C$9.99"; case .annual: return "C$79.99"; case .offline: return "C$49.99" }
    }
    var interval: String {
        switch self { case .monthly: return "per month"; case .annual: return "per year"; case .offline: return "one-time purchase" }
    }
}

struct MembershipConfiguration: Codable {
    var enabled: Bool
    var monthlyProductID: String
    var annualProductID: String
    var offlineProductID: String
    var privacyURL: String
    var termsURL: String
    func productID(for plan: MembershipPlan) -> String {
        switch plan { case .monthly: return monthlyProductID; case .annual: return annualProductID; case .offline: return offlineProductID }
    }
    func plan(for productID: String) -> MembershipPlan? { MembershipPlan.allCases.first { self.productID(for: $0) == productID } }
    func validate() throws {
        guard enabled else { return }
        let ids = MembershipPlan.allCases.map { productID(for: $0) }
        try require(Set(ids).count == 3 && ids.allSatisfy { !$0.isEmpty && $0.count <= 255 && !$0.contains(where: { $0.isWhitespace }) }, "Provide three unique App Store product identifiers.")
        for value in [privacyURL, termsURL] {
            let url = URLComponents(string: value)
            try require(url?.scheme == "https" && url?.host?.isEmpty == false && url?.user == nil && url?.password == nil, "Provide published HTTPS privacy and terms pages before enabling purchases.")
        }
    }
}

/// Constructed only from a cryptographically verified StoreKit transaction.
/// Never restored from the app's editable bakery JSON or from a selected plan.
struct MembershipEntitlement: Equatable {
    var plan: MembershipPlan
    var expiration: Date?
    var revoked: Bool
    var upgraded: Bool
    func isActive(at date: Date) -> Bool {
        guard !revoked && !upgraded else { return false }
        if plan == .offline { return expiration == nil }
        guard let expiration else { return false }
        return expiration > date
    }
}
