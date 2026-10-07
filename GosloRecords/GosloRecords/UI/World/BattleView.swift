import SwiftUI

/// Battle screen: the opponent at the top, you from behind at the bottom, crowd bars,
/// narration in the text box and a 4-move menu. Each round is played back as animation.
struct BattleView: View {
    @Environment(AppModel.self) private var model
    let clash: ClashState
    let state: GameState

    private enum Stage { case intro, menu, animating, counter, finished }

    @State private var stage: Stage = .intro
    @State private var message = ""
    @State private var playerHype = Double(ClashState.startingHype)
    @State private var opponentHype = Double(ClashState.startingHype)
    @State private var shown = 0
    @State private var entered = false
    @State private var projectile: Projectile?
    @State private var projectileProgress: CGFloat = 0
    @State private var flashPlayer = false
    @State private var flashOpponent = false
    @State private var shakePlayer: CGFloat = 0
    @State private var shakeOpponent: CGFloat = 0
    @State private var lungePlayer = false
    @State private var lungeOpponent = false
    @State private var pop: DamagePop?
    @State private var banner: String?
    @State private var faintedPlayer = false
    @State private var faintedOpponent = false
    @State private var idle = false
    // Text: advances on its own at reading speed, or on tap.
    @State private var typed = false
    @State private var revealAll = false
    @State private var skip = false
    // Secret technique gauges (displayed value, follows the animation).
    @State private var playerMeter = 0.0
    @State private var opponentMeter = 0.0
    @State private var playerSecretUsed = false
    @State private var opponentSecretUsed = false
    @State private var cinematic: SecretCinematic?
    @State private var whiteFlash = false
    // Countering a boss's technique.
    @State private var counterTaps = 0
    @State private var counterLeft: CGFloat = 1

