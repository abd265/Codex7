import SwiftUI

@main
struct DarjaTogetherApp:App {
    @StateObject private var store=LearningStore()
    @StateObject private var audio=AudioService()
    var body:some Scene {WindowGroup {RootView().environmentObject(store).environmentObject(audio).preferredColorScheme(.light)}}
}

struct RootView:View {
    @EnvironmentObject private var store:LearningStore
    @EnvironmentObject private var audio:AudioService
    @Environment(\.scenePhase) private var phase
    @State private var tab=ProcessInfo.processInfo.arguments.contains("--screenshot-journey") ? 1:ProcessInfo.processInfo.arguments.contains("--screenshot-play") ? 2:ProcessInfo.processInfo.arguments.contains("--screenshot-words") ? 3:0
    @State private var parent=false
    var body:some View {
        Group {
            if let error=store.loadError {ContentUnavailableView("Learning pack unavailable",systemImage:"book.closed",description:Text(error))}
            else if !store.preferences.didOnboard {WelcomeView()}
            else {
                TabView(selection:$tab) {
                    NavigationStack {TodayView().toolbar {ToolbarItem(placement:.topBarTrailing){parentButton}}}.tabItem{Label("Today",systemImage:"sun.max.fill")}.tag(0)
                    NavigationStack {JourneyView().toolbar{ToolbarItem(placement:.topBarTrailing){parentButton}}}.tabItem{Label("Journey",systemImage:"map.fill")}.tag(1)
                    NavigationStack {PlayRoomView()}.tabItem{Label("Play",systemImage:"sparkles")}.tag(2)
                    NavigationStack {LibraryView()}.tabItem{Label("My words",systemImage:"books.vertical.fill")}.tag(3)
                }.tint(DarjaTheme.teal).sheet(isPresented:$parent){ParentGateView()}
            }
        }.foregroundStyle(DarjaTheme.ink).onChange(of:phase){_,new in if new == .background {audio.stopAll()}}
    }
    private var parentButton:some View {Button{parent=true}label:{Image(systemName:"lock.shield").foregroundStyle(DarjaTheme.muted)}.accessibilityLabel("Parent dashboard").accessibilityIdentifier("parentButton")}
}

struct WelcomeView:View {
    @EnvironmentObject private var store:LearningStore
    @State private var name=""
    var body:some View {
        ScrollView {
            VStack(spacing:22) {
                HStack {Image(systemName:"sparkle");Text("DARJA TOGETHER").tracking(3)}.font(.system(.caption,design:.rounded,weight:.bold)).foregroundStyle(DarjaTheme.teal).padding(.top,24)
                TeacherAvatar().frame(width:190,height:190)
                VStack(spacing:10){Text("A little Darja.\nA world of connection.").font(.system(size:34,weight:.bold,design:.rounded)).multilineTextAlignment(.center);Text("Meet Nadia, your companion for an adventure in Algerian Arabic.").foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center)}
                PaperCard(color:DarjaTheme.mint) {VStack(alignment:.leading,spacing:14){Label("Start with listening and pictures",systemImage:"ear");Label("Small steps, at your own pace",systemImage:"leaf");Label("Stories, games and family moments",systemImage:"heart")}.font(.system(.subheadline,design:.rounded,weight:.medium))}
                TextField("Your explorer name (optional)",text:$name).textContentType(.nickname).padding(17).background(.white,in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("explorerName")
                Button("Let’s begin") {store.preferences.learnerName=name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Explorer":String(name.prefix(30));store.preferences.didOnboard=true}.buttonStyle(PrimaryAction()).accessibilityIdentifier("beginButton")
                Text("Made for a complete beginner. No account or ads.\nA parent can add your family’s own Darja voice.").font(.footnote).foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center)
                AlgeriaSkyline()
            }.padding(24).frame(maxWidth:560).frame(maxWidth:.infinity)
        }.background(DarjaTheme.cream).tint(DarjaTheme.teal)
    }
}

