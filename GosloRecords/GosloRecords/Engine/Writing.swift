import Foundation

/// A writing session (story.json): finish each couplet before the timer runs out.
/// In a duel, the opponent lands a line first and it costs you some edge.
struct Writing: Codable, Equatable, Identifiable {
    let id: String
    /// Cast id of the coach (studio) or the opponent (duel).
    let partner: String
    let title: String
    let intro: String
    /// Duel against the partner (their attacks hurt) rather than a studio session.
    let duel: Bool
    let boss: Bool
    let startScore: Int
    let passScore: Int
    let timeoutPenalty: Int
    let rounds: [WritingRound]
    let win: InterviewResult
    let lose: InterviewResult

    enum CodingKeys: String, CodingKey {
        case id, partner, title, intro, duel, boss, rounds, win, lose
        case startScore = "start_score"
        case passScore = "pass_score"
        case timeoutPenalty = "timeout_penalty"
    }

    init(id: String, partner: String, title: String, intro: String = "", duel: Bool = false, boss: Bool = false,
         startScore: Int = 40, passScore: Int = 70, timeoutPenalty: Int = 10, rounds: [WritingRound],
         win: InterviewResult, lose: InterviewResult) {
        self.id = id
        self.partner = partner
        self.title = title
        self.intro = intro
        self.duel = duel
        self.boss = boss
        self.startScore = startScore
        self.passScore = passScore
        self.timeoutPenalty = timeoutPenalty
        self.rounds = rounds
        self.win = win
        self.lose = lose
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        partner = try c.decode(String.self, forKey: .partner)
        title = try c.decode(String.self, forKey: .title)
        intro = try c.decodeIfPresent(String.self, forKey: .intro) ?? ""
        duel = try c.decodeIfPresent(Bool.self, forKey: .duel) ?? false
        boss = try c.decodeIfPresent(Bool.self, forKey: .boss) ?? false
        startScore = try c.decodeIfPresent(Int.self, forKey: .startScore) ?? 40
        passScore = try c.decodeIfPresent(Int.self, forKey: .passScore) ?? 70
        timeoutPenalty = try c.decodeIfPresent(Int.self, forKey: .timeoutPenalty) ?? 10
        rounds = try c.decode([WritingRound].self, forKey: .rounds)
        win = try c.decode(InterviewResult.self, forKey: .win)
        lose = try c.decode(InterviewResult.self, forKey: .lose)
    }
}

struct WritingRound: Codable, Equatable {
    /// The opponent's line before yours (duels only).
    let attack: WritingAttack?
    /// First line of your couplet, already written.
    let setup: String
    /// Seconds to pick the second line, before the Plume bonus.
    let time: Double
    let options: [WritingOption]

    init(attack: WritingAttack? = nil, setup: String, time: Double = 9, options: [WritingOption]) {
        self.attack = attack
        self.setup = setup
        self.time = time
        self.options = options
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attack = try c.decodeIfPresent(WritingAttack.self, forKey: .attack)
        setup = try c.decode(String.self, forKey: .setup)
        time = try c.decodeIfPresent(Double.self, forKey: .time) ?? 9
        options = try c.decode([WritingOption].self, forKey: .options)
    }
}

struct WritingAttack: Codable, Equatable {
    let line: String
    let damage: Int
}

struct WritingOption: Codable, Equatable {
    /// The second line of the couplet.
    let line: String
    let score: Int
    let reaction: String
    let requires: ChoiceRequirement?

    init(line: String, score: Int, reaction: String, requires: ChoiceRequirement? = nil) {
        self.line = line
        self.score = score
        self.reaction = reaction
        self.requires = requires
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        line = try c.decode(String.self, forKey: .line)
        score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        reaction = try c.decode(String.self, forKey: .reaction)
        requires = try c.decodeIfPresent(ChoiceRequirement.self, forKey: .requires)
    }

    func isAvailable(in state: GameState) -> Bool { requires?.isMet(by: state) ?? true }
}

struct WritingLogEntry: Codable, Equatable {
    let round: Int
    /// nil when the timer ran out.
    let option: Int?
    let attackDelta: Int
    let scoreDelta: Int
    let reaction: String
}

/// Writing session in progress (saved with the game).
struct WritingState: Codable, Equatable {
    static let scoreRange = 0...100

    let id: String
    var score: Int
    var roundIndex = 0
    /// The current round's attack has already been applied.
    var attacked = false
    /// What the current round's attack actually cost (after clamping).
    var attackDelta = 0
    var log: [WritingLogEntry] = []
    let roundCount: Int
    let passScore: Int

    init(writing: Writing) {
        id = writing.id
        score = writing.startScore
        roundCount = writing.rounds.count
        passScore = writing.passScore
    }

    var isOver: Bool { roundIndex >= roundCount }
    var passed: Bool { score >= passScore }
}

enum WritingEngine {
    static let blankLine = "… (trou noir)"

    /// Seconds to answer: every Plume level above 1 adds half a second.
    static func time(for round: WritingRound, plumeLevel: Int) -> Double {
        round.time + 0.5 * Double(max(0, plumeLevel - 1))
    }

    static func clamp(_ value: Int) -> Int {
        min(max(value, WritingState.scoreRange.lowerBound), WritingState.scoreRange.upperBound)
    }

    /// The opponent's line hits (once per round).
    static func applyAttack(of round: WritingRound, to state: inout WritingState) {
        guard !state.attacked else { return }
        state.attacked = true
        let before = state.score
        if let attack = round.attack { state.score = clamp(state.score - attack.damage) }
        state.attackDelta = state.score - before
    }

    /// Your line: nil option = the timer ran out.
    static func write(_ option: WritingOption?, index: Int?, in round: WritingRound, timeoutPenalty: Int,
                      to state: inout WritingState) {
        applyAttack(of: round, to: &state)
        let attackDelta = state.attackDelta
        let before = state.score
        state.score = clamp(state.score + (option?.score ?? -timeoutPenalty))
        state.log.append(WritingLogEntry(round: state.roundIndex, option: index, attackDelta: attackDelta,
                                         scoreDelta: state.score - before,
                                         reaction: option?.reaction ?? "Trou noir. Tu ouvres la bouche, rien ne sort. Le beat continue sans toi, poliment."))
        state.roundIndex += 1
        state.attacked = false
        state.attackDelta = 0
    }
}
