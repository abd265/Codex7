import Foundation

/// Local intent is kept separately from untrusted URL parameters. The SDK's
/// device-only PKCE verifier and the Auth server still verify every code.
struct PendingAccountEmail: Codable, Equatable {
    enum Purpose: String, Codable { case signup, recovery }
    let email: String
    let purpose: Purpose
    let requestedAt: Date

    func isCurrent(at now: Date) -> Bool {
        let age = now.timeIntervalSince(requestedAt)
        return AccountPolicy.validEmail(email) && age >= -30 && age <= 3600
    }
}

enum AccountEmailLink {
    static func isCallback(_ url: URL) -> Bool {
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return value.scheme == "riseandbake" && value.host == "auth" && value.path == "/callback"
            && value.user == nil && value.password == nil && value.port == nil
    }

    static func authorizationCode(from url: URL) -> String? {
        guard isCallback(url), url.absoluteString.utf8.count <= 4096,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false),
              value.fragment == nil, let items = value.queryItems, items.count == 1,
              items[0].name == "code", let code = items[0].value,
              !code.isEmpty, code.utf8.count <= 512,
              code.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else { return nil }
        return code
    }
}
