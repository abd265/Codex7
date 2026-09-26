import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

struct PuzzleBoardView: View {
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragging: Int?
    @GestureState private var translation = CGSize.zero
    @State private var effects: [HarbourMoveEvent] = []
    @State private var celebration: HarbourMoveEvent?
    @State private var shakeTriggers: [Int:CGFloat] = [:]

    var body: some View {
        GeometryReader { geo in
            let level = store.currentLevel
            let cell = (geo.size.width-32)/CGFloat(level.columns)
            let width = cell*CGFloat(level.columns)
            let height = cell*CGFloat(level.rows)
            ZStack(alignment:.topLeading) {
                boardFrame(width:width,height:height)
                grid(columns:level.columns,rows:level.rows,cell:cell).offset(x:16,y:16)
                ForEach(Array(level.blocked.enumerated()),id:\.offset) { _,block in
                    stone(cell:cell)
                        .position(x:16+(CGFloat(block.x)+0.5)*cell,y:16+(CGFloat(block.y)+0.5)*cell)
                }
                ForEach(Array(level.gates.enumerated()),id:\.offset) { _,gate in
                    gateView(gate,cell:cell,width:width,height:height)
                }
                if let game = store.session?.game {
                    ForEach(game.pieces) { piece in
                        pieceView(piece,cell:cell)
                            .offset(x:16+CGFloat(piece.origin.x)*cell,y:16+CGFloat(piece.origin.y)*cell)
                            .animation(reduceMotion ? nil : .spring(response:0.28,dampingFraction:0.72),value:piece.origin)
                            .zIndex(dragging == piece.id ? 5 : 1)
                            .transition(.identity)
                    }
                }
                ForEach(effects) { event in
                    DockEffect(event:event,level:level,cell:cell).zIndex(10)
                }
                if let celebration {
                    celebrationLabel(celebration)
                        .frame(width:width-8)
                        .position(x:(width+32)/2,y:(height+32)*0.44)
                        .id(celebration.id)
                        .transition(reduceMotion ? .opacity : .scale(scale:0.6).combined(with:.opacity))
                        .zIndex(12)
                }
            }.frame(width:width+32,height:height+32)
        }
        .accessibilityElement(children:.contain)
        .accessibilityLabel("Puzzle board. Match every prism to its coloured dock.")
        .onChange(of:store.moveEvent?.id) { _,_ in
            if let event = store.moveEvent { receive(event) }
            else { clearEffects() }
        }
        .onChange(of:store.session?.id) { _,_ in clearEffects() }
        .onDisappear { clearEffects() }
    }

