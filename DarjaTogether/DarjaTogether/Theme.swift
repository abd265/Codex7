import SwiftUI

enum DarjaTheme {
    static let ink = Color(hex:0x203D42)
    static let teal = Color(hex:0x187D78)
    static let cream = Color(hex:0xFCF8EF)
    static let mint = Color(hex:0xE0F0E5)
    static let gold = Color(hex:0xF2BD54)
    static let coral = Color(hex:0xD87356)
    static let lilac = Color(hex:0xE8E3F6)
    static let muted = Color(hex:0x657A7C)
}
extension Color {
    init(hex:UInt32) { self.init(.sRGB,red:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255,opacity:1) }
}
struct PaperCard<Content:View>:View {
    var color:Color = .white
    @ViewBuilder var content:Content
    var body:some View { content.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(color,in:RoundedRectangle(cornerRadius:26)).overlay(RoundedRectangle(cornerRadius:26).stroke(DarjaTheme.ink.opacity(0.06),lineWidth:1)) }
}
struct PrimaryAction:ButtonStyle {
    var color:Color = DarjaTheme.teal
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(.headline,design:.rounded)).foregroundStyle(.white).padding(.vertical,17).padding(.horizontal,22).frame(maxWidth:.infinity).background(color,in:RoundedRectangle(cornerRadius:19)).scaleEffect(configuration.isPressed ? 0.97:1).opacity(configuration.isPressed ? 0.85:1)
    }
}
struct SectionTitle:View {
    let title:String
    var subtitle:String? = nil
    var body:some View { VStack(alignment:.leading,spacing:5){Text(title).font(.system(.title2,design:.rounded,weight:.bold));if let subtitle {Text(subtitle).font(.subheadline).foregroundStyle(DarjaTheme.muted)}}.frame(maxWidth:.infinity,alignment:.leading) }
}
struct TagPill:View {
    let text:String
    var color:Color = DarjaTheme.mint
    var body:some View {Text(text).font(.system(.caption,design:.rounded,weight:.bold)).padding(.horizontal,12).padding(.vertical,7).background(color,in:Capsule())}
}
struct TeacherAvatar:View {
    var name:String = "nadia"
    var talking:Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false
    var body:some View {
        GeometryReader { geo in
            let s=geo.size.width
            ZStack {
                Circle().fill(DarjaTheme.gold.opacity(0.24)).frame(width:s*0.94,height:s*0.94)
                Circle().stroke(DarjaTheme.teal.opacity(0.12),style:StrokeStyle(lineWidth:1.5,dash:[3,7])).padding(2)
                if name == "fennec" {
                    FennecFace().padding(s*0.13)
                } else {
                    Ellipse().fill(name == "yacine" ? DarjaTheme.coral:DarjaTheme.teal).frame(width:s*0.66,height:s*0.52).offset(y:s*0.34)
                    RoundedRectangle(cornerRadius:s*0.3).fill(Color(hex:0x413431)).frame(width:s*0.59,height:s*0.76).offset(y:s*0.015)
                    Ellipse().fill(Color(hex:0xDDA274)).frame(width:s*0.18,height:s*0.21).offset(y:s*0.25)
                    Ellipse().fill(Color(hex:0xF0BA8C)).frame(width:s*0.47,height:s*0.57).offset(y:-s*0.035)
                    Ellipse().fill(Color(hex:0x413431)).frame(width:s*0.51,height:s*0.19).rotationEffect(.degrees(-17)).offset(x:-s*0.04,y:-s*0.28)
                    HStack(spacing:s*0.15) { Capsule().frame(width:s*0.035,height:s*0.055); Capsule().frame(width:s*0.035,height:s*0.055) }.foregroundStyle(Color(hex:0x382F31)).offset(y:-s*0.035)
                    HStack(spacing:s*0.24){Ellipse();Ellipse()}.foregroundStyle(DarjaTheme.coral.opacity(0.35)).frame(width:s*0.37,height:s*0.05).offset(y:s*0.045)
                    if talking {Ellipse().fill(Color(hex:0x863C3B)).frame(width:s*0.09,height:s*0.09).offset(y:s*0.105)} else {Smile().stroke(Color(hex:0x863C3B),style:StrokeStyle(lineWidth:s*0.018,lineCap:.round)).frame(width:s*0.13,height:s*0.065).offset(y:s*0.09)}
                    if name != "yacine" {Image(systemName:"sparkle").font(.system(size:s*0.09,weight:.bold)).foregroundStyle(DarjaTheme.gold).offset(x:s*0.25,y:-s*0.18)}
                }
                Image(systemName:"sparkle").foregroundStyle(DarjaTheme.gold).font(.system(size:s*0.14)).offset(x:s*0.4,y:-s*0.3)
            }.frame(width:s,height:geo.size.height).clipShape(Circle()).offset(y:float && !reduceMotion ? -3:3)
                .animation(reduceMotion ? nil:.easeInOut(duration:2.4).repeatForever(autoreverses:true),value:float).onAppear{float=true}
        }.aspectRatio(1,contentMode:.fit).accessibilityLabel(name.capitalized + ", your learning companion")
    }
}
struct Smile:Shape {func path(in r:CGRect)->Path {var p=Path();p.move(to:CGPoint(x:0,y:0));p.addQuadCurve(to:CGPoint(x:r.width,y:0),control:CGPoint(x:r.midX,y:r.height*1.7));return p}}
struct FennecFace:View {
    var body:some View {GeometryReader { g in
        let s=g.size.width
        ZStack {
            HStack(spacing:s*0.09) {ForEach(0..<2){i in RoundedRectangle(cornerRadius:s*0.15).fill(DarjaTheme.gold).frame(width:s*0.33,height:s*0.72).rotationEffect(.degrees(i == 0 ? -18:18))}}.offset(y:-s*0.12)
            Ellipse().fill(Color(hex:0xF1C97D)).frame(width:s,height:s*0.77).offset(y:s*0.15)
            Ellipse().fill(DarjaTheme.cream).frame(width:s*0.66,height:s*0.43).offset(y:s*0.32)
            HStack(spacing:s*0.31){Circle();Circle()}.frame(width:s*0.45,height:s*0.06).offset(y:s*0.12)
            Image(systemName:"heart.fill").resizable().frame(width:s*0.13,height:s*0.1).rotationEffect(.degrees(180)).offset(y:s*0.3)
        }.foregroundStyle(DarjaTheme.ink).frame(width:s,height:s)
    }}
}
struct AlgeriaSkyline:View {
    var body:some View {GeometryReader { g in
        ZStack(alignment:.bottom) {
            Circle().fill(DarjaTheme.gold).frame(width:62,height:62).offset(x:g.size.width*0.22,y:-42)
            HStack(alignment:.bottom,spacing:7){ForEach(0..<9){i in
                VStack(spacing:8){RoundedRectangle(cornerRadius:10).fill(DarjaTheme.teal.opacity(0.18)).frame(width:8,height:17);RoundedRectangle(cornerRadius:8).fill(DarjaTheme.teal.opacity(0.12)).frame(width:11,height:22)}.padding(9).frame(maxWidth:.infinity).frame(height:CGFloat([55,79,68,101,84,61,94,72,47][i])).background(i % 2 == 0 ? Color.white.opacity(0.72):Color(hex:0xEADABD),in:UnevenRoundedRectangle(topLeadingRadius:12,topTrailingRadius:12))
            }}
        }
    }.frame(height:112).accessibilityHidden(true)}
}
