import SwiftUI

/// Battle screen: the opponent at the top, you from behind at the bottom, crowd bars,
/// narration in the text box and a 4-move menu. Each round is played back as animation.
struct BattleView: View {
    @Environment(AppModel.self) private var model
    let clash: ClashState
    let state: GameState

    private enum Stage { case intro, menu, charge, freestyle, animating, counter, micDrop, finished }

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
    @State private var micDropped = false
    // Secret technique polish: slow-motion zoom on the target, burst, crowd shout, stunned stars, boss "VS".
    @State private var zoom: CGFloat = 1
    @State private var zoomAnchor: UnitPoint = .center
    @State private var drained = false
    @State private var impact: ImpactShown?
    @State private var reaction: ImpactShown?
    @State private var dizzyPlayer = false
    @State private var dizzyOpponent = false
    @State private var vsShown = false
    /// The poster of a won clash, to share.
    @State private var poster: UIImage?

    private static let opponentAnchor = UnitPoint(x: 0.72, y: 0.36)
    private static let playerAnchor = UnitPoint(x: 0.27, y: 0.74)

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
            let opponentSpot = CGPoint(x: w * Self.opponentAnchor.x, y: arena * Self.opponentAnchor.y)
            let playerSpot = CGPoint(x: w * Self.playerAnchor.x, y: arena * Self.playerAnchor.y)