    private var opponent: CastMember? { model.engine.castMember(clash.opponentId) }
    private var counterStyle: CounterStyle { opponent?.clash?.counter ?? .mash }
    private var opponentName: String { opponent?.name ?? "???" }
    private var opponentLevel: Int { opponent?.clash?.scaled(by: clash.levelBonus).level ?? 1 }
    private var playerLevel: Int {
        let levels = Skill.allCases.map { state.skills.level($0) }
        return max(1, Int((Double(levels.reduce(0, +)) / Double(levels.count)).rounded()))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, arena = geo.size.height * 0.58
            let opponentSpot = CGPoint(x: w * 0.72, y: arena * 0.36)
            let playerSpot = CGPoint(x: w * 0.27, y: arena * 0.74)

            VStack(spacing: 0) {
                ZStack {
                    BattleBackdrop()
                        .frame(width: w, height: arena)
                        .clipped()

                    Platform().frame(width: 170, height: 40).position(x: opponentSpot.x, y: opponentSpot.y + 54)
                    Platform().frame(width: 190, height: 44).position(x: playerSpot.x, y: playerSpot.y + 58)

                    // Opponent (facing us).
                    PixelImage(CharacterSprite.image(opponent?.look ?? CharacterLook(), facing: .down), width: 124)
                        .opacity(flashOpponent ? 0.15 : 1)
                        .modifier(Shake(amount: shakeOpponent))
                        .offset(x: lungeOpponent ? -26 : 0, y: (lungeOpponent ? 16 : 0) + (idle ? -2 : 2))
                        .offset(y: faintedOpponent ? 90 : 0)
                        .opacity(faintedOpponent ? 0 : 1)
                        .offset(x: entered ? 0 : -w)
                        .position(opponentSpot)

                    // The player, from behind.
                    PixelImage(CharacterSprite.image(state.rapper.look, facing: .up), width: 140)
                        .opacity(flashPlayer ? 0.15 : 1)
                        .modifier(Shake(amount: shakePlayer))
                        .offset(x: lungePlayer ? 28 : 0, y: (lungePlayer ? -18 : 0) + (idle ? 2 : -1))
                        .offset(y: faintedPlayer ? 110 : 0)
                        .opacity(faintedPlayer ? 0 : 1)
                        .offset(x: entered ? 0 : w)
                        .position(playerSpot)

                    InfoPanel(name: opponentName, level: opponentLevel, hype: opponentHype, highlight: false, showsNumbers: false,
                              meter: opponentSecretUsed ? 0 : opponentMeter, secretUsed: opponentSecretUsed)
                        .frame(width: w * 0.56)
                        .position(x: w * 0.31, y: arena * 0.13)
                        .offset(x: entered ? 0 : -w)

                    InfoPanel(name: state.rapper.name, level: playerLevel, hype: playerHype, highlight: true, showsNumbers: true,
                              meter: playerSecretUsed ? 0 : playerMeter, secretUsed: playerSecretUsed)
                        .frame(width: w * 0.56)
                        .position(x: w * 0.71, y: arena * 0.80)
                        .offset(x: entered ? 0 : w)

                    if let projectile {
                        ProjectileView(move: projectile.move)
                            .modifier(ProjectileMotion(progress: projectileProgress, from: projectile.fromPlayer ? playerSpot : opponentSpot,
                                                       to: projectile.fromPlayer ? opponentSpot : playerSpot, wave: projectile.move == .flow))
                    }

                    if let pop {
                        DamagePopView(pop: pop)
                            .position(pop.onPlayer ? CGPoint(x: playerSpot.x + 50, y: playerSpot.y - 70)
                                                   : CGPoint(x: opponentSpot.x - 40, y: opponentSpot.y - 60))
                            .id(pop.id)
                    }

                    if let banner {
                        Text(banner)
                            .font(.display(46))
                            .foregroundStyle(Theme.accent)
                            .shadow(color: .black, radius: 0, x: 3, y: 3)
                            .rotationEffect(.degrees(-6))
                            .transition(.scale(scale: 2.2).combined(with: .opacity))
                            .position(x: w / 2, y: arena * 0.45)
                    }

                    if let cinematic {
                        SecretCinematicView(cinematic: cinematic)
                            .frame(width: w, height: arena)
                            .transition(.opacity)
                    }

                    if whiteFlash {
                        Color.white.frame(width: w, height: arena).transition(.opacity)
                    }
                }
                .frame(width: w, height: arena)
                .clipped()

                controls
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.06))
            }
        }
        .overlay {
            if stage == .counter {
                switch counterStyle {
                case .mash:
                    CounterOverlay(taps: counterTaps, timeLeft: counterLeft)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onEnded { _ in
                            counterTaps += 1
                            SoundEngine.shared.play(.tap)
                        })
                        .transition(.opacity)
                case .pen:
                    PenCounterOverlay(timeLeft: counterLeft) { counterTaps = ClashState.counterEquivalentTaps(score: $0) }
                        .transition(.opacity)
                case .beat:
                    BeatCounterOverlay(timeLeft: counterLeft) { counterTaps = ClashState.counterEquivalentTaps(score: $0) }
                        .transition(.opacity)
                }
            }
        }
        .onAppear(perform: intro)
    }

    // MARK: Bottom panel

    @ViewBuilder
    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            DialogueFrame(speaker: nil, showsArrow: typed && (stage == .animating || stage == .intro)) {
                TypewriterText(text: message, font: .system(size: 16, weight: .bold, design: .monospaced),
                               revealAll: revealAll) { typed = true }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if typed { skip = true } else { revealAll = true }
            }

            switch stage {
            case .menu:
                if let intel = model.engine.scoutingReport(for: clash.opponentId, in: state) {
                    Text(intelText(intel))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
                if clash.isBoss, case let bonus = model.engine.bossExperience(against: clash.opponentId, in: state), bonus > 0 {
                    Text("TU CONNAIS SON JEU : +\(bonus) \(bonus > 1 ? "NIVEAUX" : "NIVEAU")")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                }
                if clash.playerSecretReady {
                    SecretButton(technique: model.engine.playerSecret(in: state)) { play(.secret) }
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    let levels = model.engine.clashLevels(for: clash, in: state)
                    ForEach(ClashMove.allCases) { move in
                        MoveButton(move: move, level: levels(move.skill)) { play(.move(move)) }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                if clash.isWild {
                    Button("FUIR") { model.flee() }
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            case .finished:
                Button("Continuer") { model.finishClash() }
                    .buttonStyle(PrimaryButtonStyle())
                    .transition(.scale.combined(with: .opacity))
            case .intro, .animating, .counter:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: stage)
    }

    private func intelText(_ profile: ClashProfile) -> String {
        var parts: [String] = []
        if let weakness = profile.weakness { parts.append("Point faible : \(weakness.label)") }
        if let resistance = profile.resistance { parts.append("résiste à : \(resistance.label)") }
        return "YANIS : " + parts.joined(separator: " · ")
    }

    // MARK: Sequencing

    private func intro() {
        playerHype = Double(clash.playerHype)
        opponentHype = Double(clash.opponentHype)
        playerMeter = Double(clash.playerMeter)
        opponentMeter = Double(clash.opponentMeter)
        playerSecretUsed = clash.playerSecretUsed
        opponentSecretUsed = clash.opponentSecretUsed
        shown = clash.log.count
        withAnimation(.easeOut(duration: 0.7)) { entered = true }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { idle = true }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            if clash.isBoss {
                await showBanner("BOSS")
                await say("\(opponentName.uppercased()) : \(opponent?.role ?? "") — \(opponent?.bio ?? "")", hold: 0.4)
            } else {
                await say(clash.isWild ? "\(opponentName) surgit du terrain vague !" : "\(opponentName) veut clasher !", hold: 0.6)
            }
            await settle(clash)
        }
    }

    /// After a round: a boss's technique to counter, the end of the clash, or the next move.
    private func settle(_ updated: ClashState) async {
        if let pending = updated.pendingCounter {
            await runCounter(pending)
        } else if updated.isOver {
            await finish(updated)
        } else {
            message = "Que vas-tu faire ?"
            stage = .menu
        }
    }

    /// The boss announces its technique, the player taps as fast as they can, then it lands (softened).
    private func runCounter(_ pending: PendingCounter) async {
        let instruction = switch counterStyle {
        case .mash: "Tapote vite pour la contrer !"
        case .pen: "Touche les mots barrés en rouge, et rien d'autre !"
        case .beat: "Tape quand l'anneau touche la cible !"
        }
        await say("Oh non. \(opponentName.uppercased()) déclenche sa TECHNIQUE SECRÈTE… \(instruction)", hold: 0)
        SoundEngine.shared.play(.secretRiser)
        withAnimation(.easeOut(duration: 0.3)) {
            cinematic = SecretCinematic(name: pending.secret.name, byPlayer: false, look: opponent?.look ?? CharacterLook(),
                                        prop: pending.secret.prop)
        }
        try? await Task.sleep(for: .milliseconds(1400))
        withAnimation(.easeIn(duration: 0.2)) { cinematic = nil }

        counterTaps = 0
        counterLeft = 1
        message = counterStyle == .mash ? "TAPOTE ! TAPOTE ! TAPOTE !" : "CONTRE !"
        withAnimation(.easeOut(duration: 0.15)) { stage = .counter }
        withAnimation(.linear(duration: ClashState.counterSeconds)) { counterLeft = 0 }
        try? await Task.sleep(for: .seconds(ClashState.counterSeconds))
        withAnimation(.easeIn(duration: 0.15)) { stage = .animating }

        guard let updated = model.counterSecret(taps: counterTaps) else {
            stage = .menu
            return
        }
        let entries = Array(updated.log.dropFirst(shown))
        shown = updated.log.count
        for entry in entries { await animate(entry) }
        playerHype = Double(updated.playerHype)
        withAnimation(.easeOut(duration: 0.4)) { opponentSecretUsed = updated.opponentSecretUsed }
        await settle(updated)
    }

    private enum BattleAction { case move(ClashMove), secret }

    private func play(_ action: BattleAction) {
        guard stage == .menu else { return }
        stage = .animating
        let result: ClashState? = switch action {
        case .move(let move): model.clashMove(move)
        case .secret: model.clashSecret()
        }
        guard let updated = result else {
            stage = .menu
            return
        }
        let entries = Array(updated.log.dropFirst(shown))
        shown = updated.log.count
        Task {
            for entry in entries { await animate(entry) }
            playerHype = Double(updated.playerHype)
            opponentHype = Double(updated.opponentHype)
            withAnimation(.easeOut(duration: 0.4)) {
                playerMeter = Double(updated.playerMeter)
                opponentMeter = Double(updated.opponentMeter)
                playerSecretUsed = updated.playerSecretUsed
                opponentSecretUsed = updated.opponentSecretUsed
            }
            await settle(updated)
        }
    }

    private func animate(_ entry: ClashLogEntry) async {
        let attacker = entry.byPlayer ? state.rapper.name : opponentName
        if let secret = entry.secret {
            await playSecret(secret, entry: entry, attacker: attacker)
            return
        }
        await say("\(attacker.uppercased()) lance \(entry.move.label.uppercased()) !", hold: 0.1)

        withAnimation(.spring(response: 0.16, dampingFraction: 0.5)) {
            if entry.byPlayer { lungePlayer = true } else { lungeOpponent = true }
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            lungePlayer = false
            lungeOpponent = false
        }

        projectileProgress = 0
        projectile = Projectile(move: entry.move, fromPlayer: entry.byPlayer)
        withAnimation(.easeIn(duration: 0.45)) { projectileProgress = 1 }
        try? await Task.sleep(for: .milliseconds(460))
        projectile = nil

        if entry.impact == .miss {
            SoundEngine.shared.play(.miss)
            await showBanner("RATÉ !")
        } else {
            for _ in 0..<3 {
                if entry.byPlayer { flashOpponent = true } else { flashPlayer = true }
                try? await Task.sleep(for: .milliseconds(60))
                flashOpponent = false
                flashPlayer = false
                try? await Task.sleep(for: .milliseconds(60))
            }
            withAnimation(.linear(duration: 0.35)) {
                if entry.byPlayer { shakeOpponent += 1 } else { shakePlayer += 1 }
            }
            withAnimation(.easeOut(duration: 0.7)) {
                if entry.byPlayer {
                    opponentHype = max(0, opponentHype - Double(entry.damage))
                } else {
                    playerHype = max(0, playerHype - Double(entry.damage))
                }
            }
            pop = DamagePop(value: entry.damage, onPlayer: !entry.byPlayer, id: entry.id)
            SoundEngine.shared.play(entry.impact == .strong ? .strongHit : .hit)
            withAnimation(.easeOut(duration: 0.5)) {
                if entry.byPlayer { playerMeter += Double(entry.damage) } else { opponentMeter += Double(entry.damage) }
            }
            switch entry.impact {
            case .strong: await showBanner("ÇA TOUCHE !")
            case .weak: await showBanner("ÇA GLISSE…")
            default: try? await Task.sleep(for: .milliseconds(450))
            }
        }
        await say(entry.line, hold: 0.8)
    }

    private func finish(_ final: ClashState) async {
        withAnimation(.easeIn(duration: 0.6)) {
            if final.playerWon { faintedOpponent = true } else { faintedPlayer = true }
        }
        SoundEngine.shared.play(final.playerWon ? .victory : .defeat)
        await say(final.playerWon
                  ? "\(opponentName.uppercased()) est K.O. verbal ! Le public est avec toi."
                  : "Le public a choisi \(opponentName.hasSuffix(".") ? String(opponentName.dropLast()) : opponentName). Tu quittes la scène, tête basse.", hold: 0.2)
        stage = .finished
    }

    /// The full secret technique sequence: announcement, cinematic, flash, big hit.
    private func playSecret(_ secret: SecretTechnique, entry: ClashLogEntry, attacker: String) async {
        // A countered boss technique was already announced before the taps.
        if entry.countered == nil {
            await say(entry.byPlayer
                      ? "Ta jauge déborde… \(attacker.uppercased()) déclenche sa TECHNIQUE SECRÈTE !"
                      : "Oh non. \(attacker.uppercased()) a gardé une TECHNIQUE SECRÈTE…", hold: 0.2)
            SoundEngine.shared.play(.secretRiser)
            withAnimation(.easeOut(duration: 0.3)) {
                cinematic = SecretCinematic(name: secret.name, byPlayer: entry.byPlayer,
                                            look: entry.byPlayer ? state.rapper.look : (opponent?.look ?? CharacterLook()),
                                            prop: secret.prop)
            }
            try? await Task.sleep(for: .milliseconds(2200))
            withAnimation(.easeIn(duration: 0.2)) { cinematic = nil }
        }

        SoundEngine.shared.play(.secretHit)
        withAnimation(.easeOut(duration: 0.08)) { whiteFlash = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeIn(duration: 0.4)) { whiteFlash = false }
        withAnimation(.linear(duration: 0.6)) {
            if entry.byPlayer { shakeOpponent += 2 } else { shakePlayer += 2 }
        }
        withAnimation(.easeOut(duration: 1.0)) {
            if entry.byPlayer {
                opponentHype = max(0, opponentHype - Double(entry.damage))
                playerSecretUsed = true
            } else {
                playerHype = max(0, playerHype - Double(entry.damage))
                opponentSecretUsed = true
            }
        }
        pop = DamagePop(value: entry.damage, onPlayer: !entry.byPlayer, id: entry.id)
        await showBanner(entry.byPlayer ? "LÉGENDAIRE !" : counterBanner(entry.countered))
        await say(entry.line, hold: 1.2)
    }

    private func counterBanner(_ countered: Double?) -> String {
        guard let countered else { return "AÏE AÏE AÏE" }
        if countered >= ClashState.counterMaxReduction * 0.9 { return "CONTRÉ !" }
        if countered >= ClashState.counterMaxReduction * 0.4 { return "À MOITIÉ PARÉ" }
        return "AÏE AÏE AÏE"
    }

    /// Shows a line and waits long enough to read it. Tap: show it all, tap again: next.
    private func say(_ text: String, hold: Double) async {
        message = text
        typed = false
        revealAll = false
        skip = false
        let typing = Double(text.count) * TypewriterText.defaultSpeed
        let reading = max(1.1, Double(text.count) * 0.03) + hold
        var waited = 0.0
        while waited < typing + reading && !skip {
            try? await Task.sleep(for: .milliseconds(50))
            waited += 0.05
        }
        skip = false
    }

    private func showBanner(_ text: String) async {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { banner = text }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeOut(duration: 0.2)) { banner = nil }
    }
}