struct TodayView:View {
    @EnvironmentObject private var store:LearningStore
    @EnvironmentObject private var audio:AudioService
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack{VStack(alignment:.leading,spacing:5){Text("SALAM, \(store.preferences.learnerName.uppercased())").font(.system(.caption,design:.rounded,weight:.bold)).tracking(1.8).foregroundStyle(DarjaTheme.teal);Text("Let’s explore Darja.").font(.system(.largeTitle,design:.rounded,weight:.bold))};Spacer()}
                PaperCard(color:DarjaTheme.mint) {
                    VStack(alignment:.leading,spacing:16){
                        HStack(alignment:.center,spacing:15){VStack(alignment:.leading,spacing:10){TagPill(text:"YOUR DAILY ADVENTURE",color:.white.opacity(0.7));Text("Little words.\nBig adventures.").font(.system(size:29,weight:.bold,design:.rounded));Text("Listen, play and try it together.").font(.subheadline).foregroundStyle(DarjaTheme.muted)};TeacherAvatar(name:store.preferences.avatar.rawValue,talking:audio.isSpeaking).frame(width:110,height:110)}
                        if let week=store.currentWeek,let session=store.sessions(for:week).first(where:{!store.progress.completedSessions.contains($0.id)}) ?? week.sessions.first {
                            NavigationLink {LessonView(week:week,session:session)}label:{HStack{Image(systemName:"play.fill");Text("Start my adventure");Spacer();Text("5–8 min").font(.caption)}}.buttonStyle(PrimaryAction()).accessibilityIdentifier("startLesson")
                            Text("Week \(week.id) · \(week.title)").font(.system(.caption,design:.rounded,weight:.semibold)).foregroundStyle(DarjaTheme.teal)
                        }
                    }
                }
                HStack(spacing:12){stat("star.fill","\(store.totalStars)","Stars",DarjaTheme.gold);stat("checkmark.seal.fill","\(store.completedSessionCount)","Adventures",DarjaTheme.teal);stat("heart.fill","\(store.dueWords.count)","To revisit",DarjaTheme.coral)}
                if store.todayMinutes >= store.preferences.dailyMinutes {PaperCard(color:DarjaTheme.gold.opacity(0.2)){Label("You reached your gentle goal today. A lovely time for a break or a family conversation.",systemImage:"leaf.fill").font(.subheadline)}}
                SectionTitle(title:"A little discovery",subtitle:"A familiar word is a lovely place to start.")
                if let word=store.allWords.first {
                    NavigationLink {WordDetailView(word:word)}label:{PaperCard {HStack(spacing:18){Text(word.emoji).font(.system(size:45));VStack(alignment:.leading,spacing:6){Text(word.arabic).font(.system(size:29,weight:.bold));Text(word.english).font(.subheadline).foregroundStyle(DarjaTheme.muted)};Spacer();Image(systemName:"arrow.up.right").foregroundStyle(DarjaTheme.teal)}}}.buttonStyle(.plain)
                }
                SectionTitle(title:"Your learning passport",subtitle:"Six chapters. Your own pace. All yours to explore.")
                HStack(spacing:10){ForEach(Array((store.curriculum?.stages ?? []).prefix(3)),id:\.id){stage in VStack(spacing:10){Text(stage.emoji).font(.system(size:30));Text(stage.title).font(.system(.caption,design:.rounded,weight:.semibold)).multilineTextAlignment(.center)}.frame(maxWidth:.infinity,minHeight:94).padding(8).background(.white,in:RoundedRectangle(cornerRadius:19))}}
                if !store.earnedBadges.isEmpty {Text("\(store.earnedBadges.count) passport stamps collected ✨").font(.subheadline).foregroundStyle(DarjaTheme.teal)}
                AlgeriaSkyline().padding(.top,3)
            }.padding(22).frame(maxWidth:700).frame(maxWidth:.infinity)
        }.background(DarjaTheme.cream).navigationTitle("Darja Together").navigationBarTitleDisplayMode(.inline)
    }
    private func stat(_ icon:String,_ value:String,_ label:String,_ color:Color)->some View {VStack(spacing:8){Image(systemName:icon).foregroundStyle(color);Text(value).font(.system(.title2,design:.rounded,weight:.bold));Text(label).font(.caption).foregroundStyle(DarjaTheme.muted)}.frame(maxWidth:.infinity).padding(.vertical,16).background(.white,in:RoundedRectangle(cornerRadius:20))}
}

