import SwiftUI

/// Mini-games: Punchliner, Fuir la foule, Cale la platine, and the epilogue auditions.
/// The rules live in Engine/Minigames.swift; these screens only play them.
struct MinigameView: View {
    @Environment(AppModel.self) private var model
    let minigame: MinigameState
    let state: GameState

    @State private var started = false

    private var data: Minigame? { model.engine.minigame(minigame.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let data {
                Text(data.title.uppercased())
                    .font(.display(28))
                    .foregroundStyle(Theme.text)
                if !started && minigame.round == 0 && minigame.escaped == nil {
                    Text(data.intro)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("C'est parti") { withAnimation(.easeOut(duration: 0.2)) { started = true } }
                        .buttonStyle(PrimaryButtonStyle())
                } else if minigame.isOver {
                    MinigameResult(minigame: minigame)
                } else {
                    switch minigame.kind {
                    case .punchliner: PunchlinerBoard(minigame: minigame)
                    case .platine: PlatineBoard(minigame: minigame)
                    case .fuite: ChaseBoard(look: state.rapper.look)
                    case .signing: SigningBoard()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// End screen: how it went round by round, then back to the map with the result.
private struct MinigameResult: View {
    @Environment(AppModel.self) private var model
    let minigame: MinigameState

    var body: some View {
        let score = model.engine.minigameScore(minigame)
        let passed = score >= (model.engine.minigame(minigame.id)?.passScore ?? 1)
        VStack(alignment: .leading, spacing: 10) {
            Text(passed ? "RÉUSSI" : "RATÉ")
                .font(.display(44))
                .foregroundStyle(passed ? Color(red: 1, green: 0.85, blue: 0.3) : Theme.accent)
            if minigame.kind != .fuite {
                Text("SCORE \(Int((score * 100).rounded())) %")
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(minigame.log.enumerated()), id: \.offset) { _, line in
                        Text("— \(line)").font(.system(size: 14)).foregroundStyle(Theme.text.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
            Button("Continuer") { model.finishMinigame() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

// MARK: - Punchliner

/// The setup line, the start of the punchline, and 20 tiles to finish it before time runs out.
private struct PunchlinerBoard: View {
    @Environment(AppModel.self) private var model
    let minigame: MinigameState

    static let seconds = 20.0

    @State private var picked: [String] = []
    @State private var reaction: String?
    @State private var deadline = Date().addingTimeInterval(PunchlinerBoard.seconds)
    /// Time left when the app went to the background: the clock waits for the player.
    @State private var pausedLeft: TimeInterval?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if let current = model.state.flatMap({ model.engine.punchlinerRound(in: $0) }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("COUPLET \(minigame.round + 1)/\(minigame.roundCount)").font(.mono(11, weight: .bold))
                    Spacer()
                    if reaction == nil {
                        TimelineView(.periodic(from: .now, by: 0.25)) { context in
                            let left = max(0, deadline.timeIntervalSince(context.date))
                            Text("\(Int(left.rounded(.up))) s")
                                .font(.mono(13, weight: .bold))
                                .foregroundStyle(left < 5 ? Theme.accent : Theme.text)
                                .onChange(of: left == 0) { _, timedOut in if timedOut && pausedLeft == nil { drop() } }
                        }
                    }
                }
                .foregroundStyle(Theme.muted)

                Text(current.round.setup)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text.opacity(0.75))
                (Text(current.round.lead + " ").foregroundStyle(Theme.text)
                    + Text(picked.isEmpty ? "…" : picked.joined(separator: " ")).foregroundStyle(Theme.accent))
                    .font(.system(size: 20, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)

                if let reaction {
                    Text(reaction)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button(minigame.isOver ? "Résultat" : "Couplet suivant") { next() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                        ForEach(current.tiles, id: \.self) { word in
                            let used = picked.contains(word)
                            Button {
                                if !used && picked.count < PunchlinerEngine.maxWords { picked.append(word) }
                            } label: {
                                Text(word)
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .foregroundStyle(used ? Theme.muted : Theme.text)
                                    .background(used ? Color.white.opacity(0.04) : Color.white.opacity(0.1))
                                    .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(used)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        Button("Effacer") { if !picked.isEmpty { picked.removeLast() } }
                            .font(.mono(13, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                        Button("Lâcher la punchline") { drop() }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(picked.isEmpty)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: picked)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active, pausedLeft == nil, reaction == nil {
                    pausedLeft = max(0, deadline.timeIntervalSinceNow)
                } else if phase == .active, let left = pausedLeft {
                    deadline = Date().addingTimeInterval(left)
                    pausedLeft = nil
                }
            }
        } else {
            // Last line dropped: the result screen takes over once the reaction has been read.
            if let reaction {
                VStack(alignment: .leading, spacing: 12) {
                    Text(reaction).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func drop() {
        guard reaction == nil else { return }
        reaction = model.dropPunchline(picked) ?? "…"
        SoundEngine.shared.play(.hit)
    }

    private func next() {
        picked = []
        reaction = nil
        deadline = Date().addingTimeInterval(PunchlinerBoard.seconds)
    }
}

// MARK: - Cale la platine

/// The pitch fader swings between 96 and 112 %; stop it on 100.
private struct PlatineBoard: View {
    @Environment(AppModel.self) private var model
    let minigame: MinigameState

    @State private var startedAt = Date()
    @State private var stopped: (pitch: Double, reaction: String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ESSAI \(min(minigame.round + 1, minigame.roundCount))/\(minigame.roundCount)")
                .font(.mono(11, weight: .bold))
                .foregroundStyle(Theme.muted)
            TimelineView(.animation(paused: stopped != nil)) { context in
                let pitch = stopped?.pitch ?? PlatineEngine.pitch(at: context.date.timeIntervalSince(startedAt),
                                                                  run: minigame.round)
                PitchFader(pitch: pitch)
            }
            .frame(height: 220)

            if let stopped {
                Text(stopped.reaction)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(minigame.isOver ? "Résultat" : "Essai suivant") {
                    self.stopped = nil
                    startedAt = Date()
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Spacer(minLength: 0)
                Button("STOP") {
                    let elapsed = Date().timeIntervalSince(startedAt)
                    stopped = model.stopPlatine(after: elapsed)
                    SoundEngine.shared.play(.select)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .onAppear { startedAt = Date() }
    }
}

/// A vertical fader from 96 % (bottom) to 112 % (top), with the 100 % notch highlighted.
private struct PitchFader: View {
    let pitch: Double

    var body: some View {
        GeometryReader { geo in
            let low = 96.0, high = 112.0
            let y = { (value: Double) in geo.size.height * CGFloat(1 - (value - low) / (high - low)) }
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.white.opacity(0.08))
                    .frame(width: 18)
                    .frame(maxWidth: .infinity)
                ForEach([96, 100, 104, 108, 112], id: \.self) { mark in
                    HStack(spacing: 6) {
                        Rectangle().fill(mark == 100 ? Color(red: 0.4, green: 0.9, blue: 0.5) : Theme.line)
                            .frame(width: mark == 100 ? 90 : 40, height: mark == 100 ? 3 : 1)
                        Text("\(mark) %").font(.mono(10, weight: .bold))
                            .foregroundStyle(mark == 100 ? Color(red: 0.4, green: 0.9, blue: 0.5) : Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width / 2 + 40, y: y(Double(mark)))
                }
                Rectangle().fill(Theme.accent)
                    .frame(width: 64, height: 14)
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                    .position(x: geo.size.width / 2, y: y(min(max(pitch, low), high)))
                Text(String(format: "%.1f %%", pitch).replacingOccurrences(of: ".", with: ","))
                    .font(.display(36))
                    .foregroundStyle(Theme.text)
                    .position(x: 70, y: geo.size.height / 2)
            }
        }
        .accessibilityLabel("Pitch : \(Int(pitch.rounded())) pour cent")
    }
}

// MARK: - Fuir la foule

/// The chase: the grid seen from above, fans closing in, the D-pad to run for the door.
private struct ChaseBoard: View {
    @Environment(AppModel.self) private var model
    let look: CharacterLook

    @State private var chase: CrowdChase = {
        var rng = SystemRandomNumberGenerator()
        return CrowdChase(using: &rng)
    }()
    @State private var held: Direction?
    @State private var reported = false

    private static let fanLooks: [CharacterLook] = [
        CharacterLook(skin: "#e0ac7e", top: "#c0392b", bottom: "#23232a", hat: .cap),
        CharacterLook(skin: "#8d5524", top: "#2f4a9a", bottom: "#141418", hairStyle: .puff),
        CharacterLook(skin: "#f1c9a5", top: "#e8c547", bottom: "#2f4a7a", hairStyle: .long),
        CharacterLook(skin: "#5a3825", top: "#4fd6e0", bottom: "#23232a", hat: .beanie),
        CharacterLook(skin: "#c68642", top: "#e04fb0", bottom: "#141418", glasses: true),
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(chase.escaped ? "DEHORS !" : (chase.caught ? "RATTRAPÉ…" : "FONCE VERS LA PORTE"))
                    .font(.mono(12, weight: .bold))
                Spacer()
                Text("\(max(0, Int((CrowdChase.timeLimit - Double(chase.steps) * CrowdChase.stepSeconds).rounded(.up)))) s")
                    .font(.mono(13, weight: .bold))
            }
            .foregroundStyle(Theme.text)

            GeometryReader { geo in
                let tile = min(geo.size.width / CGFloat(CrowdChase.width), geo.size.height / CGFloat(CrowdChase.height))
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color(red: 0.16, green: 0.16, blue: 0.19))
                        .frame(width: tile * CGFloat(CrowdChase.width), height: tile * CGFloat(CrowdChase.height))
                    // The door the van waits behind.
                    Rectangle().fill(Color(red: 1, green: 0.82, blue: 0.48))
                        .frame(width: tile, height: tile)
                        .overlay(Image(systemName: "door.left.hand.open").foregroundStyle(Theme.background))
                        .position(center(CrowdChase.door, tile))
                    ForEach(Array(CrowdChase.obstacles), id: \.self) { point in
                        Rectangle().fill(Color(red: 0.08, green: 0.08, blue: 0.1))
                            .frame(width: tile * 0.6, height: tile * 0.6)
                            .position(center(point, tile))
                    }
                    ForEach(Array(chase.fans.enumerated()), id: \.offset) { index, fan in
                        SpriteView(look: ChaseBoard.fanLooks[index % ChaseBoard.fanLooks.count], facing: .down,
                                   frame: chase.steps % 2 + 1, size: tile)
                            .position(center(fan, tile))
                            .animation(.linear(duration: CrowdChase.stepSeconds * 0.9), value: fan)
                    }
                    SpriteView(look: look, facing: held ?? .up, frame: held == nil ? 0 : 1, size: tile)
                        .position(center(chase.player, tile))
                        .animation(.linear(duration: 0.12), value: chase.player)
                }
                .frame(width: tile * CGFloat(CrowdChase.width), height: tile * CGFloat(CrowdChase.height))
                .frame(maxWidth: .infinity)
            }

            DPad { held = $0 }
                .frame(maxWidth: .infinity)
        }
        .task { await runCrowd() }
        .task(id: held) { await runPlayer() }
        .onChange(of: chase.isOver) { _, over in
            guard over, !reported else { return }
            reported = true
            SoundEngine.shared.play(chase.escaped ? .victory : .defeat)
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                model.endChase(escaped: chase.escaped)
            }
        }
    }

    private func center(_ point: TilePoint, _ tile: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(point.x) + 0.5) * tile, y: (CGFloat(point.y) + 0.5) * tile)
    }

    /// The crowd steps forward on its own clock.
    private func runCrowd() async {
        var rng = SystemRandomNumberGenerator()
        while !Task.isCancelled && !chase.isOver {
            try? await Task.sleep(for: .seconds(CrowdChase.stepSeconds))
            chase.step(using: &rng)
        }
    }

    /// Holding a direction moves one tile at once, then keeps moving about twice as fast as the crowd.
    private func runPlayer() async {
        guard let direction = held else { return }
        while !Task.isCancelled && !chase.isOver && held == direction {
            chase.move(direction)
            SoundEngine.shared.play(.step)
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}

// MARK: - Signing (epilogue)

/// Artist cards: talent and buzz on show, reliability hidden behind a hint. Pick within the budget, then sign.
private struct SigningBoard: View {
    @Environment(AppModel.self) private var model
    @State private var picked: [String] = []

    var body: some View {
        if let offer = model.state.flatMap({ model.engine.signingOffer(in: $0) }) {
            let spent = picked.compactMap { id in offer.spec.artists.first { $0.id == id }?.cost }.reduce(0, +)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("BUDGET \(offer.budget - spent)/\(offer.budget) K€").font(.mono(12, weight: .bold))
                    Spacer()
                    Text("CONTRATS \(picked.count)/\(offer.spec.picks)").font(.mono(12, weight: .bold))
                }
                .foregroundStyle(Theme.muted)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(offer.spec.artists) { artist in
                            let selected = picked.contains(artist.id)
                            let affordable = selected || (picked.count < offer.spec.picks
                                && spent + artist.cost <= offer.budget)
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    if selected { picked.removeAll { $0 == artist.id } } else { picked.append(artist.id) }
                                }
                            } label: {
                                ArtistCard(artist: artist, selected: selected)
                            }
                            .buttonStyle(PressScaleStyle())
                            .disabled(!affordable)
                            .opacity(affordable ? 1 : 0.4)
                        }
                    }
                }

                Button(picked.count < 2 ? "Signer \(picked.count == 1 ? "cet artiste" : "")" : "Signer ces deux artistes") {
                    model.sign(picked)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(picked.isEmpty)
            }
        }
    }
}

private struct ArtistCard: View {
    let artist: SigningArtist
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(artist.name.uppercased()).font(.display(18)).foregroundStyle(Theme.text)
                Text(artist.style).font(.mono(10, weight: .bold)).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(artist.cost) K€").font(.mono(13, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
            }
            Text(artist.pitch).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            gauge("TALENT", artist.talent)
            gauge("BUZZ", artist.buzz)
            HStack(spacing: 6) {
                Text("FIABILITÉ ?").font(.mono(10, weight: .bold)).foregroundStyle(Theme.muted)
                Text(artist.flaw).font(.system(size: 12).italic()).foregroundStyle(Theme.text.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(selected ? 0.12 : 0.04))
        .overlay(Rectangle().stroke(selected ? Theme.accent : Color.white.opacity(0.2), lineWidth: selected ? 3 : 1))
        .multilineTextAlignment(.leading)
    }

    private func gauge(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.mono(10, weight: .bold)).foregroundStyle(Theme.muted).frame(width: 52, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle().fill(index < value ? Theme.accent : Color.white.opacity(0.15)).frame(height: 6)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.lowercased()) \(value) sur 10")
    }
}
