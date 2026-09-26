import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

struct HarbourRootView: View {
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.scenePhase) private var scenePhase
    private let ticker = Timer.publish(every:0.25,on:.main,in:.common).autoconnect()
    var body: some View {
        ZStack {
            HarbourBackground()
            if store.playing { VoyageView() }
            else {
                VStack(spacing:0) {
                    if store.homeTab == 0 { HarbourHomeView() }
                    else if store.homeTab == 1 { VoyageChartView() }
                    else { CollectionView() }
                    tabBar
                }
            }
            if let toast = store.toast {
                VStack { Spacer(); Text(toast).font(.system(size:13,weight:.medium)).multilineTextAlignment(.center).padding(16).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:18)).padding(.horizontal,26).padding(.bottom,store.playing ? 115 : 90) }
                    .allowsHitTesting(false).transition(.opacity)
            }
        }.foregroundStyle(.white)
            .sheet(isPresented:$store.showSettings) { HarbourSettingsView() }
            .sheet(isPresented:$store.showHelp) { HowToPlayView() }
            .onReceive(ticker) { _ in store.tick() }
            .onChange(of:scenePhase) { _,phase in if phase != .active { store.suspend() } }
    }
    private var tabBar: some View {
        HStack(spacing:0) {
            tab(0,icon:"house.fill",title:"Harbour")
            tab(1,icon:"map.fill",title:"Voyage")
            tab(2,icon:"sparkles",title:"Treasures")
        }.padding(.top,12).padding(.bottom,5).background(HarbourTheme.ink.opacity(0.85))
            .overlay(alignment:.top) { Rectangle().fill(.white.opacity(0.06)).frame(height:1) }
    }
    private func tab(_ index:Int,icon:String,title:String) -> some View {
        Button { store.homeTab = index; store.impact() } label: {
            VStack(spacing:6) { Image(systemName:icon).font(.system(size:20)); Text(title).font(.system(size:10,weight:.semibold,design:.rounded)) }
                .foregroundStyle(store.homeTab == index ? HarbourTheme.lavender : HarbourTheme.muted.opacity(0.65)).frame(maxWidth:.infinity).frame(height:44)
        }.buttonStyle(.plain).accessibilityAddTraits(store.homeTab == index ? .isSelected : [])
    }
}

struct HarbourHomeView: View {
    @EnvironmentObject private var store: HarbourStore
    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(spacing:20) {
                HStack {
                    HStack(spacing:8) { Image(systemName:"safari").font(.system(size:24,weight:.light)).foregroundStyle(HarbourTheme.mint); Eyebrow(text:"A little escape") }
                    Spacer(); RoundIconButton(icon:"gearshape",label:"Settings") { store.showSettings = true }
                }
                VStack(spacing:6) {
                    Text("Prism Harbour").font(.system(size:38,weight:.bold,design:.serif)).tracking(-1.8).minimumScaleFactor(0.7).lineLimit(1)
                    Text("Find your flow. Follow the colours.").font(.system(size:14)).foregroundStyle(HarbourTheme.muted)
                }
                HarbourIllustration().frame(height:215).padding(.vertical,-10)
                VStack(spacing:14) {
                    HStack {
                        VStack(alignment:.leading,spacing:6) { Eyebrow(text:regionName(store.nextLevel.region)); Text("Your next little adventure").font(.system(size:18,weight:.semibold,design:.rounded)) }
                        Spacer(); CoinPill(coins:store.progress.coins)
                    }
                    Button { store.continueVoyage() } label: {
                        HStack { Image(systemName:"play.fill").font(.system(size:13)); Text(continueTitle); Spacer(); Image(systemName:"arrow.right") }.padding(.horizontal,22)
                    }.buttonStyle(PrimaryButtonStyle())
                    HStack(spacing:6) {
                        Image(systemName:"star.fill").foregroundStyle(HarbourTheme.gold)
                        Text("\(store.totalStars) stars collected").foregroundStyle(HarbourTheme.muted)
                        Text("·").foregroundStyle(HarbourTheme.muted)
                        Text("\(store.completedCount)/36 levels").foregroundStyle(HarbourTheme.muted)
                    }.font(.system(size:11,weight:.medium))
                }
                Button { store.start(LevelCatalog.daily(for:Date()),daily:true) } label: {
                    GlassPanel {
                        HStack(spacing:14) {
                            Image(systemName:store.dailyCompleted ? "checkmark.seal.fill" : "moon.stars.fill").font(.system(size:25)).foregroundStyle(HarbourTheme.gold).frame(width:48,height:48).background(HarbourTheme.gold.opacity(0.09),in:RoundedRectangle(cornerRadius:15))
                            VStack(alignment:.leading,spacing:5) { Text("The daily tide").font(.system(size:16,weight:.bold,design:.rounded)); Text(store.dailyCompleted ? "Beautifully sailed. Play again?" : "A new puzzle, every day.").font(.system(size:12)).foregroundStyle(HarbourTheme.muted) }
                            Spacer(); Image(systemName:"arrow.up.right").foregroundStyle(HarbourTheme.gold)
                        }
                    }
                }.buttonStyle(.plain)
                Button { store.showHelp = true } label: { Label("New here? Learn to sail",systemImage:"questionmark.circle").font(.system(size:12,weight:.medium)).foregroundStyle(HarbourTheme.muted) }.padding(.bottom,8)
            }.padding(.horizontal,24).padding(.top,12).frame(maxWidth:560).frame(maxWidth:.infinity)
        }
    }
    private var continueTitle:String {
        if let session = store.session, !session.game.isComplete, session.relaxed || session.remaining > 0 {
            return session.dailyKey == nil ? "Continue level \(session.game.level.id)" : "Continue daily tide"
        }
        return "Play level \(store.nextLevel.id)"
    }
}

