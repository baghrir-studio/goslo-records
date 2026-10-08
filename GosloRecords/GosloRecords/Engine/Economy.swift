import Foundation

/// Picked at creation (Normal by default): how generous the career is.
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case facile, normal, difficile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .facile: "Facile"
        case .normal: "Normal"
        case .difficile: "Difficile"
        }
    }

    var pitch: String {
        switch self {
        case .facile: "Gains plus forts, pertes plus douces, loyer léger. Pour profiter de l'histoire."
        case .normal: "L'équilibre prévu : chaque choix compte, rien n'est donné."
        case .difficile: "Le game ne fait pas de cadeau : pertes plus lourdes, loyer cher, rivaux plus forts."
        }
    }

    /// Multiplies what a choice gives.
    var gainFactor: Double {
        switch self {
        case .facile: 1.2
        case .normal: 1
        case .difficile: 0.85
        }
    }

    /// Multiplies what a choice costs.
    var lossFactor: Double {
        switch self {
        case .facile: 0.75
        case .normal: 1
        case .difficile: 1.25
        }
    }

    /// Rent, each turn.
    var rent: Int {
        switch self {
        case .facile: 1
        case .normal: -(GameEngine.semesterUpkeep[.argent] ?? -2)
        case .difficile: 3
        }
    }

    /// Levels added to every move in a clash.
    var clashLevelBonus: Int {
        switch self {
        case .facile: 1
        case .normal: 0
        case .difficile: -1
        }
    }
}

/// How stats move: gains shrink near the top (100 is hard to reach and harder to keep), the difficulty scales
/// gains and losses, and low or high stats have consequences at the end of each turn.
enum Economy {
    /// Above this, gains start to shrink.
    static let softCap = 60
    /// Respect under this: venues stop booking you.
    static let lowRespect = 25
    /// Respect from this: venues book you, money comes in.
    static let highRespect = 65
    /// Mental under this: burn-out, one action only next turn.
    static let burnout = 12

    /// The change a choice really makes, at the current value.
    static func tuned(_ delta: Int, at value: Int, difficulty: Difficulty) -> Int {
        guard delta != 0 else { return 0 }
        if delta < 0 { return Int((Double(delta) * difficulty.lossFactor).rounded()) }
        var gain = Double(delta) * difficulty.gainFactor
        if value > softCap {
            // At 70 a gain is worth 65 %, at 80 a third, at 90 an eighth: the top is earned.
            gain *= max(0.06, pow(Double(100 - value) / Double(100 - softCap), 1.5))
        }
        return max(1, Int(gain.rounded()))
    }

    /// End-of-turn costs and income, and the warnings that go with them.
    static func turnEnd(for state: GameState) -> (effects: [StatKind: Int], notes: [String]) {
        let stats = state.stats
        var effects = GameEngine.upkeep(for: stats)
        effects[.argent] = -state.difficulty.rent
        if state.difficulty == .difficile, let streams = effects[.streams] {
            effects[.streams] = Int((Double(streams) * 1.25).rounded())
        }
        var notes: [String] = []
        if stats.credibilite < lowRespect {
            effects[.argent, default: 0] -= 1
            effects[.streams, default: 0] -= 2
            notes.append("Ton respect est au plus bas : les salles ne te bookent plus et le public décroche.")
        } else if stats.credibilite >= highRespect {
            effects[.argent, default: 0] += 3
            notes.append("Ton respect paie : les salles te bookent, le cachet tombe.")
        }
        if stats.mental < burnout {
            notes.append("Burn-out : tu n'as la force que pour une seule chose la prochaine fois.")
        }
        return (effects, notes)
    }
}

extension GameState {
    var difficulty: Difficulty { rapper.difficulty }

    /// Applies what a choice, a result or a reward gives or costs, tuned by `Economy`. Returns what changed.
    @discardableResult
    mutating func applyStats(_ effects: [StatKind: Int]) -> [StatKind: Int] {
        var tuned: [StatKind: Int] = [:]
        for (kind, delta) in effects {
            tuned[kind] = Economy.tuned(delta, at: stats[kind], difficulty: difficulty)
        }
        return stats.apply(tuned)
    }
}
