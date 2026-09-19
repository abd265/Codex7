import SwiftUI

struct MembershipPlansView: View {
    @EnvironmentObject private var membership: MembershipStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected: MembershipPlan = .annual
    private var chosenPrice: String { membership.product(for: selected)?.displayPrice ?? selected.proposedPrice }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 9) {
                    Label("RISE & BAKE", systemImage: "sparkles").font(.caption.weight(.bold)).tracking(2)
                    Text("A little help.\nA lot more baking.").font(.system(size: 33, weight: .bold, design: .serif))
                    Text("Choose a plan that fits your bakery.").font(.subheadline)
                }.foregroundStyle(Color.bakeTeal).padding(.top, 6)

                if !membership.enabled {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Proposed launch pricing", systemImage: "calendar.badge.clock").font(.headline)
                        Text("Plans are not on sale yet. Prices below are proposed in Canadian dollars. You can use this installation without a subscription.").font(.subheadline)
                    }.padding(18).background(Color.bakeTint, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(Color.bakeDeep).accessibilityIdentifier("plans.availability")
                }
                if !membership.active.isEmpty {
                    ForEach(membership.active, id: \.plan) { entitlement in
                        VStack(alignment: .leading, spacing: 6) {
                            Label("\(entitlement.plan.title) active", systemImage: "checkmark.seal.fill").font(.headline)
                            if let expiry = entitlement.expiration { Text("Current access ends \(expiry.formatted(date: .abbreviated, time: .omitted)). Check renewal settings in the App Store.").font(.footnote) }
                            else { Text("One-time purchase restored on this device.").font(.footnote) }
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color.bakeTint, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(Color.bakeDeep).accessibilityElement(children: .combine).accessibilityIdentifier("plans.active.\(entitlement.plan.rawValue)")
                    }
                }
                VStack(spacing: 12) {
                    ForEach(MembershipPlan.allCases) { plan in planCard(plan) }
                }
                BakeCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Made for your everyday baking").font(.headline)
                        feature("Orders, customers & pickup planning", "bag")
                        feature("Recipes, baking journal & timers", "oven")
                        feature("Ingredient costing & shopping lists", "cart")
                        feature("Your bakery logo & branded receipts", "doc.text")
                        feature("Baking backgrounds & your own menu", "paintpalette")
                        Text("Bakery records are saved on this iPhone. These plans do not currently include cloud sync or an online customer storefront.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if membership.active.isEmpty {
                    AccountPrimaryButton(title: membership.enabled ? "\(selected == .offline ? "Buy" : "Subscribe") · \(chosenPrice)" : "Purchases coming soon", busy: membership.busy) {
                        Task { await membership.purchase(selected) }
                    }.disabled(!membership.enabled || membership.product(for: selected) == nil).accessibilityIdentifier("plans.purchase")
                    if membership.enabled && membership.loaded && membership.product(for: selected) == nil {
                        Text("This plan is not available from the App Store in this installation. No purchase has started.").font(.footnote).foregroundStyle(.secondary)
                        Button("Reload prices") { Task { await membership.load() } }.accessibilityIdentifier("plans.reload")
                    }
                    if membership.enabled && membership.product(for: selected) != nil {
                        Text(selected == .offline ? "One payment for this phone-based edition. No subscription or automatic renewal." : "Payment is charged to your Apple Account. The subscription renews automatically at \(chosenPrice) \(selected.interval) unless cancelled at least 24 hours before the current period ends. Manage or cancel in your App Store account.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 14) {
                    Button("Restore purchases") { Task { await membership.restore() } }.disabled(membership.busy).accessibilityIdentifier("plans.restore")
                    if membership.enabled {
                        Link("Manage subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!).accessibilityIdentifier("plans.manage")
                    }
                    if membership.enabled, let config = membership.configuration,
                       let privacy = URL(string: config.privacyURL), privacy.scheme == "https",
                       let terms = URL(string: config.termsURL), terms.scheme == "https" {
                        HStack { Link("Privacy", destination: privacy); Text("·"); Link("Terms", destination: terms) }
                    }
                    Text("Account security and two-factor authentication are never paid add-ons.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.bottom, 20)
            }.frame(maxWidth: 560).padding(22).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Plans & pricing").navigationBarTitleDisplayMode(.inline)
        .task { await membership.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await membership.refreshEntitlements() } } }
        .alert("Your plan", isPresented: Binding(get: { membership.message != nil }, set: { if !$0 { membership.message = nil } })) { Button("OK", role: .cancel) { membership.message = nil } } message: { Text(membership.message ?? "") }
    }
    private func feature(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(.subheadline).labelStyle(.titleAndIcon)
    }
    private func planCard(_ plan: MembershipPlan) -> some View {
        Button { selected = plan } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(plan.title).font(.headline)
                        Text(plan == .offline ? "Pay once for the phone-based edition" : plan == .annual ? "One payment each year" : "A smaller payment each month").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: selected == plan ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(Color.bakeTeal)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(membership.product(for: plan)?.displayPrice ?? (membership.enabled ? "Unavailable" : plan.proposedPrice)).font(.system(size: 29, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(plan.interval).font(.subheadline).foregroundStyle(.secondary)
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected == plan ? Color.bakeTeal : .gray.opacity(0.15), lineWidth: selected == plan ? 2 : 1))
        }.buttonStyle(.plain).accessibilityIdentifier("plans.select.\(plan.rawValue)").accessibilityAddTraits(selected == plan ? [.isSelected] : [])
    }
}
