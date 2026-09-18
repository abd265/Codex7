import SwiftUI

struct BakingWorkspaceView: View {
    @State private var tab = "Journal"
    var body: some View {
        VStack(spacing: 0) {
            Picker("Baking workspace", selection: $tab) { ForEach(["Journal", "Recipes", "Orders"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented).padding()
            if tab == "Journal" { BakeJournalView() }
            else if tab == "Recipes" { RecipeBookView() }
            else { ProductionView() }
        }.bakeryBackground()
    }
}
struct RecipeBookView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var query = ""
    @State private var adding = false
    var filtered: [BakeRecipe] { store.state.recipes.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }.sorted { $0.name < $1.name } }
    var body: some View {
        List {
            Section { Text("Your methods, measured and remembered.").font(.headline).padding(.vertical, 8) }
            ForEach(filtered) { recipe in
                NavigationLink { RecipeDetailView(id: recipe.id) } label: { RecipeRow(recipe: recipe) }.accessibilityIdentifier("recipe.\(recipe.id)")
            }
        }.bakeryBackground().navigationTitle("Recipe book").searchable(text: $query, prompt: "Find a recipe")
        .toolbar { Button { adding = true } label: { Label("New recipe", systemImage: "plus") } }
        .sheet(isPresented: $adding) { RecipeEditor() }
    }
}
struct RecipeRow: View {
    @EnvironmentObject private var store: BakeryStore
    var recipe: BakeRecipe
    var body: some View {
        HStack(spacing: 14) {
            if let p = recipe.productID.flatMap({ store.state.product($0) }) { ProductPhoto(product: p, size: 64) }
            else { Image(systemName: "book.closed").font(.title).foregroundStyle(Color.bakeTeal).frame(width: 64, height: 64).background(Color.bakeTint, in: RoundedRectangle(cornerRadius: 14)) }
            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.name).font(.headline)
                Text("\(recipe.yield) \(recipe.yieldUnit) · \(recipe.ingredients.count) ingredients").font(.caption).foregroundStyle(.secondary)
                Label(durationLabel(Double(recipe.totalMinutes * 60)), systemImage: "clock").font(.caption).foregroundStyle(Color.bakeTeal)
            }
        }.padding(.vertical, 5)
    }
}
struct RecipeDetailView: View {
    @EnvironmentObject private var store: BakeryStore
    var id: String
    @State private var quantity = 1
    @State private var loaded = false
    @State private var editing = false
    @State private var newSession: String?
    var recipe: BakeRecipe? { store.state.recipes.first { $0.id == id } }
    var body: some View {
        List {
            if let r = recipe {
                Section { RecipeRow(recipe: r); Stepper("Make \(quantity) \(r.yieldUnit)", value: $quantity, in: 1...9999)
                    Button { var result = ""; if store.perform({ result = try $0.startBake(recipeID: r.id, quantity: quantity) }) { newSession = result } } label: { Label("Start this bake", systemImage: "play.circle.fill").font(.headline) }.accessibilityIdentifier("bake.start")
                }
                Section("Ingredients · scaled to your yield") { ForEach(r.ingredients) { i in LabeledContent(i.name, value: "\(r.scaledAmount(i, quantity: quantity).formatted(.number.precision(.fractionLength(0...2)))) \(i.unit)") } }
                Section("Method") { ForEach(Array(r.method.enumerated()), id: \.element.id) { index, step in MethodRow(step: step, number: index + 1) } }
                if !r.notes.isEmpty { Section("Recipe notes") { Text(r.notes) } }
            }
        }.bakeryBackground().navigationTitle(recipe?.name ?? "Recipe").navigationBarTitleDisplayMode(.inline)
        .onAppear { if !loaded { quantity = recipe?.yield ?? 1; loaded = true } }
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) { if let r = recipe { RecipeEditor(recipe: r) } }
        .navigationDestination(item: $newSession) { BakeSessionView(id: $0) }
    }
}
struct MethodRow: View {
    var step: RecipeStep
    var number: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(step.title)").font(.headline)
            Text(step.instruction).font(.subheadline).foregroundStyle(.secondary)
            HStack { Label(durationLabel(Double(step.minutes * 60)), systemImage: "clock"); if let t = step.temperatureC { Label("\(t)°C / \(Int((Double(t) * 1.8 + 32).rounded()))°F", systemImage: "thermometer.medium") } }.font(.caption).foregroundStyle(Color.bakeTeal)
        }.padding(.vertical, 8)
    }
}
struct RecipeEditor: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    var recipe: BakeRecipe?
    @State private var loaded = false
    @State private var draft = BakeRecipe(name: "", ingredients: [RecipeIngredient(name: "", amount: 100)], method: [RecipeStep(title: "Mix", instruction: "", minutes: 10)])
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Recipe name", text: $draft.name)
                    Picker("Link to product", selection: Binding(get: { draft.productID ?? "" }, set: { draft.productID = $0.isEmpty ? nil : $0 })) { Text("Independent recipe").tag(""); ForEach(store.state.products) { Text($0.name).tag($0.id) } }
                    Stepper("Recipe yield: \(draft.yield)", value: $draft.yield, in: 1...9999)
                    TextField("Yield unit (loaves, cookies…)", text: $draft.yieldUnit)
                }
                Section("Ingredients for this yield") {
                    ForEach($draft.ingredients) { $item in
                        VStack(alignment: .leading) {
                            TextField("Ingredient name", text: $item.name)
                            HStack { TextField("Amount", value: $item.amount, format: .number).keyboardType(.decimalPad); Picker("Unit", selection: $item.unit) { ForEach(RecipeIngredient.units, id: \.self) { Text($0).tag($0) } }.labelsHidden() }
                        }
                    }.onDelete { draft.ingredients.remove(atOffsets: $0) }
                    Button("Add ingredient", systemImage: "plus") { draft.ingredients.append(RecipeIngredient(name: "", amount: 100)) }
                }
                Section("Method · swipe to remove, drag to reorder") {
                    ForEach($draft.method) { $step in
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Step name", text: $step.title).font(.headline)
                            TextField("Instructions", text: $step.instruction, axis: .vertical).lineLimit(2...6)
                            HStack { Text("Minutes"); Spacer(); TextField("Minutes", value: $step.minutes, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                            Toggle("Oven temperature", isOn: Binding(get: { step.temperatureC != nil }, set: { step.temperatureC = $0 ? 180 : nil }))
                            if step.temperatureC != nil { Stepper("\(step.temperatureC ?? 180)°C", value: Binding(get: { step.temperatureC ?? 180 }, set: { step.temperatureC = $0 }), in: 0...350, step: 5) }
                        }.padding(.vertical, 6)
                    }.onDelete { draft.method.remove(atOffsets: $0) }.onMove { draft.method.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add step", systemImage: "plus") { draft.method.append(RecipeStep(title: "", instruction: "", minutes: 10)) }
                }
                Section("Notes") { TextField("What makes this recipe yours?", text: $draft.notes, axis: .vertical).lineLimit(3...8) }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle(recipe == nil ? "New recipe" : "Edit recipe").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.perform({ try $0.saveRecipe(draft) }) { dismiss() } else { error = store.error; store.error = nil } } }
            }.onAppear { if !loaded { if let recipe { draft = recipe }; loaded = true } }
        }
    }
}
struct BakeJournalView: View {
    @EnvironmentObject private var store: BakeryStore
    @State private var filter = "Active"
    var sessions: [BakeSession] { store.state.bakeSessions.filter { $0.complete == (filter == "Finished") }.sorted { $0.startedAt > $1.startedAt } }
    var body: some View {
        List {
            Section {
                NavigationLink { RecipeBookView() } label: { Label("Start a bake from your recipes", systemImage: "plus.circle.fill").font(.headline) }
                Picker("Bakes", selection: $filter) { Text("Active").tag("Active"); Text("Finished").tag("Finished") }.pickerStyle(.segmented)
            }
            if sessions.isEmpty { Section { ContentUnavailableView(filter == "Active" ? "Your next bake starts here" : "Your baking story", systemImage: "oven", description: Text(filter == "Active" ? "Pick a recipe, measure your ingredients, and track every step." : "Finished bakes and tasting notes will appear here.")) } }
            ForEach(sessions) { b in NavigationLink { BakeSessionView(id: b.id) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    RecipeRow(recipe: b.recipe)
                    HStack { Text("\(b.quantity) \(b.recipe.yieldUnit)"); Spacer(); Text(Date(timeIntervalSince1970: b.startedAt), style: .date) }.font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: Double(b.completedCount), total: Double(max(1, b.steps.count)))
                    Text("\(b.completedCount) of \(b.steps.count) steps complete").font(.caption)
                }.padding(.vertical, 6)
            }.accessibilityIdentifier("session.\(b.id)") }
        }.bakeryBackground().navigationTitle("Baking journal")
    }
}
struct BakeSessionView: View {
    @EnvironmentObject private var store: BakeryStore
    var id: String
    @State private var notes = ""
    @State private var rating = 0
    @State private var loaded = false
    @State private var finish = false
    @State private var notesSaved = false
    var session: BakeSession? { store.state.bakeSessions.first { $0.id == id } }
    var body: some View {
        List {
            if let b = session {
                Section {
                    RecipeRow(recipe: b.recipe)
                    LabeledContent("Your batch", value: "\(b.quantity) \(b.recipe.yieldUnit)")
                    LabeledContent("Started", value: Date(timeIntervalSince1970: b.startedAt).formatted(date: .abbreviated, time: .shortened))
                    if let end = b.finishedAt { LabeledContent("Total time", value: durationLabel(end - b.startedAt)) }
                    ProgressView(value: Double(b.completedCount), total: Double(max(1, b.steps.count)))
                }
                Section("Ingredient checklist") {
                    ForEach(b.recipe.ingredients) { i in
                        Button { store.perform { s in if let index = s.bakeSessions.firstIndex(where: { $0.id == id }) { if s.bakeSessions[index].checkedIngredients.contains(i.id) { s.bakeSessions[index].checkedIngredients.remove(i.id) } else { s.bakeSessions[index].checkedIngredients.insert(i.id) } } } } label: {
                            HStack { Image(systemName: b.checkedIngredients.contains(i.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(Color.bakeTeal); Text(i.name).foregroundStyle(.primary); Spacer(); Text("\(b.recipe.scaledAmount(i, quantity: b.quantity).formatted(.number.precision(.fractionLength(0...2)))) \(i.unit)").foregroundStyle(.secondary) }
                        }.disabled(b.complete)
                    }
                }
                ForEach(Array(b.recipe.method.enumerated()), id: \.element.id) { index, step in
                    Section {
                        MethodRow(step: step, number: index + 1)
                        if let log = b.steps.first(where: { $0.id == step.id }) { BakeTimerRow(sessionID: id, step: step, log: log, finished: b.complete) }
                    }
                }
                Section("Bake notes & result") {
                    TextField("Dough feel, room temperature, changes, tasting notes…", text: $notes, axis: .vertical).lineLimit(4...12).accessibilityIdentifier("bake.notes")
                    Picker("Result", selection: $rating) { Text("Not rated").tag(0); ForEach(1...5, id: \.self) { Text("\($0) / 5").tag($0) } }
                    Button(notesSaved ? "Notes saved" : "Save notes") { saveNotes() }
                }
                if !b.complete { Section { Button("Finish bake") { finish = true }.font(.headline) } }
            }
        }.bakeryBackground().navigationTitle(session?.recipe.name ?? "Bake").navigationBarTitleDisplayMode(.inline)
        .onAppear { if !loaded, let b = session { notes = b.notes; rating = b.rating; loaded = true } }
        .onChange(of: notes) { _, _ in notesSaved = false }.onChange(of: rating) { _, _ in notesSaved = false }
        .confirmationDialog("Finish this bake?", isPresented: $finish, titleVisibility: .visible) { Button("Save and finish bake") { if saveNotes() { store.perform { try $0.finishBake(id) } } } } message: { Text("Active timers will stop. Your ingredients, step times and notes will stay in the journal.") }
        .onDisappear { if loaded { saveNotes() } }
    }
    @discardableResult private func saveNotes() -> Bool {
        let ok = store.perform { s in if let i = s.bakeSessions.firstIndex(where: { $0.id == id }) { s.bakeSessions[i].notes = notes; s.bakeSessions[i].rating = rating } }
        notesSaved = ok; return ok
    }
}
struct BakeTimerRow: View {
    @EnvironmentObject private var store: BakeryStore
    var sessionID: String
    var step: RecipeStep
    var log: BakeStepLog
    var finished: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = log.elapsed(at: context.date.timeIntervalSince1970)
                let remaining = Double(step.minutes * 60) - elapsed
                HStack {
                    Label(log.completedAt != nil ? "Complete" : log.startedAt != nil ? (remaining <= 0 && step.minutes > 0 ? "Time to check" : "Running") : (log.accumulatedSeconds > 0 ? "Paused" : "Ready"), systemImage: log.completedAt != nil ? "checkmark.circle.fill" : "timer")
                    Spacer(); Text(durationLabel(elapsed)).monospacedDigit()
                }.font(.subheadline.weight(.semibold)).foregroundStyle(Color.bakeTeal)
                if step.minutes > 0 && log.startedAt != nil { Text(remaining > 0 ? "\(durationLabel(remaining)) remaining" : "\(durationLabel(-remaining)) past planned time").font(.caption).foregroundStyle(.secondary) }
            }
            if !finished {
                HStack {
                    if log.completedAt == nil {
                        Button(log.startedAt == nil ? "Start timer" : "Pause") { change(log.startedAt == nil ? "start" : "pause") }.buttonStyle(.bordered).accessibilityIdentifier("timer.\(step.id)")
                        Button("Complete step") { change("complete") }.buttonStyle(.borderedProminent)
                    } else { Button("Reset step") { change("reset") }.buttonStyle(.bordered) }
                }
            }
        }.padding(.vertical, 6)
    }
    private func change(_ action: String) { store.perform { try $0.changeStep(sessionID: sessionID, stepID: step.id, action: action) } }
}
func durationLabel(_ seconds: Double) -> String {
    let total = seconds.isFinite ? Int(min(32_503_680_000, max(0, seconds))) : 0; let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
    return h > 0 ? "\(h)h \(m.formatted(.number.precision(.integerLength(2))))m" : "\(m)m \(s.formatted(.number.precision(.integerLength(2))))s"
}