// MARK: - Pieces

private struct Projectile: Equatable {
    let move: ClashMove
    let fromPlayer: Bool
}

private struct DamagePop: Equatable {
    let value: Int
    let onPlayer: Bool
    let id: Int
}

private struct DamagePopView: View {
    let pop: DamagePop
    @State private var rise = false

    var body: some View {
        Text("−\(pop.value)")
            .font(.display(36))
            .foregroundStyle(pop.onPlayer ? Theme.accent : .white)
            .shadow(color: .black, radius: 0, x: 2, y: 2)
            .offset(y: rise ? -46 : 0)
            .opacity(rise ? 0 : 1)
            .scaleEffect(rise ? 1 : 1.4)
            .onAppear { withAnimation(.easeOut(duration: 1.0)) { rise = true } }
    }
}

/// What travels from the attacker to the target, by move type.
private struct ProjectileView: View {
    let move: ClashMove

    var body: some View {
        switch move {
        case .punchline:
            Text("!?#")
                .font(.display(44))
                .foregroundStyle(Theme.accent)
                .shadow(color: .white, radius: 0, x: 2, y: 2)
        case .flow:
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle().fill(Color.white).frame(width: 10, height: 10)
                }
            }
            .shadow(color: Theme.accent, radius: 6)
        case .presence:
            Image(systemName: "sparkles")
                .font(.system(size: 54, weight: .black))
                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.4))
                .shadow(color: .white, radius: 10)
        case .story:
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: Theme.accent, radius: 8)
        }
    }
}

