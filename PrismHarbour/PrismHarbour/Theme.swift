import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

enum HarbourTheme {
    static let ink = Color(hex: 0x100B30)
    static let panel = Color(hex: 0x38245F)
    static let muted = Color(hex: 0xC1B8E5)
    static let lavender = Color(hex: 0xA977FF)
    static let mint = Color(hex: 0x4CF2BD)
    static let gold = Color(hex: 0xFFDC68)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

extension PrismColor {
    var tint: Color {
        switch self {
        case .coral: return Color(hex: 0xFF515D)
        case .amber: return Color(hex: 0xFFBF32)
        case .mint: return Color(hex: 0x21DDB0)
        case .sky: return Color(hex: 0x27BAFF)
        case .violet: return Color(hex: 0x9E62FF)
        case .rose: return Color(hex: 0xFF57BD)
        }
    }
    var jewelLight: Color {
        switch self {
        case .coral: return Color(hex: 0xFFA69D)
        case .amber: return Color(hex: 0xFFF59F)
        case .mint: return Color(hex: 0xAEFFE5)
        case .sky: return Color(hex: 0xA6F2FF)
        case .violet: return Color(hex: 0xE1B6FF)
        case .rose: return Color(hex: 0xFFC6EE)
        }
    }
    var jewelDark: Color {
        switch self {
        case .coral: return Color(hex: 0xA7193B)
        case .amber: return Color(hex: 0xBC6311)
        case .mint: return Color(hex: 0x087D72)
        case .sky: return Color(hex: 0x1464BC)
        case .violet: return Color(hex: 0x5023AA)
        case .rose: return Color(hex: 0xA92382)
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
        GeometryReader { geo in
            ZStack {
                HarbourTheme.ink
                Image("HarbourWorld").resizable().scaledToFill().frame(width:geo.size.width,height:geo.size.height).clipped().opacity(0.30)
                LinearGradient(colors:[Color(hex:0x271849).opacity(0.30),HarbourTheme.ink.opacity(0.80)],startPoint:.top,endPoint:.bottom)
            }
        }.ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(20).background {
            RoundedRectangle(cornerRadius:25)
                .fill(LinearGradient(colors:[Color(hex:0x583B85),Color(hex:0x30214F)],startPoint:.topLeading,endPoint:.bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius:25).strokeBorder(LinearGradient(colors:[Color(hex:0xBF8AF4).opacity(0.65),Color(hex:0x6E429E).opacity(0.25)],startPoint:.top,endPoint:.bottom),lineWidth:1.5))
                .shadow(color:.black.opacity(0.25),radius:0,y:5)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var color: Color = HarbourTheme.mint
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size:20,weight:.heavy,design:.rounded))
            .foregroundStyle(.white).shadow(color:.black.opacity(0.3),radius:0,y:2)
            .frame(maxWidth:.infinity).padding(.vertical,18)
            .background {
                RoundedRectangle(cornerRadius:23).fill(color.opacity(0.45)).offset(y:configuration.isPressed ? 2 : 6)
                RoundedRectangle(cornerRadius:23).fill(LinearGradient(colors:[color,color.opacity(0.65)],startPoint:.top,endPoint:.bottom))
                    .overlay(alignment:.top) { RoundedRectangle(cornerRadius:20).fill(.white.opacity(0.25)).frame(height:24).padding(5) }
                    .overlay(RoundedRectangle(cornerRadius:23).strokeBorder(.white.opacity(0.55),lineWidth:2))
                    .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(color.opacity(0.8),lineWidth:1).padding(3))
            }
            .shadow(color:.black.opacity(0.32),radius:8,y:8)
            .offset(y:configuration.isPressed ? 4 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response:0.25,dampingFraction:0.55),value:configuration.isPressed)
    }
}

struct JewelPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(response:0.25,dampingFraction:0.55),value:configuration.isPressed)
    }
}

