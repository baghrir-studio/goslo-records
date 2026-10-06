import Foundation

/// A short repeatable mini-game (story.json "minigames"), started from an event choice ("minigame": id).
struct Minigame: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        /// Finish punchlines with word tiles.
        case punchliner
        /// Run through the crowd to the door.
        case fuite
        /// Stop DJ Bobine's pitch on 100 %.
        case platine
    }

    let id: String
    let kind: Kind
    let title: String
    let intro: String
    /// Score (0…1) to reach for the win result.
    let passScore: Double
    /// Punchliner only.
    let rounds: [PunchlinerRound]
    let win: InterviewResult
    let lose: InterviewResult

    enum CodingKeys: String, CodingKey {
        case id, kind, title, intro, rounds, win, lose
        case passScore = "pass_score"
    }

    init(id: String, kind: Kind, title: String, intro: String = "", passScore: Double = 0.5,
         rounds: [PunchlinerRound] = [], win: InterviewResult, lose: InterviewResult) {
        self.id = id
        self.kind = kind
        self.title = title
        self.intro = intro
        self.passScore = passScore
        self.rounds = rounds
        self.win = win
        self.lose = lose
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(Kind.self, forKey: .kind)
        title = try c.decode(String.self, forKey: .title)
        intro = try c.decodeIfPresent(String.self, forKey: .intro) ?? ""
        passScore = try c.decodeIfPresent(Double.self, forKey: .passScore) ?? 0.5
        rounds = try c.decodeIfPresent([PunchlinerRound].self, forKey: .rounds) ?? []
        win = try c.decode(InterviewResult.self, forKey: .win)
        lose = try c.decode(InterviewResult.self, forKey: .lose)
    }

    /// Rounds the player goes through.
    var roundCount: Int {
        switch kind {
        case .punchliner: rounds.count
        case .platine: PlatineEngine.runs
        case .fuite: 1
        }
    }
}

/// Mini-game in progress (saved with the game).
struct MinigameState: Codable, Equatable {
    let id: String
    let kind: Minigame.Kind
    var round = 0
    var points = 0
    /// Reaction to each round, in order.
    var log: [String] = []
    /// Fuite only: set by the chase screen once it's over.
    var escaped: Bool?
    let roundCount: Int

    init(minigame: Minigame) {
        id = minigame.id
        kind = minigame.kind
        roundCount = minigame.roundCount
    }

    var isOver: Bool { kind == .fuite ? escaped != nil : round >= roundCount }
}

// MARK: - Punchliner

/// One punchline to finish: the first line, the start of the second, and 20 word tiles.
struct PunchlinerRound: Codable, Equatable {
    let setup: String
    /// Start of the second line; the player's words follow.
    let lead: String
    /// Endings worth points (exact word sequences).
    let answers: [PunchlinerAnswer]
    /// Extra tiles, so there are 20 in all.
    let decoys: [String]
    /// Last words that at least rhyme with the setup.
    let rhymes: [String]

    /// Every tile, each word once.
    var words: [String] {
        var seen = Set<String>()
        return (answers.flatMap(\.words) + decoys).filter { seen.insert($0).inserted }
    }
}

struct PunchlinerAnswer: Codable, Equatable {
    let words: [String]
    let score: Int
    let reaction: String
}

enum PunchlinerEngine {
    static let tileCount = 20
    static let maxWords = 6
    /// Points when the line only rhymes.
    static let rhymeScore = 2

    /// The tiles of a round, shuffled the same way every time (stable per minigame and round).
    static func tiles(for round: PunchlinerRound, seed: UInt64) -> [String] {
        var rng = SeededGenerator(seed: seed)
        return round.words.shuffled(using: &rng)
    }

    static func seed(_ minigameId: String, round: Int) -> UInt64 {
        ConcertEngine.seed(minigameId, song: round)
    }

    /// Points and reaction for the words the player lined up (empty = time ran out).
    static func judge(_ words: [String], in round: PunchlinerRound) -> (points: Int, reaction: String) {
        if words.isEmpty {
            return (0, "Trou noir. Le beat continue sans toi, poliment.")
        }
        if let answer = round.answers.first(where: { $0.words == words }) {
            return (answer.score, answer.reaction)
        }
        if let last = words.last, round.rhymes.contains(last) {
            return (rhymeScore, "Ça rime, au moins. Le reste de la phrase cherche encore son chemin.")
        }
        return (0, "Silence gêné. Quelqu'un tousse. Même le beat hésite.")
    }

    /// Best possible total, to turn points into a 0…1 score.
    static func maxPoints(_ minigame: Minigame) -> Int {
        minigame.rounds.map { $0.answers.map(\.score).max() ?? 0 }.reduce(0, +)
    }
}

// MARK: - Cale la platine

/// DJ Bobine's pitch drifts up and down; the player stops it as close to 100 % as they can.
enum PlatineEngine {
    static let runs = 3
    /// Points per run, by precision.
    static let maxPoints = 3

