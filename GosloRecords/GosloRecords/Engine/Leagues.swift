import Foundation

/// Permanent leagues (Clash Royale / Brawl Stars style, without seasons): clash wins earn trophies, losses take
/// some back, but never below the floor of the best league reached. Leagues never reset; reaching one pays once.
enum League: Int, Codable, CaseIterable, Identifiable, Comparable {
    case bronze, argent, or, platine, diamant, legende, icone

    var id: Int { rawValue }

    static func < (a: League, b: League) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .bronze: "Bronze"
        case .argent: "Argent"
        case .or: "Or"
        case .platine: "Platine"
        case .diamant: "Diamant"
        case .legende: "Légende"
        case .icone: "Icône"
        }
    }

    /// Trophies needed to enter it (also its floor once reached).
    var threshold: Int {
        switch self {
        case .bronze: 0
        case .argent: 120
        case .or: 300
        case .platine: 520
        case .diamant: 800
        case .legende: 1150
        case .icone: 1600
        }
    }

    var next: League? { League(rawValue: rawValue + 1) }

    static func of(trophies: Int) -> League {
        allCases.last { trophies >= $0.threshold } ?? .bronze
    }

    /// The cosmetic title it gives, shown under the rapper's name.
    var title: String? {
        switch self {
        case .bronze: nil
        case .argent: "Tchatcheur d'argent"
        case .or: "Plume dorée"
        case .platine: "Flow de platine"
        case .diamant: "Diamant brut"
        case .legende: "Légende du bitume"
        case .icone: "Icône du rap"
        }
    }

    /// One-time reward for reaching it: money and a chest.
    var reward: (money: Int, chest: ChestRarity?) {
        switch self {
        case .bronze: (0, nil)
        case .argent: (4, .argent)
        case .or: (6, .or)
        case .platine: (8, .or)
        case .diamant: (10, .legendaire)
        case .legende: (12, .legendaire)
        case .icone: (15, .legendaire)
        }
    }

    /// Badge colour (hex, for the UI).
    var color: String {
        switch self {
        case .bronze: "#c47a3d"
        case .argent: "#c9ced8"
        case .or: "#f2c14e"
        case .platine: "#7fe0d0"
        case .diamant: "#5ab4ff"
        case .legende: "#c86bff"
        case .icone: "#ff4d2e"
        }
    }
}

enum Trophies {
    /// Base trophies for a win and for a loss, by kind of clash.
    static func base(wild: Bool, boss: Bool) -> (win: Int, loss: Int) {
        if wild { return (20, 14) }
        if boss { return (34, 12) }
        return (28, 18)
    }

    static let winRange = 8...50
    static let lossRange = 4...30

    /// Trophies won (positive) or lost (negative) for a clash. `gap` is the opponent's strength minus the player's
    /// (in levels, average over the four moves): a stronger opponent pays more and costs less.
    static func delta(won: Bool, wild: Bool, boss: Bool, gap: Double) -> Int {
        let base = base(wild: wild, boss: boss)
        if won {
            let value = Int((Double(base.win) + gap * 5).rounded())
            return min(max(value, winRange.lowerBound), winRange.upperBound)
        }
        let value = Int((Double(base.loss) - gap * 4).rounded())
        return -min(max(value, lossRange.lowerBound), lossRange.upperBound)
    }
}

extension GameState {
    var league: League { League.of(trophies: trophies) }
    /// The league title shown under the rapper's name (the best league reached).
    var leagueTitle: String? { bestLeague.title }
}

extension GameEngine {
    /// Opponent strength minus the player's, in levels (average over the moves).
    func strengthGap(for clash: ClashState, in state: GameState) -> Double {
        guard let profile = castMember(clash.opponentId)?.clash?.scaled(by: clash.levelBonus) else { return 0 }
        let levels = clashLevels(for: clash, in: state)
        let moves = ClashMove.allCases
        let opponent = Double(moves.reduce(0) { $0 + profile.stat($1) }) / Double(moves.count)
        let player = Double(moves.reduce(0) { $0 + levels($1.skill) }) / Double(moves.count)
        return opponent - player
    }

    /// Trophies and the chest for a finished clash. `ranked`: the clash counts (a terrain vague duel past the
    /// period's paid share is a friendly match: no trophies, no chest).
    func applyLadder(_ clash: ClashState, ranked: Bool, in state: inout GameState, outcome: inout TurnOutcome) {
        guard ranked else {
            outcome.notes.append("Match amical : ni trophées ni coffre.")
            return
        }
        let won = clash.playerWon
        let delta = Trophies.delta(won: won, wild: clash.isWild, boss: clash.isBoss, gap: strengthGap(for: clash, in: state))
        if won { grantChest(chestRarity(for: clash, in: state), in: &state, outcome: &outcome) }
        changeTrophies(by: delta, in: &state, outcome: &outcome)
    }

    /// Moves the trophy count (never below the best league's floor) and pays every league reached for the first time.
    func changeTrophies(by delta: Int, in state: inout GameState, outcome: inout TurnOutcome) {
        let before = state.trophies
        state.trophies = max(state.bestLeague.threshold, state.trophies + delta)
        outcome.trophies = state.trophies - before
        let reached = League.of(trophies: state.trophies)
        guard reached > state.bestLeague else { return }
        for league in League.allCases where league > state.bestLeague && league <= reached {
            let reward = league.reward
            outcome.add(state.stats.apply([.argent: reward.money]))
            outcome.notes.append("LIGUE \(league.name.uppercased()) ATTEINTE ! Titre : « \(league.title ?? league.name) ».")
            if let chest = reward.chest, !grantChest(chest, in: &state, outcome: &outcome) {
                // Slots full: the league chest is paid in money instead, so the reward is never lost.
                let money = state.stats.apply([.argent: chest.money.upperBound])
                outcome.add(money)
                outcome.notes.append("Le coffre de ligue est payé cash : +\(money[.argent] ?? 0) argent.")
            }
            outcome.league = league
        }
        state.bestLeague = reached
    }
}
