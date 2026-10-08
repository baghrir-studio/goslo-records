import Foundation

/// Clash tactics: chain two moves for a combo, read the opponent's tell and answer with its counter,
/// and play to the crowd (each district's public loves one move).
struct ClashCombo: Equatable {
    let first: ClashMove
    let then: ClashMove
    let name: String
    let multiplier: Double

    static let all = [
        ClashCombo(first: .flow, then: .punchline, name: "Mise en place", multiplier: 1.4),
        ClashCombo(first: .story, then: .punchline, name: "Le Retournement", multiplier: 1.5),
        ClashCombo(first: .punchline, then: .presence, name: "Le Silence qui Tue", multiplier: 1.35),
        ClashCombo(first: .presence, then: .story, name: "Storytelling de Scène", multiplier: 1.35),
    ]

    static func find(after previous: ClashMove?, with move: ClashMove) -> ClashCombo? {
        guard let previous else { return nil }
        return all.first { $0.first == previous && $0.then == move }
    }

    /// The combo this move would start (to hint the next step).
    static func started(by move: ClashMove) -> ClashCombo? { all.first { $0.first == move } }
}

extension ClashMove {
    /// The move that shuts this one down when you see it coming.
    var counter: ClashMove {
        switch self {
        case .punchline: .presence   // You own the stage: the punchline falls flat.
        case .flow: .punchline       // You cut them off mid-flow.
        case .presence: .story       // You tell the crowd who they really are.
        case .story: .flow           // You talk over the story.
        }
    }

    /// What the opponent does before playing this move (the tell the player can read).
    func tell(_ name: String) -> String {
        switch self {
        case .punchline: "\(name) sourit en coin… une punchline arrive."
        case .flow: "\(name) hoche la tête en rythme… il va dérouler."
        case .presence: "\(name) écarte les bras vers le public…"
        case .story: "\(name) sort son téléphone et cherche une photo…"
        }
    }
}

enum ClashTactics {
    /// A countered move only lands this share of its damage.
    static let parryFactor = 0.3
    /// The crowd's favourite move hits this much harder, for both sides.
    static let crowdBonus = 1.2

    /// What each district's public loves.
    static func crowdFavorite(in district: District) -> ClashMove {
        switch district {
        case .bloc: .story
        case .centre: .flow
        case .hauts: .punchline
        case .dome: .presence
        }
    }

    /// The opponent's next move as the player sees it coming: chosen after each round, or at the start
    /// their strongest move.
    static func telegraphed(_ state: ClashState, profile: ClashProfile) -> ClashMove {
        state.nextOpponentMove ?? ClashMove.allCases.max { profile.stat($0) < profile.stat($1) } ?? .flow
    }
}