/// Moves a view along the attacker → target line (optionally as a wave).
private struct ProjectileMotion: ViewModifier, Animatable {
    var progress: CGFloat
    let from: CGPoint
    let to: CGPoint
    let wave: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let x = from.x + (to.x - from.x) * progress
        let y = from.y + (to.y - from.y) * progress + (wave ? sin(progress * .pi * 6) * 22 : -sin(progress * .pi) * 40)
        content
            .scaleEffect(0.6 + progress * 0.7)
            .rotationEffect(.degrees(wave ? 0 : Double(progress) * 300))
            .position(x: x, y: y)
    }
}

/// Horizontal shake: each +1 to `amount` plays one shake.
private struct Shake: GeometryEffect {
    var amount: CGFloat

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(amount * .pi * 6), y: 0))
    }
}

private struct InfoPanel: View {
    let name: String
    let level: Int
    let hype: Double
    let highlight: Bool
    let showsNumbers: Bool
    var meter: Double = 0
    var secretUsed = false

    @State private var blink = false

    private var ready: Bool { !secretUsed && meter >= Double(ClashState.secretThreshold) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(name.uppercased())
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text("NIV.\(level)").font(.system(size: 12, weight: .heavy, design: .monospaced))
            }
            HStack(spacing: 6) {
                Text("PUBLIC").font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.accent)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.15))
                        Rectangle()
                            .fill(barColor)
                            .frame(width: geo.size.width * CGFloat(hype) / CGFloat(ClashState.startingHype))
                    }
                }
                .frame(height: 8)
                .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            }
            HStack(spacing: 6) {
                Text(ready ? "★ PRÊTE" : (secretUsed ? "UTILISÉE" : "SECRÈTE"))
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(ready ? Color(red: 1, green: 0.85, blue: 0.3) : .white.opacity(0.5))
                    .frame(width: 52, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.1))
                        Rectangle()
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3), Theme.accent],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(1, meter / Double(ClashState.secretThreshold)))
                    }
                }
                .frame(height: 4)
            }
            .opacity(ready && blink ? 0.45 : 1)
            .onChange(of: ready) { _, isReady in
                if isReady { withAnimation(.easeInOut(duration: 0.4).repeatForever()) { blink = true } }
            }
            .onAppear {
                if ready { withAnimation(.easeInOut(duration: 0.4).repeatForever()) { blink = true } }
            }
            if showsNumbers {
                Text("\(Int(hype.rounded())) %")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .contentTransition(.numericText(value: hype))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.92))
        .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
    }

    private var barColor: Color {
        if hype < 25 { return Color(red: 1, green: 0.25, blue: 0.2) }
        return highlight ? Theme.accent : Color.white
    }
}

