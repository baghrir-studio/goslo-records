import Foundation

/// What the end of a period (turn) paid and cost, split by source. Filled by `GameEngine.finishAction`
/// when a turn closes, and shown on the period briefing.
struct PeriodSummary: Equatable {
    /// Rent taken this turn (a positive number, from the difficulty).
    var rent = 0
    /// Upkeep and bookings actually applied (`Economy.turnEnd`, rent included), plus aging in a free career.
    var upkeep: [StatKind: Int] = [:]
    /// Album sales.
    var albums: [StatKind: Int] = [:]
    /// The Top goslo radio's payout.
    var chart: [StatKind: Int] = [:]
    /// Decorations, buildings and the radio once bought (`decorIncome`).
    var income: [StatKind: Int] = [:]
    /// The Top's lines for this turn ("Top goslo radio : « … » n°3 ▲2.").
    var chartNotes: [String] = []

    /// Everything together.
    var net: [StatKind: Int] {
        var total: [StatKind: Int] = [:]
        for part in [upkeep, albums, chart, income] {
            for (kind, value) in part { total[kind, default: 0] += value }
        }
        return total.filter { $0.value != 0 }
    }

    /// Money brought in by the turn (rent left out).
    var earned: Int { (albums[.argent] ?? 0) + (chart[.argent] ?? 0) + (income[.argent] ?? 0) }
}

/// The compact card shown when a new period starts: what it paid, and what to aim for next.
struct PeriodBriefing: Equatable {
    static let maxObjectives = 3

    let isNewYear: Bool
    let summary: PeriodSummary?
    let objectives: [String]
    /// What the neighbourhood wants this period (`Neighbourhood.demand`), once the player can build.
    var demand: String? = nil

    var title: String { isNewYear ? "Nouvelle année" : "Nouvelle période" }
}

extension GameEngine {
    /// The briefing for the period that just started (`summary`: what the turn that closed paid).
    func periodBriefing(in state: GameState, summary: PeriodSummary?) -> PeriodBriefing {
        let builds = !state.placed.isEmpty || ArtistLevel.level(xp: state.artistXP) >= 2
        return PeriodBriefing(isNewYear: state.isNewYear, summary: summary, objectives: periodObjectives(in: state),
                              demand: builds ? Neighbourhood.demand(turn: state.turn).line : nil)
    }

    /// Up to three short goals: the story objective, the season's open challenges, and something to save for.
    func periodObjectives(in state: GameState) -> [String] {
        var story: [String] = []
        if let objective = currentObjective(in: state) {
            let place = objectiveDistrict(in: state).map { " (\($0.name))" } ?? ""
            story.append(objective.label + place)
        }
        let challenges = state.challenges.filter { !$0.done }.map { challenge in
            "\(challenge.label) (\(Challenges.progress(challenge, in: state))/\(Challenges.goal(challenge)))"
        }
        let money = savingGoal(in: state).map { ["\($0.name) : encore \($0.missing) d'argent"] } ?? []
        // Money waiting in your buildings: go and pick it up before it stops piling up.
        let waiting = state.placed.reduce(0) { $0 + $1.stored }
        let pickup = waiting > 0 ? ["Ramasse \(waiting) d'argent dans tes bâtiments"] : []
        // A rival holding one of your buildings comes right after the story.
        let raid = raidObjective(in: state).map { [$0] } ?? []
        // One of each first, then more challenges if there's room.
        var picked = story + raid + pickup + challenges.prefix(1) + money
        picked += challenges.dropFirst()
        return Array(picked.prefix(PeriodBriefing.maxObjectives))
    }

    /// The cheapest thing the player could buy at their level but can't afford yet (a purchase never takes the last
    /// coin, so it needs one more than the price): shop gear not owned yet, a decoration or building not put down yet,
    /// goslo radio itself.
    func savingGoal(in state: GameState) -> (name: String, missing: Int)? {
        let level = ArtistLevel.level(xp: state.artistXP)
        let owned = Set(state.decor.values).union(state.placed.map(\.decor))
        var options: [(name: String, price: Int)] = Shop.gear.filter { !state.items.contains($0.id) }.map { ($0.name, $0.price) }
        options += Decor.allCases.filter { level >= $0.minLevel && !owned.contains($0) }.map { ($0.name, $0.price) }
        if level >= RadioDeal.minLevel, !state.flags.contains(RadioDeal.flag) { options.append(("goslo radio", RadioDeal.price)) }
        let argent = state.stats.argent
        guard let next = options.filter({ argent <= $0.price }).min(by: { $0.price < $1.price }) else { return nil }
        return (next.name, next.price + 1 - argent)
    }
}

extension Stats {
    /// What moved since `earlier`, by stat (zeros left out).
    func changes(since earlier: Stats) -> [StatKind: Int] {
        var changes: [StatKind: Int] = [:]
        for kind in StatKind.allCases where self[kind] != earlier[kind] { changes[kind] = self[kind] - earlier[kind] }
        return changes
    }
}