struct RoundIconButton: View {
    let icon: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action:action) {
            Image(systemName:icon).font(.system(size:19,weight:.bold)).foregroundStyle(.white)
                .frame(width:46,height:46)
                .background {
                    Circle().fill(Color(hex:0x2C1B51)).offset(y:3)
                    Circle().fill(LinearGradient(colors:[Color(hex:0x8B63BF),Color(hex:0x56307E)],startPoint:.top,endPoint:.bottom))
                }
                .overlay(Circle().strokeBorder(Color(hex:0xCBB0EE).opacity(0.8),lineWidth:1.5))
                .shadow(color:.black.opacity(0.25),radius:4,y:3)
        }.buttonStyle(JewelPressStyle()).accessibilityLabel(label)
    }
}

struct CoinPill: View {
    let coins: Int
    var body: some View {
        HStack(spacing:7) {
            ZStack {
                Circle().fill(LinearGradient(colors:[Color(hex:0xFFF8C0),HarbourTheme.gold,Color(hex:0xC8841F)],startPoint:.topLeading,endPoint:.bottomTrailing))
                Circle().strokeBorder(Color(hex:0xFFF2AE),lineWidth:2).padding(3)
                Image(systemName:"sparkle").font(.system(size:14,weight:.black)).foregroundStyle(Color(hex:0x9E551F))
            }.frame(width:29,height:29).shadow(color:.black.opacity(0.25),radius:0,y:2)
            Text(coins.formatted()).font(.system(size:17,weight:.heavy,design:.rounded)).monospacedDigit().foregroundStyle(.white)
        }.padding(.leading,5).padding(.trailing,14).padding(.vertical,5)
            .background(Color(hex:0x24123C).opacity(0.9),in:Capsule())
            .overlay(Capsule().strokeBorder(HarbourTheme.gold.opacity(0.6),lineWidth:1.5))
            .accessibilityElement(children:.ignore).accessibilityLabel("\(coins) pearls")
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = HarbourTheme.mint
    var body: some View { Text(text.uppercased()).font(.system(size:10,weight:.heavy,design:.rounded)).tracking(1.8).foregroundStyle(color) }
}

/// Faceted, bevelled jewels retain their colour and optional accessibility symbol at every board size.
struct PrismTile: View {
    var color: PrismColor
    var symbols = false
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width,geo.size.height)
            let radius = side * 0.21
            let inset = max(3,side * 0.12)
            ZStack {
                RoundedRectangle(cornerRadius:radius).fill(color.jewelDark).offset(y:side*0.06)
                RoundedRectangle(cornerRadius:radius).fill(LinearGradient(colors:[color.jewelLight,color.tint,color.jewelDark],startPoint:.topLeading,endPoint:.bottomTrailing))
                jewelFacets(size:geo.size,inset:inset)
                RoundedRectangle(cornerRadius:radius*0.65)
                    .fill(LinearGradient(colors:[color.jewelLight.opacity(0.55),color.tint,color.tint.opacity(0.60)],startPoint:.topLeading,endPoint:.bottomTrailing))
                    .padding(inset)
                    .overlay(RoundedRectangle(cornerRadius:radius*0.65).strokeBorder(.white.opacity(0.25),lineWidth:0.8).padding(inset))
                RoundedRectangle(cornerRadius:radius).strokeBorder(color.jewelLight.opacity(0.9),lineWidth:max(1,side*0.025))
                RoundedRectangle(cornerRadius:radius*0.75).trim(from:0.53,to:0.87).stroke(.white.opacity(0.7),style:StrokeStyle(lineWidth:side*0.045,lineCap:.round)).padding(side*0.06)
                if symbols {
                    Image(systemName:color.symbol).font(.system(size:side*0.34,weight:.black)).foregroundStyle(color.jewelDark.opacity(0.83))
                        .shadow(color:color.jewelLight.opacity(0.8),radius:0,y:1)
                } else {
                    Image(systemName:"sparkle").font(.system(size:side*0.18,weight:.bold)).foregroundStyle(.white.opacity(0.8))
                        .position(x:geo.size.width*0.25,y:geo.size.height*0.23)
                }
            }
        }
    }
    private func jewelFacets(size:CGSize,inset:CGFloat) -> some View {
        Canvas { context,_ in
            let w=size.width; let h=size.height; let i=inset
            var top=Path(); top.move(to:CGPoint(x:i,y:1)); top.addLine(to:CGPoint(x:w-i,y:1)); top.addLine(to:CGPoint(x:w-i*1.8,y:i*1.6)); top.addLine(to:CGPoint(x:i*1.8,y:i*1.6)); top.closeSubpath()
            context.fill(top,with:.color(.white.opacity(0.40)))
            var left=Path(); left.move(to:CGPoint(x:1,y:i)); left.addLine(to:CGPoint(x:i*1.6,y:i*1.8)); left.addLine(to:CGPoint(x:i*1.6,y:h-i*1.8)); left.addLine(to:CGPoint(x:1,y:h-i)); left.closeSubpath()
            context.fill(left,with:.color(color.jewelLight.opacity(0.45)))
            var right=Path(); right.move(to:CGPoint(x:w-1,y:i)); right.addLine(to:CGPoint(x:w-i*1.6,y:i*1.8)); right.addLine(to:CGPoint(x:w-i*1.6,y:h-i*1.8)); right.addLine(to:CGPoint(x:w-1,y:h-i)); right.closeSubpath()
            context.fill(right,with:.color(color.jewelDark.opacity(0.45)))
            var bottom=Path(); bottom.move(to:CGPoint(x:i,y:h-1)); bottom.addLine(to:CGPoint(x:w-i,y:h-1)); bottom.addLine(to:CGPoint(x:w-i*1.8,y:h-i*1.6)); bottom.addLine(to:CGPoint(x:i*1.8,y:h-i*1.6)); bottom.closeSubpath()
            context.fill(bottom,with:.color(color.jewelDark.opacity(0.60)))
        }
    }
}

