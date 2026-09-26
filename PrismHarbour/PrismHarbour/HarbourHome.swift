import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

struct HarbourRootView: View {
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ticker = Timer.publish(every:0.25,on:.main,in:.common).autoconnect()
    var body: some View {
        ZStack {
            HarbourBackground()
            if store.playing { VoyageView().transition(.opacity) }
            else {
                VStack(spacing:0) {
                    Group {
                        if store.homeTab == 0 { HarbourHomeView() }
                        else if store.homeTab == 1 { VoyageChartView() }
                        else { CollectionView() }
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                    tabBar
                }.transition(.opacity)
            }
            if let toast = store.toast {
                VStack {
                    Spacer()
                    Text(toast).font(.system(size:14,weight:.bold,design:.rounded)).multilineTextAlignment(.center)
                        .padding(16).background(Color(hex:0x311F54),in:RoundedRectangle(cornerRadius:20))
                        .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(HarbourTheme.gold.opacity(0.55)))
                        .shadow(color:.black.opacity(0.3),radius:12,y:5)
                        .padding(.horizontal,26).padding(.bottom,store.playing ? 115 : 92)
                }.allowsHitTesting(false).transition(.opacity)
            }
        }.foregroundStyle(.white).tint(HarbourTheme.mint)
            .animation(reduceMotion ? nil : .easeInOut(duration:0.25),value:store.playing)
            .sheet(isPresented:$store.showSettings) { HarbourSettingsView() }
            .sheet(isPresented:$store.showHelp) { HowToPlayView() }
            .onReceive(ticker) { _ in store.tick() }
            .onChange(of:scenePhase) { _,phase in if phase != .active { store.suspend() } }
    }
    private var tabBar: some View {
        HStack(spacing:8) {
            tab(0,icon:"house.fill",title:"Harbour")
            tab(1,icon:"map.fill",title:"Voyage")
            tab(2,icon:"crown.fill",title:"Treasures")
        }.padding(.horizontal,18).padding(.top,11).padding(.bottom,6)
            .background(LinearGradient(colors:[Color(hex:0x3B255F),Color(hex:0x211339)],startPoint:.top,endPoint:.bottom))
            .overlay(alignment:.top) { Rectangle().fill(LinearGradient(colors:[.clear,HarbourTheme.gold.opacity(0.7),.clear],startPoint:.leading,endPoint:.trailing)).frame(height:2) }
    }
    private func tab(_ index:Int,icon:String,title:String) -> some View {
        let selected=store.homeTab == index
        return Button { store.homeTab=index; store.impact() } label: {
            VStack(spacing:5) {
                Image(systemName:icon).font(.system(size:selected ? 25 : 22,weight:.bold)).shadow(color:selected ? HarbourTheme.gold.opacity(0.35) : .clear,radius:7)
                Text(title).font(.system(size:11,weight:.heavy,design:.rounded))
            }.foregroundStyle(selected ? HarbourTheme.gold : Color(hex:0xBAA4D7))
                .frame(maxWidth:.infinity).frame(height:51)
                .background(selected ? Color.white.opacity(0.06) : .clear,in:RoundedRectangle(cornerRadius:16))
        }.buttonStyle(JewelPressStyle()).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct HarbourHomeView: View {
    @EnvironmentObject private var store: HarbourStore
    var body: some View {
        GeometryReader { geo in
            ZStack {
                homeScenery(size:geo.size)
                ScrollView(showsIndicators:false) {
                    VStack(spacing:18) {
                        HStack { CoinPill(coins:store.progress.coins); Spacer(); RoundIconButton(icon:"gearshape.fill",label:"Settings") { store.showSettings=true } }
                        HarbourWordmark().padding(.top,4)
                        Spacer(minLength:110)
                        launchControls
                        dailyQuest
                        Button { store.showHelp=true } label: {
                            Label("How to play",systemImage:"questionmark.circle.fill").font(.system(size:12,weight:.bold,design:.rounded)).foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal,18).padding(.vertical,9).background(Color(hex:0x24113E).opacity(0.7),in:Capsule())
                        }.buttonStyle(JewelPressStyle())
                    }.padding(.horizontal,24).padding(.top,10).padding(.bottom,15)
                        .frame(maxWidth:520).frame(minHeight:max(620,geo.size.height)).frame(maxWidth:.infinity)
                }
            }
        }
    }
    private func homeScenery(size:CGSize) -> some View {
        ZStack {
            Image("HarbourWorld").resizable().scaledToFill().frame(width:size.width,height:size.height+100).clipped().offset(y:-35)
            LinearGradient(stops:[.init(color:Color(hex:0x210C49).opacity(0.2),location:0),.init(color:.clear,location:0.4),.init(color:Color(hex:0x190C35).opacity(0.45),location:0.7),.init(color:Color(hex:0x180D2D).opacity(0.95),location:1)],startPoint:.top,endPoint:.bottom)
            HomeFloatingJewels()
            HarbourSparkles(density:30)
        }.ignoresSafeArea(edges:.top).accessibilityHidden(true)
    }
    private var launchControls: some View {
        VStack(spacing:13) {
            HStack(spacing:7) {
                Image(systemName:"location.fill").font(.system(size:10))
                Text(regionName(store.nextLevel.region).uppercased()).tracking(1.4)
            }.font(.system(size:11,weight:.heavy,design:.rounded)).foregroundStyle(HarbourTheme.gold)
                .padding(.horizontal,15).padding(.vertical,8).background(Color(hex:0x24113E).opacity(0.8),in:Capsule())
            Button { store.continueVoyage() } label: {
                HStack(spacing:10) {
                    Image(systemName:"play.fill").font(.system(size:22,weight:.heavy))
                    Text(isResuming ? "CONTINUE" : "PLAY").font(.system(size:28,weight:.black,design:.rounded)).tracking(1)
                    Spacer(minLength:10)
                    Text("\(displayLevel)").font(.system(size:22,weight:.black,design:.rounded)).frame(width:42,height:37)
                        .background(Color(hex:0x067A54).opacity(0.35),in:RoundedRectangle(cornerRadius:12))
                }.padding(.horizontal,26)
            }.buttonStyle(PrimaryButtonStyle(color:Color(hex:0x39D689))).accessibilityLabel(continueTitle)
            HStack(spacing:8) {
                Image(systemName:"star.fill").foregroundStyle(HarbourTheme.gold)
                Text("\(store.totalStars) stars")
                Text("•").foregroundStyle(HarbourTheme.gold)
                Text("\(store.completedCount) / 36 harbours")
            }.font(.system(size:12,weight:.bold,design:.rounded)).shadow(color:.black,radius:2,y:1)
        }
    }
    private var dailyQuest: some View {
        Button { store.start(LevelCatalog.daily(for:Date()),daily:true) } label: {
            HStack(spacing:12) {
                Image("PrizeChest").resizable().scaledToFill().frame(width:78,height:78).clipShape(RoundedRectangle(cornerRadius:19))
                    .overlay(RoundedRectangle(cornerRadius:19).strokeBorder(HarbourTheme.gold.opacity(0.55),lineWidth:1))
                VStack(alignment:.leading,spacing:5) {
                    Text("DAILY TREASURE").font(.system(size:10,weight:.black,design:.rounded)).tracking(1).foregroundStyle(HarbourTheme.gold)
                    Text(store.dailyCompleted ? "Treasure collected!" : "A new adventure").font(.system(size:17,weight:.heavy,design:.rounded)).foregroundStyle(.white)
                    Label(store.dailyCompleted ? "Play again" : "Earn 75 pearls",systemImage:store.dailyCompleted ? "checkmark.seal.fill" : "sparkle")
                        .font(.system(size:12,weight:.bold,design:.rounded)).foregroundStyle(Color(hex:0xE4CFF6))
                }
                Spacer(minLength:0)
                Image(systemName:"chevron.right").font(.system(size:17,weight:.heavy)).foregroundStyle(HarbourTheme.gold)
            }.padding(10)
                .background(LinearGradient(colors:[Color(hex:0x653887).opacity(0.95),Color(hex:0x321E54).opacity(0.97)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:27))
                .overlay(RoundedRectangle(cornerRadius:27).strokeBorder(LinearGradient(colors:[HarbourTheme.gold.opacity(0.9),Color(hex:0x7A4399)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:1.5))
                .shadow(color:.black.opacity(0.3),radius:8,y:5)
        }.buttonStyle(JewelPressStyle()).accessibilityLabel(store.dailyCompleted ? "Daily treasure completed. Play again" : "Daily treasure. Earn 75 pearls")
    }
    private var isResuming:Bool {
        guard let session=store.session else { return false }
        return !session.game.isComplete && (session.relaxed || session.remaining>0)
    }
    private var displayLevel:Int { isResuming ? (store.session?.game.level.id ?? store.nextLevel.id) : store.nextLevel.id }
    private var continueTitle:String {
        if isResuming,let session=store.session { return session.dailyKey == nil ? "Continue level \(session.game.level.id)" : "Continue daily tide" }
        return "Play level \(store.nextLevel.id)"
    }
}

private struct HomeFloatingJewels: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval:1.0/24.0,paused:reduceMotion || scenePhase != .active)) { timeline in
            GeometryReader { geo in
                let time=reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                floating(.coral,size:48,phase:time*0.8,angle:-14)
                    .position(x:geo.size.width*0.13,y:geo.size.height*0.44)
                floating(.violet,size:42,phase:time*0.7+2,angle:16)
                    .position(x:geo.size.width*0.86,y:geo.size.height*0.33)
                floating(.sky,size:29,phase:time*0.6+4,angle:22)
                    .position(x:geo.size.width*0.82,y:geo.size.height*0.54)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
    private func floating(_ color:PrismColor,size:CGFloat,phase:Double,angle:Double)->some View {
        PrismTile(color:color,symbols:true).frame(width:size,height:size)
            .rotationEffect(.degrees(angle+(reduceMotion ? 0 : sin(phase*0.5)*5)))
            .offset(y:reduceMotion ? 0 : CGFloat(sin(phase)*8))
            .shadow(color:color.tint.opacity(0.5),radius:9,y:5)
    }
}

private struct HarbourWordmark: View {
    var body: some View {
        VStack(spacing:-6) {
            HStack(spacing:8) {
                Image(systemName:"sparkle").font(.system(size:20,weight:.bold)).rotationEffect(.degrees(-12)).foregroundStyle(HarbourTheme.gold)
                Text("PRISM").font(.system(size:54,weight:.black,design:.rounded)).tracking(1.5)
                    .foregroundStyle(LinearGradient(colors:[.white,Color(hex:0xFFF7BA),Color(hex:0xFFD152)],startPoint:.top,endPoint:.bottom))
                    .shadow(color:Color(hex:0x7A351C),radius:0,y:3)
                    .shadow(color:Color(hex:0x291050),radius:0,y:6)
                Image(systemName:"sparkle").font(.system(size:20,weight:.bold)).rotationEffect(.degrees(12)).foregroundStyle(HarbourTheme.gold)
            }
            Text("HARBOUR").font(.system(size:32,weight:.black,design:.rounded)).tracking(3)
                .foregroundStyle(LinearGradient(colors:[.white,Color(hex:0xC8FFEA),Color(hex:0x50E7D0)],startPoint:.top,endPoint:.bottom))
                .shadow(color:Color(hex:0x165263),radius:0,y:3)
                .shadow(color:Color(hex:0x291050),radius:0,y:5)
        }.shadow(color:Color(hex:0x271039).opacity(0.8),radius:8,y:4)
            .frame(maxWidth:.infinity).minimumScaleFactor(0.75).lineLimit(1)
            .accessibilityElement(children:.ignore).accessibilityLabel("Prism Harbour")
    }
}

func regionName(_ region:Int) -> String {
    let names=LevelCatalog.regionNames
    return names[min(max(region,0),names.count-1)]
}

struct VoyageChartView: View {
    @EnvironmentObject private var store: HarbourStore
    var body: some View {
        VStack(spacing:0) {
            HStack {
                VStack(alignment:.leading,spacing:3) {
                    Eyebrow(text:"Your adventure",color:HarbourTheme.gold)
                    Text("The voyage").font(.system(size:30,weight:.black,design:.rounded))
                }
                Spacer(); CoinPill(coins:store.progress.coins)
            }.padding(.horizontal,24).padding(.top,13).padding(.bottom,16)
                .background(Color(hex:0x281643).opacity(0.8))
            ScrollViewReader { proxy in
                ScrollView(showsIndicators:false) {
                    VStack(spacing:0) {
                        ForEach(0..<3) { region in RegionRouteView(region:region) }
                        Text("More magic with every move").font(.system(size:13,weight:.bold,design:.rounded)).foregroundStyle(HarbourTheme.gold).padding(.bottom,30)
                    }.frame(maxWidth:540).frame(maxWidth:.infinity)
                }.onAppear {
                    if store.progress.highestUnlocked>1 { proxy.scrollTo("level-\(min(36,store.progress.highestUnlocked))",anchor:.center) }
                }
            }
        }
    }
}

private struct RegionRouteView: View {
    @EnvironmentObject private var store: HarbourStore
    let region:Int
    private let step:CGFloat=85
    private var tint:Color { [HarbourTheme.mint,Color(hex:0xFF86B8),HarbourTheme.lavender][region] }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment:.top) {
                routeScenery(width:geo.size.width)
                routePath(width:geo.size.width)
                ForEach(0..<12) { index in
                    let level=LevelCatalog.campaign[region*12+index]
                    RouteLevelNode(level:level,tint:tint).id("level-\(level.id)").position(point(index,width:geo.size.width))
                }
                regionHeading.padding(.top,22)
                routeDecorations(width:geo.size.width)
            }
        }.frame(height:1140)
    }
    private var regionHeading: some View {
        VStack(spacing:7) {
            Eyebrow(text:"Chapter 0\(region+1)",color:tint)
            Text(regionName(region)).font(.system(size:26,weight:.black,design:.rounded))
            HStack(spacing:5) {
                Image(systemName:"star.fill").foregroundStyle(HarbourTheme.gold)
                Text("\(stars) / 36").foregroundStyle(HarbourTheme.gold)
            }.font(.system(size:12,weight:.heavy,design:.rounded))
        }.padding(.horizontal,24).padding(.vertical,13)
            .background(Color(hex:0x24143D).opacity(0.9),in:RoundedRectangle(cornerRadius:26))
            .overlay(RoundedRectangle(cornerRadius:26).strokeBorder(tint.opacity(0.5),lineWidth:1.5))
    }
    private var stars:Int { ((region*12+1)...(region*12+12)).reduce(0) { $0+(store.progress.stars[$1] ?? 0) } }
    private func point(_ index:Int,width:CGFloat)->CGPoint {
        CGPoint(x:width*0.5+sin(Double(index)*0.86)*width*0.27,y:177+CGFloat(index)*step)
    }
    private func routeScenery(width:CGFloat)->some View {
        ZStack {
            Image("HarbourWorld").resizable().scaledToFill().frame(width:width,height:1140).clipped().opacity(region == 0 ? 0.52 : 0.30)
            LinearGradient(colors:[HarbourTheme.ink.opacity(0.7),Color(hex:0x271D4E).opacity(0.15),HarbourTheme.ink.opacity(0.8)],startPoint:.top,endPoint:.bottom)
            tint.opacity(0.06)
        }.accessibilityHidden(true)
    }
    private func routePath(width:CGFloat)->some View {
        Canvas { context,_ in
            var path=Path(); path.move(to:point(0,width:width))
            for index in 1..<12 {
                let a=point(index-1,width:width); let b=point(index,width:width)
                path.addCurve(to:b,control1:CGPoint(x:a.x,y:a.y+step*0.55),control2:CGPoint(x:b.x,y:b.y-step*0.55))
            }
            context.stroke(path,with:.color(Color(hex:0x171136).opacity(0.75)),style:StrokeStyle(lineWidth:23,lineCap:.round))
            context.stroke(path,with:.color(Color(hex:0xAA76AF).opacity(0.55)),style:StrokeStyle(lineWidth:14,lineCap:.round))
            context.stroke(path,with:.color(HarbourTheme.gold.opacity(0.65)),style:StrokeStyle(lineWidth:4,lineCap:.round,dash:[1,12]))
        }.accessibilityHidden(true)
    }
    private func routeDecorations(width:CGFloat)->some View {
        ZStack {
            ForEach(0..<5) { index in
                let x=width*(index%2 == 0 ? 0.12 : 0.86)
                let y:CGFloat=CGFloat(280+index*177)
                VStack(spacing:6) {
                    Image(systemName:["sparkles","sailboat.fill","moon.stars.fill","water.waves","sparkles"][index])
                        .font(.system(size:index%2 == 0 ? 26 : 34,weight:.bold)).foregroundStyle(tint.opacity(0.48))
                    if index%2 != 0 { Ellipse().fill(tint.opacity(0.17)).frame(width:44,height:5) }
                }.position(x:x,y:y)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct RouteLevelNode: View {
    @EnvironmentObject private var store:HarbourStore
    let level:Level
    let tint:Color
    private var unlocked:Bool { level.id<=store.progress.highestUnlocked }
    private var current:Bool { level.id==min(36,store.progress.highestUnlocked) }
    private var stars:Int { store.progress.stars[level.id] ?? 0 }
    var body: some View {
        Button { store.start(level) } label: {
            ZStack {
                if current {
                    Circle().strokeBorder(HarbourTheme.gold.opacity(0.28),lineWidth:7).frame(width:83,height:83)
                    Image(systemName:"arrowtriangle.down.fill").font(.system(size:15,weight:.black)).foregroundStyle(HarbourTheme.gold).offset(y:-57)
                }
                Circle().fill(Color(hex:0x1B1032).opacity(0.85)).frame(width:65,height:65).offset(y:5)
                Circle().fill(LinearGradient(colors:nodeColors,startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:64,height:64)
                    .overlay(Circle().strokeBorder(unlocked ? HarbourTheme.gold.opacity(0.95) : Color(hex:0x725587),lineWidth:3))
                    .overlay(Circle().strokeBorder(.white.opacity(unlocked ? 0.35 : 0.08),lineWidth:2).padding(7))
                if unlocked { Text("\(level.id)").font(.system(size:25,weight:.black,design:.rounded)).shadow(color:.black.opacity(0.5),radius:0,y:2) }
                else { Image(systemName:"lock.fill").font(.system(size:19,weight:.bold)).foregroundStyle(Color(hex:0xA388B8)) }
                if unlocked {
                    HStack(spacing:2) {
                        ForEach(0..<3) { index in Image(systemName:"star.fill").font(.system(size:index == 1 ? 15 : 12,weight:.black)).foregroundStyle(index<stars ? HarbourTheme.gold : Color(hex:0x6A457F)).shadow(color:Color(hex:0x27133E),radius:0,y:2).offset(y:index == 1 ? -2 : 0) }
                    }.offset(y:35)
                }
            }.frame(width:94,height:90).shadow(color:current ? tint.opacity(0.35) : .clear,radius:12)
        }.buttonStyle(JewelPressStyle()).disabled(!unlocked)
            .accessibilityLabel("Level \(level.id), \(level.title), \(unlocked ? "\(stars) stars" : "locked")")
    }
    private var nodeColors:[Color] {
        if current { return [Color(hex:0x8AFAD1),Color(hex:0x20B887),Color(hex:0x087B67)] }
        if unlocked { return [Color(hex:0xC28AFF),Color(hex:0x8350C6),Color(hex:0x552D84)] }
        return [Color(hex:0x57416B),Color(hex:0x322440)]
    }
}

struct CollectionView: View {
    @EnvironmentObject private var store: HarbourStore
    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(spacing:22) {
                HStack {
                    VStack(alignment:.leading,spacing:4) { Eyebrow(text:"Earned with every adventure",color:HarbourTheme.gold); Text("Your treasures").font(.system(size:30,weight:.black,design:.rounded)) }
                    Spacer()
                }
                treasureHero
                HStack(spacing:9) {
                    statistic("\(store.totalStars)","Stars",icon:"star.fill",color:HarbourTheme.gold)
                    statistic("\(store.completedCount)","Harbours",icon:"flag.fill",color:HarbourTheme.mint)
                    statistic("\(store.progress.coins)","Pearls",icon:"sparkle",color:HarbourTheme.lavender)
                }
                HStack { Eyebrow(text:"The prism collection",color:HarbourTheme.gold); Spacer(); Text("\(unlockedCount) / 6").font(.system(size:12,weight:.heavy,design:.rounded)).foregroundStyle(HarbourTheme.muted) }
                LazyVGrid(columns:[GridItem(.flexible(),spacing:14),GridItem(.flexible(),spacing:14)],spacing:16) {
                    ForEach(0..<6) { index in treasure(index) }
                }
                Text("Every treasure is earned by playing.").font(.system(size:12,weight:.bold,design:.rounded)).foregroundStyle(HarbourTheme.muted).padding(.bottom,10)
            }.padding(24).frame(maxWidth:600).frame(maxWidth:.infinity)
        }
    }
    private var unlockedCount:Int { [1,6,12,20,28,36].filter { store.completedCount >= $0 }.count }
    private var treasureHero:some View {
        ZStack(alignment:.bottom) {
            Image("PrizeChest").resizable().scaledToFill().frame(height:200).clipped()
            LinearGradient(colors:[.clear,Color(hex:0x29133F).opacity(0.95)],startPoint:.center,endPoint:.bottom)
            Text("A little magic. All yours.").font(.system(size:20,weight:.heavy,design:.rounded)).padding(.bottom,17).shadow(color:.black.opacity(0.6),radius:3)
            HarbourSparkles(density:12)
        }.frame(height:200).clipShape(RoundedRectangle(cornerRadius:28))
            .overlay(RoundedRectangle(cornerRadius:28).strokeBorder(HarbourTheme.gold.opacity(0.7),lineWidth:1.5))
    }
    private func treasure(_ index:Int)->some View {
        let required=[1,6,12,20,28,36][index]
        let unlocked=store.completedCount>=required
        let color=PrismColor.allCases[index]
        return VStack(spacing:12) {
            ZStack {
                Circle().fill(color.tint.opacity(unlocked ? 0.15 : 0.025)).frame(width:85,height:85)
                PrismTile(color:color,symbols:true).frame(width:57,height:57).rotationEffect(.degrees(-10)).opacity(unlocked ? 1 : 0.25)
                if !unlocked { Image(systemName:"lock.fill").font(.system(size:16,weight:.bold)).foregroundStyle(.white.opacity(0.7)).offset(x:25,y:28) }
            }
            Text(["First light","Sea glass","Coral keeper","Night navigator","Prism collector","Harbour master"][index]).font(.system(size:15,weight:.heavy,design:.rounded)).lineLimit(1).minimumScaleFactor(0.8)
            Text(unlocked ? "COLLECTED" : "Clear \(required) levels").font(.system(size:10,weight:.heavy,design:.rounded)).foregroundStyle(unlocked ? color.tint : HarbourTheme.muted)
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    Capsule().fill(.black.opacity(0.2))
                    Capsule().fill(color.tint.opacity(unlocked ? 0.8 : 0.45)).frame(width:geo.size.width*min(1,CGFloat(store.completedCount)/CGFloat(required)))
                }
            }.frame(height:5)
        }.padding(16).frame(maxWidth:.infinity)
            .background(LinearGradient(colors:[Color(hex:0x493064),Color(hex:0x2C1D43)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:25))
            .overlay(RoundedRectangle(cornerRadius:25).strokeBorder(unlocked ? color.tint.opacity(0.65) : .white.opacity(0.10),lineWidth:1.5))
    }
    private func statistic(_ value:String,_ title:String,icon:String,color:Color)->some View {
        VStack(spacing:7) {
            Image(systemName:icon).font(.system(size:18,weight:.bold)).foregroundStyle(color)
            Text(value).font(.system(size:24,weight:.black,design:.rounded)).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.system(size:11,weight:.bold,design:.rounded)).foregroundStyle(HarbourTheme.muted)
        }.frame(maxWidth:.infinity).padding(.vertical,16).background(Color(hex:0x38224F),in:RoundedRectangle(cornerRadius:21))
            .overlay(RoundedRectangle(cornerRadius:21).strokeBorder(color.opacity(0.3),lineWidth:1))
    }
}

struct HarbourSettingsView: View {
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReset=false
    var body: some View {
        NavigationStack {
            Form {
                Section("Make it your adventure") {
                    Toggle("Game sounds",isOn:$store.settings.sound)
                    Toggle("Haptic feedback",isOn:$store.settings.haptics)
                    Toggle("Prism symbols",isOn:$store.settings.symbols)
                }
                Section { Toggle("Calm mode",isOn:$store.settings.relaxed) }
                    footer: { Text("Take your time with no countdown. Applies when you start a new campaign level. The daily tide is always timed.") }
                Section {
                    HStack { Text("Version"); Spacer(); Text("2.0").foregroundStyle(.secondary) }
                    Text("Your voyage is saved on this device. Prism Harbour works entirely offline and does not collect personal data.").font(.footnote).foregroundStyle(.secondary)
                }
                Section { Button("Start a fresh voyage",role:.destructive) { confirmingReset=true } }
            }.scrollContentBackground(.hidden).background(HarbourTheme.ink).navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { store.save(); dismiss() } } }
                .onDisappear { store.save() }
                .confirmationDialog("Erase your progress and start again?",isPresented:$confirmingReset,titleVisibility:.visible) { Button("Reset all progress",role:.destructive) { store.resetProgress(); dismiss() } } message: { Text("This removes your stars, pearls, treasures, and current puzzle from this device.") }
        }.presentationDragIndicator(.visible).preferredColorScheme(.dark)
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:26) {
                    HarbourIllustration().frame(height:180)
                    Text("Let the magic flow.").font(.system(size:30,weight:.black,design:.rounded))
                    instruction("Slide your jewels","Drag a prism horizontally or vertically. Lift your finger to place it. Pieces move together and cannot pass through each other.","hand.draw.fill")
                    instruction("Find a matching gate","Guide each piece through a dock of the same colour and symbol. Its full width must fit the opening.","arrow.right.to.line")
                    instruction("Clear the harbour","Dock every piece before the tide runs out. Fewer moves earn more stars. Turn on Calm mode in Settings to play without a timer.","sparkles")
                    instruction("Give magic a boost","Undo is always free. A hint costs 15 pearls; 30 more seconds costs 30. Clear new levels to earn pearls.","wand.and.stars")
                    Text("You can also tap a prism and use the arrow controls, or its VoiceOver actions, to move one cell at a time.").font(.system(size:13)).foregroundStyle(HarbourTheme.muted)
                    Button("Let’s play!") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                }.padding(26)
            }.background(HarbourTheme.ink).navigationTitle("How to play").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDragIndicator(.visible).preferredColorScheme(.dark)
    }
    private func instruction(_ title:String,_ text:String,_ icon:String)->some View {
        HStack(alignment:.top,spacing:15) {
            Image(systemName:icon).font(.system(size:23,weight:.bold)).foregroundStyle(HarbourTheme.mint).frame(width:36)
            VStack(alignment:.leading,spacing:7) {
                Text(title).font(.system(size:19,weight:.heavy,design:.rounded))
                Text(text).font(.system(size:14)).foregroundStyle(HarbourTheme.muted).lineSpacing(4)
            }
        }
    }
}
