import SwiftUI

struct BakeryBackground: ViewModifier {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background {
            GeometryReader { proxy in
                ZStack {
                    Color(uiColor: .systemGroupedBackground)
                    if (store.state.settings.background ?? "flourGarden") != "plain" {
                        Image(store.state.settings.background ?? "flourGarden").resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
                        Color(uiColor: .systemGroupedBackground).opacity(colorScheme == .dark ? 0.82 : 0.35)
                    }
                }.ignoresSafeArea()
            }
        }
    }
}
extension View { func bakeryBackground() -> some View { modifier(BakeryBackground()) } }
struct AppearanceView: View {
    @EnvironmentObject private var store: BakeryStore
    let options = [("flourGarden", "Flour Garden", "Warm ivory, wheat & sourdough"), ("berryPatisserie", "Berry Patisserie", "Strawberries, cake & soft blush"), ("midnightBakery", "Midnight Bakery", "A cozy oven beneath the stars"), ("plain", "Simple & Calm", "A clean canvas for your kitchen")]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 18) {
                ForEach(options, id: \.0) { item in
                    Button { store.perform { $0.settings.background = item.0 } } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                if item.0 == "plain" { RoundedRectangle(cornerRadius: 18).fill(Color.bakeTint).frame(height: 215) }
                                else { GeometryReader { proxy in Image(item.0).resizable().scaledToFill().frame(width: proxy.size.width, height: 215).clipped() }.frame(height: 215).clipShape(RoundedRectangle(cornerRadius: 18)) }
                                if store.state.settings.background == item.0 { Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Color.bakeTeal).padding(10).background(.regularMaterial, in: Circle()).padding(6) }
                            }
                            Text(item.1).font(.headline).foregroundStyle(.primary)
                            Text(item.2).font(.caption).foregroundStyle(.secondary)
                        }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain).accessibilityIdentifier("background.\(item.0)").accessibilityLabel(item.1 + (store.state.settings.background == item.0 ? ", selected" : ""))
                }
            }.padding(18)
        }.navigationTitle("Make it yours").bakeryBackground()
    }
}
struct BakeryHero: View {
    @EnvironmentObject private var store: BakeryStore
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let logo = store.state.settings.profile?.logoData { BakeryLogoView(data: logo, size: 42) }
                Text(store.state.settings.bakery).font(.caption.weight(.semibold))
            }
            Text(title).font(.system(.largeTitle, design: .rounded).bold())
            Text(subtitle).font(.subheadline)
        }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, minHeight: 225, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Image(store.state.settings.background == "plain" ? "bake0" : (store.state.settings.background ?? "flourGarden")).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom).clipped()
                    .overlay(LinearGradient(colors: [Color.bakeDeep.opacity(0.92), Color.bakeDeep.opacity(0.48)], startPoint: .leading, endPoint: .trailing))
            }
        }.clipShape(RoundedRectangle(cornerRadius: 26))
    }
}