private struct MoveButton: View {
    let move: ClashMove
    let level: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(move.label.uppercased())
                        .font(.display(19))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 2)
                    Text("\(move.skill.label.uppercased()) \(level)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
                Text(move.hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .overlay(Rectangle().stroke(Color.white.opacity(0.8), lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Spotlight under each character.
private struct Platform: View {
    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.05)], center: .center,
                                 startRadius: 4, endRadius: 100))
            .overlay(Ellipse().stroke(Color.white.opacity(0.25), lineWidth: 2))
    }
}

/// Stage backdrop: dark gradient and swinging light beams.
private struct BattleBackdrop: View {
    @State private var swing = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.05, blue: 0.1), Color(red: 0.04, green: 0.04, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
            ForEach(0..<3, id: \.self) { index in
                LinearGradient(colors: [Theme.accent.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(width: 70, height: 600)
                    .rotationEffect(.degrees((swing ? 18 : -18) * (index == 1 ? -1 : 1)), anchor: .top)
                    .offset(x: CGFloat(index - 1) * 130, y: -40)
                    .blendMode(.screen)
            }
            // Crowd silhouettes at the bottom.
            HStack(spacing: 2) {
                ForEach(0..<16, id: \.self) { index in
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 22, height: CGFloat(26 + (index * 37) % 18))
                        .offset(y: swing && index % 3 == 0 ? -4 : 0)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { swing = true }
        }
    }
}

// MARK: - Counter

/// Full-screen tap zone while a boss's technique is on its way: a gauge to fill before time runs out.
private struct CounterOverlay: View {
    let taps: Int
    let timeLeft: CGFloat

    private var filled: CGFloat { min(1, CGFloat(taps) / CGFloat(ClashState.counterTaps)) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
            VStack(spacing: 18) {
                Text(filled >= 1 ? "PARÉ !" : "TAPOTE !")
                    .font(.display(64))
                    .foregroundStyle(filled >= 1 ? Color(red: 1, green: 0.85, blue: 0.3) : .white)
                    .shadow(color: Theme.accent, radius: 0, x: 4, y: 4)
                    .scaleEffect(1 + 0.06 * CGFloat(taps % 2))
                    .animation(.spring(response: 0.12, dampingFraction: 0.4), value: taps)
                VStack(alignment: .leading, spacing: 6) {
                    Text("CONTRE  \(min(taps, ClashState.counterTaps))/\(ClashState.counterTaps)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.15))
                            Rectangle().fill(Theme.accent).frame(width: geo.size.width * filled)
                        }
                    }
                    .frame(height: 16)
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                    GeometryReader { geo in
                        Rectangle().fill(Color.white.opacity(0.7)).frame(width: geo.size.width * timeLeft)
                    }
                    .frame(height: 4)
                }
                .frame(maxWidth: 280)
            }
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel("Tapote l'écran le plus vite possible pour contrer la technique secrète")
    }
}

