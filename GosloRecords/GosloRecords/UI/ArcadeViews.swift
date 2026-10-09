import SwiftUI

private let arcadeGold = Color(red: 1, green: 0.85, blue: 0.3)

/// The arcade: every mini-game, outside any career. Free ones from the start, the others unlock with achievements.
struct ArcadeView: View {
    @Environment(AppModel.self) private var model
    @State private var freestyling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BackButton(title: "Accueil") { model.go(.home) }
                Spacer()
            }
            .padding(.horizontal, Theme.gutter)

            Text("Arcade").font(.display(52))
                .padding(.horizontal, Theme.gutter)
            Text("Les mini-jeux, sans carrière, au même niveau pour tout le monde. Les autres se débloquent en jouant.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Arcade.games) { game in
                        if game.id == Arcade.flagshipID {
                            ArcadeFlagshipCard(game: game, unlocked: model.isUnlocked(game), best: model.profile.arcadeBest[game.id]) {
                                play(game)
                            }
                            .padding(.bottom, 6)
                        } else {
                            ArcadeRow(game: game, unlocked: model.isUnlocked(game), best: model.profile.arcadeBest[game.id]) {
                                play(game)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $freestyling) {
            FreestyleOverlay { rhymes in
                if let game = Arcade.game("freestyle") { model.recordArcade(game, score: rhymes) }
                freestyling = false
            }
            .ignoresSafeArea()
        }
    }

    private func play(_ game: ArcadeGame) {
        if game.mode == .freestyle {
            freestyling = true
        } else {
            model.startArcade(game)
        }
    }
}

/// Punchliner, the flagship: a bigger card on top of the list, with its badge and its promise (the mic, the share).
private struct ArcadeFlagshipCard: View {
    let game: ArcadeGame
    let unlocked: Bool
    let best: Int?
    let play: () -> Void

    @State private var glow = false

    var body: some View {
        Button(action: play) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("★ JEU PHARE")
                        .font(.mono(10, weight: .heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(arcadeGold)
                        .foregroundStyle(.black)
                    Text("NOUVEAU")
                        .font(.mono(10, weight: .heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.background)
                    Spacer(minLength: 0)
                    if unlocked, let best {
                        Text("RECORD : \(best) \(game.unit)")
                            .font(.mono(10, weight: .bold))
                            .foregroundStyle(arcadeGold)
                    }
                }
                Text(game.title.uppercased())
                    .font(.display(44))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unlocked ? game.pitch : "🔒 Débloqué par le succès « \(game.unlockedBy?.title ?? "") »")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Label("Ta voix", systemImage: "mic.fill")
                    Label("Ton beat", systemImage: "waveform")
                    Label("Partage", systemImage: "square.and.arrow.up")
                }
                .font(.mono(11, weight: .bold))
                .foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    Image(systemName: unlocked ? "play.fill" : "lock.fill")
                    Text(unlocked ? "Jouer" : "Verrouillé")
                }
                .font(.display(22))
                .textCase(.uppercase)
                .foregroundStyle(unlocked ? Color.black : Theme.faint)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(unlocked ? arcadeGold : Color.white.opacity(0.06))
            }
            .padding(16)
            .background(arcadeGold.opacity(0.08))
            .overlay(Rectangle().stroke(arcadeGold.opacity(glow ? 1 : 0.55), lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
        .accessibilityLabel("\(game.title), jeu phare. \(game.pitch)")
    }
}

private struct ArcadeRow: View {
    let game: ArcadeGame
    let unlocked: Bool
    let best: Int?
    let play: () -> Void

