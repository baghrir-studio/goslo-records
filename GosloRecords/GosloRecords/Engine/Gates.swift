import Foundation

/// Barriers against farming. Every repeatable source the player can trigger from the map goes through one:
/// - a progress gate (chapter or artist level) before it opens at all;
/// - a cooldown: it pays at most `perPeriod` times a period (turn) and `perYear` times a year.
/// Past the cap it still answers (a line of flavour) but pays nothing. The counters live in `GameState`
/// and reset in `finishAction`, so the reward is decided once, in the engine, whatever the UI shows or skips.
enum Gate: String, CaseIterable, Codable {
    /// The bench in Le Bloc: an encounter in the street (`Location.quartier`).
    case bench
    /// The phone button: social media and DMs (`Location.reseaux`).
    case phone
    /// Wild clashes in the terrain vague (and the street cypher).
    case terrain
    /// Street happenings that pay: the fan's selfie, the beatboxer's challenge.
    case happening

    var minChapter: Int {
        switch self {
        case .happening: 2
        case .bench, .phone, .terrain: 1
        }
    }

    var minArtistLevel: Int { 1 }

    /// Rewarded uses per period. Repeats beyond the first ones need progress: the terrain vague
    /// pays one more duel at artist levels 3 and 6.
    func perPeriod(level: Int) -> Int {
        switch self {
        case .bench, .phone, .happening: 1
        case .terrain: 3 + (level >= 3 ? 1 : 0) + (level >= 6 ? 1 : 0)
        }
    }

    /// Rewarded uses per year (nil: only the period cap).
    var perYear: Int? {
        switch self {
        case .phone: 4
        case .bench, .terrain, .happening: nil
        }
    }

    /// What the player hears once the period's (or year's) share is spent.
    func spentLine(yearly: Bool) -> String {
        switch self {
        case .bench: "Le banc est occupé. Repasse la période prochaine."
        case .phone: yearly ? "Tu as assez scrollé cette année. Pose ce téléphone, va vivre un peu."
                            : "Rien de neuf sur ton téléphone. Reviens plus tard."
        case .terrain: "Le terrain vague t'a assez vu pour cette période : la victoire compte, mais plus personne ne filme."
        case .happening: "Tu as déjà fait ton show de rue pour cette période. Reviens plus tard."
        }
    }
}

/// Whether a gated source pays right now.
enum GateStatus: Equatable {
    case open
    /// Not yet: the progress it needs.
    case locked(String)
    /// Already paid enough this period or this year.
    case spent(String)

    var isOpen: Bool { self == .open }

    /// The short line to show in the dialogue box (nil when open).
    var line: String? {
        switch self {
        case .open: nil
        case .locked(let line), .spent(let line): line
        }
    }
}

/// A gated visit: the encounter, or why nothing happens (no action spent, nothing paid).
enum GatedVisit: Equatable {
    case event(GameEvent)
    case closed([String])
}

enum Gates {
    /// The bench pays more as the career goes on (not as the player sits again): +10 % per artist level, up to +50 %.
    static func benchScale(level: Int) -> Double { 1 + 0.1 * Double(min(max(level, 1), 6) - 1) }

    /// Scales the gains of a choice (losses stay as they are).
    static func scaled(_ effects: [StatKind: Int], by factor: Double) -> [StatKind: Int] {
        guard factor != 1 else { return effects }
        return effects.mapValues { $0 > 0 ? max(factor > 0 ? 1 : 0, Int((Double($0) * factor).rounded())) : $0 }
    }

    static func scaled(_ xp: [Skill: Int], by factor: Double) -> [Skill: Int] {
        guard factor != 1 else { return xp }
        return xp.mapValues { $0 > 0 ? Int((Double($0) * factor).rounded()) : $0 }
    }
}

extension GameEngine {
    func gateStatus(_ gate: Gate, in state: GameState) -> GateStatus {
        if state.chapter < gate.minChapter { return .locked("Chapitre \(gate.minChapter) requis pour ça.") }
        let level = ArtistLevel.level(xp: state.artistXP)
        if level < gate.minArtistLevel { return .locked("Niveau \(gate.minArtistLevel) requis pour ça.") }
        if let perYear = gate.perYear, state.gateYearUses[gate.rawValue, default: 0] >= perYear {
            return .spent(gate.spentLine(yearly: true))
        }
        if state.gatePeriodUses[gate.rawValue, default: 0] >= gate.perPeriod(level: level) {
            return .spent(gate.spentLine(yearly: false))
        }
        return .open
    }

    /// Counts one rewarded use. Returns false (and counts nothing) if the gate is closed.
    @discardableResult
    func useGate(_ gate: Gate, in state: inout GameState) -> Bool {
        guard gateStatus(gate, in: state).isOpen else { return false }
        state.gatePeriodUses[gate.rawValue, default: 0] += 1
        state.gateYearUses[gate.rawValue, default: 0] += 1
        return true
    }

    /// A new period (and maybe a new year): the cooldowns start over. Called by `finishAction`.
    func resetGates(in state: inout GameState) {
        state.gatePeriodUses = [:]
        if state.isNewYear { state.gateYearUses = [:] }
    }

    /// Sitting on the bench: a street encounter (1 action) once a period. The story always gets through.
    func sitOnBench<R: RandomNumberGenerator>(in state: inout GameState, using rng: inout R) throws -> GatedVisit {
        try gatedVisit(.bench, at: .quartier, in: &state, using: &rng)
    }

    /// The phone button: social media (1 action), once a period and a few times a year.
    func checkPhone<R: RandomNumberGenerator>(in state: inout GameState, using rng: inout R) throws -> GatedVisit {
        try gatedVisit(.phone, at: .reseaux, in: &state, using: &rng)
    }

    private func gatedVisit<R: RandomNumberGenerator>(_ gate: Gate, at location: Location, in state: inout GameState,
                                                      using rng: inout R) throws -> GatedVisit {
        guard canVisit(state) else { throw GameEngineError.cannotVisit }
        if storyEvent(at: location, in: state) != nil {
            return .event(try visit(location, in: &state, using: &rng))
        }
        let status = gateStatus(gate, in: state)
        if let line = status.line { return .closed([line]) }
        let event = try visit(location, in: &state, using: &rng)
        useGate(gate, in: &state)
        state.currentGate = gate
        return .event(event)
    }
}
