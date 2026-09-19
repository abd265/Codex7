import SwiftUI
import AuthenticationServices
import CoreImage.CIFilterBuiltins

struct AccountRouter: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            switch account.route {
            case .local: AccountWorkspace(id: nil).id("local")
            case .account(let id): AccountWorkspace(id: id).id(id)
            case .checking: ProgressView("Opening your bakery…").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(uiColor: .systemGroupedBackground))
            case .welcome: AccountWelcomeView(create: account.welcomeCreatesAccount)
            case .emailCode(let email): AccountEmailCodeView(email: email, recovery: false)
            case .recoveryCode(let email): AccountEmailCodeView(email: email, recovery: true)
            case .secondFactor: AccountChallengeView()
            case .newPassword: AccountPasswordView()
            }
            if scenePhase != .active && account.route != .local {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                VStack(spacing: 12) { Image(systemName: "lock.shield").font(.largeTitle); Text("Rise & Bake").font(.title2.bold()) }.foregroundStyle(Color.bakeDeep)
            }
        }.tint(.bakeTeal)
        .alert("Please check", isPresented: Binding(get: { account.error != nil }, set: { if !$0 { account.error = nil } })) { Button("OK", role: .cancel) { account.error = nil } } message: { Text(account.error ?? "") }
    }
}
struct AccountWorkspace: View {
    @StateObject private var store: BakeryStore
    init(id: UUID?) { _store = StateObject(wrappedValue: BakeryStore(accountID: id)) }
    var body: some View { RootView().environmentObject(store) }
}