// MARK: - Secret technique

private struct SecretCinematic: Equatable {
    let name: String
    let byPlayer: Bool
    let look: CharacterLook
    /// SF Symbol raining down behind the character (techniques won along the story).
    var prop: String? = nil
}

/// Props falling across the screen, slightly rotating: the gag of the technique.
private struct PropRain: View {
    let symbol: String
    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<14, id: \.self) { index in
                let x = geo.size.width * (CGFloat(index) + 0.5) / 14
                let delay = Double((index * 7) % 5) * 0.12
                Image(systemName: symbol)
                    .font(.system(size: CGFloat(22 + (index * 5) % 18), weight: .bold))
                    .foregroundStyle(index % 3 == 0 ? Theme.accent : Color(red: 1, green: 0.85, blue: 0.3))
                    .rotationEffect(.degrees(fallen ? Double((index % 2 == 0 ? 1 : -1) * 160) : 0))
                    .position(x: x, y: fallen ? geo.size.height + 40 : -40)
                    .animation(.easeIn(duration: 1.6).delay(delay), value: fallen)
            }
        }
        .allowsHitTesting(false)
        .onAppear { fallen = true }
    }
}

/// Full-screen overlay: radiating rays, giant character, technique name.
private struct SecretCinematicView: View {
    let cinematic: SecretCinematic
    @State private var spin = false
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
            // Radiating rays.
            ZStack {
                ForEach(0..<12, id: \.self) { index in
                    Rectangle()
                        .fill((index % 2 == 0 ? Theme.accent : Color(red: 1, green: 0.85, blue: 0.3)).opacity(0.35))
                        .frame(width: 26, height: 900)
                        .rotationEffect(.degrees(Double(index) * 15))
                }
            }
            .rotationEffect(.degrees(spin ? 40 : 0))

