import Foundation

/// The player's own song, made from the lines they picked in a Punchliner: an instrumental in their style,
/// then their verse, one line per bar. Played by `TrackView`, the lines rapped by the phone's voice.
struct PlayerTrack: Equatable {
    static let introBars = 2
    static let outroBars = 2

    let title: String
    let lines: [String]
    let song: ConcertSong
    let seed: UInt64
    let style: ConcertGroove.Style

    init(title: String, lines: [String], style: Style, seed: UInt64) {
        self.title = title
        self.lines = lines
        self.style = style.groove
        self.seed = seed
        song = ConcertSong(title: title, bpm: style.trackBPM, bars: PlayerTrack.introBars + lines.count + PlayerTrack.outroBars)
    }

    /// Seconds from the start of the audio (count-in included) at which line `index` starts: one line per bar.
    func lineStart(_ index: Int) -> Double {
        Double(ConcertEngine.countInBeats + (PlayerTrack.introBars + index) * 4) * song.beat
    }

    var barSeconds: Double { 4 * song.beat }
}

extension Style {
    /// The instrumental that suits each style.
    var groove: ConcertGroove.Style {
        switch self {
        case .boomBap: .boomBap
        case .trap: .trap
        case .melancolique: .afro
        case .drill: .drill
        }
    }

    /// Slow enough for the phone's voice to rap a line per bar.
    var trackBPM: Double {
        switch self {
        case .boomBap: 86
        case .trap: 80
        case .melancolique: 84
        case .drill: 78
        }
    }
}

extension GameEngine {
    /// The track from a finished Punchliner (nil for other mini-games, or a verse left blank).
    func track(for minigame: MinigameState, rapper: Rapper) -> PlayerTrack? {
        guard minigame.kind == .punchliner, let lyrics = minigame.lyrics, lyrics.count >= 2 else { return nil }
        let title = minigame.hook.map { $0.prefix(1).uppercased() + $0.dropFirst() }
            ?? self.minigame(minigame.id)?.title ?? "Sans titre"
        return PlayerTrack(title: title.trimmingCharacters(in: CharacterSet(charactersIn: "« »")), lines: lyrics,
                           style: rapper.style, seed: ConcertEngine.seed(minigame.id + rapper.name, song: lyrics.count))
    }
}