struct AccountCanvas<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Image(systemName: "birthday.cake.fill").font(.system(size: 32)).foregroundStyle(Color.bakeDeep).frame(width: 72, height: 72).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    Text("Rise & Bake").font(.system(size: 35, weight: .bold, design: .serif)).foregroundStyle(Color.bakeDeep)
                    Text("A little planning. A lovely day of baking.").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
                }.padding(.top, 30)
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(.title2, design: .rounded).bold()); Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    content
                }.padding(24).background(Color(uiColor: .systemBackground).opacity(0.97), in: RoundedRectangle(cornerRadius: 28)).overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.bakeDeep.opacity(0.08)))
                Text("Made for the way you bake.").font(.footnote).foregroundStyle(.secondary).padding(.bottom, 20)
            }.frame(maxWidth: 440).padding(22).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively)
        .background { GeometryReader { proxy in Image("flourGarden").resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped().overlay(Color(uiColor: .systemBackground).opacity(0.35)) }.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }
}
struct AccountPrimaryButton: View {
    var title: String
    var busy: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) { HStack { Spacer(); if busy { ProgressView().tint(.white) }; Text(title).fontWeight(.semibold); Spacer() }.padding(.vertical, 11) }.buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 14)).disabled(busy)
    }
}
struct AccountField: View {
    var title: String
    @Binding var text: String
    var secure = false
    var creating = false
    var identifier: String
    @State private var reveal = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium))
            HStack {
                Group {
                    if secure && !reveal { SecureField(title, text: $text).textContentType(creating ? .newPassword : .password) }
                    else { TextField(title, text: $text).textContentType(secure ? (creating ? .newPassword : .password) : .emailAddress).keyboardType(secure ? .default : .emailAddress) }
                }.textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier(identifier)
                if secure { Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye") }.accessibilityLabel(reveal ? "Hide password" : "Show password") }
            }.padding(14).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
struct AccountWelcomeView: View {
    @EnvironmentObject private var account: AccountStore
    @State var create = false
    @State private var showPlans = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    var body: some View {
        AccountCanvas(title: create ? "Your next chapter starts here" : "Welcome to your bakery", subtitle: create ? "Create an account for your baking business." : "Sign in and make room for something lovely.") {
            Button { showPlans = true } label: {
                HStack { Label("Plans & pricing", systemImage: "sparkles"); Spacer(); Image(systemName: "chevron.right") }.font(.subheadline.weight(.semibold))
            }.accessibilityIdentifier("auth.plans")
            if !account.enabled {
                Label("Accounts are coming soon. Your bakery is available on this iPhone without signing in.", systemImage: "person.crop.circle.badge.clock")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("auth.availability")
            }
            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn, onRequest: account.prepareApple) { result in Task { await account.apple(result) } }.signInWithAppleButtonStyle(.black).frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("auth.apple").disabled(!account.appleAvailable)
                Button { Task { await account.google() } } label: { Text("Continue with Google").font(.system(size: 17, weight: .medium)).foregroundStyle(.primary).frame(maxWidth: .infinity).frame(height: 50).background(.white, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.5))) }.accessibilityIdentifier("auth.google").disabled(!account.googleAvailable)
                if account.enabled && (!account.appleAvailable || !account.googleAvailable) {
                    Text("Some sign-in options aren’t available yet. You can use email below.").font(.caption).foregroundStyle(.secondary)
                }
            }.disabled(account.busy)
            HStack { Rectangle().frame(height: 1); Text("or use email").font(.caption).fixedSize(); Rectangle().frame(height: 1) }.foregroundStyle(.secondary.opacity(0.6))
            VStack(spacing: 14) {
                AccountField(title: "Email address", text: $email, identifier: "auth.email")
                AccountField(title: "Password", text: $password, secure: true, creating: create, identifier: "auth.password")
                if create {
                    AccountField(title: "Confirm password", text: $confirmation, secure: true, creating: true, identifier: "auth.confirm")
                    Text("Use at least 12 characters. A few memorable words work well.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Forgot password?") { Task { await account.requestReset(email: email) } }.font(.subheadline).frame(maxWidth: .infinity, alignment: .trailing).accessibilityIdentifier("auth.forgot")
                }
            }.disabled(account.busy)
            AccountPrimaryButton(title: create ? "Create my account" : "Sign in", busy: account.busy) {
                if !AccountPolicy.validEmail(email.trimmingCharacters(in: .whitespacesAndNewlines)) { account.error = "Enter a valid email address."; return }
                if create { do { try AccountPolicy.validateNewPassword(password, confirmation: confirmation) } catch { account.error = error.localizedDescription; return } }
                guard !password.isEmpty else { account.error = "Enter your password."; return }
                Task { await account.signIn(email: email, password: password, create: create); password = ""; confirmation = "" }
            }.accessibilityIdentifier("auth.submit")
            HStack { Text(create ? "Already baking with us?" : "New here?").foregroundStyle(.secondary); Button(create ? "Sign in" : "Create an account") { create.toggle(); password = ""; confirmation = "" }.fontWeight(.semibold).accessibilityIdentifier("auth.switch").disabled(account.busy) }.font(.subheadline).frame(maxWidth: .infinity)
            Text("Account security includes optional two-factor authentication when accounts are available.").font(.caption).foregroundStyle(.secondary)
            if let config = account.configuration, config.enabled, let privacy = URL(string: config.privacyURL), let terms = URL(string: config.termsURL) {
                HStack { Link("Privacy", destination: privacy); Text("·"); Link("Terms", destination: terms) }.font(.caption).frame(maxWidth: .infinity)
            }
            Button("Continue on this iPhone") { Task { await account.continueLocally() } }.font(.subheadline).frame(maxWidth: .infinity).disabled(account.busy).accessibilityIdentifier("auth.local")
        }.onDisappear { password = ""; confirmation = "" }
        .sheet(isPresented: $showPlans) { NavigationStack { MembershipPlansView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPlans = false }.accessibilityIdentifier("plans.done") } } } }
    }
}
struct AccountCodeField: View {
    @Binding var code: String
    var body: some View {
        TextField("Six-digit code", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode).font(.system(size: 28, weight: .medium, design: .monospaced)).multilineTextAlignment(.center).padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14)).onChange(of: code) { _, value in code = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6)) }.accessibilityIdentifier("auth.code")
    }
}
struct AccountEmailCodeView: View {
    @EnvironmentObject private var account: AccountStore
    var email: String
    var recovery: Bool
    @State private var code = ""
    var body: some View {
        AccountCanvas(title: "Check your inbox", subtitle: "If a message can be sent to \(email), it will contain a six-digit code. Check your spam folder too.") {
            AccountCodeField(code: $code)
            AccountPrimaryButton(title: recovery ? "Verify reset code" : "Verify email", busy: account.busy) { Task { await account.emailCode(email: email, code: code, recovery: recovery); code = "" } }.disabled(!AccountPolicy.validCode(code))
            Button("Send a new code") { Task { await account.resendCode(email: email, recovery: recovery) } }.disabled(account.busy)
            if let notice = account.notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
            Text("Email verification is separate from your authenticator’s two-factor code.").font(.footnote).foregroundStyle(.secondary)
            Button("Back to sign in") { Task { await account.continueLocally(); account.route = .welcome } }.disabled(account.busy)
        }
    }
}
struct AccountPasswordView: View {
    @EnvironmentObject private var account: AccountStore
    @State private var password = ""
    @State private var confirmation = ""
    var body: some View {
        AccountCanvas(title: "A fresh start", subtitle: "Choose a new password with at least 12 characters.") {
            AccountField(title: "New password", text: $password, secure: true, creating: true, identifier: "auth.newPassword")
            AccountField(title: "Confirm password", text: $confirmation, secure: true, creating: true, identifier: "auth.confirm")
            AccountPrimaryButton(title: "Save new password", busy: account.busy) { Task { await account.newPassword(password, confirmation: confirmation); password = ""; confirmation = "" } }
        }.onDisappear { password = ""; confirmation = "" }
    }
}
struct AccountChallengeView: View {
    @EnvironmentObject private var account: AccountStore
    @State private var code = ""
    @State private var factor = ""
    var body: some View {
        AccountCanvas(title: "One more step", subtitle: "Enter the current code from your authenticator app to open your bakery.") {
            Image(systemName: "lock.shield.fill").font(.system(size: 42)).foregroundStyle(Color.bakeTeal).frame(maxWidth: .infinity)
            if account.factors.count > 1 { Picker("Authenticator", selection: $factor) { ForEach(account.factors) { Text($0.friendlyName ?? "Authenticator").tag($0.id) } } }
            AccountCodeField(code: $code)
            AccountPrimaryButton(title: "Verify & continue", busy: account.busy) { Task { await account.verifyFactor(id: factor, code: code); code = "" } }.disabled(!AccountPolicy.validCode(code) || factor.isEmpty)
            Text("Lost your authenticator? Use your second enrolled authenticator. A password-reset email does not bypass this protection.").font(.footnote).foregroundStyle(.secondary)
            Button("Back to sign in") { Task { await account.signOut() } }.disabled(account.busy)
        }.onAppear { factor = account.factors.first?.id ?? "" }
    }
}