/// Timelines pause while the app is inactive; the view is removed when its screen is hidden.
struct HarbourSparkles: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var density = 24
    var body: some View {
        TimelineView(.animation(minimumInterval:1.0/24.0,paused:reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context,size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<density {
                    let seed=Double(index)
                    let x=CGFloat((index*137+37)%997)/997*size.width
                    let base=CGFloat((index*211+97)%991)/991*size.height
                    let drift=reduceMotion ? 0 : sin(time*0.35+seed)*14
                    let alpha=reduceMotion ? 0.5 : 0.25+(sin(time*1.4+seed*2.1)+1)*0.25
                    let radius=CGFloat(index%4 == 0 ? 2.8 : 1.4)
                    let center=CGPoint(x:x+CGFloat(drift),y:base-CGFloat(sin(time*0.22+seed)*10))
                    context.fill(Path(ellipseIn:CGRect(x:center.x-radius,y:center.y-radius,width:radius*2,height:radius*2)),with:.color((index%3 == 0 ? HarbourTheme.gold : .white).opacity(alpha)))
                    if index%4 == 0 {
                        var glint=Path(); glint.move(to:CGPoint(x:center.x-6,y:center.y)); glint.addLine(to:CGPoint(x:center.x+6,y:center.y)); glint.move(to:CGPoint(x:center.x,y:center.y-6)); glint.addLine(to:CGPoint(x:center.x,y:center.y+6))
                        context.stroke(glint,with:.color(.white.opacity(alpha*0.6)),lineWidth:1)
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct HarbourIllustration: View {
    var compact = false
    var body: some View {
        GeometryReader { geo in
            Image("HarbourWorld").resizable().scaledToFill().frame(width:geo.size.width,height:geo.size.height).clipped()
                .overlay(HarbourSparkles(density:12))
                .mask(RoundedRectangle(cornerRadius:compact ? 22 : 34))
                .overlay(RoundedRectangle(cornerRadius:compact ? 22 : 34).strokeBorder(HarbourTheme.gold.opacity(0.35),lineWidth:1.5))
        }.accessibilityHidden(true)
    }
}
