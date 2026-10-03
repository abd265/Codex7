import SwiftUI

struct LessonView:View {
    @EnvironmentObject private var store:LearningStore
    @EnvironmentObject private var audio:AudioService
    @Environment(\.dismiss) private var dismiss
    let week:WeekUnit
    let session:LessonSession
    @State private var phase=0
    @State private var card=0
    @State private var selected:String?
    @State private var correct=false
    @State private var triedSpeaking=false
    @State private var practicedSpeaking=false
    @State private var practicedWriting=false
    @State private var finished=false
    @State private var started=Date()
    @State private var options:[DarjaWord]=[]
    @State private var strokes:[[CGPoint]]=[]
    @State private var currentStroke:[CGPoint]=[]
    private var words:[DarjaWord] {Array(store.words(ids:session.wordIds).prefix(5))}
    private var word:DarjaWord? {words.isEmpty ? nil:words[min(card,words.count-1)]}
    private var title:String { ["Meet a new word","Listen & find","Your turn to speak","A tiny bit of Arabic"][min(phase,3)] }
    var body:some View {
        ScrollView {
            VStack(spacing:22) {
                if finished {celebration}
                else if let word {
                    HStack {TagPill(text:"\(min(card+1,words.count)) OF \(words.count) WORDS");Spacer();Text("Week \(week.id)").font(.caption).foregroundStyle(DarjaTheme.muted)}
                    ProgressView(value:Double(card*4+phase),total:Double(max(1,words.count*4))).tint(DarjaTheme.teal)
                    if card == 0 && phase == 0 {Text(session.instructions).font(.subheadline).foregroundStyle(DarjaTheme.muted).frame(maxWidth:.infinity,alignment:.leading)}
                    HStack(spacing:13){TeacherAvatar(name:store.preferences.avatar.rawValue,talking:audio.isSpeaking).frame(width:65,height:65);VStack(alignment:.leading,spacing:5){Text(title).font(.system(.title3,design:.rounded,weight:.bold));Text(instruction).font(.subheadline).foregroundStyle(DarjaTheme.muted)};Spacer()}
                    if phase == 0 {discovery(word)}
                    if phase == 1 {listening(word)}
                    if phase == 2 {speaking(word)}
                    if phase == 3 {writing(word)}
                    if !audio.status.isEmpty {Text(audio.status).font(.caption).foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center)}
                    if phase != 1 || correct {
                        Button(phase == 3 && card == words.count-1 ? "Collect my star":"Continue") {advance()}.buttonStyle(PrimaryAction()).accessibilityIdentifier("lessonNext")
                    }
                    Text("Try it in your own time. You can listen as often as you like.").font(.caption).foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center)
                } else {ContentUnavailableView("No words in this activity",systemImage:"book")}
            }.padding(22).frame(maxWidth:630).frame(maxWidth:.infinity)
        }.background(DarjaTheme.cream).navigationTitle(session.title).navigationBarTitleDisplayMode(.inline)
            .onAppear{started=Date();prepareOptions()}.onDisappear{audio.stopAll()}
    }
    private var instruction:String {
        switch phase {case 0:return "Look at the picture, then listen.";case 1:return "Listen to the word. Tap the matching picture.";case 2:return "Listen again, then have a go. Every try matters.";default:return week.id < 4 ? "Meet the shape. You don’t need to read it yet.":"Follow the word from right to left with your finger."}
    }
    private func discovery(_ w:DarjaWord)->some View {
        PaperCard {VStack(spacing:20){Text(w.emoji).font(.system(size:98)).frame(height:130).frame(maxWidth:.infinity).background(DarjaTheme.mint.opacity(0.65),in:RoundedRectangle(cornerRadius:24));if store.preferences.showArabic {Text(w.arabic).font(.system(size:42,weight:.bold)).multilineTextAlignment(.center).environment(\.layoutDirection,.rightToLeft)};if store.preferences.showTransliteration {Text(w.transliteration).font(.title3).foregroundStyle(DarjaTheme.teal)};Text(meaning(w)).font(.system(.title3,design:.rounded,weight:.semibold));hearButton(w);voiceLabel(w)}.frame(maxWidth:.infinity)}
    }
    private func listening(_ w:DarjaWord)->some View {
        VStack(spacing:20){Button {audio.speak(w,helperLanguage:store.preferences.helperLanguage)}label:{Label("Listen to the mystery word",systemImage:"speaker.wave.2.fill")}.buttonStyle(PrimaryAction()).accessibilityIdentifier("listenPrompt");voiceLabel(w)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:14){ForEach(options,id:\.id){choice in
                Button {selected=choice.id;correct=choice.id == w.id;if correct {store.reviewWord(w.id,remembered:true)}}label:{VStack(spacing:8){Text(choice.emoji).font(.system(size:60)).frame(height:80);if selected == choice.id {Image(systemName:correct ? "checkmark.circle.fill":"arrow.counterclockwise.circle.fill").foregroundStyle(correct ? DarjaTheme.teal:DarjaTheme.coral)}else{Text(" ").font(.caption)}}.frame(maxWidth:.infinity).padding(15).background(selected == choice.id && correct ? DarjaTheme.mint:.white,in:RoundedRectangle(cornerRadius:23)).overlay(RoundedRectangle(cornerRadius:23).stroke(selected == choice.id ? DarjaTheme.teal:.clear,lineWidth:2))}.buttonStyle(.plain).accessibilityLabel(choice.english).accessibilityIdentifier("answer-"+choice.id).disabled(correct)
            }}
            if selected != nil {Text(correct ? "You found it! \(w.arabic)":"Let’s listen once more and try another picture.").font(.system(.headline,design:.rounded)).foregroundStyle(correct ? DarjaTheme.teal:DarjaTheme.coral).multilineTextAlignment(.center)}
        }
    }
    private func speaking(_ w:DarjaWord)->some View {
        PaperCard(color:DarjaTheme.lilac.opacity(0.65)){VStack(spacing:20){Text(w.emoji).font(.system(size:72));Text(w.arabic).font(.system(size:35,weight:.bold));if store.preferences.showTransliteration {Text(w.transliteration).foregroundStyle(DarjaTheme.muted)};hearButton(w)
            if store.preferences.microphoneEnabled {
                Button {if audio.isRecording {audio.stopRecording();triedSpeaking=true}else{Task{await audio.startRecording(wordId:"practice-"+w.id)}}}label:{Label(audio.isRecording ? "Stop recording":"Record my try",systemImage:audio.isRecording ? "stop.circle.fill":"mic.fill")}.buttonStyle(PrimaryAction(color:DarjaTheme.coral))
                if audio.hasRecording(wordId:"practice-"+w.id) {Button{audio.playRecording(wordId:"practice-"+w.id)}label:{Label("Hear my recording",systemImage:"play.circle.fill")}.font(.headline).padding(8)}
                Text("Your voice stays on this device. Listen back together; the app does not grade pronunciation.").font(.caption).foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center)
            } else {Text("Say it to Nadia or someone in your family. A parent can enable recording later.").font(.subheadline).multilineTextAlignment(.center)}
            Button {triedSpeaking.toggle()}label:{Label(triedSpeaking ? "I had a go!":"I tried saying it",systemImage:triedSpeaking ? "checkmark.circle.fill":"bubble.left")}.font(.headline).padding(12).background(.white.opacity(0.75),in:Capsule()).accessibilityIdentifier("speakingAttempt")
        }.frame(maxWidth:.infinity)}
    }
    private func writing(_ w:DarjaWord)->some View {
        VStack(spacing:16){
            ZStack {
                RoundedRectangle(cornerRadius:25).fill(.white)
                VStack(spacing:12){Text(w.arabic).font(.system(size:60,weight:.medium)).minimumScaleFactor(0.4).foregroundStyle(DarjaTheme.teal.opacity(0.2)).padding(.horizontal,15);Image(systemName:"arrow.left").foregroundStyle(DarjaTheme.teal.opacity(0.2)).font(.largeTitle)}
                Canvas {context,_ in for stroke in strokes+[currentStroke] {guard let first=stroke.first else{continue};var p=Path();p.move(to:first);for point in stroke.dropFirst(){p.addLine(to:point)};context.stroke(p,with:.color(DarjaTheme.teal),style:StrokeStyle(lineWidth:5,lineCap:.round,lineJoin:.round))}}
                    .gesture(DragGesture(minimumDistance:0).onChanged{value in currentStroke.append(value.location)}.onEnded{_ in if !currentStroke.isEmpty{strokes.append(currentStroke)};currentStroke=[]})
                    .accessibilityLabel("Finger drawing area. Trace the word or draw its meaning.")
                    .accessibilityIdentifier("tracingCanvas")
                    .accessibilityElement()
            }.frame(height:230)
            HStack{Text("← Arabic flows right to left").font(.caption).foregroundStyle(DarjaTheme.muted);Spacer();Button("Clear"){strokes=[];currentStroke=[]}.font(.subheadline)}
            Text(week.id < 4 ? "Look, trace, or just notice. This is a first hello to Arabic writing.":"This is free tracing practice. A family member can help with letter shapes and dots.").font(.subheadline).foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center)
        }
    }
    private func hearButton(_ w:DarjaWord)->some View {Button {audio.speak(w,helperLanguage:store.preferences.helperLanguage)}label:{Label("Hear it",systemImage:"speaker.wave.2.fill")}.font(.system(.headline,design:.rounded)).foregroundStyle(DarjaTheme.teal).padding(.horizontal,25).padding(.vertical,13).background(DarjaTheme.mint,in:Capsule()).accessibilityIdentifier("hearWord")}
    private func voiceLabel(_ w:DarjaWord)->some View {Text(audio.hasRecording(wordId:"family-"+w.id) ? "Your family’s voice":"Device Arabic voice · pronunciation may differ from Darja").font(.caption2).foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center)}
    private func meaning(_ w:DarjaWord)->String {w.meaning(in:store.preferences.helperLanguage)}
    private func prepareOptions(){guard let w=word else{return};var distinct=Set([w.emoji]);let pool=store.words(ids:week.wordIds+week.reviewWordIds)+store.allWords;var others:[DarjaWord]=[];for candidate in pool where candidate.id != w.id {if distinct.insert(candidate.emoji).inserted {others.append(candidate)};if others.count == 3 {break}};options=([w]+others).shuffled()}
    private func advance(){
        audio.stopAll()
        practicedSpeaking = practicedSpeaking || triedSpeaking
        practicedWriting = practicedWriting || !strokes.isEmpty
        if phase < 3 {phase+=1;if phase == 1 {prepareOptions()}}
        else if card+1 < words.count {card+=1;phase=0;selected=nil;correct=false;triedSpeaking=false;strokes=[];prepareOptions()}
        else {
            var practiced:[Skill]=[.listening,.vocabulary]
            if practicedSpeaking {practiced.append(.speaking)}
            if practicedWriting {practiced.append(.writing)}
            store.completeSession(session,weekId:week.id,skills:practiced,minutes:max(1,Int(Date().timeIntervalSince(started)/60)))
            finished=true
        }
    }
    private var celebration:some View {VStack(spacing:25){Image(systemName:"star.circle.fill").font(.system(size:100)).foregroundStyle(DarjaTheme.gold).padding(.top,30);Text("A little closer, together.").font(.system(.largeTitle,design:.rounded,weight:.bold)).multilineTextAlignment(.center);Text("You explored \(words.count) words today. Take them into your world!").foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center);PaperCard(color:DarjaTheme.mint){VStack(alignment:.leading,spacing:12){Label("YOUR FAMILY MOMENT",systemImage:"heart.fill").font(.caption).fontWeight(.bold);Text(week.familyActivity).font(.headline);Text(week.phrase).font(.system(size:28,weight:.bold)).frame(maxWidth:.infinity,alignment:.trailing)}};Button("Back to my adventure"){dismiss()}.buttonStyle(PrimaryAction()).accessibilityIdentifier("finishLesson");extraActivity}}
    @ViewBuilder private var extraActivity:some View {
        PaperCard {VStack(alignment:.leading,spacing:14){Text("One more little adventure?").font(.headline);Text(session.instructions).font(.subheadline).foregroundStyle(DarjaTheme.muted)
            if let storyID=week.storyId,let story=store.story(id:storyID),session.kind == "story" {NavigationLink{StoryReaderView(story:story)}label:{Label("Explore this week’s story",systemImage:"book.fill")}}
            else if session.kind == "play" {NavigationLink{MemoryGameView()}label:{Label("Play picture pairs",systemImage:"square.grid.2x2.fill")}}
            else if session.kind == "family" {NavigationLink{FamilyGameView()}label:{Label("Play together",systemImage:"person.2.fill")}}
            else if session.kind == "review" {NavigationLink{ReviewView()}label:{Label("Visit my word garden",systemImage:"leaf.fill")}}
            else if session.kind == "speak" {NavigationLink{ConversationView()}label:{Label("Try a little conversation",systemImage:"bubble.left.fill")}}
            else {NavigationLink{TreasureView()}label:{Label("Find Darja around me",systemImage:"key.fill")}}
        }}
    }
}