struct AccountSettingsView: View {
    @EnvironmentObject private var account: AccountStore
    @State private var showEnrollment = false
    @State private var removing: String?
    @State private var code = ""
    @State private var confirmDelete = false
    var body: some View {
        Form {
            Section { Label(account.user?.email ?? "Your account", systemImage: "person.crop.circle"); Text("Bakery records in this account are saved on this iPhone.").font(.footnote).foregroundStyle(.secondary) }
            Section { NavigationLink { MembershipPlansView() } label: { Label("Plans & pricing", systemImage: "sparkles") } }
            Section("Two-factor authentication") {
                Label(account.factors.isEmpty ? "Not enabled" : "Authenticator enabled", systemImage: account.factors.isEmpty ? "shield" : "checkmark.shield.fill")
                ForEach(account.factors) { factor in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(factor.friendlyName ?? "Authenticator"); Spacer(); Button("Remove", role: .destructive) { removing = factor.id; code = "" } }
                        if removing == factor.id { AccountCodeField(code: $code); Button("Verify and remove", role: .destructive) { Task { await account.removeFactor(id: factor.id, code: code); if account.error == nil { removing = nil }; code = "" } }.disabled(!AccountPolicy.validCode(code)) }
                    }
                }
                Button(account.factors.isEmpty ? "Set up authenticator" : "Add a backup authenticator") { Task { await account.enroll(); showEnrollment = account.enrollment != nil } }.accessibilityIdentifier("auth.enroll")
                Text("Keep a second authenticator on another trusted device. Never share your setup key or verification codes.").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("Sign out") { Task { await account.signOut() } }
                Button("Delete account…", role: .destructive) { confirmDelete = true }
            }
        }.navigationTitle("Account & security").disabled(account.busy)
        .sheet(isPresented: $showEnrollment) { AccountEnrollmentView().interactiveDismissDisabled() }
        .sheet(isPresented: $confirmDelete) { AccountDeleteView() }
    }
}
struct AccountEnrollmentView: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var reveal = false
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 20) {
                Text("Add an authenticator").font(.title2.bold())
                Text("Scan this code using an authenticator on another device, or enter the setup key in an authenticator on this iPhone.")
                if let enrollment = account.enrollment, let totp = enrollment.totp {
                    if let qr = qrImage(totp.uri) { Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().frame(width: 220, height: 220).padding(10).background(.white).frame(maxWidth: .infinity).accessibilityLabel("Authenticator setup QR code") }
                    Button(reveal ? "Hide setup key" : "Show setup key") { reveal.toggle() }
                    if reveal {
                        Text(totp.secret).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Button("Copy setup key") { UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: totp.secret]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)]) }
                    }
                    AccountCodeField(code: $code)
                    AccountPrimaryButton(title: "Verify & enable", busy: account.busy) { Task { await account.verifyFactor(id: enrollment.id, code: code); code = ""; if account.enrollment == nil { dismiss() } } }.disabled(!AccountPolicy.validCode(code))
                    Text("Two-factor authentication turns on after this code is verified.").font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(24) }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { Task { await account.cancelEnrollment(); if account.enrollment == nil { dismiss() } } }.disabled(account.busy) } }
        }
    }
    private func qrImage(_ uri: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(uri.utf8)
        guard let output = filter.outputImage, let image = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), from: output.extent.applying(CGAffineTransform(scaleX: 8, y: 8))) else { return nil }
        return UIImage(cgImage: image)
    }
}
struct AccountDeleteView: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    var body: some View {
        NavigationStack { Form {
            Section { Text("Permanently delete your account and its bakery records on this iPhone. Export any records you want to keep before continuing. This cannot be undone."); Text("Sign in again using Google if it is linked to your account, otherwise use your usual method. Complete any enabled two-factor check, then return here within five minutes.").font(.footnote).foregroundStyle(.secondary); TextField("Type DELETE to confirm", text: $confirmation).autocorrectionDisabled().textInputAutocapitalization(.characters) }
            Section {
                if account.user?.identities?.contains(where: { $0.provider == "apple" }) == true {
                    Text("Confirm with Apple to revoke the account’s Apple authorization.").font(.footnote)
                    SignInWithAppleButton(.continue, onRequest: account.prepareApple) { result in Task { await account.apple(result, deleting: true) } }.frame(height: 48)
                } else { Button("Permanently delete account", role: .destructive) { Task { await account.deleteAccount() } } }
            }.disabled(confirmation != "DELETE" || account.busy)
        }.navigationTitle("Delete account").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(account.busy) } } }
    }
}
