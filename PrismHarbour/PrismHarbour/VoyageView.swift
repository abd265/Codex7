import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

struct VoyageView: View {
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmRestart = false
    var body: some View {
        GeometryReader { geo in
            let level = store.currentLevel
            let boardWidth = min(geo.size.width-44, min(430, max(220,(geo.size.height-375)*CGFloat(level.columns)/CGFloat(level.rows)+32)))
            ScrollView(showsIndicators:false) {
                VStack(spacing:16) {
                    header
                    title
                    status
                    PuzzleBoardView().frame(width:boardWidth,height:(boardWidth-32)*CGFloat(level.rows)/CGFloat(level.columns)+32)
                        .frame(maxWidth:.infinity)
                    instruction
                    controls
                    boosters.padding(.top,2)
                }.padding(.horizontal,22).padding(.top,8).padding(.bottom,14).frame(maxWidth:600).frame(maxWidth:.infinity)
            }
        }
        .overlay { if store.paused || store.expired || store.reward != nil { gameOverlay } }
        .confirmationDialog("Start this level again?",isPresented:$confirmRestart,titleVisibility:.visible) {
            Button("Restart level") { store.retry() }
        } message: { Text("Your current moves will be reset. Pearls spent on hints or time will not be returned.") }
    }
    private var header: some View {
        HStack {
            RoundIconButton(icon:"chevron.left",label:"Pause and leave level") { store.setPaused(true) }
            Spacer(); CoinPill(coins:store.progress.coins); Spacer()
            RoundIconButton(icon:"pause.fill",label:"Pause game") { store.setPaused(true) }
        }
    }
    private var title: some View {
        VStack(spacing:6) {
            Eyebrow(text:store.isDaily ? "The daily tide" : "\(regionName(store.currentLevel.region)) · Level \(String(format:"%02d",store.currentLevel.id))")
            Text(store.currentLevel.title).font(.system(size:27,weight:.semibold,design:.serif)).minimumScaleFactor(0.65).lineLimit(1)
        }
    }
    private var status: some View {
        HStack {
            HStack(spacing:7) {
                Image(systemName:store.session?.relaxed == true ? "infinity" : "timer").foregroundStyle(timeLow ? Color(hex:0xFF8B95) : HarbourTheme.mint)
                Text(timeText).font(.system(size:19,weight:.bold,design:.rounded)).monospacedDigit().foregroundStyle(timeLow ? Color(hex:0xFF8B95) : .white)
            }
            Spacer()
            Text("\(store.session?.game.moves ?? 0) moves").font(.system(size:12,weight:.medium)).foregroundStyle(HarbourTheme.muted)
            Spacer()
            HStack(spacing:6) {
                Image(systemName:"square.stack.3d.up.fill").foregroundStyle(HarbourTheme.lavender)
                Text("\(store.session?.game.pieces.count ?? 0) left").font(.system(size:12,weight:.semibold))
            }
        }.padding(.horizontal,8).padding(.vertical,1)
    }
    private var instruction: some View {
        HStack(spacing:6) {
            Image(systemName:store.hintMove == nil ? "hand.draw" : "sparkles")
            Text(store.hintMove.map { "Slide the glowing prism \(String(describing:$0.direction))" } ?? "Slide each prism to its matching dock")
        }.font(.system(size:11,weight:.medium)).foregroundStyle(store.hintMove == nil ? HarbourTheme.muted : HarbourTheme.gold)
            .frame(height:16)
    }
    private var controls: some View {
        HStack(spacing:12) {
            if let selected = store.selectedPiece, let piece = store.session?.game.pieces.first(where: { $0.id == selected }) {
                Image(systemName:piece.color.symbol).foregroundStyle(piece.color.tint).frame(width:20)
                ForEach([Direction.left,.up,.down,.right],id:\.self) { direction in
                    Button { withAnimation(reduceMotion ? nil : .snappy(duration:0.18)) { store.move(pieceID:selected,direction:direction,steps:1) } } label: {
                        Image(systemName:arrow(direction)).font(.system(size:15,weight:.bold)).frame(width:43,height:36).background(.white.opacity(0.07),in:RoundedRectangle(cornerRadius:11))
                    }.buttonStyle(.plain).accessibilityLabel("Move \(piece.color.name) \(String(describing:direction))")
                }
            } else {
                Circle().fill(HarbourTheme.mint.opacity(0.5)).frame(width:4,height:4)
                Text("Tap a prism for arrow controls").font(.system(size:10)).foregroundStyle(HarbourTheme.muted.opacity(0.7))
            }
        }.frame(height:36)
    }
    private var boosters: some View {
        HStack(spacing:12) {
            booster("Undo","Free",icon:"arrow.uturn.backward",color:HarbourTheme.mint,disabled:store.session?.history.isEmpty ?? true) { withAnimation(reduceMotion ? nil : .snappy(duration:0.2)) { store.undo() } }
            booster(store.findingHint ? "Finding…" : "Hint","15 pearls",icon:"sparkles",color:HarbourTheme.gold,disabled:store.findingHint) { store.requestHint() }
            if store.session?.relaxed == true {
                booster("Restart","Fresh start",icon:"arrow.clockwise",color:HarbourTheme.lavender) { confirmRestart = true }
            } else {
                booster("+30 sec","30 pearls",icon:"timer",color:HarbourTheme.lavender) { store.addTime() }
            }
        }
    }
    private func booster(_ title:String,_ subtitle:String,icon:String,color:Color,disabled:Bool = false,action:@escaping()->Void)->some View {
        Button(action:action) {
            VStack(spacing:6) {
                Image(systemName:icon).font(.system(size:20,weight:.medium)).foregroundStyle(color)
                Text(title).font(.system(size:12,weight:.bold,design:.rounded))
                Text(subtitle).font(.system(size:9)).foregroundStyle(HarbourTheme.muted)
            }.frame(maxWidth:.infinity).padding(.vertical,11).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:18))
                .overlay(RoundedRectangle(cornerRadius:18).stroke(.white.opacity(0.06))).opacity(disabled ? 0.35 : 1)
        }.buttonStyle(.plain).disabled(disabled)
    }
    private var timeLow:Bool { store.session?.relaxed == false && (store.session?.remaining ?? 0) < 30 }
    private var timeText:String {
        guard let session = store.session else { return "0:00" }
        if session.relaxed { return "Calm" }
        let seconds = max(0,Int(ceil(session.remaining)))
        return String(format:"%d:%02d",seconds/60,seconds%60)
    }
    private var gameOverlay: some View {
        ZStack {
            HarbourTheme.ink.opacity(0.84).ignoresSafeArea().background(.ultraThinMaterial)
            ScrollView {
                VStack(spacing:22) {
                    if let reward = store.reward { victory(reward) }
                    else if store.expired { timeUp }
                    else { pauseMenu }
                }.padding(28).frame(maxWidth:410).frame(maxWidth:.infinity).padding(.vertical,38)
            }.scrollBounceBehavior(.basedOnSize)
        }.transition(.opacity)
    }
    @ViewBuilder private func victory(_ reward:CompletionReward)->some View {
        HarbourIllustration().frame(height:170)
        Eyebrow(text:store.isDaily ? "Daily tide complete" : "Beautifully sailed",color:HarbourTheme.mint)
        Text("Clear waters.").font(.system(size:38,weight:.bold,design:.serif))
        HStack(spacing:18) { ForEach(0..<3) { index in Image(systemName:"star.fill").font(.system(size:index == 1 ? 47 : 36)).foregroundStyle(index < reward.stars ? HarbourTheme.gold : .white.opacity(0.13)).rotationEffect(.degrees(index == 0 ? -12 : index == 2 ? 12 : 0)) } }.padding(.vertical,7)
        Text("Every prism found its way home.").font(.system(size:15)).foregroundStyle(HarbourTheme.muted)
        GlassPanel {
            HStack {
                VStack(spacing:5) { Text("\(store.session?.game.moves ?? 0)").font(.system(size:24,weight:.bold,design:.rounded)); Text("MOVES").font(.system(size:9,weight:.bold)).tracking(2).foregroundStyle(HarbourTheme.muted) }
                Spacer(); Rectangle().fill(.white.opacity(0.1)).frame(width:1,height:35); Spacer()
                VStack(spacing:5) { Text("+\(reward.coins)").font(.system(size:24,weight:.bold,design:.rounded)).foregroundStyle(HarbourTheme.gold); Text("PEARLS").font(.system(size:9,weight:.bold)).tracking(2).foregroundStyle(HarbourTheme.muted) }
            }.padding(.horizontal,24)
        }
        Text("Three stars: \(store.currentLevel.parMoves) moves or fewer").font(.system(size:11)).foregroundStyle(HarbourTheme.muted)
        if !store.isDaily && store.currentLevel.id < LevelCatalog.campaign.count {
            Button { store.start(LevelCatalog.campaign[store.currentLevel.id]) } label: { Label("Next harbour",systemImage:"arrow.right") }.buttonStyle(PrimaryButtonStyle())
        } else {
            Button("Back to the harbour") { store.leaveGame() }.buttonStyle(PrimaryButtonStyle())
        }
        HStack(spacing:26) { Button("Play again") { store.retry() }; Button("Harbour") { store.leaveGame() } }.font(.system(size:13,weight:.semibold)).foregroundStyle(HarbourTheme.muted)
    }
    private var pauseMenu: some View {
        Group {
            Image(systemName:"moon.zzz.fill").font(.system(size:54)).foregroundStyle(HarbourTheme.lavender).padding(.vertical,15)
            Eyebrow(text:"Take a breath")
            Text("A moment of calm.").font(.system(size:32,weight:.bold,design:.serif)).multilineTextAlignment(.center)
            Text("Your voyage will be right here.").font(.system(size:15)).foregroundStyle(HarbourTheme.muted)
            Button("Keep sailing") { store.setPaused(false) }.buttonStyle(PrimaryButtonStyle())
            menuRow("Start this level again",icon:"arrow.clockwise") { confirmRestart = true }
            menuRow("How to play",icon:"questionmark.circle") { store.showHelp = true }
            menuRow("Settings",icon:"slider.horizontal.3") { store.showSettings = true }
            menuRow("Return to harbour",icon:"house") { store.leaveGame() }
        }
    }
    private var timeUp: some View {
        Group {
            Image(systemName:"water.waves").font(.system(size:60)).foregroundStyle(HarbourTheme.mint).padding(.vertical,20)
            Eyebrow(text:"The tide has turned")
            Text("Another wave awaits.").font(.system(size:32,weight:.bold,design:.serif)).multilineTextAlignment(.center)
            Text("Try a fresh route, or give yourself a little more time.").font(.system(size:15)).foregroundStyle(HarbourTheme.muted).multilineTextAlignment(.center).lineSpacing(4)
            Button("Try again") { store.retry() }.buttonStyle(PrimaryButtonStyle())
            Button("Add 30 seconds · 30 pearls") { store.addTime() }.font(.system(size:14,weight:.semibold)).foregroundStyle(HarbourTheme.gold)
            Button("Back to harbour") { store.leaveGame() }.font(.system(size:13)).foregroundStyle(HarbourTheme.muted)
            if !store.isDaily { Text("Prefer a gentler pace? Enable Calm mode in Settings for your next level.").font(.system(size:12)).foregroundStyle(HarbourTheme.muted).multilineTextAlignment(.center).padding(.top,14) }
        }
    }
    private func menuRow(_ title:String,icon:String,action:@escaping()->Void)->some View {
        Button(action:action) { HStack { Image(systemName:icon).frame(width:24).foregroundStyle(HarbourTheme.lavender); Text(title); Spacer(); Image(systemName:"chevron.right").font(.system(size:11)) }.font(.system(size:14,weight:.medium)).padding(16).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:15)) }.buttonStyle(.plain)
    }
}

