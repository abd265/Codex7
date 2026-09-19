import SwiftUI
import Auth
import AuthenticationServices
import CryptoKit
import Security
import UserNotifications

enum AccountRoute: Equatable {
    case local, welcome, checking, emailCode(String), recoveryCode(String), secondFactor, newPassword, account(UUID)
}

@MainActor final class AccountStore: ObservableObject {
    @Published var route: AccountRoute = .checking
    @Published var busy = false
    @Published var error: String?
    @Published var notice: String?
    @Published private(set) var user: User?
    @Published private(set) var factors: [Factor] = []
    @Published private(set) var enrollment: AuthMFAEnrollResponse?
    let configuration: AccountConfiguration?
    @Published var welcomeCreatesAccount = false
    private let client: AuthClient?
    private var listener: Task<Void, Never>?
    private var recovering = false
    private var appleNonce: String?
    private var googleAccessToken: String?
    var enabled: Bool { client != nil }
    var appleAvailable: Bool { enabled && configuration?.appleEnabled == true }
    var googleAvailable: Bool { enabled && configuration?.googleEnabled == true }
    private static let localPreference = "risebake.continueLocally"
    var authenticated: Bool { if case .account = route { return true }; return false }

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-welcome") {
            UserDefaults.standard.set(false, forKey: Self.localPreference)
        }
        if ProcessInfo.processInfo.arguments.contains("--receipt-fixture") || ProcessInfo.processInfo.arguments.contains("--costing-fixture") {
            UserDefaults.standard.set(true, forKey: Self.localPreference)
        }
        #endif
        let config = Bundle.main.url(forResource: "AuthConfig", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(AccountConfiguration.self, from: $0) }
        configuration = config
        if let config, config.enabled, (try? config.validate()) != nil, let url = config.url {
            client = AuthClient(configuration: .init(url: url.appendingPathComponent("auth/v1"), headers: ["apikey": config.publishableKey], flowType: .pkce, redirectToURL: AccountConfiguration.callback, storageKey: "risebake.\(url.host ?? "auth")", localStorage: AccountKeychain(), emitLocalSessionAsInitialSession: true))
        } else { client = nil }
        // Service availability must never hide the account screens. The local choice
        // only controls the next launch; it never changes or migrates bakery records.
        route = UserDefaults.standard.bool(forKey: Self.localPreference) ? .local : .welcome
        if let client {
            listener = Task { [weak self] in
                for await (event, _) in client.authStateChanges {
                    guard let self else { return }
                    if event == .signedOut || event == .userDeleted {
                        if client.currentSession == nil { self.clearSessionUI() }
                    } else if event == .tokenRefreshed && self.authenticated && !self.busy {
                        await self.run { try await self.reconcile() }
                    }
                }
            }
            Task { await restoreSession() }
        }
    }
    deinit { listener?.cancel() }
    private func service() throws -> AuthClient {
        guard let client else { throw AccountError.message("Accounts aren’t available yet. Continue on this iPhone to use your bakery.") }
        return client
    }
    func run(_ action: () async throws -> Void) async {
        guard !busy else { return }
        busy = true; error = nil; notice = nil
        defer { busy = false }
        do { try await action() }
        catch is CancellationError { }
        catch let failure as ASWebAuthenticationSessionError where failure.code == .canceledLogin { }
        catch { self.error = safeMessage(error) }
    }
    private func safeMessage(_ error: Error) -> String {
        if let value = error as? AccountError { return value.localizedDescription }
        if error is URLError { return "Couldn’t connect. Check your internet connection and try again." }
        // Do not echo provider payloads, tokens or account-existence details into the UI.
        return "That didn’t work. Check your details or code and try again. If you’ve made several attempts, wait a moment first."
    }
    func restoreSession() async {
        guard let client, client.currentSession != nil else { return }
        await run { try await reconcile() }
    }
    private func reconcile() async throws {
        let client = try service()
        if !authenticated { route = .checking }
        do {
            let session = try await client.session
            let verified = try await client.user(jwt: session.accessToken)
            guard verified.id == session.user.id else { throw AccountError.message("Please sign in again.") }
            let serverFactors = verified.factors ?? []
            let verifiedTOTP = serverFactors.filter { $0.status == .verified && $0.factorType == "totp" }
            let assurance = try await client.mfa.getAuthenticatorAssuranceLevel()
            user = verified; factors = verifiedTOTP
            let decision = AccountPolicy.access(emailConfirmed: verified.emailConfirmedAt != nil, hasVerifiedFactor: serverFactors.contains { $0.status == .verified }, assurance: assurance.currentLevel)
            switch decision {
            case .confirmEmail: route = .emailCode(verified.email ?? "")
            case .secondFactor:
                guard !verifiedTOTP.isEmpty else { throw AccountError.message("This account needs an authentication method that isn’t available here. Contact support to recover access.") }
                route = .secondFactor
            case .allowed: route = recovering ? .newPassword : .account(verified.id)
            }
        } catch { route = .welcome; throw error }
    }
    func signIn(email: String, password: String, create: Bool) async {
        await run {
            let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard AccountPolicy.validEmail(email) else { throw AccountError.message("Enter a valid email address.") }
            let client = try service(); recovering = false
            if create {
                let result = try await client.signUp(email: email, password: password)
                if result.session == nil { route = .emailCode(email); return }
            } else { _ = try await client.signIn(email: email, password: password) }
            try await reconcile()
        }
    }
    func google() async {
        await run {
            let client = try service()
            guard configuration?.googleEnabled == true else { throw AccountError.message("Google sign-in is not enabled yet.") }
            recovering = false
            let session = try await client.signInWithOAuth(provider: .google, redirectTo: AccountConfiguration.callback) { $0.prefersEphemeralWebBrowserSession = true }
            googleAccessToken = session.providerToken
            try await reconcile()
        }
    }
    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        appleNonce = nil
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { error = "Couldn’t start secure sign-in. Please try again."; return }
        let nonce = bytes.map { String(format: "%02x", $0) }.joined()
        appleNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func apple(_ result: Result<ASAuthorization, Error>, deleting: Bool = false) async {
        if case .failure(let failure) = result, (failure as? ASAuthorizationError)?.code == .canceled { appleNonce = nil; return }
        await run {
            defer { appleNonce = nil }
            let client = try service()
            guard configuration?.appleEnabled == true else { throw AccountError.message("Apple sign-in is not enabled yet.") }
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential, let nonce = appleNonce, let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else { throw AccountError.message("Apple could not complete sign-in. Please try again.") }
            if deleting {
                guard let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else { throw AccountError.message("Please authorize Apple again to delete your account.") }
                try await deleteAccountRequest(appleCode: code)
            } else {
                recovering = false
                _ = try await client.signInWithIdToken(credentials: .init(provider: .apple, idToken: token, nonce: nonce))
                try await reconcile()
            }
        }
    }
    func requestReset(email: String) async {
        await run {
            let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard AccountPolicy.validEmail(email) else { throw AccountError.message("Enter your email address first.") }
            try await service().resetPasswordForEmail(email)
            route = .recoveryCode(email)
        }
    }
    func resendCode(email: String, recovery: Bool) async {
        await run {
            if recovery { try await service().resetPasswordForEmail(email) }
            else { try await service().resend(email: email, type: .signup) }
            notice = "If a message can be sent, a new code will arrive shortly."
        }
    }
    func emailCode(email: String, code: String, recovery: Bool) async {
        await run {
            guard AccountPolicy.validCode(code) else { throw AccountError.message("Enter the six-digit code from your email.") }
            recovering = recovery
            _ = try await service().verifyOTP(email: email, token: code, type: recovery ? .recovery : .signup)
            try await reconcile()
        }
    }
    func newPassword(_ password: String, confirmation: String) async {
        await run {
            try AccountPolicy.validateNewPassword(password, confirmation: confirmation)
            _ = try await service().update(user: .init(password: password))
            recovering = false; try await reconcile()
        }
    }
    func verifyFactor(id: String, code: String) async {
        await run {
            guard AccountPolicy.validCode(code) else { throw AccountError.message("Enter the six-digit code from your authenticator.") }
            _ = try await service().mfa.challengeAndVerify(params: .init(factorId: id, code: code))
            enrollment = nil; try await reconcile()
        }
    }
    func enroll() async {
        await run {
            guard authenticated else { throw AccountError.message("Please finish signing in first.") }
            enrollment = try await service().mfa.enroll(params: .totp(issuer: "Rise & Bake", friendlyName: "Authenticator \(factors.count + 1)"))
        }
    }
    func cancelEnrollment() async {
        await run {
            guard let pending = enrollment else { return }
            _ = try await service().mfa.unenroll(params: .init(factorId: pending.id))
            enrollment = nil
        }
    }
    func removeFactor(id: String, code: String) async {
        await run {
            guard authenticated, AccountPolicy.validCode(code) else { throw AccountError.message("Enter a current authenticator code to remove this method.") }
            let client = try service()
            _ = try await client.mfa.challengeAndVerify(params: .init(factorId: id, code: code))
            _ = try await client.mfa.unenroll(params: .init(factorId: id))
            try await reconcile()
        }
    }
    func signOut() async {
        await run {
            // Clear access even if the network is unavailable. SDK local sign-out removes the local session.
            try await service().signOut(scope: .local)
            clearSessionUI()
        }
    }
    private func clearSessionUI() {
        let wasLocal = route == .local
        user = nil; factors = []; enrollment = nil; recovering = false; googleAccessToken = nil
        BakeNotifications.shared.sync([])
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        route = wasLocal ? .local : .welcome
    }
    func continueLocally() async {
        if client?.currentSession != nil { await signOut(); if error != nil { return } }
        UserDefaults.standard.set(true, forKey: Self.localPreference)
        user = nil; enrollment = nil; route = .local
    }
    func showWelcome(create: Bool = false) {
        welcomeCreatesAccount = create
        error = nil; notice = nil
        route = .welcome
    }
    func deleteAccount() async { await run { try await deleteAccountRequest(appleCode: nil) } }
    private func deleteAccountRequest(appleCode: String?) async throws {
        guard authenticated, let user, let config = configuration, let base = config.url else { throw AccountError.message("Sign in again before deleting your account.") }
        let session = try await service().session
        var request = URLRequest(url: base.appendingPathComponent("functions/v1/delete-account"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["appleAuthorizationCode": appleCode ?? "", "googleAccessToken": googleAccessToken ?? ""])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 204 else { throw AccountError.message("Your account was not deleted. Sign out and sign in again, complete two-factor verification, then retry.") }
        let deletedID = user.id
        try? await service().signOut(scope: .local)
        clearSessionUI()
        do { try BakeryStore.deleteWorkspace(accountID: deletedID) }
        catch { throw AccountError.message("Your online account was deleted, but its local records could not be removed. Contact support before using this installation on a shared device.") }
    }
}

enum AccountError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