    private func boardFrame(width:CGFloat,height:CGFloat)->some View {
        ZStack {
            RoundedRectangle(cornerRadius:28)
                .fill(Color(hex:0x073551)).offset(y:7)
            RoundedRectangle(cornerRadius:28)
                .fill(LinearGradient(colors:[Color(hex:0x81FFF0),Color(hex:0x21B8C8),Color(hex:0x127CB2)],startPoint:.topLeading,endPoint:.bottomTrailing))
            RoundedRectangle(cornerRadius:28)
                .strokeBorder(LinearGradient(colors:[Color(hex:0xC5FFF8),Color(hex:0x17739D)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:2)
            RoundedRectangle(cornerRadius:19)
                .fill(Color(hex:0x082F56)).padding(11)
                .overlay(RoundedRectangle(cornerRadius:19).strokeBorder(Color(hex:0x063251),lineWidth:3).padding(11))
                .overlay(RoundedRectangle(cornerRadius:17).strokeBorder(Color(hex:0x82F2EE).opacity(0.22),lineWidth:1).padding(14))
        }
        .frame(width:width+32,height:height+32)
        .shadow(color:Color(hex:0x071D3C).opacity(0.6),radius:14,y:11)
        .accessibilityHidden(true)
    }

    private func grid(columns:Int,rows:Int,cell:CGFloat)->some View {
        Canvas { context,_ in
            for y in 0..<rows { for x in 0..<columns {
                let rect = CGRect(x:CGFloat(x)*cell+1.5,y:CGFloat(y)*cell+1.5,width:cell-3,height:cell-3)
                let path = Path(roundedRect:rect,cornerRadius:cell*0.15)
                context.fill(path,with:.color(Color(hex:(x+y)%2 == 0 ? 0x174D77 : 0x1A557F)))
                context.stroke(path,with:.color(Color(hex:0x80CFE4).opacity(0.14)),lineWidth:0.8)
                var bevel = Path()
                bevel.move(to:CGPoint(x:rect.minX+cell*0.18,y:rect.minY+1))
                bevel.addLine(to:CGPoint(x:rect.maxX-cell*0.18,y:rect.minY+1))
                context.stroke(bevel,with:.color(.black.opacity(0.16)),lineWidth:1.5)
            } }
        }.frame(width:CGFloat(columns)*cell,height:CGFloat(rows)*cell).accessibilityHidden(true)
    }

    private func stone(cell:CGFloat)->some View {
        ZStack {
            RoundedRectangle(cornerRadius:cell*0.18).fill(Color(hex:0x172B45)).offset(y:3)
            RoundedRectangle(cornerRadius:cell*0.18)
                .fill(LinearGradient(colors:[Color(hex:0x648CA0),Color(hex:0x34556C)],startPoint:.topLeading,endPoint:.bottomTrailing))
            RoundedRectangle(cornerRadius:cell*0.16).strokeBorder(Color(hex:0x8CADBA).opacity(0.55),lineWidth:1.5)
            Image(systemName:"plus").font(.system(size:cell*0.25,weight:.black)).foregroundStyle(Color(hex:0x1F3B55)).rotationEffect(.degrees(45))
        }.frame(width:cell-5,height:cell-5).accessibilityHidden(true)
    }

    private func gateView(_ gate:Gate,cell:CGFloat,width:CGFloat,height:CGFloat)->some View {
        let horizontal = gate.side == .up || gate.side == .down
        let length = CGFloat(gate.span)*cell-3
        let midpoint = 16+(CGFloat(gate.start)+CGFloat(gate.span)/2)*cell
        let x = horizontal ? midpoint : (gate.side == .left ? 8 : width+24)
        let y = horizontal ? (gate.side == .up ? 8 : height+24) : midpoint
        return ZStack {
            RoundedRectangle(cornerRadius:6).fill(gate.color.jewelDark).offset(y:2)
            RoundedRectangle(cornerRadius:6)
                .fill(LinearGradient(colors:[gate.color.jewelLight,gate.color.tint,gate.color.jewelDark],startPoint:.topLeading,endPoint:.bottomTrailing))
                .shadow(color:gate.color.tint.opacity(0.75),radius:7)
            RoundedRectangle(cornerRadius:6).strokeBorder(gate.color.jewelLight,lineWidth:1.3)
            Group {
                if horizontal {
                    HStack(spacing:3) { Image(systemName:gate.color.symbol); Image(systemName:arrow(gate.side)) }
                } else {
                    VStack(spacing:3) { Image(systemName:gate.color.symbol); Image(systemName:arrow(gate.side)) }
                }
            }.font(.system(size:8,weight:.black)).foregroundStyle(gate.color.jewelDark)
                .shadow(color:.white.opacity(0.6),radius:0,y:0.5)
        }
        .frame(width:horizontal ? length : 14,height:horizontal ? 14 : length).position(x:x,y:y)
        .accessibilityLabel("\(gate.color.name) dock on the \(String(describing:gate.side)) edge, position \(gate.start+1), width \(gate.span)")
    }

    private func pieceView(_ piece:Piece,cell:CGFloat)->some View {
        let selected = store.selectedPiece == piece.id
        let hinted = store.hintMove?.pieceID == piece.id
        return ZStack(alignment:.topLeading) {
            PieceConnections(cells:piece.cells,cell:cell).fill(piece.color.jewelDark).offset(y:3)
            PieceConnections(cells:piece.cells,cell:cell).fill(piece.color.tint)
            ForEach(Array(piece.cells.enumerated()),id:\.offset) { _,point in
                PrismTile(color:piece.color,symbols:store.settings.symbols)
                    .frame(width:cell-3,height:cell-3)
                    .offset(x:CGFloat(point.x)*cell+1.5,y:CGFloat(point.y)*cell+1.5)
            }
            if selected || hinted {
                PieceSilhouette(cells:piece.cells,cell:cell)
                    .stroke(hinted ? HarbourTheme.gold : .white.opacity(0.97),lineWidth:2.4)
                    .shadow(color:hinted ? HarbourTheme.gold.opacity(0.75) : .white.opacity(0.5),radius:4)
            }
            if hinted, let move = store.hintMove {
                Image(systemName:arrow(move.direction)).font(.system(size:cell*0.32,weight:.black))
                    .foregroundStyle(.white).padding(7)
                    .background(Color(hex:0x432F66),in:Circle())
                    .overlay(Circle().strokeBorder(HarbourTheme.gold,lineWidth:2))
                    .offset(x:CGFloat(piece.cells[0].x)*cell+cell*0.15,y:CGFloat(piece.cells[0].y)*cell+cell*0.15)
            }
        }
        .frame(width:CGFloat(piece.width)*cell,height:CGFloat(piece.height)*cell,alignment:.topLeading)
        .contentShape(PieceSilhouette(cells:piece.cells,cell:cell))
        .offset(dragging == piece.id ? translation : .zero)
        .modifier(PrismShake(trigger:shakeTriggers[piece.id,default:0],enabled:!reduceMotion))
        .shadow(color:hinted ? HarbourTheme.gold.opacity(0.65) : .black.opacity(selected ? 0.45 : 0.30),radius:selected ? 6 : 2,y:selected ? 5 : 3)
        .onTapGesture {
            guard !store.paused, !store.expired, store.reward == nil else { return }
            store.selectedPiece = piece.id; store.impact()
        }
        .highPriorityGesture(DragGesture(minimumDistance:5)
            .updating($dragging) { _,state,_ in
                if !store.paused && !store.expired && store.reward == nil { state = piece.id }
            }
            .updating($translation) { value,state,_ in
                guard !store.paused, !store.expired, store.reward == nil else { return }
                if abs(value.translation.width) > abs(value.translation.height) { state = CGSize(width:value.translation.width,height:0) }
                else { state = CGSize(width:0,height:value.translation.height) }
            }
            .onChanged { _ in
                guard !store.paused, !store.expired, store.reward == nil else { return }
                store.selectedPiece = piece.id
            }
            .onEnded { value in
                let dx = value.translation.width; let dy = value.translation.height
                let horizontal = abs(dx) > abs(dy)
                let distance = horizontal ? dx : dy
                guard abs(distance) >= cell*0.22 else { return }
                let direction:Direction = horizontal ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                withAnimation(reduceMotion ? nil : .spring(response:0.26,dampingFraction:0.72)) {
                    store.move(pieceID:piece.id,direction:direction,steps:max(1,Int((abs(distance)/cell).rounded())))
                }
            })
        .accessibilityElement(children:.ignore)
        .accessibilityLabel("\(piece.color.name) prism, \(piece.cells.count) squares, column \(piece.origin.x+1), row \(piece.origin.y+1)")
        .accessibilityHint("Swipe actions to move toward the matching \(piece.color.name) dock")
        .accessibilityAction(named:"Move up") { store.move(pieceID:piece.id,direction:.up,steps:1) }
        .accessibilityAction(named:"Move down") { store.move(pieceID:piece.id,direction:.down,steps:1) }
        .accessibilityAction(named:"Move left") { store.move(pieceID:piece.id,direction:.left,steps:1) }
        .accessibilityAction(named:"Move right") { store.move(pieceID:piece.id,direction:.right,steps:1) }
    }

    private func celebrationLabel(_ event:HarbourMoveEvent)->some View {
        Text(event.combo > 1 ? "\(event.combo)× Brilliant!" : "Beautiful!")
            .font(.system(size:35,weight:.black,design:.rounded)).italic()
            .foregroundStyle(LinearGradient(colors:[.white,Color(hex:0xFFF29C),HarbourTheme.gold],startPoint:.top,endPoint:.bottom))
            .shadow(color:Color(hex:0x51366D),radius:0,x:2,y:3)
            .shadow(color:Color(hex:0x51366D),radius:0,x:-2,y:-1)
            .shadow(color:.black.opacity(0.4),radius:5,y:5)
            .lineLimit(1).minimumScaleFactor(0.6)
            .rotationEffect(.degrees(reduceMotion ? 0 : -7))
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func receive(_ event:HarbourMoveEvent) {
        let sessionID = store.session?.id
        if event.result == .blocked {
            withAnimation(reduceMotion ? nil : .linear(duration:0.3)) {
                shakeTriggers[event.piece.id,default:0] += 1
            }
        }
        guard event.result == .exited else { return }
        effects.append(event)
        withAnimation(reduceMotion ? .easeOut(duration:0.15) : .spring(response:0.32,dampingFraction:0.6)) {
            celebration = event
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds:850_000_000)
            guard !Task.isCancelled, store.session?.id == sessionID, celebration?.id == event.id else { return }
            withAnimation(.easeOut(duration:0.24)) { celebration = nil }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds:1_350_000_000)
            guard !Task.isCancelled, store.session?.id == sessionID else { return }
            effects.removeAll { $0.id == event.id }
        }
    }

    private func clearEffects() {
        effects = []; celebration = nil; shakeTriggers = [:]
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

/// Coloured bridges visually join cells belonging to one piece. Separate pieces
/// retain a dark gap even when they happen to share the same colour.
struct PieceConnections: Shape {
    var cells:[Cell]
    var cell:CGFloat
    func path(in rect:CGRect)->Path {
        var path = Path()
        let occupied = Set(cells)
        for c in cells {
            let x = CGFloat(c.x)*cell
            let y = CGFloat(c.y)*cell
            if occupied.contains(Cell(x:c.x+1,y:c.y)) {
                path.addRect(CGRect(x:x+cell*0.5,y:y+1.5,width:cell,height:cell-3))
            }
            if occupied.contains(Cell(x:c.x,y:c.y+1)) {
                path.addRect(CGRect(x:x+1.5,y:y+cell*0.5,width:cell-3,height:cell))
            }
        }
        return path
    }
}
