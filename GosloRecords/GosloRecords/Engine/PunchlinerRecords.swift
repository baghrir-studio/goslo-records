import Foundation

// Punchliner's personal records (kept on the device, with the achievements) and the crowd's mood after a line.

/// How the crowd takes a line: hands up, nodding, or arms crossed.
enum PunchlineCrowdMood: Equatable {
    /// The real punchline, or a rich rhyme: hands up, jumping, lighters and phones out.
    case hype
    /// A decent line, or a sufficient rhyme: heads nod.
    case nod
    /// A weak rhyme, no rhyme, a flop or a blank: arms crossed.
    case meh
}

extension PunchlinerEngine {
    /// The crowd's mood for a line worth `points` (a chosen ending's score, or a written ending's points).
    static func crowdMood(points: Int) -> PunchlineCrowdMood {
        switch points {
        case bestScore...: .hype
        case PunchlinerEngine.points(for: .suffisante)...: .nod
        default: .meh
        }
    }
}

/// A rhyme the player wrote: their ending, its last word, and the word it rhymed with.
struct RhymePair: Codable, Equatable {
    let ending: String
    let word: String
    let target: String
    let quality: RhymeQuality

    /// Only an ending that rhymes, with a word from the dictionary, makes a pair.
    init?(_ written: WrittenEnding) {
        guard written.known, written.quality > .aucune, !written.word.isEmpty else { return nil }
        self.init(ending: written.text, word: written.word, target: written.target, quality: written.quality)
    }

    init(ending: String, word: String, target: String, quality: RhymeQuality) {
        self.ending = ending
        self.word = word
        self.target = target
        self.quality = quality
    }

    /// A richer rhyme wins; between two as rich, the longer word.
    func beats(_ other: RhymePair?) -> Bool {
        guard let other else { return true }
        if quality != other.quality { return quality > other.quality }
        return word.count > other.word.count
    }
}

extension MinigameState {
    /// Punchliner: keeps count of the rich rhymes written this game, and the best rhyme.
    mutating func noteRhyme(_ written: WrittenEnding) {
        if written.known && written.quality == .riche { richRhymes = (richRhymes ?? 0) + 1 }
        if let pair = RhymePair(written), pair.beats(bestRhyme) { bestRhyme = pair }
    }
}

/// Punchliner records, all games together (story and arcade).
struct PunchlinerRecord: Codable, Equatable {
    /// Best score, in %.
    var bestScore = 0
    /// Rich rhymes written, all games together.
    var richRhymes = 0
    /// The best rhyme ever written.
    var bestRhyme: RhymePair?
    /// Punchliner games finished.
    var games = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        richRhymes = try c.decodeIfPresent(Int.self, forKey: .richRhymes) ?? 0
        bestRhyme = try c.decodeIfPresent(RhymePair.self, forKey: .bestRhyme)
        games = try c.decodeIfPresent(Int.self, forKey: .games) ?? 0
    }

    /// Adds a finished game (score in %). Returns what it beat.
    mutating func record(_ running: MinigameState, score: Int) -> PunchlinerRecordBreak {
        let previous = bestScore
        let rich = running.richRhymes ?? 0
        let newRhyme = running.bestRhyme.map { $0.beats(bestRhyme) } ?? false
        games += 1
        richRhymes += rich
        bestScore = max(bestScore, score)
        if newRhyme { bestRhyme = running.bestRhyme }
        return PunchlinerRecordBreak(score: score, previousBest: previous, richThisGame: rich, newBestRhyme: newRhyme)
    }
}

/// What a finished Punchliner game did to the records (for its result screen).
struct PunchlinerRecordBreak: Equatable {
    let score: Int
    /// The best score before this game.
    let previousBest: Int
    let richThisGame: Int
    /// This game's best rhyme is the best ever written.
    let newBestRhyme: Bool

    /// « Record perso ! »: a score above the old best (a blank first game beats nothing).
    var newBestScore: Bool { score > previousBest }
}

extension TrophyCase {
    /// Keeps the records of a finished Punchliner game (score in %). Other mini-games change nothing.
    mutating func recordPunchliner(_ running: MinigameState, score: Int) -> PunchlinerRecordBreak? {
        guard running.kind == .punchliner, running.isOver else { return nil }
        return punchliner.record(running, score: score)
    }
}