struct JourneyView:View {
    @EnvironmentObject private var store:LearningStore
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:24){SectionTitle(title:"Your Darja journey",subtitle:"36 weeks of tiny discoveries. Repeat or explore any week together.");ForEach(store.curriculum?.stages ?? [],id:\.id){stage in
        VStack(alignment:.leading,spacing:14){HStack{Text(stage.emoji).font(.largeTitle);VStack(alignment:.leading,spacing:4){Text(stage.title).font(.system(.title3,design:.rounded,weight:.bold));Text(stage.subtitle).font(.caption).foregroundStyle(DarjaTheme.muted)}}
            ForEach((store.curriculum?.weeks ?? []).filter{$0.stageId == stage.id},id:\.id){week in NavigationLink{WeekDetailView(week:week)}label:{HStack(spacing:14){Text(String(format:"%02d",week.id)).font(.system(.title3,design:.rounded,weight:.bold)).foregroundStyle(DarjaTheme.teal).frame(width:46,height:46).background(DarjaTheme.mint,in:RoundedRectangle(cornerRadius:14));VStack(alignment:.leading,spacing:4){Text(week.title).font(.system(.subheadline,design:.rounded,weight:.bold));Text("\(week.sessions.filter{store.progress.completedSessions.contains($0.id)}.count) of 5 adventures").font(.caption).foregroundStyle(DarjaTheme.muted)};Spacer();Image(systemName:"chevron.right").font(.caption).foregroundStyle(DarjaTheme.teal)}.padding(14).background(.white,in:RoundedRectangle(cornerRadius:20))}.buttonStyle(.plain)}
        }
    }}.padding(22).frame(maxWidth:700).frame(maxWidth:.infinity)}.background(DarjaTheme.cream).navigationTitle("Journey").navigationBarTitleDisplayMode(.inline)}
}
struct WeekDetailView:View {
    @EnvironmentObject private var store:LearningStore
    let week:WeekUnit
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:20){TagPill(text:"WEEK \(week.id)");SectionTitle(title:week.title,subtitle:week.goal);PaperCard(color:DarjaTheme.mint){VStack(alignment:.leading,spacing:10){Text(week.phrase).font(.system(size:30,weight:.bold)).frame(maxWidth:.infinity,alignment:.trailing);Text(week.phraseEnglish).font(.subheadline);Text(week.familyActivity).font(.footnote).foregroundStyle(DarjaTheme.muted)}};ForEach(Array(week.sessions.enumerated()),id:\.element.id){i,s in NavigationLink{LessonView(week:week,session:s)}label:{PaperCard {HStack(spacing:15){Image(systemName:store.progress.completedSessions.contains(s.id) ? "checkmark.circle.fill":"play.circle.fill").font(.title).foregroundStyle(DarjaTheme.teal);VStack(alignment:.leading,spacing:6){Text("ADVENTURE \(i+1)").font(.caption2).tracking(1.5).foregroundStyle(DarjaTheme.muted);Text(s.title).font(.headline);Text(s.instructions).font(.caption).foregroundStyle(DarjaTheme.muted).lineLimit(2)};Spacer();Image(systemName:"chevron.right").font(.caption)}}}.buttonStyle(.plain)};SectionTitle(title:"This week’s words");ForEach(store.words(ids:week.wordIds),id:\.id){w in NavigationLink{WordDetailView(word:w)}label:{WordRow(word:w)}.buttonStyle(.plain)}}.padding(22).frame(maxWidth:650).frame(maxWidth:.infinity)}.background(DarjaTheme.cream).navigationTitle("Week \(week.id)").navigationBarTitleDisplayMode(.inline)}
}