func regionName(_ region:Int) -> String {
    let names = LevelCatalog.regionNames
    return names[min(max(region,0),names.count-1)]
}

struct VoyageChartView: View {
    @EnvironmentObject private var store: HarbourStore
    private let columns = Array(repeating:GridItem(.flexible(),spacing:12),count:4)
    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(alignment:.leading,spacing:25) {
                HStack {
                    VStack(alignment:.leading,spacing:8) { Eyebrow(text:"One prism at a time"); Text("Your voyage").font(.system(size:34,weight:.bold,design:.serif)) }
                    Spacer(); CoinPill(coins:store.progress.coins)
                }
                Text("Three quiet corners of the coast. Thirty-six reasons to slow down.").font(.system(size:14)).foregroundStyle(HarbourTheme.muted).lineSpacing(4)
                ForEach(0..<3) { region in
                    VStack(alignment:.leading,spacing:18) {
                        HStack {
                            Image(systemName:["light.beacon.max.fill","water.waves","moon.stars.fill"][region]).foregroundStyle([HarbourTheme.mint,Color(hex:0xFF959D),HarbourTheme.lavender][region]).font(.system(size:22))
                            VStack(alignment:.leading,spacing:4) { Eyebrow(text:"Chapter 0\(region+1)",color:HarbourTheme.muted); Text(regionName(region)).font(.system(size:20,weight:.semibold,design:.rounded)) }
                            Spacer()
                            Text("\(stars(in:region))/36").font(.system(size:12,weight:.bold)).foregroundStyle(HarbourTheme.gold)
                            Image(systemName:"star.fill").font(.system(size:10)).foregroundStyle(HarbourTheme.gold)
                        }
                        LazyVGrid(columns:columns,spacing:14) {
                            ForEach(Array(LevelCatalog.campaign[(region*12)..<(region*12+12)]),id:\.id) { level in levelButton(level) }
                        }
                    }.padding(18).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).stroke(.white.opacity(0.055)))
                }
            }.padding(24).frame(maxWidth:600).frame(maxWidth:.infinity)
        }
    }
    private func stars(in region:Int)->Int { ((region*12+1)...(region*12+12)).reduce(0) { $0 + (store.progress.stars[$1] ?? 0) } }
    private func levelButton(_ level:Level) -> some View {
        let unlocked = level.id <= store.progress.highestUnlocked
        let stars = store.progress.stars[level.id] ?? 0
        let next = level.id == store.progress.highestUnlocked
        return Button { store.start(level) } label: {
            VStack(spacing:8) {
                ZStack {
                    RoundedRectangle(cornerRadius:18).fill(next ? HarbourTheme.lavender : Color.white.opacity(unlocked ? 0.085 : 0.025)).frame(height:57)
                    if unlocked { Text("\(level.id)").font(.system(size:20,weight:.bold,design:.rounded)).foregroundStyle(next ? HarbourTheme.ink : .white) }
                    else { Image(systemName:"lock.fill").font(.system(size:14)).foregroundStyle(HarbourTheme.muted.opacity(0.35)) }
                }.overlay(RoundedRectangle(cornerRadius:18).stroke(next ? .white.opacity(0.3) : .white.opacity(0.04)))
                HStack(spacing:3) { ForEach(0..<3) { star in Image(systemName:"star.fill").font(.system(size:7)).foregroundStyle(star < stars ? HarbourTheme.gold : Color.white.opacity(0.12)) } }
            }
        }.buttonStyle(.plain).disabled(!unlocked).accessibilityLabel("Level \(level.id), \(level.title), \(unlocked ? "\(stars) stars" : "locked")")
    }
}

