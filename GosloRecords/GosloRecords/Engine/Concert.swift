import Foundation

/// A concert (story.json): a setlist played as a rhythm game, with crowd interludes between songs.
struct Concert: Codable, Equatable, Identifiable {
    let id: String
    let venue: String
    let intro: String
    let startHype: Int
    let passHype: Int
    let songs: [ConcertSong]
    let win: InterviewResult
    let lose: InterviewResult

    enum CodingKeys: String, CodingKey {
        case id, venue, intro, songs, win, lose
        case startHype = "start_hype"
        case passHype = "pass_hype"
    }

    init(id: String, venue: String, intro: String = "", startHype: Int = 35, passHype: Int = 65,
         songs: [ConcertSong], win: InterviewResult, lose: InterviewResult) {
        self.id = id
        self.venue = venue
        self.intro = intro
        self.startHype = startHype
        self.passHype = passHype
        self.songs = songs
        self.win = win
        self.lose = lose
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        venue = try c.decode(String.self, forKey: .venue)
        intro = try c.decodeIfPresent(String.self, forKey: .intro) ?? ""
        startHype = try c.decodeIfPresent(Int.self, forKey: .startHype) ?? 35
        passHype = try c.decodeIfPresent(Int.self, forKey: .passHype) ?? 65
        songs = try c.decode([ConcertSong].self, forKey: .songs)
        win = try c.decode(InterviewResult.self, forKey: .win)
        lose = try c.decode(InterviewResult.self, forKey: .lose)
    }
}

struct ConcertSong: Codable, Equatable {
    let title: String
    let bpm: Double
    let bars: Int
    /// 0…1: how many off-beat notes are added on top of the downbeats.
    let density: Double
    /// Optional crowd moment after the song.
    let interlude: ConcertInterlude?

    init(title: String, bpm: Double = 90, bars: Int = 6, density: Double = 0.4, interlude: ConcertInterlude? = nil) {
        self.title = title
        self.bpm = bpm
        self.bars = bars
        self.density = density
        self.interlude = interlude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        bpm = try c.decodeIfPresent(Double.self, forKey: .bpm) ?? 90
        bars = max(1, try c.decodeIfPresent(Int.self, forKey: .bars) ?? 6)
        density = min(max(try c.decodeIfPresent(Double.self, forKey: .density) ?? 0.4, 0), 1)
        interlude = try c.decodeIfPresent(ConcertInterlude.self, forKey: .interlude)
    }

    var beat: Double { 60 / bpm }
    /// Duration including the count-in bar and a short tail.
    var duration: Double { Double(ConcertEngine.countInBeats + bars * 4 + 2) * beat }
}

/// Between two songs: something happens in the crowd, you react.
struct ConcertInterlude: Codable, Equatable {
    let text: String
    let options: [ConcertOption]
}

struct ConcertOption: Codable, Equatable {
    let label: String
    let hype: Int
    let reaction: String
}

struct ConcertNote: Equatable, Identifiable {
    let id: Int
    /// Seconds from the start of the song.
    let time: Double
    /// 0, 1 or 2.
    let lane: Int
}

enum ConcertJudgment: String, Codable, Equatable {
    case perfect
    case good
    case miss
}

/// Concert in progress (saved between songs; a song in progress restarts on resume).
struct ConcertState: Codable, Equatable {
    static let hypeRange = 0...100

    let id: String
    var hype: Int
    var songIndex = 0
    /// The song is over and its interlude is waiting for an answer.
    var inInterlude = false
    var combo = 0
    var maxCombo = 0
    var perfects = 0
    var goods = 0
    var misses = 0
    let songCount: Int
    let passHype: Int

    init(concert: Concert) {
        id = concert.id
        hype = concert.startHype
        songCount = concert.songs.count
        passHype = concert.passHype
    }

    var isOver: Bool { songIndex >= songCount }
    var passed: Bool { hype >= passHype }
}

/// Pure concert rules: charts, timing windows, scoring.
enum ConcertEngine {
    static let countInBeats = 4
    static let lanes = 3
    static let perfectWindow = 0.07
    static let baseGoodWindow = 0.15

