import Foundation

/// A short repeatable mini-game (story.json "minigames"), started from an event choice ("minigame": id).
struct Minigame: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        /// Finish punchlines with word tiles.
        case punchliner
        /// Run through the crowd to the door.
        case fuite
        /// Stop DJ Noize's pitch on 100 %.
        case platine
        /// Epilogue: sign young artists to your label, within a budget.
        case signing
        /// Repeat the beatboxer's pattern, one sound longer each round.
        case beatbox
    }

    let id: String
    let kind: Kind
    let title: String
    let intro: String
    /// Score (0…1) to reach for the win result.
    let passScore: Double
    /// Punchliner only: its own verses, played first while never seen. A game has as many verses as this.
    let rounds: [PunchlinerRound]
    /// Punchliner only: the hardest tier of pool verses it offers (nil: all of them).
    let tier: Int?
    /// Signing only.
    let signing: SigningSpec?
    let win: InterviewResult
    let lose: InterviewResult

    enum CodingKeys: String, CodingKey {
        case id, kind, title, intro, rounds, tier, signing, win, lose
        case passScore = "pass_score"
    }

    init(id: String, kind: Kind, title: String, intro: String = "", passScore: Double = 0.5,
         rounds: [PunchlinerRound] = [], tier: Int? = nil, signing: SigningSpec? = nil, win: InterviewResult,
         lose: InterviewResult) {
        self.id = id
        self.kind = kind
        self.title = title
        self.intro = intro
        self.passScore = passScore
        self.rounds = rounds
        self.tier = tier
        self.signing = signing
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
        tier = try c.decodeIfPresent(Int.self, forKey: .tier)
        signing = try c.decodeIfPresent(SigningSpec.self, forKey: .signing)
        win = try c.decode(InterviewResult.self, forKey: .win)
        lose = try c.decode(InterviewResult.self, forKey: .lose)
    }

    /// Rounds the player goes through.
    var roundCount: Int {
        switch kind {
        case .punchliner: rounds.count
        case .platine: PlatineEngine.runs
        case .beatbox: BeatboxEngine.rounds
        case .fuite, .signing: 1
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
    /// Signing only: the artists signed, in order (optional so saves from before the epilogue still load).
    var signed: [String]?
    /// Punchliner only: the verse as written, two lines per round (see `PlayerTrack`).
    var lyrics: [String]?
    /// Punchliner only: the first real punchline the player found, the track's title.
    var hook: String?
    /// Punchliner only: rich rhymes written this game, and the best rhyme written (see `noteRhyme`).
    var richRhymes: Int?
    var bestRhyme: RhymePair?
    /// Punchliner only: the ids of the verses drawn for this game, in order (`PunchlinerDeck`). nil: the
    /// mini-game's own verses (games saved before the pool).
    var verses: [String]?
    let roundCount: Int

    init(minigame: Minigame) {
        id = minigame.id
        kind = minigame.kind
        roundCount = minigame.roundCount
    }

    var isOver: Bool { kind == .fuite ? escaped != nil : round >= roundCount }
}

// MARK: - Punchliner

/// One punchline to finish: the first line, the start of the second, and four endings to pick from.
struct PunchlinerRound: Codable, Equatable {
    let setup: String
    /// Start of the second line; the chosen ending follows.
    let lead: String
    /// The endings on offer: the punchline, a decent line, a weak rhyme, and a flop that doesn't rhyme.
    let endings: [PunchlinerAnswer]
}

struct PunchlinerAnswer: Codable, Equatable {
    let text: String
    let score: Int
    let reaction: String
}

enum PunchlinerEngine {
    static let endingCount = 4
    static let bestScore = 10

    /// The order the endings are shown in, the same every time (stable per minigame and round).
    static func order(for round: PunchlinerRound, seed: UInt64) -> [Int] {
        var rng = SeededGenerator(seed: seed)
        return Array(round.endings.indices).shuffled(using: &rng)
    }

    static func seed(_ minigameId: String, round: Int) -> UInt64 {
        ConcertEngine.seed(minigameId, song: round)
    }

    /// Points and reaction for the chosen ending (nil = time ran out).
    static func judge(_ choice: Int?, in round: PunchlinerRound) -> (points: Int, reaction: String) {
        guard let choice, round.endings.indices.contains(choice) else {
            return (0, "Trou noir. Le beat continue sans toi, poliment.")
        }
        let ending = round.endings[choice]
        return (ending.score, ending.reaction)
    }

    /// Best possible total, to turn points into a 0…1 score.
    static func maxPoints(_ minigame: Minigame) -> Int { maxPoints(minigame.rounds) }

    static func maxPoints(_ rounds: [PunchlinerRound]) -> Int {
        rounds.map { $0.endings.map(\.score).max() ?? 0 }.reduce(0, +)
    }

    // MARK: Writing your own ending

    /// Longest ending the player can type.
    static let maxWrittenLength = 70

    /// Points for a typed ending: a rich rhyme is worth the real punchline.
    static func points(for quality: RhymeQuality) -> Int {
        switch quality {
        case .riche: bestScore
        case .suffisante: 6
        case .pauvre: 3
        case .aucune: 0
        }
    }

    /// The words a typed ending must rhyme with: the last word of the setup line, then the last word of the
    /// real punchline (the proposed endings rhyme on it when the setup doesn't quite). `render` agrees the text.
    static func rhymeTargets(for round: PunchlinerRound, render: (String) -> String = { $0 }) -> [String] {
        var targets: [String] = []
        let lines = [render(round.setup)] + (round.endings.max(by: { $0.score < $1.score }).map { [render($0.text)] } ?? [])
        for line in lines {
            guard let word = Rhyme.lastWord(of: line).map({ String(Rhyme.letters(of: $0)) }), !word.isEmpty,
                  !targets.contains(where: { FrenchDictionary.normalize($0) == FrenchDictionary.normalize(word) }) else { continue }
            targets.append(word)
        }
        return targets
    }

    /// Judges an ending the player typed: its last word must be in the dictionary, and rhyme with the round.
    static func judgeWritten(_ text: String, in round: PunchlinerRound, dictionary: FrenchDictionary,
                             render: (String) -> String = { $0 }) -> WrittenEnding {
        let ending = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxWrittenLength))
        let targets = rhymeTargets(for: round, render: render)
        let shownTarget = targets.first ?? "…"
        guard let word = Rhyme.lastWord(of: ending) else {
            return WrittenEnding(text: ending, word: "", target: shownTarget, quality: .aucune, known: false,
                                 feedback: "Il faut écrire une fin.", reaction: "Le micro attend. Le beat aussi.")
        }
        guard dictionary.contains(word) else {
            return WrittenEnding(text: ending, word: word, target: shownTarget, quality: .aucune, known: false,
                                 feedback: "« \(word) » n'est pas dans le dictionnaire.",
                                 reaction: "Le public sort son téléphone pour chercher le mot. Rien. DJ Noize hausse les épaules.")
        }
        // Typed without accents (« ete »)? Also try the final -e as an -é: the accent doesn't make you lose.
        var candidates = [word]
        let letters = Rhyme.letters(of: word)
        if letters.count > 2, letters.last == "e", FrenchDictionary.normalize(String(letters)) == String(letters) {
            candidates.append(String(letters.dropLast()) + "é")
        }
        // Ending on the setup's own word is no rhyme.
        if FrenchDictionary.normalize(shownTarget) == FrenchDictionary.normalize(String(letters)) {
            return WrittenEnding(text: ending, word: word, target: shownTarget, quality: .aucune, known: true,
                                 feedback: "« \(shownTarget) » avec « \(shownTarget) » : même mot, ça ne compte pas.",
                                 reaction: "Le public a l'impression d'avoir déjà entendu ça. Il y a deux secondes.")
        }
        var best: (quality: RhymeQuality, endings: (String, String)?, target: String) = (.aucune, nil, shownTarget)
        for target in targets {
            // The real punchline's own word: copying it isn't writing (the setup word still counts).
            if FrenchDictionary.normalize(target) == FrenchDictionary.normalize(String(letters)) { continue }
            for candidate in candidates {
                let match = Rhyme.match(candidate, target, lexicon: dictionary)
                if match.quality > best.quality { best = (match.quality, match.endings, target) }
            }
        }
        let quality = best.quality
        let feedback: String
        let reaction: String
        switch quality {
        case .riche:
            feedback = "Rime riche !" + spelled(best.endings)
            reaction = "La salle explose. DJ Noize coupe le son pour qu'on entende le public la répéter."
        case .suffisante:
            feedback = "Rime suffisante." + spelled(best.endings)
            reaction = "Ça rime, ça claque. Des têtes hochent jusqu'au fond."
        case .pauvre:
            feedback = "Rime pauvre." + spelled(best.endings)
            reaction = "Ça rime… de loin. DJ Noize fait semblant de régler une platine."
        case .aucune:
            feedback = "Pas de rime avec « \(shownTarget) »."
            reaction = "Le silence est poli, mais c'est un silence."
        }
        return WrittenEnding(text: ending, word: word, target: best.target, quality: quality, known: true,
                             feedback: feedback, reaction: reaction)
    }

    private static func spelled(_ endings: (String, String)?) -> String {
        guard let endings else { return "" }
        return " (-\(endings.0) / -\(endings.1))"
    }
}