struct CollectionView: View {
    @EnvironmentObject private var store: HarbourStore
    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(alignment:.leading,spacing:24) {
                VStack(alignment:.leading,spacing:8) { Eyebrow(text:"Little things, well earned"); Text("Your treasures").font(.system(size:34,weight:.bold,design:.serif)) }
                GlassPanel {
                    HStack {
                        statistic("\(store.totalStars)","Stars",icon:"star.fill",color:HarbourTheme.gold)
                        Spacer(); statistic("\(store.completedCount)","Levels",icon:"flag.fill",color:HarbourTheme.mint)
                        Spacer(); statistic("\(store.progress.coins)","Pearls",icon:"sparkle",color:HarbourTheme.lavender)
                    }
                }
                Text("THE HARBOUR COLLECTION").font(.system(size:10,weight:.bold)).tracking(2).foregroundStyle(HarbourTheme.muted)
                ForEach(0..<6) { index in
                    let required = [1,6,12,20,28,36][index]
                    let unlocked = store.completedCount >= required
                    let color = PrismColor.allCases[index]
                    GlassPanel {
                        HStack(spacing:18) {
                            PrismTile(color:color,symbols:true).frame(width:52,height:52).rotationEffect(.degrees(-8)).opacity(unlocked ? 1 : 0.2)
                            VStack(alignment:.leading,spacing:5) { Text(["First light","Sea glass","Coral keeper","Night navigator","Prism collector","Harbour master"][index]).font(.system(size:17,weight:.semibold,design:.rounded)); Text(unlocked ? "Found on your voyage" : "Clear \(required) levels to discover").font(.system(size:12)).foregroundStyle(HarbourTheme.muted) }
                            Spacer(); Image(systemName:unlocked ? "checkmark.seal.fill" : "lock.fill").foregroundStyle(unlocked ? color.tint : HarbourTheme.muted.opacity(0.4))
                        }
                    }
                }
                Text("All treasures are earned by playing. No purchases, ads, or accounts.").font(.system(size:12)).foregroundStyle(HarbourTheme.muted).multilineTextAlignment(.center).frame(maxWidth:.infinity)
            }.padding(24).frame(maxWidth:600).frame(maxWidth:.infinity)
        }
    }
    private func statistic(_ value:String,_ title:String,icon:String,color:Color)->some View {
        VStack(spacing:8) { Image(systemName:icon).foregroundStyle(color); Text(value).font(.system(size:26,weight:.bold,design:.rounded)); Text(title).font(.system(size:11)).foregroundStyle(HarbourTheme.muted) }
    }
}

struct HarbourSettingsView: View {
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReset = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Make yourself at home") {
                    Toggle("Gentle sounds",isOn:$store.settings.sound)
                    Toggle("Haptic feedback",isOn:$store.settings.haptics)
                    Toggle("Prism symbols",isOn:$store.settings.symbols)
                }
                Section {
                    Toggle("Calm mode",isOn:$store.settings.relaxed)
                } footer: { Text("Take your time with no countdown. Applies when you start a new campaign level. The daily tide is always timed.") }
                Section {
                    HStack { Text("Version"); Spacer(); Text("1.0").foregroundStyle(.secondary) }
                    HStack { Text("Made for"); Spacer(); Text("A moment of calm").foregroundStyle(.secondary) }
                    Text("Your voyage is saved on this device. Prism Harbour works entirely offline and does not collect personal data.").font(.footnote).foregroundStyle(.secondary)
                }
                Section { Button("Start a fresh voyage",role:.destructive) { confirmingReset = true } }
            }.scrollContentBackground(.hidden).background(HarbourTheme.ink).navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { store.save(); dismiss() } } }
                .onDisappear { store.save() }
                .confirmationDialog("Erase your progress and start again?",isPresented:$confirmingReset,titleVisibility:.visible) { Button("Reset all progress",role:.destructive) { store.resetProgress(); dismiss() } } message: { Text("This removes your stars, pearls, treasures, and current puzzle from this device.") }
        }.presentationDragIndicator(.visible)
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:26) {
                    HarbourIllustration().frame(height:180)
                    Text("A place for every prism.").font(.system(size:30,weight:.bold,design:.serif))
                    instruction("01","Slide, don’t rotate","Drag a prism horizontally or vertically. Lift your finger to place it. Pieces move together and cannot pass through each other.","hand.draw.fill")
                    instruction("02","Find its harbour","Guide each piece through a dock of the same colour and symbol. Its full width must fit the opening.","arrow.right.to.line")
                    instruction("03","Clear the waters","Dock every piece before the tide runs out. Fewer moves earn more stars. Turn on Calm mode in Settings to play without a timer.","sparkles")
                    instruction("04","A little help","Undo is always free. A hint costs 15 pearls; 30 more seconds costs 30. Clear new levels to earn pearls.","lifepreserver")
                    Text("You can also tap a prism and use the arrow controls, or its VoiceOver actions, to move one cell at a time.").font(.system(size:13)).foregroundStyle(HarbourTheme.muted)
                    Button("Let’s sail") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                }.padding(26)
            }.background(HarbourTheme.ink).navigationTitle("How to play").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDragIndicator(.visible)
    }
    private func instruction(_ number:String,_ title:String,_ text:String,_ icon:String)->some View {
        HStack(alignment:.top,spacing:15) {
            Image(systemName:icon).font(.system(size:22)).foregroundStyle(HarbourTheme.mint).frame(width:35)
            VStack(alignment:.leading,spacing:7) { Text(title).font(.system(size:18,weight:.bold,design:.rounded)); Text(text).font(.system(size:14)).foregroundStyle(HarbourTheme.muted).lineSpacing(4) }
        }
    }
}