    static let points: [ConcertJudgment: Int] = [.perfect: 4, .good: 2, .miss: -5]
    /// From this combo, every perfect is worth one more point.
    static let comboBonusFrom = 10

    /// Higher Scène level = more forgiving "good" window.
    static func goodWindow(sceneLevel: Int) -> Double {
        baseGoodWindow + 0.006 * Double(min(max(sceneLevel, 1), 10))
    }

    static func judge(offset: Double, sceneLevel: Int) -> ConcertJudgment? {
        let distance = abs(offset)
        if distance <= perfectWindow { return .perfect }
        if distance <= goodWindow(sceneLevel: sceneLevel) { return .good }
        return nil
    }

    // MARK: Calibration

    /// Clicks played during calibration, and how many first taps are ignored (warming up).
    static let calibrationClicks = 10
    static let calibrationWarmup = 2
    static let calibrationInterval = 0.6
    /// The offset never goes past this (a bigger one is a mistake, not latency).
    static let maxLatency = 0.25

    /// Audio and touch latency from calibration taps: the median gap between each tap and the nearest click,
    /// warm-up taps left out. Positive = the player hears (and taps) late.
    static func latency(taps: [Double], interval: Double = calibrationInterval) -> Double? {
        let gaps = taps.map { tap -> Double in
            let nearest = (tap / interval).rounded() * interval
            return tap - nearest
        }
        .dropFirst(calibrationWarmup)
        .sorted()
        guard gaps.count >= 3 else { return nil }
        let median = gaps[gaps.count / 2]
        return min(max(median, -maxLatency), maxLatency)
    }

    /// Stable seed per concert and song (Swift's own hash changes on every launch).
    static func seed(_ concertId: String, song: Int) -> UInt64 {
        concertId.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
            &+ UInt64(song) &* 7919
    }

    /// Notes of a song, taken from its instrumental (`ConcertGroove`): kicks on the left lane, snares and claps in the
    /// middle, the hook on the right. One note per eighth at most, always one on each downbeat (the kick), more with density.
    /// A note only ever sits on a sound the player hears.
    static func chart(for song: ConcertSong, seed: UInt64) -> [ConcertNote] {
        let groove = ConcertGroove.make(for: song, seed: seed)
        var rng = SeededGenerator(seed: seed &+ 1)
        var notes: [ConcertNote] = []
        var previousLane = 0
        for bar in 0..<song.bars {
            let hits = groove.hits(bar: bar)
            for step in stride(from: 0, to: 16, by: 2) {
                let isDownbeat = step == 0
                let isBeat = step % 4 == 0
                let chance = isDownbeat ? 1.0 : (isBeat ? 0.25 + song.density * 0.6 : song.density * 0.45)
                let roll = Double.random(in: 0..<1, using: &rng)
                var lanes = Set(hits.filter { $0.step == Double(step) }.compactMap { ConcertGroove.lane(of: $0.part) }).sorted()
                guard roll < chance, !lanes.isEmpty else { continue }
                if isDownbeat, lanes.contains(0) { lanes = [0] }
                // Quick off-beats stay on the same or a neighbour lane: playable with one thumb.
                let near = lanes.filter { abs($0 - previousLane) <= 1 }
                if !isBeat, !near.isEmpty { lanes = near }
                let lane = lanes[Int.random(in: 0..<lanes.count, using: &rng)]
                previousLane = lane
                let beats = Double(countInBeats + bar * 4) + Double(step) / 4
                notes.append(ConcertNote(id: notes.count, time: beats * song.beat, lane: lane))
            }
        }
        return notes
    }

    static func apply(_ judgment: ConcertJudgment, to state: inout ConcertState) {
        var delta = points[judgment, default: 0]
        switch judgment {
        case .perfect:
            state.perfects += 1
            state.combo += 1
            if state.combo >= comboBonusFrom { delta += 1 }
        case .good:
            state.goods += 1
            state.combo += 1
        case .miss:
            state.misses += 1
            state.combo = 0
        }
        state.maxCombo = max(state.maxCombo, state.combo)
        state.hype = min(max(state.hype + delta, ConcertState.hypeRange.lowerBound), ConcertState.hypeRange.upperBound)
    }