struct WordRow:View {
    let word:DarjaWord
    var body:some View {HStack(spacing:14){Text(word.emoji).font(.system(size:35)).frame(width:55,height:55).background(DarjaTheme.mint.opacity(0.6),in:RoundedRectangle(cornerRadius:17));VStack(alignment:.leading,spacing:5){Text(word.arabic).font(.system(size:23,weight:.semibold));Text(word.english).font(.subheadline).foregroundStyle(DarjaTheme.muted)};Spacer();Image(systemName:"chevron.right").font(.caption).foregroundStyle(DarjaTheme.teal)}.padding(14).background(.white,in:RoundedRectangle(cornerRadius:22))}
}
struct WordDetailView:View {
    @EnvironmentObject private var store:LearningStore
    @EnvironmentObject private var audio:AudioService
    let word:DarjaWord
    var body:some View {ScrollView {VStack(spacing:23){Text(word.emoji).font(.system(size:105)).padding(.top,30);Text(word.arabic).font(.system(size:44,weight:.bold)).multilineTextAlignment(.center);if store.preferences.showTransliteration {Text(word.transliteration).font(.title3).foregroundStyle(DarjaTheme.teal)};Text(word.meaning(in:store.preferences.helperLanguage)).font(.system(.title2,design:.rounded,weight:.semibold)).multilineTextAlignment(.center);Button{audio.speak(word,helperLanguage:store.preferences.helperLanguage)}label:{Label("Hear this word",systemImage:"speaker.wave.2.fill")}.buttonStyle(PrimaryAction());Text(audio.hasRecording(wordId:"family-"+word.id) ? "Your family’s voice":"Device Arabic voice · may differ from Darja").font(.caption).foregroundStyle(DarjaTheme.muted);if !word.note.isEmpty {PaperCard(color:DarjaTheme.mint){Text(word.note).font(.subheadline)}};if !audio.status.isEmpty {Text(audio.status).font(.caption)};Button{store.toggleBookmark(word.id)}label:{Label(store.isBookmarked(word.id) ? "Saved in my collection":"Save to my collection",systemImage:store.isBookmarked(word.id) ? "bookmark.fill":"bookmark")}.font(.headline).padding();TagPill(text:word.category.capitalized)}.padding(24).frame(maxWidth:620).frame(maxWidth:.infinity)}.background(DarjaTheme.cream).navigationTitle("Word discovery").navigationBarTitleDisplayMode(.inline).onDisappear{audio.stopAll()}}
}