    /// Seconds for one full swing on run `run` (faster each time).
    static func period(run: Int) -> Double { [3.2, 2.4, 1.7][min(max(run, 0), 2)] }

    /// The pitch (%) `time` seconds into run `run`: it swings between 96 % and 112 %.
    static func pitch(at time: Double, run: Int) -> Double {
        104 + 8 * sin(2 * .pi * time / period(run: run) - .pi / 2)
    }

    /// Points and reaction for stopping at `pitch`.
    static func judge(pitch: Double) -> (points: Int, reaction: String) {
        let gap = abs(pitch - 100)
        let shown = String(format: "%.1f", pitch).replacingOccurrences(of: ".", with: ",")
        switch gap {
        case ..<0.6: return (3, "\(shown) %. Pile. DJ Bobine pose la main sur son cœur.")
        case ..<2: return (2, "\(shown) %. Presque. Bobine dit que « presque, c'est l'énergie ».")
        case ..<5: return (1, "\(shown) %. Ça s'entend. Un pigeon ralentit, perplexe.")
        default: return (0, "\(shown) %. Ta voix ressemble à un écureuil en retard.")
        }
    }
}

// MARK: - Fuir la foule

/// The chase: a small grid, the player starts at the bottom, the door is at the top, fans close in.
struct CrowdChase: Equatable {
    static let width = 9
    static let height = 13
    static let door = TilePoint(x: 4, y: 0)
    static let start = TilePoint(x: 4, y: 12)
    /// Seconds between two crowd steps, and how long before the crowd swallows you.
    static let stepSeconds = 0.45
    static let timeLimit = 20.0
    /// A new fan pops out of a side street every this many steps.
    static let spawnEvery = 3

    /// Lamp posts and bins: nobody walks through them.
    static let obstacles: Set<TilePoint> = [
        TilePoint(x: 2, y: 3), TilePoint(x: 6, y: 3), TilePoint(x: 4, y: 5),
        TilePoint(x: 1, y: 7), TilePoint(x: 7, y: 7), TilePoint(x: 3, y: 9), TilePoint(x: 5, y: 9),
    ]

    var player = CrowdChase.start
    var fans: [TilePoint]
    var steps = 0
    var caught = false
    var escaped = false

    var isOver: Bool { caught || escaped }

    /// Two fans already between you and the door, three on your heels (not right next to you).
    init<R: RandomNumberGenerator>(using rng: inout R) {
        fans = []
        while fans.count < 2 {
            let spot = TilePoint(x: Int.random(in: 0..<CrowdChase.width, using: &rng), y: Int.random(in: 2...6, using: &rng))
            if CrowdChase.isFree(spot), !fans.contains(spot) { fans.append(spot) }
        }
        while fans.count < 5 {
            let spot = TilePoint(x: Int.random(in: 0..<CrowdChase.width, using: &rng), y: Int.random(in: 9...12, using: &rng))
            if CrowdChase.isFree(spot), !fans.contains(spot), abs(spot.x - CrowdChase.start.x) >= 2 { fans.append(spot) }
        }
    }

    static func isFree(_ point: TilePoint) -> Bool {
        (0..<width).contains(point.x) && (0..<height).contains(point.y) && !obstacles.contains(point)
    }

    /// The player moves one tile (walls and obstacles block).
    mutating func move(_ direction: Direction) {
        guard !isOver else { return }
        let target = player.moved(direction)
        guard CrowdChase.isFree(target) else { return }
        player = target
        settle()
    }

    /// The crowd moves one tile toward the player (now and then a fan hesitates), and grows.
    mutating func step<R: RandomNumberGenerator>(using rng: inout R) {
        guard !isOver else { return }
        steps += 1
        fans = fans.map { fan in
            if Int.random(in: 0..<100, using: &rng) < 20 { return fan }
            let dx = player.x - fan.x, dy = player.y - fan.y
            let tries: [Direction] = abs(dx) >= abs(dy)
                ? [dx > 0 ? .right : .left, dy > 0 ? .down : .up]
                : [dy > 0 ? .down : .up, dx > 0 ? .right : .left]
            for direction in tries {
                let next = fan.moved(direction)
                if CrowdChase.isFree(next) { return next }
            }
            return fan
        }
        if steps % CrowdChase.spawnEvery == 0 {
            let side = TilePoint(x: Bool.random(using: &rng) ? 0 : CrowdChase.width - 1, y: Int.random(in: 1...8, using: &rng))
            if CrowdChase.isFree(side), side != player { fans.append(side) }
        }
        if Double(steps) * CrowdChase.stepSeconds >= CrowdChase.timeLimit && !escaped { caught = true }
        settle()
    }

    private mutating func settle() {
        if player == CrowdChase.door { escaped = true }
        if !escaped && fans.contains(player) { caught = true }
    }
}