            VStack(spacing: 0) {
                ZStack {
                    BattleBackdrop()
                        .frame(width: w, height: arena)
                        .clipped()

                    Platform().frame(width: 170, height: 40).position(x: opponentSpot.x, y: opponentSpot.y + 54)
                    Platform().frame(width: 190, height: 44).position(x: playerSpot.x, y: playerSpot.y + 58)

                    // Opponent (facing us).
                    PixelImage(HeroSprite.image(opponent?.look ?? CharacterLook(), facing: .down), width: 92)
                        .opacity(flashOpponent ? 0.15 : 1)
                        .modifier(Shake(amount: shakeOpponent))
                        .offset(x: lungeOpponent ? -26 : 0, y: (lungeOpponent ? 16 : 0) + (idle ? -2 : 2))
                        .offset(y: faintedOpponent ? 90 : 0)
                        .opacity(faintedOpponent ? 0 : 1)
                        .offset(x: entered ? 0 : -w)
                        .position(opponentSpot)

                    // The player, from behind.
                    PixelImage(HeroSprite.image(state.rapper.look, facing: .up), width: 104)
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

                    if dizzyOpponent && !faintedOpponent {
                        DizzyStars().position(x: opponentSpot.x, y: opponentSpot.y - 58)
                    }
                    if dizzyPlayer && !faintedPlayer {
                        DizzyStars().position(x: playerSpot.x, y: playerSpot.y - 66)
                    }

                    if let impact {
                        ImpactBurst(fx: impact.fx, prop: impact.prop)
                            .position(impact.onPlayer ? playerSpot : opponentSpot)
                            .id(impact.id)
                    }

                    if let reaction {
                        ReactionBubble(text: reaction.text)
                            .position(x: w * 0.5, y: arena * 0.58)
                            .id(reaction.id)
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
                .grayscale(drained ? 1 : 0)
                .scaleEffect(zoom, anchor: zoomAnchor)
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
            if stage == .micDrop {
                MicDropOverlay { micDropped = true }
                    .transition(.opacity)
            }
            if stage == .freestyle {
                FreestyleOverlay { rhymes in resolve(.freestyle(rhymes), charge: nil) }
                    .transition(.opacity)
            }
            if stage == .charge {
                ChargeOverlay(technique: model.engine.playerSecret(in: state).name) { charge in
                    resolve(.secret, charge: charge)
                }
                .transition(.opacity)
            }
            if vsShown {
                VSSplash(player: state.rapper.look, opponent: opponent?.look ?? CharacterLook(), name: opponentName,
                         subtitle: opponent?.role ?? "Boss")
                    .transition(.opacity)
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
                if !clash.freestyleUsed {
                    Button(action: startFreestyle) {
                        HStack(spacing: 8) {
                            Text("🎤").font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("FREESTYLE").font(.system(size: 14, weight: .heavy, design: .monospaced))
                                Text("Enchaîne les rimes · 1× par clash").font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.35, green: 0.12, blue: 0.45))
                        .overlay(Rectangle().stroke(Color(red: 1, green: 0.85, blue: 0.3), lineWidth: 1.5))
                    }
                    .buttonStyle(PressScaleStyle())
                }
                TacticsStrip(tell: telegraphed.map { $0.tell(opponentName) }, counter: telegraphed?.counter,
                             crowd: clash.crowdFavorite, combo: clash.lastPlayerMove.flatMap { ClashCombo.started(by: $0) })
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    let levels = model.engine.clashLevels(for: clash, in: state)
                    let combo = clash.lastPlayerMove.flatMap { ClashCombo.started(by: $0) }
                    ForEach(ClashMove.allCases) { move in
                        MoveButton(move: move, level: levels(move.skill),
                                   badges: badges(for: move, combo: combo)) { play(.move(move)) }
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
                HStack(spacing: 10) {
                    if let poster {
                        let image = Image(uiImage: poster)
                        ShareLink(item: image,
                                  subject: Text("Clash sur goslo radio"),
                                  message: Text("\(state.rapper.name) a mis \(opponentName) K.O. @goslo_radio_lejeu"),
                                  preview: SharePreview("\(state.rapper.name) bat \(opponentName)", image: image)) {
                            Label("Affiche", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    Button("Continuer") { model.finishClash() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .transition(.scale.combined(with: .opacity))
            case .intro, .charge, .freestyle, .animating, .counter, .micDrop:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: stage)
    }

    /// The opponent's next move, as their tell gives it away.
    private var telegraphed: ClashMove? {
        guard let profile = opponent?.clash?.scaled(by: clash.levelBonus) else { return nil }
        return ClashTactics.telegraphed(clash, profile: profile)
    }

    /// Little labels on a move: counters the tell, finishes a combo, loved by the crowd.
    private func badges(for move: ClashMove, combo: ClashCombo?) -> [String] {
        var badges: [String] = []
        if telegraphed?.counter == move { badges.append("CONTRE") }
        if combo?.then == move { badges.append("COMBO") }
        if clash.crowdFavorite == move { badges.append("♥ PUBLIC") }
        return badges
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
                SoundEngine.shared.play(.secretHit)
                Haptics.shared.play(.strongHit)
                withAnimation(.easeOut(duration: 0.15)) { vsShown = true }
                try? await Task.sleep(for: .milliseconds(1900))
                withAnimation(.easeIn(duration: 0.25)) { vsShown = false }
                try? await Task.sleep(for: .milliseconds(250))
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
        clearStun()
        SoundEngine.shared.play(pending.secret.effect.sting)
        Haptics.shared.play(.secretRiser)
        withAnimation(.easeOut(duration: 0.3)) {
            cinematic = SecretCinematic(name: pending.secret.name, byPlayer: false, look: opponent?.look ?? CharacterLook(),
                                        prop: pending.secret.prop, fx: pending.secret.effect)
        }
        try? await Task.sleep(for: .milliseconds(1600))
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

    private enum BattleAction { case move(ClashMove), secret, freestyle(Int) }

    private func play(_ action: BattleAction) {
        guard stage == .menu else { return }
        if case .secret = action {
            // The player's technique is charged in rhythm first (`ChargeOverlay`), then resolved.
            message = "Tape en rythme pour charger ta technique !"
            clearStun()
            withAnimation(.easeOut(duration: 0.2)) { stage = .charge }
            return
        }
        resolve(action, charge: nil)
    }

    private func startFreestyle() {
        guard stage == .menu else { return }
        message = "Le DJ relance le beat. À toi."
        clearStun()
        withAnimation(.easeOut(duration: 0.2)) { stage = .freestyle }
    }

    private func resolve(_ action: BattleAction, charge: Double?) {
        guard stage == .menu || stage == .charge || stage == .freestyle else { return }
        withAnimation(.easeIn(duration: 0.15)) { stage = .animating }
        clearStun()
        let result: ClashState? = switch action {
        case .move(let move): model.clashMove(move)
        case .secret: model.clashSecret(charge: charge)
        case .freestyle(let rhymes): model.clashFreestyle(rhymes: rhymes)
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
        await say(entry.freestyle != nil ? "\(attacker.uppercased()) part en FREESTYLE !"
                                         : "\(attacker.uppercased()) lance \(entry.move.label.uppercased()) !", hold: 0.1)

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
            Haptics.shared.play(.miss)
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
            Haptics.shared.play(entry.impact == .strong ? .strongHit : entry.impact == .weak ? .weakHit : .hit)
            withAnimation(.easeOut(duration: 0.5)) {
                if entry.byPlayer { playerMeter += Double(entry.damage) } else { opponentMeter += Double(entry.damage) }
            }
            if let combo = entry.combo {
                await showBanner(combo.uppercased() + " !")
            } else if entry.parried == true {
                await showBanner("PARÉ !")
            } else if let rhymes = entry.freestyle {
                await showBanner("\(rhymes) RIME\(rhymes > 1 ? "S" : "") !")
            } else {
                switch entry.impact {
                case .strong: await showBanner("ÇA TOUCHE !")
                case .weak: await showBanner("ÇA GLISSE…")
                default: try? await Task.sleep(for: .milliseconds(450))
                }
            }
        }
        await say(entry.line, hold: 0.8)
    }

    private func finish(_ final: ClashState) async {
        withAnimation(.easeIn(duration: 0.6)) {
            if final.playerWon { faintedOpponent = true } else { faintedPlayer = true }
        }
        SoundEngine.shared.play(final.playerWon ? .victory : .defeat)
        Haptics.shared.play(final.playerWon ? .victory : .defeat)
        if final.playerWon {
            poster = ClashPoster.render(player: state.rapper, opponentName: opponentName,
                                        opponentLook: opponent?.look ?? CharacterLook(), clash: final)
        }
        if final.playerWon && !clash.isWild { await micDrop() }
        await say(final.playerWon
                  ? "\(opponentName.uppercased()) est K.O. verbal ! Le public est avec toi."
                  : "Le public a choisi \(opponentName.hasSuffix(".") ? String(opponentName.dropLast()) : opponentName). Tu quittes la scène, tête basse.", hold: 0.2)
        stage = .finished
    }

    /// Rival and boss wins end with a mic drop: the player flicks the phone (or taps) and the mic hits the stage.
    private func micDrop() async {
        try? await Task.sleep(for: .milliseconds(900))
        message = "Le public retient son souffle…"
        micDropped = false
        withAnimation(.easeOut(duration: 0.2)) { stage = .micDrop }
        var waited = 0.0
        // The overlay drops the mic on its own after a few seconds; the cap is only a safety net.
        while !micDropped && waited < MicDropOverlay.waitSeconds + 3 {
            try? await Task.sleep(for: .milliseconds(50))
            waited += 0.05
        }
        try? await Task.sleep(for: .milliseconds(500))
        SoundEngine.shared.play(.crowdCheer)
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.easeOut(duration: 0.3)) { stage = .animating }
    }

    /// The full secret technique sequence: announcement, cinematic, flash, big hit.
    private func playSecret(_ secret: SecretTechnique, entry: ClashLogEntry, attacker: String) async {
        // A countered boss technique was already announced before the taps.
        if entry.countered == nil {
            await say(entry.byPlayer
                      ? "Ta jauge déborde… \(attacker.uppercased()) déclenche sa TECHNIQUE SECRÈTE !"
                      : "Oh non. \(attacker.uppercased()) a gardé une TECHNIQUE SECRÈTE…", hold: 0.2)
            SoundEngine.shared.play(secret.effect.sting)
            Haptics.shared.play(.secretRiser)
            withAnimation(.easeOut(duration: 0.3)) {
                cinematic = SecretCinematic(name: secret.name, byPlayer: entry.byPlayer,
                                            look: entry.byPlayer ? state.rapper.look : (opponent?.look ?? CharacterLook()),
                                            prop: secret.prop, fx: secret.effect)
            }
            try? await Task.sleep(for: .seconds(secret.effect.cinematicSeconds))
            withAnimation(.easeIn(duration: 0.2)) { cinematic = nil }
        }

        // Slow motion: the camera pushes in on the target, the picture holds its breath…
        zoomAnchor = entry.byPlayer ? Self.opponentAnchor : Self.playerAnchor
        withAnimation(.easeOut(duration: 0.35)) {
            zoom = 1.22
            if secret.effect == .tear { drained = true }
        }
        try? await Task.sleep(for: .milliseconds(380))

        // …then the hit.
        SoundEngine.shared.play(.secretHit)
        Haptics.shared.play(.secretHit)
        impact = ImpactShown(fx: secret.effect, prop: secret.prop, onPlayer: !entry.byPlayer, id: entry.id)
        withAnimation(.easeOut(duration: 0.08)) { whiteFlash = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeIn(duration: 0.4)) { whiteFlash = false }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            zoom = 1
            drained = false
        }
        withAnimation(.linear(duration: secret.effect == .bass ? 0.9 : 0.6)) {
            let shakes: CGFloat = secret.effect == .bass ? 4 : 2
            if entry.byPlayer { shakeOpponent += shakes } else { shakePlayer += shakes }
        }
        if entry.byPlayer { dizzyOpponent = true } else { dizzyPlayer = true }
        SoundEngine.shared.play(.crowdCheer)
        reaction = ImpactShown(fx: secret.effect, prop: nil, onPlayer: !entry.byPlayer, id: entry.id,
                               text: ReactionBubble.lines[entry.id % ReactionBubble.lines.count])
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
        await showBanner(entry.byPlayer ? chargeBanner(entry.charge) : counterBanner(entry.countered))
        withAnimation(.easeOut(duration: 0.3)) {
            impact = nil
            reaction = nil
        }
        await say(entry.line, hold: 1.2)
    }

    private func chargeBanner(_ charge: Double?) -> String {
        guard let charge else { return "LÉGENDAIRE !" }
        if charge >= 0.85 { return "LÉGENDAIRE !" }
        if charge >= 0.45 { return "ÇA FRAPPE FORT !" }
        return "HORS TEMPO…"
    }

    /// The stunned stars go once the next action starts.
    private func clearStun() {
        dizzyPlayer = false
        dizzyOpponent = false
    }

    private func counterBanner(_ countered: Double?) -> String {
        guard let countered else { return "AÏE AÏE AÏE" }
        if countered >= ClashState.counterMaxReduction * 0.9 { return "CONTRÉ !" }
        if countered >= ClashState.counterMaxReduction * 0.4 { return "À MOITIÉ PARÉ" }
        return "AÏE AÏE AÏE"
    }

    /// Shows a line and waits long enough to read it. Tap: show it all, tap again: next.
    private func say(_ raw: String, hold: Double) async {
        let text = TextTemplate.render(raw, for: state.rapper)
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
    var badges: [String] = []
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
                if badges.isEmpty {
                    Text(move.hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    HStack(spacing: 4) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(badge == "CONTRE" ? Color(red: 0.2, green: 0.6, blue: 1)
                                            : badge == "COMBO" ? Theme.accent : Color(red: 1, green: 0.85, blue: 0.3))
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .overlay(Rectangle().stroke(badges.isEmpty ? Color.white.opacity(0.8) : Color(red: 1, green: 0.85, blue: 0.3), lineWidth: 2))
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

/// Stage backdrop: an LED wall pumping with the beat, swinging light beams, haze, and a crowd
/// with raised hands and phone lights.
private struct BattleBackdrop: View {
    @State private var swing = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.05, blue: 0.1), Color(red: 0.04, green: 0.04, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
            // LED wall: columns of squares rising and falling like an equalizer.
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let cell: CGFloat = 9, gap: CGFloat = 3
                    let columns = Int(size.width / (cell + gap)), rows = 9
                    for column in 0..<columns {
                        let level = 0.25 + 0.75 * abs(sin(t * (2.1 + Double(column % 5) * 0.37) + Double(column) * 0.6))
                        let lit = Int(Double(rows) * level)
                        for row in 0..<rows {
                            let on = rows - row <= lit
                            let x = CGFloat(column) * (cell + gap) + gap, y = 14 + CGFloat(row) * (cell + gap)
                            let color = row < 2 ? Color(red: 1, green: 0.85, blue: 0.3) : Theme.accent
                            context.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)),
                                         with: .color(color.opacity(on ? 0.32 : 0.05)))
                        }
                    }
                }
            }
            ForEach(0..<3, id: \.self) { index in
                LinearGradient(colors: [Theme.accent.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(width: 70, height: 600)
                    .rotationEffect(.degrees((swing ? 18 : -18) * (index == 1 ? -1 : 1)), anchor: .top)
                    .offset(x: CGFloat(index - 1) * 130, y: -40)
                    .blendMode(.screen)
            }
            // Haze rolling over the stage.
            LinearGradient(colors: [.clear, Color.white.opacity(0.07), Color.white.opacity(0.12)], startPoint: .center, endPoint: .bottom)
                .offset(x: swing ? 20 : -20)
                .blendMode(.screen)
            // The crowd: heads, raised hands, phones filming.
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let count = 18
                    let step = size.width / CGFloat(count - 1)
                    for row in 0..<2 {
                        let base = size.height - CGFloat(row) * 14
                        let shade = Color.black.opacity(row == 0 ? 0.85 : 0.6)
                        for index in 0..<count {
                            let x = CGFloat(index) * step + (row == 1 ? step / 2 : 0)
                            let bob = CGFloat(sin(t * 3 + Double(index * 3 + row))) * 2.5
                            let head = 7 + CGFloat((index * 37 + row * 11) % 4)
                            context.fill(Path(roundedRect: CGRect(x: x - 13, y: base - 22 + bob, width: 26, height: 30),
                                              cornerRadius: 10), with: .color(shade))
                            context.fill(Path(ellipseIn: CGRect(x: x - head, y: base - 34 - head + bob, width: head * 2, height: head * 2)),
                                         with: .color(shade))
                            if (index + row) % 3 == 0 {
                                // A raised arm, waving.
                                let wave = CGFloat(sin(t * 4 + Double(index))) * 6
                                var arm = Path()
                                arm.move(to: CGPoint(x: x + 8, y: base - 18 + bob))
                                arm.addLine(to: CGPoint(x: x + 14 + wave, y: base - 52 + bob))
                                context.stroke(arm, with: .color(shade), lineWidth: 6)
                                if (index + row) % 2 == 0 {
                                    // A phone screen, glowing.
                                    let flash = 0.5 + 0.5 * sin(t * 5 + Double(index * 7))
                                    context.fill(Path(CGRect(x: x + 10 + wave, y: base - 62 + bob, width: 7, height: 11)),
                                                 with: .color(Color(red: 0.85, green: 0.92, blue: 1).opacity(0.5 + 0.5 * flash)))
                                }
                            }
                        }
                    }
                }
            }
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
    var fx: SecretFX = .rays
}

/// A burst or a crowd shout on one side of the arena.
private struct ImpactShown: Equatable {
    let fx: SecretFX
    let prop: String?
    let onPlayer: Bool
    let id: Int
    var text = ""
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
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
            SecretFXBackdrop(fx: cinematic.fx, prop: cinematic.prop)

            if let prop = cinematic.prop, cinematic.fx != .emojis { PropRain(symbol: prop) }

            SecretFXCharacter(image: HeroSprite.image(cinematic.look, facing: .down, frame: shown ? 1 : 0), width: 136, fx: cinematic.fx)
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
            if cinematic.fx == .tear {
                withAnimation(.easeOut(duration: 1.6)) { shown = true }
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { shown = true }
            }
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

/// Above the moves: what the opponent is about to do, what the crowd loves, the combo you can finish.
private struct TacticsStrip: View {
    let tell: String?
    let counter: ClashMove?
    let crowd: ClashMove?
    let combo: ClashCombo?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let tell, let counter {
                Text("👁 \(tell) → \(counter.label.uppercased()) pour contrer")
                    .foregroundStyle(Color(red: 0.55, green: 0.8, blue: 1))
            }
            if let combo {
                Text("⚡ \(combo.then.label.uppercased()) maintenant : combo « \(combo.name) »")
                    .foregroundStyle(Theme.accent)
            }
            if let crowd {
                Text("♥ Ce public adore : \(crowd.label.uppercased())")
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
            }
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }
}
