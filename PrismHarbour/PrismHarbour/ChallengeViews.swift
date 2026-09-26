import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

struct ChallengeMapView: View {
    @EnvironmentObject private var store: HarbourStore
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators:false) {
                VStack(spacing:0) {
                    introduction
                    ForEach(0..<4) { tier in ChallengeRouteView(tier:tier) }
                    VStack(spacing:8) {
                        Image(systemName:"crown.fill").font(.system(size:25,weight:.black)).foregroundStyle(HarbourTheme.gold)
                        Text(store.challengeCompletedCount == 20 ? "Voyage mastered" : "One thoughtful move at a time.")
                            .font(.system(size:17,weight:.heavy,design:.rounded))
                        Text("Replay a challenge to improve your stars.").font(.system(size:12,weight:.medium,design:.rounded)).foregroundStyle(HarbourTheme.muted)
                    }.padding(.top,5).padding(.bottom,32)
                }.frame(maxWidth:540).frame(maxWidth:.infinity)
            }.onAppear {
                if store.progress.challengeHighestUnlocked>1 {
                    proxy.scrollTo("challenge-\(min(20,store.progress.challengeHighestUnlocked))",anchor:.center)
                }
            }
        }
    }
    private var introduction:some View {
        VStack(spacing:11) {
            HStack(spacing:15) {
                Label("\(store.challengeCompletedCount) / 20",systemImage:"flag.fill")
                Label("\(store.challengeTotalStars) / 60",systemImage:"star.fill")
                Label("No timer",systemImage:"infinity")
            }.font(.system(size:12,weight:.heavy,design:.rounded)).foregroundStyle(HarbourTheme.gold)
            Text("Open space. Move blockers. Find the sequence.")
                .font(.system(size:14,weight:.bold,design:.rounded)).multilineTextAlignment(.center)
            Text("These harbours need planning. Every puzzle has a verified solution; undo is free, and there is no rush.")
                .font(.system(size:12,weight:.medium,design:.rounded)).foregroundStyle(HarbourTheme.muted).multilineTextAlignment(.center).lineSpacing(3)
        }.padding(20).frame(maxWidth:.infinity)
            .background(LinearGradient(colors:[Color(hex:0x472663),Color(hex:0x27153F)],startPoint:.top,endPoint:.bottom))
    }
}

private struct ChallengeRouteView: View {
    @EnvironmentObject private var store: HarbourStore
    let tier:Int
    private let step:CGFloat=116
    private var levels:[Level] { Array(ChallengeCatalog.levels.dropFirst(tier*5).prefix(5)) }
    private var tint:Color { [HarbourTheme.mint,Color(hex:0xFF91BA),HarbourTheme.lavender,HarbourTheme.gold][tier] }
    private var stars:Int { levels.reduce(0) { $0+(store.progress.challengeStars[$1.id] ?? 0) } }
    private var copy:String {
        ["Make room before making your escape.",
         "A clear dock can hide a blocked route.",
         "Park a piece now. Bring it back later.",
         "Plan the sequence. Every space matters."][tier]
    }
    var body:some View {
        GeometryReader { geo in
            ZStack(alignment:.top) {
                Image("HarbourWorld").resizable().scaledToFill().frame(width:geo.size.width,height:790).clipped().opacity(0.27)
                LinearGradient(colors:[HarbourTheme.ink.opacity(0.85),Color(hex:0x271D4E).opacity(0.35),HarbourTheme.ink.opacity(0.9)],startPoint:.top,endPoint:.bottom)
                path(width:geo.size.width)
                heading.padding(.horizontal,26).padding(.top,20)
                ForEach(Array(levels.enumerated()),id:\.element.id) { index,level in
                    ChallengeLevelNode(level:level,tint:tint)
                        .id("challenge-\(tier*5+index+1)")
                        .position(point(index,width:geo.size.width))
                }
                Image(systemName:tier == 3 ? "crown.fill" : "sparkles")
                    .font(.system(size:34,weight:.black)).foregroundStyle(tint.opacity(0.2))
                    .position(x:geo.size.width*0.13,y:360)
                Image(systemName:"moon.stars.fill")
                    .font(.system(size:27,weight:.bold)).foregroundStyle(tint.opacity(0.2))
                    .position(x:geo.size.width*0.88,y:550)
            }
        }.frame(height:790)
    }
    private var heading:some View {
        VStack(spacing:7) {
            Eyebrow(text:"Challenge tier \(tier+1) of 4",color:tint)
            Text(ChallengeCatalog.tierName(for:101+tier*5)).font(.system(size:25,weight:.black,design:.rounded))
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(copy).font(.system(size:12,weight:.bold,design:.rounded)).foregroundStyle(HarbourTheme.muted).multilineTextAlignment(.center)
            Label("\(stars) / 15",systemImage:"star.fill").font(.system(size:12,weight:.heavy,design:.rounded)).foregroundStyle(HarbourTheme.gold)
        }.padding(.horizontal,18).padding(.vertical,15).frame(maxWidth:.infinity)
            .background(Color(hex:0x24143D).opacity(0.93),in:RoundedRectangle(cornerRadius:25))
            .overlay(RoundedRectangle(cornerRadius:25).strokeBorder(tint.opacity(0.5),lineWidth:1.5))
    }
    private func point(_ index:Int,width:CGFloat)->CGPoint {
        CGPoint(x:width*0.5+sin(Double(index)*1.1+Double(tier)*0.6)*width*0.2,y:222+CGFloat(index)*step)
    }
    private func path(width:CGFloat)->some View {
        Canvas { context,_ in
            var route=Path(); route.move(to:point(0,width:width))
            for index in 1..<5 {
                let previous=point(index-1,width:width), next=point(index,width:width)
                route.addCurve(to:next,control1:CGPoint(x:previous.x,y:previous.y+step*0.55),control2:CGPoint(x:next.x,y:next.y-step*0.55))
            }
            context.stroke(route,with:.color(Color(hex:0x171136).opacity(0.9)),style:StrokeStyle(lineWidth:24,lineCap:.round))
            context.stroke(route,with:.color(tint.opacity(0.23)),style:StrokeStyle(lineWidth:14,lineCap:.round))
            context.stroke(route,with:.color(HarbourTheme.gold.opacity(0.55)),style:StrokeStyle(lineWidth:3,lineCap:.round,dash:[1,11]))
        }.accessibilityHidden(true)
    }
}