    var body: some View {
        Button(action: play) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(game.title.uppercased())
                            .font(.display(24))
                            .foregroundStyle(unlocked ? Theme.text : Theme.faint)
                        if game.unlockedBy == nil {
                            Text("GRATUIT")
                                .font(.mono(9, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(arcadeGold)
                                .foregroundStyle(.black)
                        }
                    }
                    Text(unlocked ? game.pitch : "🔒 Débloqué par le succès « \(game.unlockedBy?.title ?? "") »")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if unlocked, let best {
                        Text("RECORD : \(best) \(game.unit)")
                            .font(.mono(10, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: unlocked ? "play.fill" : "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(unlocked ? arcadeGold : Theme.faint)
            }
            .padding(14)
            .overlay(Rectangle().stroke(unlocked ? Theme.line : Theme.line.opacity(0.5), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

/// Above an arcade game: replaces the career HUD.
struct ArcadeHeader: View {
    let game: ArcadeGame

    var body: some View {
        HStack {
            Text("ARCADE")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(arcadeGold)
            Spacer()
            Text(game.title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black)
    }
}

// MARK: - Beatbox Simon

/// The beatboxer plays the pattern (the pads light up), then it's your turn to play it back.
struct BeatboxBoard: View {
    @Environment(AppModel.self) private var model
    let minigame: MinigameState

    private enum Turn { case listening, playing, done }

    @State private var pattern: [BeatSound] = {
        var generator = SystemRandomNumberGenerator()
        return BeatboxEngine.pattern(using: &generator)
    }()
    @State private var turn: Turn = .listening
    @State private var lit: BeatSound?
    @State private var typed = 0
    @State private var playedRound = -1

    private var length: Int { BeatboxEngine.length(ofRound: minigame.round) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MOTIF \(minigame.round + 1) / \(BeatboxEngine.rounds)")
                    .font(.mono(12, weight: .bold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(length) SONS")
                    .font(.mono(12, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            Text(turn == .listening ? "Écoute…" : "À toi ! \(typed) / \(length)")
                .font(.display(34))
                .foregroundStyle(turn == .listening ? Theme.muted : arcadeGold)
            if let last = minigame.log.last {
                Text(last).font(.system(size: 14)).foregroundStyle(Theme.text.opacity(0.8))
            }
            Spacer(minLength: 0)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(BeatSound.allCases, id: \.self) { sound in
                    Button { tap(sound) } label: {
                        VStack(spacing: 4) {
                            Text(Self.emoji(sound)).font(.system(size: 30))
                            Text(sound.label).font(.display(26))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 110)
                        .background(Self.color(sound).opacity(lit == sound ? 1 : 0.35))
                        .overlay(Rectangle().stroke(Self.color(sound), lineWidth: 3))
                        .scaleEffect(lit == sound ? 1.05 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(turn != .playing)
                }
            }
        }
        .task(id: minigame.round) { await playPattern() }
    }

    private func playPattern() async {
        guard !minigame.isOver, playedRound != minigame.round else { return }
        playedRound = minigame.round
        turn = .listening
        typed = 0
        try? await Task.sleep(for: .milliseconds(700))
        // Faster as the pattern grows.
        let gap = max(0.28, 0.5 - Double(minigame.round) * 0.025)
        for sound in pattern.prefix(length) {
            light(sound)
            try? await Task.sleep(for: .seconds(gap))
        }
        turn = .playing
    }

    private func tap(_ sound: BeatSound) {
        guard turn == .playing else { return }
        light(sound)
        guard pattern[typed] == sound else {
            turn = .done
            Haptics.shared.play(.miss)
            model.beatbox(repeated: false)
            return
        }
        typed += 1
        if typed == length {
            turn = .done
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                SoundEngine.shared.play(.crowdCheer)
                model.beatbox(repeated: true)
            }
        }
    }

    private func light(_ sound: BeatSound) {
        SoundEngine.shared.play(Self.effect(sound))
        withAnimation(.easeOut(duration: 0.08)) { lit = sound }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeIn(duration: 0.12)) { if lit == sound { lit = nil } }
        }
    }

    static func effect(_ sound: BeatSound) -> SoundEffect {
        switch sound {
        case .boum: .concertKick
        case .tchak: .concertSnare
        case .ts: .concertHat
        case .wiki: .beatboxWiki
        }
    }

    static func emoji(_ sound: BeatSound) -> String {
        switch sound {
        case .boum: "🥁"
        case .tchak: "👏"
        case .ts: "✨"
        case .wiki: "💿"
        }
    }

    static func color(_ sound: BeatSound) -> Color {
        switch sound {
        case .boum: Color(red: 0.9, green: 0.2, blue: 0.2)
        case .tchak: Color(red: 0.2, green: 0.5, blue: 1)
        case .ts: Color(red: 0.95, green: 0.75, blue: 0.1)
        case .wiki: Color(red: 0.6, green: 0.3, blue: 0.9)
        }
    }
}
