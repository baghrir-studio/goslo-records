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

    /// Stable seed per concert and song (Swift's own hash changes on every launch).
    static func seed(_ concertId: String, song: Int) -> UInt64 {
        concertId.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
            &+ UInt64(song) &* 7919
    }

    /// Notes of a song: always one on each downbeat, more on the other beats and off-beats with density.
    static func chart(for song: ConcertSong, seed: UInt64) -> [ConcertNote] {
        var rng = SeededGenerator(seed: seed)
        var notes: [ConcertNote] = []
        var previousLane = 1
        for bar in 0..<song.bars {
            for step in 0..<8 {
                let isDownbeat = step == 0
                let isBeat = step % 2 == 0
                let chance = isDownbeat ? 1.0 : (isBeat ? 0.25 + song.density * 0.6 : song.density * 0.45)
                guard Double.random(in: 0..<1, using: &rng) < chance else { continue }
                var lane = Int.random(in: 0..<lanes, using: &rng)
                // Quick off-beats stay on the same or a neighbour lane: playable with one thumb.
                if !isBeat && abs(lane - previousLane) > 1 { lane = 1 }
                previousLane = lane
                let beats = Double(countInBeats + bar * 4) + Double(step) * 0.5
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
