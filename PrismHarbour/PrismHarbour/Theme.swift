import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

enum HarbourTheme {
    static let ink = Color(hex: 0x0B1027)
    static let panel = Color(hex: 0x19213E)
    static let muted = Color(hex: 0xA4AFCD)
    static let lavender = Color(hex: 0xBCA7FF)
    static let mint = Color(hex: 0x78E3D0)
    static let gold = Color(hex: 0xFFCF77)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

extension PrismColor {
    var tint: Color {
        switch self {
        case .coral: return Color(hex: 0xFF7979)
        case .amber: return Color(hex: 0xFFCB66)
        case .mint: return Color(hex: 0x66E0BA)
        case .sky: return Color(hex: 0x69C7FF)
        case .violet: return Color(hex: 0xAB8AFF)
        case .rose: return Color(hex: 0xF789C2)
        }
    }
    var symbol: String {
        switch self {
        case .coral: return "flame.fill"
        case .amber: return "sun.max.fill"
        case .mint: return "leaf.fill"
        case .sky: return "drop.fill"
        case .violet: return "moon.fill"
        case .rose: return "heart.fill"
        }
    }
    var name: String { String(describing: self).capitalized }
}

struct HarbourBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x151A38), HarbourTheme.ink, Color(hex: 0x102436)], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Circle().fill(Color(hex: 0x7255C7).opacity(0.14)).frame(width: 400, height: 400).blur(radius: 85).position(x: geo.size.width + 50, y: 90)
                Circle().fill(HarbourTheme.mint.opacity(0.06)).frame(width: 320, height: 320).blur(radius: 80).position(x: -80, y: geo.size.height * 0.75)
            }
        }.ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(20).background {
            RoundedRectangle(cornerRadius: 24).fill(.white.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.075), lineWidth: 1))
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = HarbourTheme.lavender
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(HarbourTheme.ink).frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(LinearGradient(colors: [color, color.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.2)))
            .shadow(color: color.opacity(0.2), radius: 18, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct RoundIconButton: View {
    let icon: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).frame(width: 46, height: 46)
                .background(.white.opacity(0.07), in: Circle()).overlay(Circle().stroke(.white.opacity(0.06)))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct CoinPill: View {
    let coins: Int
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkle").foregroundStyle(HarbourTheme.gold)
            Text(coins.formatted()).font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
        }.padding(.horizontal, 14).padding(.vertical, 10).background(.white.opacity(0.065), in: Capsule())
            .accessibilityLabel("\(coins) pearls")
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = HarbourTheme.mint
    var body: some View { Text(text.uppercased()).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2.6).foregroundStyle(color) }
}

struct PrismTile: View {
    var color: PrismColor
    var symbols = false
    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) * 0.22
            ZStack {
                RoundedRectangle(cornerRadius: r).fill(color.tint.opacity(0.5)).offset(y: 3)
                RoundedRectangle(cornerRadius: r).fill(LinearGradient(colors: [color.tint, color.tint.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: r).strokeBorder(.white.opacity(0.35), lineWidth: 1)
                Path { p in
                    let w = geo.size.width; let h = geo.size.height
                    p.move(to: CGPoint(x: 4, y: 4)); p.addLine(to: CGPoint(x: w-4,y: 4)); p.addLine(to: CGPoint(x: w*0.68,y: h*0.34)); p.addLine(to: CGPoint(x: w*0.32,y: h*0.34)); p.closeSubpath()
                }.fill(.white.opacity(0.2))
                Image(systemName: color.symbol).font(.system(size: min(geo.size.width, geo.size.height) * (symbols ? 0.38 : 0.26), weight: .bold))
                    .foregroundStyle(Color.black.opacity(symbols ? 0.45 : 0.15))
            }
        }
    }
}