/// An ending the player typed, judged.
struct WrittenEnding: Equatable {
    /// The ending as typed (trimmed).
    let text: String
    /// Its last word.
    let word: String
    /// The word it was checked against.
    let target: String
    let quality: RhymeQuality
    /// Was the last word in the dictionary?
    let known: Bool
    /// « Rime riche ! (-ver / -vers) », « « blarf » n'est pas dans le dictionnaire. »
    let feedback: String
    let reaction: String

    var points: Int { known ? PunchlinerEngine.points(for: quality) : 0 }
}

// MARK: - Cale la platine

/// DJ Noize's pitch drifts up and down; the player stops it as close to 100 % as they can.
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
        case ..<0.6: return (3, "\(shown) %. Pile. DJ Noize pose la main sur son cœur.")
        case ..<2: return (2, "\(shown) %. Presque. Noize dit que « presque, c'est l'énergie ».")
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

// MARK: - Signing (epilogue)

/// The label's first auditions: a budget, a few young artists, two contracts at most.
struct SigningSpec: Codable, Equatable {
    /// Money to share between the advances (Business levels add to it).
    let budget: Int
    /// Contracts at most.
    let picks: Int
    /// Points needed for the label to take off.
    let target: Int
    let artists: [SigningArtist]
}

/// A young artist. Talent and buzz are shown; reliability stays hidden until they're signed.
struct SigningArtist: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let style: String
    let pitch: String
    /// A hint about the hidden reliability.
    let flaw: String
    let cost: Int
    let talent: Int
    let buzz: Int
    let reliability: Int
    /// What happens to their first single.
    let reveal: String

    var points: Int { talent + buzz + reliability }
}

enum SigningEngine {
    /// Two artists of different styles: the label sounds like a label, not a clone factory.
    static let varietyBonus = 3
    /// Extra budget per Business level.
    static let budgetPerBusinessLevel = 2

    static func budget(_ spec: SigningSpec, businessLevel: Int) -> Int {
        spec.budget + max(0, businessLevel) * budgetPerBusinessLevel
    }

    /// Can these artists be signed together?
    static func isAffordable(_ ids: [String], in spec: SigningSpec, businessLevel: Int) -> Bool {
        let artists = ids.compactMap { id in spec.artists.first { $0.id == id } }
        return !ids.isEmpty && artists.count == ids.count && Set(ids).count == ids.count && ids.count <= spec.picks
            && artists.map(\.cost).reduce(0, +) <= budget(spec, businessLevel: businessLevel)
    }

    static func points(_ ids: [String], in spec: SigningSpec) -> Int {
        let artists = ids.compactMap { id in spec.artists.first { $0.id == id } }
        let bonus = Set(artists.map(\.style)).count > 1 ? varietyBonus : 0
        return artists.map(\.points).reduce(0, +) + bonus
    }
}