func arrow(_ direction:Direction)->String {
    switch direction { case .up: return "arrow.up"; case .down: return "arrow.down"; case .left: return "arrow.left"; case .right: return "arrow.right" }
}

struct PuzzleBoardView: View {
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragging: Int?
    @GestureState private var translation = CGSize.zero
    var body: some View {
        GeometryReader { geo in
            let level = store.currentLevel
            let cell = (geo.size.width-32)/CGFloat(level.columns)
            let width = cell*CGFloat(level.columns)
            let height = cell*CGFloat(level.rows)
            ZStack(alignment:.topLeading) {
                RoundedRectangle(cornerRadius:25).fill(Color(hex:0x090D21)).frame(width:width+32,height:height+32)
                    .overlay(RoundedRectangle(cornerRadius:25).stroke(LinearGradient(colors:[Color(hex:0x545276),Color(hex:0x242B48)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:2))
                    .shadow(color:.black.opacity(0.25),radius:18,y:12)
                grid(columns:level.columns,rows:level.rows,cell:cell).offset(x:16,y:16)
                ForEach(Array(level.blocked.enumerated()),id:\.offset) { _,block in
                    RoundedRectangle(cornerRadius:cell*0.17).fill(Color(hex:0x222A45)).overlay { Image(systemName:"xmark").font(.system(size:cell*0.19,weight:.bold)).foregroundStyle(.white.opacity(0.09)) }
                        .frame(width:cell-4,height:cell-4).position(x:16+(CGFloat(block.x)+0.5)*cell,y:16+(CGFloat(block.y)+0.5)*cell)
                }
                ForEach(Array(level.gates.enumerated()),id:\.offset) { _,gate in gateView(gate,cell:cell,width:width,height:height) }
                if let game = store.session?.game {
                    ForEach(game.pieces) { piece in pieceView(piece,cell:cell).offset(x:16+CGFloat(piece.origin.x)*cell,y:16+CGFloat(piece.origin.y)*cell).zIndex(dragging == piece.id ? 5 : 1) }
                }
            }.frame(width:width+32,height:height+32)
        }.accessibilityElement(children:.contain).accessibilityLabel("Puzzle board. Match every prism to its coloured dock.")
    }
    private func grid(columns:Int,rows:Int,cell:CGFloat)->some View {
        Canvas { context,size in
            for y in 0..<rows { for x in 0..<columns {
                let rect = CGRect(x:CGFloat(x)*cell+2,y:CGFloat(y)*cell+2,width:cell-4,height:cell-4)
                context.fill(Path(roundedRect:rect,cornerRadius:cell*0.15),with:.color(.white.opacity(0.027)))
                context.fill(Path(ellipseIn:CGRect(x:rect.midX-1,y:rect.midY-1,width:2,height:2)),with:.color(.white.opacity(0.075)))
            } }
        }.frame(width:CGFloat(columns)*cell,height:CGFloat(rows)*cell).accessibilityHidden(true)
    }
    private func gateView(_ gate:Gate,cell:CGFloat,width:CGFloat,height:CGFloat)->some View {
        let horizontal = gate.side == .up || gate.side == .down
        let length = CGFloat(gate.span)*cell-4
        let midpoint = 16+(CGFloat(gate.start)+CGFloat(gate.span)/2)*cell
        let x = horizontal ? midpoint : (gate.side == .left ? 8 : width+24)
        let y = horizontal ? (gate.side == .up ? 8 : height+24) : midpoint
        return ZStack {
            RoundedRectangle(cornerRadius:5).fill(gate.color.tint).shadow(color:gate.color.tint.opacity(0.35),radius:8)
            HStack(spacing:3) { Image(systemName:gate.color.symbol); Image(systemName:arrow(gate.side)) }.font(.system(size:7,weight:.black)).foregroundStyle(HarbourTheme.ink.opacity(0.75)).rotationEffect(.degrees(horizontal ? 0 : 90))
        }.frame(width:horizontal ? length : 12,height:horizontal ? 12 : length).position(x:x,y:y)
            .accessibilityLabel("\(gate.color.name) dock on the \(String(describing:gate.side)) edge, position \(gate.start+1), width \(gate.span)")
    }
    private func pieceView(_ piece:Piece,cell:CGFloat)->some View {
        let selected = store.selectedPiece == piece.id
        let hinted = store.hintMove?.pieceID == piece.id
        return ZStack(alignment:.topLeading) {
            ForEach(Array(piece.cells.enumerated()),id:\.offset) { _,point in
                PrismTile(color:piece.color,symbols:store.settings.symbols).frame(width:cell-3,height:cell-3).offset(x:CGFloat(point.x)*cell+1.5,y:CGFloat(point.y)*cell+1.5)
            }
            PieceSilhouette(cells:piece.cells,cell:cell).stroke(selected || hinted ? .white.opacity(0.95) : piece.color.tint.opacity(0.35),lineWidth:selected || hinted ? 2 : 1)
            if hinted, let move = store.hintMove {
                Image(systemName:arrow(move.direction)).font(.system(size:16,weight:.black)).foregroundStyle(.white).padding(7).background(HarbourTheme.ink.opacity(0.85),in:Circle()).offset(x:CGFloat(piece.cells[0].x)*cell+cell*0.15,y:CGFloat(piece.cells[0].y)*cell+cell*0.15)
            }
        }.frame(width:CGFloat(piece.width)*cell,height:CGFloat(piece.height)*cell,alignment:.topLeading)
            .contentShape(PieceSilhouette(cells:piece.cells,cell:cell))
            .offset(dragging == piece.id ? translation : .zero)
            .shadow(color:hinted ? HarbourTheme.gold.opacity(0.75) : piece.color.tint.opacity(selected ? 0.25 : 0),radius:hinted ? 12 : 6)
            .onTapGesture { store.selectedPiece = piece.id; store.impact() }
            .highPriorityGesture(DragGesture(minimumDistance:5)
            .updating($dragging) { _, state, _ in
                if !store.paused && !store.expired && store.reward == nil { state = piece.id }
            }
            .updating($translation) { value, state, _ in
                guard !store.paused, !store.expired, store.reward == nil else { return }
                if abs(value.translation.width) > abs(value.translation.height) { state = CGSize(width:value.translation.width,height:0) }
                else { state = CGSize(width:0,height:value.translation.height) }
            }.onChanged { _ in
                guard !store.paused, !store.expired, store.reward == nil else { return }
                store.selectedPiece = piece.id
            }.onEnded { value in
                let dx = value.translation.width; let dy = value.translation.height
                let horizontal = abs(dx) > abs(dy)
                let distance = horizontal ? dx : dy
                guard abs(distance) >= cell*0.22 else { return }
                let direction:Direction = horizontal ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                withAnimation(reduceMotion ? nil : .snappy(duration:0.2)) { store.move(pieceID:piece.id,direction:direction,steps:max(1,Int((abs(distance)/cell).rounded()))) }
            })
            .accessibilityElement(children:.ignore)
            .accessibilityLabel("\(piece.color.name) prism, \(piece.cells.count) squares, column \(piece.origin.x+1), row \(piece.origin.y+1)")
            .accessibilityHint("Swipe actions to move toward the matching \(piece.color.name) dock")
            .accessibilityAction(named:"Move up") { store.move(pieceID:piece.id,direction:.up,steps:1) }
            .accessibilityAction(named:"Move down") { store.move(pieceID:piece.id,direction:.down,steps:1) }
            .accessibilityAction(named:"Move left") { store.move(pieceID:piece.id,direction:.left,steps:1) }
            .accessibilityAction(named:"Move right") { store.move(pieceID:piece.id,direction:.right,steps:1) }
    }
}

struct PieceSilhouette: Shape {
    var cells:[Cell]
    var cell:CGFloat
    func path(in rect:CGRect)->Path {
        var path = Path()
        for c in cells { path.addRoundedRect(in:CGRect(x:CGFloat(c.x)*cell+1.5,y:CGFloat(c.y)*cell+1.5,width:cell-3,height:cell-3),cornerSize:CGSize(width:cell*0.2,height:cell*0.2)) }
        return path
    }
}