            if let prop = cinematic.prop { PropRain(symbol: prop) }

            PixelImage(CharacterSprite.image(cinematic.look, facing: .down, frame: shown ? 1 : 0), width: 190)
                .scaleEffect(shown ? 1 : 0.3)
                .offset(x: shown ? (cinematic.byPlayer ? -60 : 60) : 0, y: 10)

            VStack(spacing: 6) {
                Text(cinematic.byPlayer ? "TECHNIQUE SECRÈTE" : "TECHNIQUE SECRÈTE ADVERSE")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                Text(cinematic.name.uppercased())
                    .font(.display(44))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: Theme.accent, radius: 0, x: 4, y: 4)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 24)
            .offset(x: shown ? 0 : (cinematic.byPlayer ? -500 : 500))
        }
        .onAppear {
            withAnimation(.linear(duration: 2.2)) { spin = true }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { shown = true }
        }
    }
}

/// Glowing button that appears once the gauge is full.
private struct SecretButton: View {
    let technique: SecretTechnique
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("★").font(.system(size: 22, weight: .black))
                VStack(alignment: .leading, spacing: 1) {
                    Text("TECHNIQUE SECRÈTE").font(.system(size: 10, weight: .heavy, design: .monospaced))
                    Text(technique.name.uppercased()).font(.display(22)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Text("1×").font(.system(size: 11, weight: .heavy, design: .monospaced))
            }
            .foregroundStyle(Theme.background)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3), Theme.accent],
                                       startPoint: .leading, endPoint: .trailing))
            .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
            .shadow(color: Color(red: 1, green: 0.7, blue: 0.2).opacity(glow ? 0.9 : 0.2), radius: glow ? 16 : 4)
            .scaleEffect(glow ? 1.02 : 0.98)
        }
        .buttonStyle(PressScaleStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { glow = true }
        }
        .sensoryFeedback(.success, trigger: glow)
    }
}

// MARK: - Boss-specific counters

/// Scalpel's counter: three words of your couplet are struck in red. Tap them, and only them.
private struct PenCounterOverlay: View {
    let timeLeft: CGFloat
    let onScore: (Double) -> Void