    static func apply(_ judgments: [ConcertJudgment], to state: inout ConcertState) {
        for judgment in judgments { apply(judgment, to: &state) }
    }
}

// MARK: - Concert instrumentals

/// The instrumental of a concert song, decided once from its seed: a style, a minor key, and what plays on each
/// sixteenth of each bar. The audio (`ConcertMix`) and the notes to tap (`ConcertEngine.chart`) both come from it,
/// so the game is always in time with the music.
struct ConcertGroove: Equatable {
    enum Style: String, CaseIterable {
        case boomBap, trap, afro, drill
    }

    enum Part: Equatable {
        case kick, snare, hat, openHat, bass, chord, lead
    }

    struct Hit: Equatable {
        /// Sixteenths from the start of the bar (fractions for hi-hat rolls).
        let step: Double
        let part: Part
        /// MIDI note (bass, lead) or chord root.
        var note = 0
        /// Length in beats (bass, chord, lead).
        var length = 0.25
        var gain = 1.0
        /// Bass only: slides up from this note.
        var slideFrom: Int?
    }

    let style: Style
    /// Root of the minor key (MIDI, octave 3).
    let root: Int
    let bars: Int
    let bpm: Double
    /// The hook: two bars of (step, scale degree), repeated, varied on every fourth bar.
    let hook: [[(step: Int, degree: Int)]]

    static func == (lhs: ConcertGroove, rhs: ConcertGroove) -> Bool {
        lhs.style == rhs.style && lhs.root == rhs.root && lhs.bars == rhs.bars && lhs.bpm == rhs.bpm
            && lhs.hook.map { $0.map(\.step) } == rhs.hook.map { $0.map(\.step) }
            && lhs.hook.map { $0.map(\.degree) } == rhs.hook.map { $0.map(\.degree) }
    }

    /// Off-beat swing (boom bap only), as a fraction of a sixteenth.
    var swing: Double { style == .boomBap ? 0.14 : 0 }

    /// Minor pentatonic, two octaves.
    static let scale = [0, 3, 5, 7, 10, 12, 15, 17, 19, 22]
    /// i – VI – III – VII, as semitones from the root.
    static let progression = [0, 8, 3, 10]

    /// `style` forces the style (the player's own track); otherwise the seed picks it.
    static func make(for song: ConcertSong, seed: UInt64, style forced: Style? = nil) -> ConcertGroove {
        var rng = SeededGenerator(seed: seed ^ 0x9E37_79B9_7F4A_7C15)
        let picked = Style.allCases[Int.random(in: 0..<Style.allCases.count, using: &rng)]
        let style = forced ?? picked
        let root = [45, 48, 50, 43, 47][Int.random(in: 0..<5, using: &rng)]
        let rhythms: [[Int]] = switch style {
        case .boomBap: [[0, 4, 6, 10, 12], [0, 2, 6, 8, 12, 14]]
        case .trap: [[0, 2, 4, 6, 8, 10, 12, 14], [0, 2, 4, 6, 8, 10, 12, 14]]
        case .afro: [[0, 4, 6, 10, 12, 14], [2, 6, 8, 12, 14]]
        case .drill: [[0, 6, 8, 12], [0, 4, 10, 12, 14]]
        }
        // A melodic walk on the pentatonic: small steps, the odd leap, ending each phrase on the root or the fifth.
        var degree = 5
        let hook = rhythms.enumerated().map { bar, steps in
            steps.enumerated().map { index, step -> (step: Int, degree: Int) in
                if bar == 1 && index == steps.count - 1 {
                    degree = Bool.random(using: &rng) ? 5 : 3
                } else {
                    degree = min(max(degree + [-2, -1, -1, 1, 1, 2, 3][Int.random(in: 0..<7, using: &rng)], 0), scale.count - 1)
                }
                return (step, degree)
            }
        }
        return ConcertGroove(style: style, root: root, bars: song.bars, bpm: song.bpm, hook: hook)
    }