private struct ChallengeLevelNode: View {
    @EnvironmentObject private var store:HarbourStore
    let level:Level
    let tint:Color
    private var number:Int { ChallengeCatalog.number(for:level.id) ?? 1 }
    private var unlocked:Bool { number<=store.progress.challengeHighestUnlocked }
    private var current:Bool { number==min(20,store.progress.challengeHighestUnlocked) }
    private var stars:Int { store.progress.challengeStars[level.id] ?? 0 }
    private var colors:[Color] {
        if current { return [Color(hex:0xFFE994),Color(hex:0xF4BD43),Color(hex:0xBB7E24)] }
        if unlocked { return [Color(hex:0xC28AFF),Color(hex:0x8350C6),Color(hex:0x552D84)] }
        return [Color(hex:0x57416B),Color(hex:0x322440)]
    }
    var body:some View {
        Button { store.start(level) } label: {
            VStack(spacing:7) {
                ZStack {
                    if current {
                        Circle().strokeBorder(HarbourTheme.gold.opacity(0.25),lineWidth:6).frame(width:83,height:83)
                    }
                    Circle().fill(Color(hex:0x1B1032)).frame(width:66,height:66).offset(y:5)
                    Circle().fill(LinearGradient(colors:colors,startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:66,height:66)
                        .overlay(Circle().strokeBorder(unlocked ? HarbourTheme.gold : Color(hex:0x725587),lineWidth:3))
                        .overlay(Circle().strokeBorder(.white.opacity(unlocked ? 0.35 : 0.08),lineWidth:2).padding(7))
                    if unlocked {
                        Text("\(number)").font(.system(size:26,weight:.black,design:.rounded))
                            .foregroundStyle(current ? Color(hex:0x673A25) : .white)
                            .shadow(color:current ? .white.opacity(0.3) : .black.opacity(0.4),radius:0,y:2)
                    } else {
                        Image(systemName:"lock.fill").font(.system(size:19,weight:.bold)).foregroundStyle(Color(hex:0xA388B8))
                    }
                    HStack(spacing:2) {
                        ForEach(0..<3) { index in
                            Image(systemName:"star.fill").font(.system(size:index == 1 ? 15 : 12,weight:.black))
                                .foregroundStyle(index<stars ? HarbourTheme.gold : Color(hex:0x654578))
                                .shadow(color:Color(hex:0x27133E),radius:0,y:2).offset(y:index == 1 ? -2 : 0)
                        }
                    }.offset(y:36).opacity(unlocked ? 1 : 0)
                }.frame(height:82)
                Text(level.title).font(.system(size:11,weight:.heavy,design:.rounded)).lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(unlocked ? .white : HarbourTheme.muted)
                    .padding(.horizontal,10).padding(.vertical,5).background(Color(hex:0x24143D).opacity(0.95),in:Capsule())
            }.frame(width:175,height:113).shadow(color:current ? tint.opacity(0.35) : .clear,radius:12)
        }.buttonStyle(JewelPressStyle()).disabled(!unlocked)
            .accessibilityLabel("Challenge \(number), \(level.title), \(unlocked ? "\(stars) stars, three stars in \(level.parMoves) moves" : "locked")")
            .accessibilityHint(unlocked ? "Play challenge \(number)" : "Complete challenge \(max(1,number-1)) to unlock")
    }
}