    static let words = ["rime", "bitume", "flow", "carnet", "punch", "ego", "beat", "bloc", "refrain"]
    @State private var marked: Set<String> = Set(PenCounterOverlay.words.shuffled().prefix(3))
    @State private var found: Set<String> = []
    @State private var wrong: Set<String> = []

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack(spacing: 16) {
                Text(found.count == marked.count ? "CORRIGÉ !" : "STYLO ROUGE")
                    .font(.display(44))
                    .foregroundStyle(found.count == marked.count ? Color(red: 1, green: 0.85, blue: 0.3) : .white)
                    .shadow(color: Theme.accent, radius: 0, x: 3, y: 3)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(PenCounterOverlay.words, id: \.self) { word in
                        let isMarked = marked.contains(word)
                        Button {
                            guard !found.contains(word), !wrong.contains(word) else { return }
                            if isMarked { found.insert(word) } else { wrong.insert(word) }
                            SoundEngine.shared.play(.tap)
                            onScore(Double(found.count - wrong.count) / Double(marked.count))
                        } label: {
                            Text(word)
                                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                                .strikethrough(isMarked, color: Color(red: 0.9, green: 0.1, blue: 0.1))
                                .foregroundStyle(found.contains(word) ? Color(red: 1, green: 0.85, blue: 0.3)
                                                 : wrong.contains(word) ? Theme.muted : .white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Color.white.opacity(found.contains(word) ? 0.18 : 0.06))
                                .overlay(Rectangle().stroke(isMarked ? Color(red: 0.9, green: 0.1, blue: 0.1) : Color.white.opacity(0.3),
                                                            lineWidth: isMarked ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                GeometryReader { geo in
                    Rectangle().fill(Color.white.opacity(0.7)).frame(width: geo.size.width * timeLeft)
                }
                .frame(height: 4)
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 16)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.selection, trigger: found)
    }
}

/// Kolosse and the Baron: a ring closes in on the target every beat. Tap when it lands.
private struct BeatCounterOverlay: View {
    let timeLeft: CGFloat
    let onScore: (Double) -> Void

    static let period = 0.8
    static let hitsNeeded = 3
    static let target: CGFloat = 46
    static let tolerance: CGFloat = 13

    @State private var start = Date()
    @State private var hits = 0
    @State private var lastCycle = -1
    @State private var flash = false

    private func radius(at date: Date) -> CGFloat {
        let phase = date.timeIntervalSince(start).truncatingRemainder(dividingBy: Self.period) / Self.period
        return 130 - CGFloat(phase) * 110
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack(spacing: 20) {
                Text(hits >= Self.hitsNeeded ? "PARÉ !" : "SUR LE TEMPS")
                    .font(.display(44))
                    .foregroundStyle(hits >= Self.hitsNeeded ? Color(red: 1, green: 0.85, blue: 0.3) : .white)
                    .shadow(color: Theme.accent, radius: 0, x: 3, y: 3)
                TimelineView(.animation) { context in
                    let r = radius(at: context.date)
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.35), lineWidth: Self.tolerance * 2)
                            .frame(width: Self.target * 2, height: Self.target * 2)
                        Circle().stroke(flash ? Color(red: 1, green: 0.85, blue: 0.3) : Theme.accent, lineWidth: 5)
                            .frame(width: r * 2, height: r * 2)
                    }
                    .frame(width: 260, height: 260)
                }
                HStack(spacing: 8) {
                    ForEach(0..<Self.hitsNeeded, id: \.self) { index in
                        Rectangle().fill(index < hits ? Theme.accent : Color.white.opacity(0.2)).frame(width: 40, height: 10)
                    }
                }
                GeometryReader { geo in
                    Rectangle().fill(Color.white.opacity(0.7)).frame(width: geo.size.width * timeLeft)
                }
                .frame(height: 4)
                .frame(maxWidth: 280)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onEnded { _ in tap() })
        .sensoryFeedback(.impact(weight: .medium), trigger: hits)
        .onAppear { start = Date() }
    }

    private func tap() {
        let now = Date()
        let cycle = Int(now.timeIntervalSince(start) / Self.period)
        guard cycle != lastCycle, hits < Self.hitsNeeded else { return }
        lastCycle = cycle
        if abs(radius(at: now) - Self.target) <= Self.tolerance {
            hits += 1
            SoundEngine.shared.play(.concertHit)
            flash = true
            Task { try? await Task.sleep(for: .milliseconds(150)); flash = false }
            onScore(Double(hits) / Double(Self.hitsNeeded))
        } else {
            SoundEngine.shared.play(.tap)
        }
    }
}
