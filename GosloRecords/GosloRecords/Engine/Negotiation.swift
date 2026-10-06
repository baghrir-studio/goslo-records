import Foundation

/// A contract negotiation (story.json): clause by clause, push your royalties up
/// without exhausting the other side's patience.
struct Negotiation: Codable, Equatable, Identifiable {
    let id: String
    /// Cast id of the person across the table.
    let opponent: String
    let title: String
    let intro: String
    /// Starting royalties (%) and the minimum to accept the deal.
    let startRoyalties: Int
    let targetRoyalties: Int
    let startPatience: Int
    let clauses: [NegotiationClause]
    /// Line when the other side leaves the table.
    let walkout: String
    let win: InterviewResult
    let lose: InterviewResult

    enum CodingKeys: String, CodingKey {
        case id, opponent, title, intro, clauses, walkout, win, lose
        case startRoyalties = "start_royalties"
        case targetRoyalties = "target_royalties"
        case startPatience = "start_patience"
    }

    init(id: String, opponent: String, title: String, intro: String = "", startRoyalties: Int = 8,
         targetRoyalties: Int = 18, startPatience: Int = 60, clauses: [NegotiationClause], walkout: String = "",
         win: InterviewResult, lose: InterviewResult) {
        self.id = id
        self.opponent = opponent
        self.title = title
        self.intro = intro
        self.startRoyalties = startRoyalties
        self.targetRoyalties = targetRoyalties
        self.startPatience = startPatience
        self.clauses = clauses
        self.walkout = walkout
        self.win = win
        self.lose = lose
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        opponent = try c.decode(String.self, forKey: .opponent)
        title = try c.decode(String.self, forKey: .title)
        intro = try c.decodeIfPresent(String.self, forKey: .intro) ?? ""
        startRoyalties = try c.decodeIfPresent(Int.self, forKey: .startRoyalties) ?? 8
        targetRoyalties = try c.decodeIfPresent(Int.self, forKey: .targetRoyalties) ?? 18
        startPatience = try c.decodeIfPresent(Int.self, forKey: .startPatience) ?? 60
        clauses = try c.decode([NegotiationClause].self, forKey: .clauses)
        walkout = try c.decodeIfPresent(String.self, forKey: .walkout) ?? ""
        win = try c.decode(InterviewResult.self, forKey: .win)
        lose = try c.decode(InterviewResult.self, forKey: .lose)
    }
}

struct NegotiationClause: Codable, Equatable {
    /// The clause as written in the contract.
    let text: String
    /// What the other side says about it.
    let pitch: String
    let options: [NegotiationOption]
}

struct NegotiationOption: Codable, Equatable {
    let label: String
    /// Royalty points gained or lost.
    let royalties: Int
    /// Patience gained or lost by the other side.
    let patience: Int
    let reaction: String
    let requires: ChoiceRequirement?

    init(label: String, royalties: Int, patience: Int, reaction: String, requires: ChoiceRequirement? = nil) {
        self.label = label
        self.royalties = royalties
        self.patience = patience
        self.reaction = reaction
        self.requires = requires
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        royalties = try c.decodeIfPresent(Int.self, forKey: .royalties) ?? 0
        patience = try c.decodeIfPresent(Int.self, forKey: .patience) ?? 0
        reaction = try c.decode(String.self, forKey: .reaction)
        requires = try c.decodeIfPresent(ChoiceRequirement.self, forKey: .requires)
    }

    func isAvailable(in state: GameState) -> Bool { requires?.isMet(by: state) ?? true }
}

struct NegotiationLogEntry: Codable, Equatable {
    let clause: Int
    let option: Int
    let royaltiesDelta: Int
    let patienceDelta: Int
    let reaction: String
}

/// Negotiation in progress (saved with the game).
struct NegotiationState: Codable, Equatable {
    static let royaltiesRange = 0...50
    static let patienceRange = 0...100

    let id: String
    var royalties: Int
    var patience: Int
    var clauseIndex = 0
    var log: [NegotiationLogEntry] = []
    let clauseCount: Int
    let target: Int

    init(negotiation: Negotiation) {
        id = negotiation.id
        royalties = negotiation.startRoyalties
        patience = negotiation.startPatience
        clauseCount = negotiation.clauses.count
        target = negotiation.targetRoyalties
    }

    var walkedOut: Bool { patience <= 0 }
    var isOver: Bool { walkedOut || clauseIndex >= clauseCount }
    var passed: Bool { !walkedOut && royalties >= target }
}

enum NegotiationEngine {
    /// Applies an option. Business level softens the other side: every two levels above 1 save one patience
    /// point on demanding answers.
    static func apply(_ option: NegotiationOption, optionIndex: Int, businessLevel: Int, to state: inout NegotiationState) {
        var patience = option.patience
        if patience < 0 { patience = min(0, patience + max(0, businessLevel - 1) / 2) }
        let beforeRoyalties = state.royalties, beforePatience = state.patience
        state.royalties = min(max(state.royalties + option.royalties, NegotiationState.royaltiesRange.lowerBound),
                              NegotiationState.royaltiesRange.upperBound)
        state.patience = min(max(state.patience + patience, NegotiationState.patienceRange.lowerBound),
                             NegotiationState.patienceRange.upperBound)
        state.log.append(NegotiationLogEntry(clause: state.clauseIndex, option: optionIndex,
                                             royaltiesDelta: state.royalties - beforeRoyalties,
                                             patienceDelta: state.patience - beforePatience, reaction: option.reaction))
        state.clauseIndex += 1
    }
}
