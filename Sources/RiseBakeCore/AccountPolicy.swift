import Foundation

/// UI access decision made only after Auth has refreshed the session and fetched the user.
/// Server APIs must independently validate JWTs and enforce AAL2 for enrolled users.
enum AccountAccess: Equatable { case confirmEmail, secondFactor, allowed }
enum AccountPolicy {
    static func access(emailConfirmed: Bool, hasVerifiedFactor: Bool, assurance: String?) -> AccountAccess {
        guard emailConfirmed else { return .confirmEmail }
        guard assurance == "aal1" || assurance == "aal2" else { return .secondFactor }
        if hasVerifiedFactor && assurance != "aal2" { return .secondFactor }
        return .allowed
    }
    static func validEmail(_ value: String) -> Bool {
        value.count <= 254 && value.range(of: #"\A[^\s@]+@[^\s@]+\.[^\s@]+\z"#, options: .regularExpression) != nil
    }
    static func validCode(_ value: String) -> Bool {
        value.count == 6 && value.utf8.allSatisfy { (48...57).contains($0) }
    }
    static func validateNewPassword(_ password: String, confirmation: String) throws {
        try require(password.count >= 12 && password.utf8.count <= 128, "Use a password with 12–128 characters.")
        try require(password == confirmation, "The passwords don’t match.")
    }
    static func folder(root: URL, accountID: UUID?) -> URL {
        guard let accountID else { return root }
        return root.appendingPathComponent("accounts", isDirectory: true).appendingPathComponent(accountID.uuidString.lowercased(), isDirectory: true)
    }
    static func cleanBakery(from catalog: BakeryState) -> BakeryState {
        var result = catalog
        result.customers = []; result.orders = []; result.recurring = []
        result.tasks = [:]; result.cart = [:]; result.bakeSessions = []; result.nextOrder = 1
        result.settings.bakery = "My bakery"; result.settings.owner = "Baker"; result.settings.profile = nil
        return result
    }
}

struct AccountConfiguration: Codable {
    var enabled: Bool
    var projectURL: String
    var publishableKey: String
    var googleEnabled: Bool
    var appleEnabled: Bool
    var privacyURL: String
    var termsURL: String
    static let callback = URL(string: "riseandbake://auth/callback")!
    var url: URL? { URL(string: projectURL) }
    func validate() throws {
        guard enabled else { return }
        let components = URLComponents(string: projectURL)
        try require(components?.scheme == "https" && components?.host?.hasSuffix(".supabase.co") == true && components?.user == nil && components?.password == nil && components?.query == nil && components?.fragment == nil && ["", "/"].contains(components?.path ?? "invalid"), "Enter the HTTPS URL of your Supabase project.")
        // Publishable keys are public configuration. Never accept service-role JWTs or secret keys.
        try require(publishableKey.hasPrefix("sb_publishable_") && publishableKey.count > 25, "Use a Supabase publishable key, never a secret or service-role key.")
        for value in [privacyURL, termsURL] {
            let u = URLComponents(string: value)
            try require(u?.scheme == "https" && u?.host != nil && u?.user == nil && u?.password == nil, "Provide HTTPS privacy and terms pages.")
        }
    }
}
