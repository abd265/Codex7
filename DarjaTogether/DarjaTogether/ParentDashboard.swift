import SwiftUI

struct ParentGateView:View {
    @EnvironmentObject private var store:LearningStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var pin=""
    @State private var confirm=""
    @State private var unlocked=false
    @State private var error=""
    var body:some View {NavigationStack {
        Group {
            if unlocked {ParentDashboardView()}
            else {ScrollView{VStack(spacing:23){Image(systemName:"lock.shield.fill").font(.system(size:65)).foregroundStyle(DarjaTheme.teal).padding(.top,35);Text(store.hasParentPIN ? "A moment for grown-ups":"Set up your parent space").font(.system(.title,design:.rounded,weight:.bold)).multilineTextAlignment(.center);Text(store.hasParentPIN ? "Enter your four-digit parent PIN.":"Grown-ups: choose a four-digit PIN to protect microphone settings, family recordings and progress controls.").foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center);SecureField("Four-digit PIN",text:$pin).keyboardType(.numberPad).textContentType(.oneTimeCode).padding(18).background(.white,in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("parentPIN");if !store.hasParentPIN {SecureField("Confirm PIN",text:$confirm).keyboardType(.numberPad).padding(18).background(.white,in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("confirmPIN")};if !error.isEmpty{Text(error).font(.subheadline).foregroundStyle(DarjaTheme.coral)};Button(store.hasParentPIN ? "Unlock parent space":"Save PIN & continue"){unlock()}.buttonStyle(PrimaryAction()).accessibilityIdentifier("unlockParents");Text("Keep your PIN somewhere safe. Closing this panel locks it again.").font(.caption).foregroundStyle(DarjaTheme.muted).multilineTextAlignment(.center)}.padding(25).frame(maxWidth:520).frame(maxWidth:.infinity)}.background(DarjaTheme.cream)}
        }.toolbar{ToolbarItem(placement:.topBarTrailing){Button("Done"){dismiss()}}}
    }.tint(DarjaTheme.teal).onChange(of:phase){_,new in if new == .background {unlocked=false;pin="";confirm=""}}}
    private func unlock(){if store.hasParentPIN {if store.verifyParentPIN(pin){unlocked=true;error=""}else{error=store.parentPINLockedUntil != nil ? "Please wait a minute before trying again.":"That PIN did not match. Try again.";pin=""}}else{guard pin == confirm else{error="The PINs don’t match.";return};if store.setParentPIN(pin){unlocked=true;error=""}else{error="Use exactly four digits."}}}
}

struct ParentDashboardView:View {
    @EnvironmentObject private var store:LearningStore
    @EnvironmentObject private var audio:AudioService
    @State private var reset=false
    @State private var newPIN=""
    @State private var pinMessage=""
    private var progressReport:String {
        "Darja Together — family practice report\nExplorer: \(store.preferences.learnerName)\nDate: \(Date().formatted(date:.abbreviated,time:.omitted))\nActivities completed: \(store.completedSessionCount) of 180\nStars: \(store.totalStars)\n" + Skill.allCases.map{"\($0.title): \(store.skillCount($0)) practice activities"}.joined(separator:"\n") + "\nPractice counts record participation and self-report. They are not proficiency or pronunciation scores."
    }
    var body:some View {Form {
        Section {VStack(alignment:.leading,spacing:8){Text("Small steps, real connection.").font(.system(.title2,design:.rounded,weight:.bold));Text("Designed for complete beginners, with simple language and a gentle pace.").font(.subheadline).foregroundStyle(DarjaTheme.muted)}}
        Section("Learning at a glance") {
            LabeledContent("Adventures completed",value:"\(store.completedSessionCount) / 180")
            LabeledContent("Today’s logged practice",value:"About \(store.todayMinutes) min")
            ForEach(Skill.allCases){skill in HStack{Text(skill.emoji);Text(skill.title);Spacer();Text("\(store.skillCount(skill)) activities").foregroundStyle(DarjaTheme.teal)}}
            Text("These counts reflect completed activities and self-reported practice, not mastery. Shared reading, copying and independent communication need your own observation.").font(.caption).foregroundStyle(DarjaTheme.muted)
            ShareLink(item:progressReport){Label("Share practice report",systemImage:"square.and.arrow.up")}
        }
        if !store.earnedBadges.isEmpty {Section("Learning passport") {ForEach(store.earnedBadges){badge in HStack{Text(badge.emoji).font(.title);VStack(alignment:.leading){Text(badge.title).font(.headline);Text(badge.description).font(.caption).foregroundStyle(DarjaTheme.muted)}}}}}
        Section("Your explorer") {
            TextField("Explorer name",text:$store.preferences.learnerName)
            Picker("Companion",selection:$store.preferences.avatar){ForEach(LearnerAvatar.allCases){avatar in Text(avatar.displayName).tag(avatar)}}
            Picker("Meaning hints",selection:$store.preferences.helperLanguage){ForEach(HelperLanguage.allCases){language in Text(language.displayName).tag(language)}}
            Toggle("Show pronunciation hints",isOn:$store.preferences.showTransliteration)
            Toggle("Show script on discovery cards",isOn:$store.preferences.showArabic)
            Text("Instruction text is in English. Meaning hints can be English or French. Arabic remains visible in activities that introduce reading and writing.").font(.caption).foregroundStyle(DarjaTheme.muted)
            Stepper("Daily goal: \(store.preferences.dailyMinutes) minutes",value:$store.preferences.dailyMinutes,in:5...20,step:1)
            Text("A gentle goal, not a lockout. First lessons usually take 5–8 minutes. Skip a day without losing rewards.").font(.caption).foregroundStyle(DarjaTheme.muted)
        }
        Section("Voice & your family’s Darja") {
            Toggle("Allow local voice recording",isOn:$store.preferences.microphoneEnabled).onChange(of:store.preferences.microphoneEnabled){_,enabled in if !enabled{audio.stopAll()}}
            Text("Recording is off by default. iOS asks for microphone permission on first use. Recordings stay in this app on the device; they are not sent for analysis. A new recording replaces that word’s previous clip.").font(.caption).foregroundStyle(DarjaTheme.muted)
            NavigationLink("Family voice studio"){FamilyVoiceStudioView()}
            NavigationLink("Our family’s words"){FamilyWordsView()}
            Text("The base pack uses Central/Algiers-style Darja with feminine examples where relevant. Family variants are welcome. There are no separate regional audio packs in this build.").font(.caption).foregroundStyle(DarjaTheme.muted)
            Text("The built-in Arabic voice is synthetic and may use formal-Arabic pronunciation. Record a family example in the voice studio to replace it for that word.").font(.caption).foregroundStyle(DarjaTheme.muted)
        }
        Section("Teaching guide") {NavigationLink("How to use the 36-week journey"){ParentGuideView()};NavigationLink("Observe a learning milestone"){AssessmentGuideView()}}
        Section("Privacy & controls") {
            Text("No account, advertising, analytics or open chatbot. Nadia uses prepared prompts. Learning data and recordings stay local. Learning data may be included in device backups; voice recordings are excluded from backup. Deleting the app removes its local data.").font(.footnote)
            SecureField("New four-digit parent PIN",text:$newPIN).keyboardType(.numberPad)
            Button("Change PIN"){pinMessage=store.setParentPIN(newPIN) ? "PIN updated.":"Use exactly four digits.";newPIN=""}
            if !pinMessage.isEmpty {Text(pinMessage).font(.caption)}
            Button("Reset learning progress",role:.destructive){reset=true}
        }
        if let error=store.storageError {Section("Storage notice"){Text(error).foregroundStyle(DarjaTheme.coral)}}
        Section {Text("Darja Together 1.0 · Made for family learning").font(.caption).foregroundStyle(DarjaTheme.muted)}
    }.scrollContentBackground(.hidden).background(DarjaTheme.cream).navigationTitle("Parent space").navigationBarTitleDisplayMode(.inline).confirmationDialog("Reset stars, saved words, completed lessons and review history?",isPresented:$reset,titleVisibility:.visible){Button("Reset progress",role:.destructive){store.resetProgress()};Button("Cancel",role:.cancel){}}message:{Text("Family vocabulary, voice clips, settings and the parent PIN will be kept.")}}
}

struct FamilyVoiceStudioView:View {
    @EnvironmentObject private var store:LearningStore
    @State private var query=""
    @State private var recordedOnly=false
    @EnvironmentObject private var audio:AudioService
    var filtered:[DarjaWord]{store.allWords.filter{(query.isEmpty || ($0.english+" "+$0.arabic+" "+$0.transliteration).localizedCaseInsensitiveContains(query)) && (!recordedOnly || audio.hasRecording(wordId:"family-"+$0.id) || audio.hasRecording(wordId:"practice-"+$0.id))}}
    var body:some View {List{Section {Text("Choose a word, then record a trusted family member saying it naturally. This becomes the example your child hears. Child practice clips remain separate.").font(.subheadline);Toggle("Only words with recordings",isOn:$recordedOnly)};ForEach(filtered,id:\.id){word in NavigationLink{RecordingEditorView(word:word)}label:{HStack{Text(word.emoji);VStack(alignment:.leading){Text(word.arabic).font(.title3);Text(word.english).font(.caption)};Spacer();if audio.hasRecording(wordId:"family-"+word.id){Image(systemName:"waveform.circle.fill").foregroundStyle(DarjaTheme.teal)}}}}}.searchable(text:$query,prompt:"Find a word to record").navigationTitle("Family voice studio").navigationBarTitleDisplayMode(.inline)}
}
struct RecordingEditorView:View {
    @EnvironmentObject private var store:LearningStore
    @EnvironmentObject private var audio:AudioService
    let word:DarjaWord
    @State private var removeKey:String?
    var body:some View {List{Section {Text(word.emoji).font(.system(size:55));Text(word.arabic).font(.system(size:30,weight:.bold));Text(word.transliteration);Text(word.english);if !word.note.isEmpty{Text(word.note).font(.footnote)}};Section("Family pronunciation example") {
        if store.preferences.microphoneEnabled {Button{if audio.isRecording{audio.stopRecording()}else{Task{await audio.startRecording(wordId:"family-"+word.id)}}}label:{Label(audio.isRecording ? "Stop & save":"Record family example",systemImage:audio.isRecording ? "stop.fill":"mic.fill")}}else{Text("Enable local voice recording in Parent space first.").foregroundStyle(DarjaTheme.muted)}
        if audio.hasRecording(wordId:"family-"+word.id){Button("Play family example"){audio.playRecording(wordId:"family-"+word.id)};Button("Delete family example",role:.destructive){removeKey="family-"+word.id}}
        Text("Up to 30 seconds. Speak once, naturally, with a brief pause. Your next saved clip replaces this example.").font(.caption)
    };if audio.hasRecording(wordId:"practice-"+word.id){Section("Child’s latest practice") {Button("Play child’s practice"){audio.playRecording(wordId:"practice-"+word.id)};Button("Delete child’s practice",role:.destructive){removeKey="practice-"+word.id};Text("This is never used as the pronunciation model.").font(.caption)}};if !audio.status.isEmpty {Section{Text(audio.status).font(.footnote)}}}.navigationTitle("Voice recording").navigationBarTitleDisplayMode(.inline).onDisappear{audio.stopAll()}.confirmationDialog("Delete this voice clip?",isPresented:Binding(get:{removeKey != nil},set:{if !$0{removeKey=nil}}),titleVisibility:.visible){Button("Delete recording",role:.destructive){if let key=removeKey{audio.deleteRecording(wordId:key)};removeKey=nil};Button("Cancel",role:.cancel){removeKey=nil}}}
}

struct FamilyWordsView:View {
    @EnvironmentObject private var store:LearningStore
    @EnvironmentObject private var audio:AudioService
    @State private var arabic=""
    @State private var pronunciation=""
    @State private var english=""
    @State private var french=""
    @State private var emoji="🏡"
    @State private var message=""
    @State private var deleteWord:DarjaWord?
    var body:some View {Form{Section{Text("Add names, expressions or regional words your family actually uses. Record them in the voice studio after adding.").font(.subheadline)};Section("Add a family word") {TextField("Arabic word or expression",text:$arabic).environment(\.layoutDirection,.rightToLeft);TextField("Pronunciation hint",text:$pronunciation);TextField("English meaning",text:$english);TextField("French meaning (optional)",text:$french);TextField("Picture emoji",text:$emoji);Button("Add to our family collection"){if store.addFamilyWord(arabic:arabic,transliteration:pronunciation,english:english,french:french,emoji:emoji) != nil {arabic="";pronunciation="";english="";french="";message="Added. Open the word below to record your family’s voice."}else{message="Add an Arabic expression and its English meaning."}};if !message.isEmpty{Text(message).font(.caption)}};Section("Our family collection") {ForEach(store.familyWords,id:\.id){word in NavigationLink{RecordingEditorView(word:word)}label:{HStack{Text(word.emoji);Text(word.arabic);Spacer();Text(word.english).font(.caption)}}.swipeActions{Button("Delete",role:.destructive){deleteWord=word}}};if store.familyWords.isEmpty{Text("Your family’s words will appear here and in My words.").font(.caption)}}}.navigationTitle("Our family’s words").navigationBarTitleDisplayMode(.inline).confirmationDialog("Delete this family word and its recordings?",isPresented:Binding(get:{deleteWord != nil},set:{if !$0{deleteWord=nil}}),titleVisibility:.visible){Button("Delete word",role:.destructive){if let word=deleteWord{let familyDeleted=audio.deleteRecording(wordId:"family-"+word.id);let practiceDeleted=audio.deleteRecording(wordId:"practice-"+word.id);if familyDeleted && practiceDeleted{store.deleteFamilyWord(word)}else{message="A voice clip could not be removed. The word was kept. Try again."}};deleteWord=nil};Button("Cancel",role:.cancel){deleteWord=nil}}}
}

struct ParentGuideView:View {
    @EnvironmentObject private var store:LearningStore
    var body:some View {List{Section("Start where she is") {Text("Begin with Week 1. The language starts simply while the adventures encourage curiosity. Use pictures, listen, imitate and play; introduce print only after meaning feels familiar.");Text("Each week offers five short activities. Sessions 1–2 introduce a small number of new words. Other sessions reuse them. Repeat any week and use fewer words whenever needed.")};Section("A kind teaching rhythm") {ForEach(store.curriculum?.parentGuidance ?? [],id:\.self){Text($0)}};Section("Pronunciation hints") {ForEach(store.curriculum?.pronunciationTips ?? []){tip in VStack(alignment:.leading,spacing:7){Text(tip.symbol).font(.title2).fontWeight(.bold);Text(tip.explanation);if let word=store.word(id:tip.exampleWordId){Text("\(word.arabic) · \(word.transliteration)").foregroundStyle(DarjaTheme.teal)}}}};Section("Content notes & sources") {Text("Activities and stories are original. Darja spelling and regional speech vary. The family’s competent speaker should check pronunciation and preferred expressions. This is a learning foundation, not a promise of fluency.");ForEach(store.curriculum?.sources ?? []){source in VStack(alignment:.leading,spacing:6){Text(source.title).font(.headline);Text(source.note).font(.caption);if let url=URL(string:source.url){Link("View source",destination:url)}}}}}.navigationTitle("Teaching guide").navigationBarTitleDisplayMode(.inline)}
}
struct AssessmentGuideView:View {
    private let checks=[("Listening","Use a familiar word with a new picture or object. Can she choose it without watching your gestures?"),("Speaking","Invite her to ask for something she wants. Note whether she repeats a model or makes her own request."),("Reading","Show taught words. Check meaning separately from memorising the shape. Shared story listening is not independent decoding."),("Writing","Ask her to make a useful label or message. Record whether she traces, copies, builds, dictates, or writes independently."),("Conversation","Have a short exchange and ask a new, familiar question. Give time to respond, ask for help, or request repetition.")]
    var body:some View{List{Section{Text("Every four weeks, notice what she can do in real life. Use the same gentle descriptions for each skill: not yet, with a model, with a cue, independently, or in a new situation.")};ForEach(checks,id:\.0){skill,prompt in Section(skill){Text(prompt)}};Section("Keep one small memory"){Text("Save a willing voice sample, a photo of her writing, or a short family note outside the app. These observations complement the app’s activity counts.")}}.navigationTitle("Learning milestones").navigationBarTitleDisplayMode(.inline)}
}