/// Original vector harbour artwork. No reference artwork is embedded in the app.
struct HarbourIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var compact = false
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                Circle().fill(HarbourTheme.lavender.opacity(0.08)).frame(width: w*0.73).position(x:w*0.52,y:h*0.47)
                Circle().stroke(HarbourTheme.lavender.opacity(0.12),lineWidth:1).frame(width:w*0.76).position(x:w*0.52,y:h*0.47)
                Canvas { context, size in
                    for i in 0..<22 {
                        let x = CGFloat((i * 137 + 19) % 1000) / 1000 * size.width
                        let y = CGFloat((i * 83 + 37) % 660) / 1000 * size.height
                        context.fill(Path(ellipseIn: CGRect(x:x,y:y,width:i % 5 == 0 ? 3 : 1.5,height:i % 5 == 0 ? 3 : 1.5)), with:.color(.white.opacity(i % 3 == 0 ? 0.65 : 0.24)))
                    }
                    for i in 0..<7 {
                        let y = size.height * (0.70 + Double(i)*0.04)
                        var wave = Path(); wave.move(to: CGPoint(x: size.width*0.08,y:y))
                        wave.addCurve(to: CGPoint(x:size.width*0.95,y:y-6),control1:CGPoint(x:size.width*0.3,y:y-15),control2:CGPoint(x:size.width*0.7,y:y+14))
                        context.stroke(wave,with:.color(HarbourTheme.mint.opacity(0.06 + Double(7-i)*0.013)),lineWidth:1)
                    }
                    var beam = Path(); beam.move(to:CGPoint(x:w*0.52,y:h*0.32)); beam.addLine(to:CGPoint(x:w*0.96,y:h*0.07)); beam.addLine(to:CGPoint(x:w*0.94,y:h*0.46)); beam.closeSubpath()
                    context.fill(beam,with:.linearGradient(Gradient(colors:[HarbourTheme.gold.opacity(0.18),HarbourTheme.gold.opacity(0)]),startPoint:CGPoint(x:w*0.52,y:h*0.32),endPoint:CGPoint(x:w*0.96,y:h*0.28)))
                }
                Ellipse().fill(Color(hex:0x182E44)).frame(width:w*0.65,height:h*0.19).overlay(Ellipse().stroke(HarbourTheme.mint.opacity(0.18),lineWidth:1)).position(x:w*0.5,y:h*0.72)
                lighthouse.frame(width:w*0.2,height:h*0.56).position(x:w*0.53,y:h*0.43)
                gem(.coral, size:w*0.145).rotationEffect(.degrees(-14)).position(x:w*0.22,y:h*0.56)
                gem(.mint, size:w*0.13).rotationEffect(.degrees(13)).position(x:w*0.77,y:h*0.60)
                gem(.violet, size:w*0.095).rotationEffect(.degrees(18)).position(x:w*0.82,y:h*0.26)
                gem(.amber, size:w*0.075).rotationEffect(.degrees(-12)).position(x:w*0.23,y:h*0.21)
                Image(systemName:"sparkle").font(.system(size:22)).foregroundStyle(HarbourTheme.gold).position(x:w*0.70,y:h*0.10)
                Image(systemName:"sparkle").font(.system(size:13)).foregroundStyle(HarbourTheme.mint).position(x:w*0.32,y:h*0.39)
            }
        }.accessibilityHidden(true)
    }
    private func gem(_ color: PrismColor,size:CGFloat) -> some View {
        PrismTile(color:color).frame(width:size,height:size).shadow(color:color.tint.opacity(0.24),radius:15,y:8)
    }
    private var lighthouse: some View {
        GeometryReader { geo in
            let w=geo.size.width; let h=geo.size.height
            ZStack {
                Path { p in p.move(to:CGPoint(x:w*0.3,y:h*0.25)); p.addLine(to:CGPoint(x:w*0.7,y:h*0.25));p.addLine(to:CGPoint(x:w*0.88,y:h*0.96));p.addLine(to:CGPoint(x:w*0.12,y:h*0.96));p.closeSubpath() }
                    .fill(LinearGradient(colors:[Color(hex:0xE5DCF9),Color(hex:0x807AAB)],startPoint:.leading,endPoint:.trailing))
                Path { p in p.move(to:CGPoint(x:w*0.24,y:h*0.5));p.addLine(to:CGPoint(x:w*0.76,y:h*0.43));p.addLine(to:CGPoint(x:w*0.81,y:h*0.62));p.addLine(to:CGPoint(x:w*0.19,y:h*0.69));p.closeSubpath() }.fill(Color(hex:0x8470B4))
                RoundedRectangle(cornerRadius:4).fill(HarbourTheme.gold).frame(width:w*0.44,height:h*0.16).shadow(color:HarbourTheme.gold.opacity(0.4),radius:18).position(x:w*0.5,y:h*0.2)
                Path { p in p.move(to:CGPoint(x:w*0.1,y:h*0.12));p.addLine(to:CGPoint(x:w*0.5,y:0));p.addLine(to:CGPoint(x:w*0.9,y:h*0.12));p.closeSubpath() }.fill(Color(hex:0xAAA1D5))
                RoundedRectangle(cornerRadius:3).fill(Color(hex:0x635C91)).frame(width:w*0.76,height:h*0.05).position(x:w*0.5,y:h*0.31)
                Capsule().fill(HarbourTheme.ink.opacity(0.6)).frame(width:w*0.17,height:h*0.15).position(x:w*0.5,y:h*0.87)
            }
        }
    }
}
