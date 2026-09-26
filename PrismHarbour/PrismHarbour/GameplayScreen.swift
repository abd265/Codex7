import SwiftUI
#if canImport(PrismCore)
import PrismCore
#endif

struct VoyageView: View {
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmRestart = false
    @State private var showVictory = false

    var body: some View {
        GeometryReader { geo in
            let level = store.currentLevel
            let boardWidth = min(geo.size.width - 36, min(430, max(220, (geo.size.height - 344) * CGFloat(level.columns) / CGFloat(level.rows) + 32)))
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    header
                    Text(level.title)
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .shadow(color: Color(hex: 0x170B42), radius: 0, y: 3)
                        .minimumScaleFactor(0.7).lineLimit(1).frame(height: 32)
                    status
                    PuzzleBoardView()
                        .frame(width: boardWidth, height: (boardWidth - 32) * CGFloat(level.rows) / CGFloat(level.columns) + 32)
                        .frame(maxWidth: .infinity)
                    controls
                    boosters
                }
                .padding(.horizontal, 18).padding(.top, 5).padding(.bottom, 12)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
        }
        .overlay { if store.paused || store.expired || (showVictory && store.reward != nil) { gameOverlay } }
        .task(id: store.reward != nil) {
            if store.reward == nil { showVictory = false; return }
            if !reduceMotion { try? await Task.sleep(nanoseconds: 700_000_000) }
            guard !Task.isCancelled, store.reward != nil else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.8)) { showVictory = true }
        }
        .confirmationDialog("Start this level again?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Restart level") { store.retry() }
        } message: { Text("Your moves will reset. Pearls spent on hints or time will not be returned.") }
    }
    private var header: some View {
        HStack(spacing: 8) {
            RoundIconButton(icon: "chevron.left", label: "Pause and leave level") { store.setPaused(true) }
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                Text(store.isChallenge ? "CHALLENGE \(store.challengeNumber ?? 1)" : (store.isDaily ? "DAILY TIDE" : "LEVEL \(store.currentLevel.id)"))
                    .font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(HarbourTheme.gold)
                Text(store.isChallenge ? ChallengeCatalog.tierName(for:store.currentLevel.id) : (store.isDaily ? "A fresh challenge" : regionName(store.currentLevel.region)))
                    .font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 4)
            RoundIconButton(icon: "pause.fill", label: "Pause game") { store.setPaused(true) }
        }.frame(height: 46)
    }
    private var status: some View {
        HStack(spacing: 8) {
            meter(icon: store.isChallenge ? "brain.head.profile" : (store.session?.relaxed == true ? "infinity" : "timer"), text: timeText,
                  caption: store.isChallenge ? "THINK AHEAD" : "TIME", color: timeLow ? Color(hex: 0xFF728C) : HarbourTheme.mint)
            meter(icon: "arrow.up.and.down.and.arrow.left.and.right", text: "\(store.session?.game.moves ?? 0) moves",
                  caption: "AIM FOR \(store.currentLevel.parMoves)", color: HarbourTheme.gold)
            meter(icon: "diamond.fill", text: "\(store.session?.game.pieces.count ?? 0) left",
                  caption: "TO DOCK", color: HarbourTheme.lavender)
        }.frame(height: 49)
    }
    private func meter(icon: String, text: String, caption: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
                .shadow(color: color.opacity(0.4), radius: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.system(size: 14, weight: .heavy, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.65)
                Text(caption).font(.system(size: 7, weight: .black, design: .rounded)).tracking(0.6).foregroundStyle(color.opacity(0.9))
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(LinearGradient(colors: [Color(hex: 0x4B2B84), Color(hex: 0x281951)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.45), lineWidth: 1.3))
            .shadow(color: Color(hex: 0x10042F).opacity(0.5), radius: 0, y: 3)
    }
    private var controls: some View {
        HStack(spacing: 10) {
            if let selected = store.selectedPiece, let piece = store.session?.game.pieces.first(where: { $0.id == selected }) {
                Image(systemName: piece.color.symbol).foregroundStyle(piece.color.tint).font(.system(size: 20, weight: .black))
                ForEach([Direction.left, .up, .down, .right], id: \.self) { direction in
                    Button { store.move(pieceID: selected, direction: direction, steps: 1) } label: {
                        Image(systemName: arrow(direction)).font(.system(size: 16, weight: .black))
                            .frame(width: 43, height: 34)
                            .background(LinearGradient(colors: [Color(hex: 0x7552B5), Color(hex: 0x432775)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.25)))
                            .shadow(color: Color(hex: 0x170934), radius: 0, y: 3)
                    }.buttonStyle(GamePressStyle()).accessibilityLabel("Move \(piece.color.name) \(String(describing: direction))")
                }
            } else {
                Image(systemName: store.hintMove == nil ? "hand.draw.fill" : "sparkles").foregroundStyle(HarbourTheme.gold)
                Text(store.hintMove.map { "Slide the glowing prism \(String(describing: $0.direction))" } ?? (store.isChallenge ? "Move blockers aside. Make space to escape." : "Slide gems into their matching docks"))
                    .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            }
        }.frame(height: 38)
    }
    private var boosters: some View {
        HStack(spacing: 13) {
            booster("Undo", "FREE", icon: "arrow.uturn.backward", color: HarbourTheme.mint,
                    disabled: store.session?.history.isEmpty ?? true) { store.undo() }
            booster(store.findingHint ? "Finding…" : "Hint", "15", icon: "sparkles", color: HarbourTheme.gold,
                    disabled: store.findingHint) { store.requestHint() }
            if store.isChallenge || store.session?.relaxed == true {
                booster("Restart", "FREE", icon: "arrow.clockwise", color: HarbourTheme.lavender) { confirmRestart = true }
            } else {
                booster("+30 sec", "30", icon: "hourglass.bottomhalf.filled", color: HarbourTheme.lavender) { store.addTime() }
            }
            VStack(spacing: 5) {
                Image(systemName: "sparkle").font(.system(size: 20, weight: .black)).foregroundStyle(HarbourTheme.gold)
                Text(store.progress.coins.formatted()).font(.system(size: 15, weight: .heavy, design: .rounded)).monospacedDigit()
                Text("PEARLS").font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(HarbourTheme.gold)
            }.frame(width: 54).accessibilityLabel("\(store.progress.coins) pearls")
        }.frame(height: 80).padding(.horizontal, 4)
    }
    private func booster(_ title: String, _ price: String, icon: String, color: Color, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .bottom) {
                    Circle().fill(Color(hex: 0x210C43)).frame(width: 48, height: 48).offset(y: 3)
                    Circle().fill(LinearGradient(colors: [color.opacity(0.9), color.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48).overlay(Circle().strokeBorder(color, lineWidth: 2))
                    Image(systemName: icon).font(.system(size: 23, weight: .bold)).foregroundStyle(.white)
                        .shadow(color: Color(hex: 0x29124E).opacity(0.7), radius: 0, y: 2).offset(y: -12)
                    HStack(spacing: 2) {
                        if price != "FREE" { Image(systemName: "sparkle").font(.system(size: 7, weight: .black)) }
                        Text(price).font(.system(size: 9, weight: .black, design: .rounded))
                    }.foregroundStyle(Color(hex: 0x543211)).padding(.horizontal, 7).padding(.vertical, 2)
                        .background(LinearGradient(colors: [.white, HarbourTheme.gold], startPoint: .top, endPoint: .bottom), in: Capsule()).offset(y: 4)
                }.frame(height: 52)
                Text(title).font(.system(size: 11, weight: .heavy, design: .rounded))
            }.frame(maxWidth: .infinity).opacity(disabled ? 0.42 : 1)
        }.buttonStyle(GamePressStyle()).disabled(disabled).accessibilityLabel("\(title), \(price == "FREE" ? "Free" : price + " pearls")")
    }
    private var timeLow: Bool { !store.isChallenge && store.session?.relaxed == false && (store.session?.remaining ?? 0) < 30 }
    private var timeText: String {
        guard let session = store.session else { return "0:00" }
        if store.isChallenge { return "Untimed" }
        if session.relaxed { return "Calm" }
        let seconds = max(0, Int(ceil(session.remaining)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    private var gameOverlay: some View {
        ZStack {
            Color(hex: 0x13092F).opacity(0.91).ignoresSafeArea()
            if let reward = store.reward, showVictory {
                VictoryCelebration(reward: reward)
            } else {
                ScrollView {
                    VStack(spacing: 19) { if store.expired { timeUp } else { pauseMenu } }
                        .padding(26).frame(maxWidth: 400).background {
                            RoundedRectangle(cornerRadius: 32)
                                .fill(LinearGradient(colors: [Color(hex: 0x623BA0), Color(hex: 0x29184F)], startPoint: .top, endPoint: .bottom))
                                .overlay(RoundedRectangle(cornerRadius: 32).strokeBorder(HarbourTheme.gold.opacity(0.6), lineWidth: 2))
                        }.padding(24).frame(maxWidth: .infinity).padding(.vertical, 24)
                }.scrollBounceBehavior(.basedOnSize)
            }
        }.transition(.opacity)
    }
    private var pauseMenu: some View {
        Group {
            Image(systemName: "pause.circle.fill").font(.system(size: 58, weight: .bold)).foregroundStyle(HarbourTheme.gold)
                .shadow(color: .black.opacity(0.25), radius: 0, y: 4)
            Text("A moment of calm.").font(.system(size: 27, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
            Text(store.isChallenge ? "No timer. Try a sequence, undo, and try again. Aim for \(store.currentLevel.parMoves) moves to earn three stars." : "Your gems are right where you left them.").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(HarbourTheme.muted).multilineTextAlignment(.center)
            Button("Keep sailing") { store.setPaused(false) }.buttonStyle(PrimaryButtonStyle(color: HarbourTheme.mint))
            menuRow("Start this level again", icon: "arrow.clockwise") { confirmRestart = true }
            menuRow("How to play", icon: "questionmark.circle.fill") { store.showHelp = true }
            menuRow("Settings", icon: "gearshape.fill") { store.showSettings = true }
            if store.isChallenge {
                menuRow("Back to challenges", icon: "map.fill") { store.leaveGame(); store.homeTab=1; store.challengeMap=true }
            }
            menuRow("Return to harbour", icon: "house.fill") { store.leaveGame() }
        }
    }
    private var timeUp: some View {
        Group {
            Image(systemName: "hourglass").font(.system(size: 58, weight: .bold)).foregroundStyle(HarbourTheme.gold)
            Text("Another wave awaits!").font(.system(size: 29, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
            Text("You’re close. Add a little time or try a fresh route.").font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(HarbourTheme.muted).multilineTextAlignment(.center)
            Button("Try again") { store.retry() }.buttonStyle(PrimaryButtonStyle(color: HarbourTheme.mint))
            Button("Add 30 seconds · 30 pearls") { store.addTime() }.font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(HarbourTheme.gold)
            Button("Back to harbour") { store.leaveGame() }.font(.system(size: 14, weight: .bold, design: .rounded))
        }
    }
    private func menuRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 23).foregroundStyle(HarbourTheme.gold)
                Text(title); Spacer(); Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
            }.font(.system(size: 14, weight: .bold, design: .rounded)).padding(13)
                .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(GamePressStyle())
    }
}

struct GamePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .brightness(configuration.isPressed ? 0.07 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct VictoryCelebration: View {
    let reward: CompletionReward
    @EnvironmentObject private var store: HarbourStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var starsShown = 0
    var body: some View {
        ZStack {
            CelebrationConfetti()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    treasureStars.padding(.top, 5).padding(.bottom, 15)
                    Text(challengeMastered ? "Voyage mastered" : "Clear waters.").font(.system(size: 38, weight: .black, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xE4CBFF)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color(hex: 0x70449D), radius: 0, y: 3)
                    Text(store.isChallenge ? "CHALLENGE \(store.challengeNumber ?? 1) COMPLETE!" : (store.isDaily ? "DAILY TIDE COMPLETE!" : "LEVEL \(store.currentLevel.id) COMPLETE!"))
                        .font(.system(size: 12, weight: .black, design: .rounded)).tracking(1.5).foregroundStyle(HarbourTheme.gold)
                    HStack(spacing: 0) {
                        rewardStat("\(store.session?.game.moves ?? 0)", caption: "MOVES", icon: "arrow.up.and.down.and.arrow.left.and.right", color: HarbourTheme.mint)
                        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 34)
                        rewardStat("+\(reward.coins)", caption: "PEARLS", icon: "sparkle", color: HarbourTheme.gold)
                    }.padding(.vertical, 19)
                        .background(LinearGradient(colors: [Color(hex: 0x633790), Color(hex: 0x311952)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(HarbourTheme.gold.opacity(0.5), lineWidth: 1.5))
                    Text("Three stars: \(store.currentLevel.parMoves) moves or fewer")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(HarbourTheme.muted)
                    if let next = store.followingLevel {
                        Button { store.start(next) } label: {
                            HStack { Text(store.isChallenge ? "Next challenge" : "Next harbour"); Image(systemName: "arrow.right.circle.fill") }
                        }.buttonStyle(PrimaryButtonStyle(color: HarbourTheme.mint))
                    } else if store.isChallenge {
                        Text("All 20 challenges cleared. Revisit your favourites to perfect the route.")
                            .font(.system(size:12,weight:.medium,design:.rounded)).multilineTextAlignment(.center).foregroundStyle(HarbourTheme.muted)
                        Button("Back to challenges") { store.leaveGame(); store.homeTab=1; store.challengeMap=true }
                            .buttonStyle(PrimaryButtonStyle(color: HarbourTheme.mint))
                    } else {
                        Button("Back to the harbour") { store.leaveGame() }.buttonStyle(PrimaryButtonStyle(color: HarbourTheme.mint))
                    }
                    HStack(spacing: 30) {
                        Button("Play again") { store.retry() }
                        Button("Harbour") { store.leaveGame() }
                    }.font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8)).padding(.top, 5)
                }.padding(28).frame(maxWidth: 390).frame(maxWidth: .infinity)
                    .scaleEffect(revealed ? 1 : 0.8).opacity(revealed ? 1 : 0)
            }.scrollBounceBehavior(.basedOnSize)
        }
        .task {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75)) { revealed = true }
            for index in 1...3 {
                if !reduceMotion { try? await Task.sleep(nanoseconds: 170_000_000) }
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.48)) { starsShown = index }
            }
        }
    }
    private var challengeMastered:Bool { store.isChallenge && store.followingLevel == nil }
    private var treasureStars: some View {
        ZStack(alignment: .bottom) {
            Image("PrizeChest").resizable().scaledToFill().frame(width: 245, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .overlay(LinearGradient(colors: [.clear, Color(hex: 0x13092F)], startPoint: .center, endPoint: .bottom))
            HStack(spacing: 13) {
                ForEach(0..<3) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: index == 1 ? 61 : 47, weight: .black))
                        .foregroundStyle(starGradient(index))
                        .shadow(color: Color(hex: 0x9B4A14), radius: 0, y: 4)
                        .shadow(color: index < reward.stars ? HarbourTheme.gold.opacity(0.7) : .clear, radius: 12)
                        .rotationEffect(.degrees(index == 0 ? -16 : index == 2 ? 16 : 0))
                        .scaleEffect(starsShown > index ? 1 : 0.01)
                        .offset(y: index == 1 ? -10 : 0)
                }
            }.offset(y: 10)
        }
    }
    private func starGradient(_ index: Int) -> LinearGradient {
        LinearGradient(colors: index < reward.stars ? [Color(hex: 0xFFF9BA), HarbourTheme.gold, Color(hex: 0xF49B26)] : [Color(hex: 0x684D82), Color(hex: 0x493565)], startPoint: .top, endPoint: .bottom)
    }
    private func rewardStat(_ value: String, caption: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 19, weight: .bold))
                Text(value).font(.system(size: 29, weight: .black, design: .rounded))
            }.foregroundStyle(color)
            Text(caption).font(.system(size: 9, weight: .black, design: .rounded)).tracking(1.5)
        }.frame(maxWidth: .infinity)
    }
}

func arrow(_ direction: Direction) -> String {
    switch direction { case .up: return "arrow.up"; case .down: return "arrow.down"; case .left: return "arrow.left"; case .right: return "arrow.right" }
}