    /// Lane of the notes a part produces (nil = heard, not played).
    static func lane(of part: Part) -> Int? {
        switch part {
        case .kick: 0
        case .snare: 1
        case .lead: 2
        case .hat, .openHat, .bass, .chord: nil
        }
    }

    /// Everything that plays in a bar.
    func hits(bar: Int) -> [Hit] {
        let b = bar % 2 == 1
        let turnaround = bar % 4 == 3
        let chordRoot = root + ConcertGroove.progression[bar % 4] - (ConcertGroove.progression[bar % 4] > 7 ? 12 : 0)
        var hits: [Hit] = []
        func add(_ part: Part, _ steps: [Double], gain: Double = 1) {
            hits += steps.map { Hit(step: $0, part: part, gain: gain) }
        }
        switch style {
        case .boomBap:
            add(.kick, b ? [0, 3, 8, 10] : [0, 7, 10])
            add(.snare, [4, 12])
            if b { add(.snare, [15], gain: 0.35) }
            add(.hat, stride(from: 0.0, to: 16, by: 2).map { $0 }, gain: 0.8)
            add(.openHat, [14], gain: 0.6)
            hits.append(Hit(step: 0, part: .bass, note: chordRoot - 12, length: 1.5))
            hits.append(Hit(step: 10, part: .bass, note: chordRoot - 12, length: 0.7))
            hits.append(Hit(step: 0, part: .chord, note: chordRoot, length: 2.5, gain: 0.8))
        case .trap:
            add(.kick, b ? [0, 3, 10, 13] : [0, 6, 10])
            add(.snare, [8])
            if turnaround { add(.snare, [14], gain: 0.6) }
            add(.hat, stride(from: 0.0, to: 12, by: 2).map { $0 })
            let roll: [Double] = b ? stride(from: 12.0, to: 16, by: 0.5).map { $0 } : stride(from: 12.0, to: 16, by: 4.0 / 3).map { $0 }
            add(.hat, roll, gain: 0.8)
            add(.openHat, [6], gain: 0.5)
            hits.append(Hit(step: 0, part: .bass, note: chordRoot - 12, length: 2))
            hits.append(Hit(step: 10, part: .bass, note: chordRoot - 5, length: 1, slideFrom: chordRoot - 12))
        case .afro:
            add(.kick, [0, 4, 8, 12])
            add(.snare, b ? [6, 10, 14] : [6, 14], gain: 0.8)
            add(.hat, stride(from: 0.0, to: 16, by: 1).map { $0 }, gain: 0.45)
            add(.openHat, [2, 10], gain: 0.4)
            for (step, offset) in [(0, 0), (3, 0), (6, 7), (10, 0), (12, 5)] {
                hits.append(Hit(step: Double(step), part: .bass, note: chordRoot - 12 + offset, length: 0.6))
            }
            for step in [2.0, 6, 10, 14] { hits.append(Hit(step: step, part: .chord, note: chordRoot, length: 0.4, gain: 0.6)) }
        case .drill:
            add(.kick, b ? [0, 3, 11] : [0, 11])
            add(.snare, b ? [8, 14] : [8])
            add(.hat, [0, 3, 6, 8, 10, 13, 14], gain: 0.85)
            hits.append(Hit(step: 0, part: .bass, note: chordRoot - 12, length: 1.4, slideFrom: chordRoot - 10))
            hits.append(Hit(step: 6, part: .bass, note: chordRoot - 9, length: 1, slideFrom: chordRoot - 12))
            hits.append(Hit(step: 11, part: .bass, note: chordRoot - 14, length: 1.2, slideFrom: chordRoot - 9))
            hits.append(Hit(step: 0, part: .chord, note: chordRoot, length: 4, gain: 0.5))
        }
        // The hook, an octave up; the turnaround bar answers with the phrase shifted up.
        for (step, degree) in hook[bar % 2] {
            let lift = turnaround ? 2 : 0
            let note = root + 12 + ConcertGroove.scale[min(degree + lift, ConcertGroove.scale.count - 1)]
            hits.append(Hit(step: Double(step), part: .lead, note: note, length: style == .drill ? 0.75 : 0.4))
        }
        return hits
    }
}
