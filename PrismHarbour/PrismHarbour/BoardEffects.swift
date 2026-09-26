import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

/// Short-lived presentation only. Puzzle state and rewards stay authoritative in the store.
struct DockEffect: View {
    let event: HarbourMoveEvent
    let level: Level
    let cell: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var flight: CGFloat = 0

    private var boardSize: CGSize {
        CGSize(width: CGFloat(level.columns) * cell + 32, height: CGFloat(level.rows) * cell + 32)
    }
    private var gatePoint: CGPoint {
        let midpointX = 16 + (CGFloat(event.piece.origin.x) + CGFloat(event.piece.width) / 2) * cell
        let midpointY = 16 + (CGFloat(event.piece.origin.y) + CGFloat(event.piece.height) / 2) * cell
        switch event.direction {
        case .up: return CGPoint(x: midpointX, y: 12)
        case .down: return CGPoint(x: midpointX, y: boardSize.height - 12)
        case .left: return CGPoint(x: 12, y: midpointY)
        case .right: return CGPoint(x: boardSize.width - 12, y: midpointY)
        }
    }
    private var travel: CGSize {
        switch event.direction {
        case .up: return CGSize(width: 0, height: -CGFloat(event.piece.origin.y + event.piece.height) * cell - 10)
        case .down: return CGSize(width: 0, height: CGFloat(level.rows - event.piece.origin.y) * cell + 10)
        case .left: return CGSize(width: -CGFloat(event.piece.origin.x + event.piece.width) * cell - 10, height: 0)
        case .right: return CGSize(width: CGFloat(level.columns - event.piece.origin.x) * cell + 10, height: 0)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !reduceMotion {
                ZStack(alignment: .topLeading) {
                    PieceConnections(cells: event.piece.cells, cell: cell).fill(event.piece.color.tint)
                    ForEach(Array(event.piece.cells.enumerated()), id: \.offset) { _, point in
                        PrismTile(color: event.piece.color, symbols: true)
                            .frame(width: cell - 3, height: cell - 3)
                            .offset(x: CGFloat(point.x) * cell + 1.5, y: CGFloat(point.y) * cell + 1.5)
                    }
                }
                .frame(width: CGFloat(event.piece.width) * cell, height: CGFloat(event.piece.height) * cell)
                .shadow(color: event.piece.color.tint.opacity(0.8), radius: 12)
                .scaleEffect(1 - flight * 0.16)
                .offset(x: 16 + CGFloat(event.piece.origin.x) * cell + travel.width * flight,
                        y: 16 + CGFloat(event.piece.origin.y) * cell + travel.height * flight)
                .opacity(Double(1 - flight * flight))
                .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active || reduceMotion)) { clock in
                let elapsed = clock.date.timeIntervalSince(event.createdAt)
                Canvas { context, _ in
                    let t = reduceMotion ? 0.28 : max(0, elapsed - 0.08)
                    let alpha = max(0, 1 - t / 1.15)
                    guard alpha > 0 else { return }
                    let ring = CGFloat(8 + t * 78)
                    let circle = Path(ellipseIn: CGRect(x: gatePoint.x - ring, y: gatePoint.y - ring, width: ring * 2, height: ring * 2))
                    context.stroke(circle, with: .color(event.piece.color.tint.opacity(alpha * 0.8)), lineWidth: 5 * alpha)
                    context.stroke(circle, with: .color(.white.opacity(alpha * 0.45)), lineWidth: 1.3)
                    if !reduceMotion {
                        for index in 0..<24 {
                            let angle = Double(index) * 2.399963 + Double(event.piece.id)
                            let speed = Double(32 + index % 7 * 11)
                            let x = gatePoint.x + CGFloat(cos(angle) * speed * t)
                            let y = gatePoint.y + CGFloat(sin(angle) * speed * t + 32 * t * t)
                            let size = CGFloat(2 + index % 4) * CGFloat(alpha)
                            let color = index % 3 == 0 ? HarbourTheme.gold : index % 3 == 1 ? Color.white : event.piece.color.tint
                            let spark = Path { path in
                                path.move(to: CGPoint(x: x, y: y - size * 1.8))
                                path.addLine(to: CGPoint(x: x + size * 0.55, y: y - size * 0.55))
                                path.addLine(to: CGPoint(x: x + size * 1.8, y: y))
                                path.addLine(to: CGPoint(x: x + size * 0.55, y: y + size * 0.55))
                                path.addLine(to: CGPoint(x: x, y: y + size * 1.8))
                                path.addLine(to: CGPoint(x: x - size * 0.55, y: y + size * 0.55))
                                path.addLine(to: CGPoint(x: x - size * 1.8, y: y))
                                path.addLine(to: CGPoint(x: x - size * 0.55, y: y - size * 0.55))
                                path.closeSubpath()
                            }
                            context.fill(spark, with: .color(color.opacity(alpha)))
                        }
                    }
                }
            }
            .frame(width: boardSize.width, height: boardSize.height)
        }
        .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
        .allowsHitTesting(false).accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.46)) { flight = 1 }
        }
    }
}

struct PrismShake: GeometryEffect {
    var trigger: CGFloat
    var enabled: Bool
    var animatableData: CGFloat {
        get { trigger }
        set { trigger = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: enabled ? sin(trigger * .pi * 6) * 5 : 0, y: 0))
    }
}

struct CelebrationConfetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var born = Date()
    @State private var running = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running || scenePhase != .active || reduceMotion)) { clock in
            Canvas { context, size in
                guard !reduceMotion else { return }
                let elapsed = clock.date.timeIntervalSince(born)
                guard elapsed < 4 else { return }
                let colors: [Color] = [HarbourTheme.gold, HarbourTheme.mint, .pink, .cyan, .white, HarbourTheme.lavender]
                for index in 0..<78 {
                    let delay = Double(index % 13) * 0.035
                    let t = max(0, elapsed - delay)
                    let originX = size.width * (index % 2 == 0 ? 0.1 : 0.9)
                    let vx = (index % 2 == 0 ? 1.0 : -1.0) * Double(35 + index * 17 % 170)
                    let vy = -Double(90 + index * 23 % 180)
                    let x = originX + CGFloat(vx * t)
                    let y = size.height * 0.25 + CGFloat(vy * t + 100 * t * t)
                    var particle = context
                    particle.opacity = min(1, max(0, 4 - elapsed))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(t * Double(110 + index * 7)))
                    let rect = CGRect(x: -3, y: -5, width: 6, height: 10)
                    particle.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(colors[index % colors.count]))
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
        .task {
            try? await Task.sleep(nanoseconds: 4_200_000_000)
            if !Task.isCancelled { running = false }
        }
    }
}
