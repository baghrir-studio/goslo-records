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

extension PlayerTrack {
    /// The instrumental as a 16-bit mono WAV file, for the voice booth (AVAudioPlayer plays files).
    static func wav(_ samples: [Float], sampleRate: Double) -> Data {
        let rate = UInt32(sampleRate.rounded())
        let dataSize = UInt32(samples.count * 2)
        var data = Data(capacity: 44 + samples.count * 2)
        func append(_ text: String) { data.append(contentsOf: Array(text.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        append("RIFF"); append32(36 + dataSize); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(1); append32(rate); append32(rate * 2); append16(2); append16(16)
        append("data"); append32(dataSize)
        for sample in samples {
            let clipped = max(-1, min(1, sample.isFinite ? sample : 0))
            append16(UInt16(bitPattern: Int16((clipped * 32_767).rounded())))
        }
        return data
    }

    /// File name of the player's recorded voice on this track: one per title, overwritten on a new take.
    var voiceFileName: String {
        let words = title.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { FrenchDictionary.normalize(String($0)) }.filter { !$0.isEmpty }
        let slug = String(words.joined(separator: "-").prefix(60))
        return "voix-\(slug.isEmpty ? "sans-titre" : slug).m4a"
    }
}
