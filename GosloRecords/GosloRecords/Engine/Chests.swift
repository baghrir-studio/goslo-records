import Foundation

/// Victory chests (Clash Royale style): a won clash that already pays drops a chest into one of four slots.
/// A chest opens after a few in-game periods (one chest unlocks at a time), or right away for a little money.
/// No real-time clock anywhere: everything is counted in periods (`GameState.turn`).
enum ChestRarity: String, Codable, CaseIterable, Identifiable {
    case bronze, argent, or, legendaire

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bronze: "Bronze"
        case .argent: "Argent"
        case .or: "Or"
        case .legendaire: "Légendaire"
        }
    }

    /// Periods (turns) it takes to unlock once started.
    var unlockPeriods: Int {
        switch self {
        case .bronze: 1
        case .argent: 2
        case .or: 3
        case .legendaire: 4
        }
    }

    /// Money inside (argent, the 0–100 stat): modest, so the stats stay balanced.
    var money: ClosedRange<Int> {
        switch self {
        case .bronze: 1...2
        case .argent: 2...4
        case .or: 4...6
        case .legendaire: 6...10
        }
    }

    /// Artist XP inside.
    var xp: ClosedRange<Int> {
        switch self {
        case .bronze: 4...6
        case .argent: 7...10
        case .or: 12...18
        case .legendaire: 20...30
        }
    }

    /// Chance (in %) of a piece of clothing the player doesn't own yet.
    var wearableChance: Int {
        switch self {
        case .bronze: 0
        case .argent: 15
        case .or: 35
        case .legendaire: 100
        }
    }

    /// Chance (in %) of a career technique unlocked ahead of its level.
    var techniqueChance: Int {
        switch self {
        case .bronze, .argent: 0
        case .or: 10
        case .legendaire: 35
        }
    }

    /// Chance (in %) of a crew card (or a fragment of one already owned).
    var crewChance: Int {
        switch self {
        case .bronze: 0
        case .argent: 10
        case .or: 25
        case .legendaire: 50
        }
    }

    /// Money per remaining period to open it right now.
    static let rushPerPeriod = 3
}

/// A chest waiting in a slot.
struct VictoryChest: Codable, Equatable, Identifiable {
    /// Serial number in the career (also seeds its contents).
    let id: Int
    let rarity: ChestRarity
    /// Turn the unlock started (nil: still locked, waiting for the player to pick it).
    var unlockStartedTurn: Int?
}

/// Where a chest stands.
enum ChestStatus: Equatable {
    /// Waiting: the player can start its unlock (if no other chest is unlocking).
    case locked
    /// Unlocking: periods left.
    case unlocking(Int)
    case ready
}

/// What came out of a chest.
struct ChestLoot: Equatable {
    let rarity: ChestRarity
    /// Money actually added (after clamping).
    var money = 0
    var xp = 0
    /// Clothing id (`Wardrobe`).
    var wearable: String?
    /// Technique id (story.json "techniques").
    var technique: String?
    /// Crew card (or fragment) won.
    var crew: CrewGain?
    /// Level-ups and other lines.
    var notes: [String] = []
}

enum Chests {
    static let slots = 4

    /// Story flag that unlocks a technique won in a chest (`UnlockableTechnique.isUnlocked`).
    static func techniqueFlag(_ id: String) -> String { "coffre_technique_\(id)" }

    /// Drop odds (in %, bronze/argent/or/légendaire) for a won clash.
    static func odds(wild: Bool, boss: Bool) -> [ChestRarity: Int] {
        if wild { return [.bronze: 70, .argent: 22, .or: 7, .legendaire: 1] }
        if boss { return [.bronze: 20, .argent: 40, .or: 30, .legendaire: 10] }
        return [.bronze: 45, .argent: 35, .or: 17, .legendaire: 3]
    }

    static func roll(_ odds: [ChestRarity: Int], value: Int) -> ChestRarity {
        var left = value % max(1, odds.values.reduce(0, +))
        for rarity in ChestRarity.allCases {
            left -= odds[rarity, default: 0]
            if left < 0 { return rarity }
        }
        return .bronze
    }
}

extension GameEngine {
    func chestStatus(_ chest: VictoryChest, in state: GameState) -> ChestStatus {
        guard let start = chest.unlockStartedTurn else { return .locked }
        let left = start + chest.rarity.unlockPeriods - state.turn
        return left <= 0 ? .ready : .unlocking(left)
    }

    /// The chest currently counting down (only one at a time).
    func unlockingChest(in state: GameState) -> VictoryChest? {
        state.chests.first { if case .unlocking = chestStatus($0, in: state) { return true } else { return false } }
    }

    func hasReadyChest(in state: GameState) -> Bool {
        state.chests.contains { chestStatus($0, in: state) == .ready }
    }

    /// Money to open it now: the periods left (all of them if not started) times `rushPerPeriod`.
    func rushCost(_ chest: VictoryChest, in state: GameState) -> Int {
        switch chestStatus(chest, in: state) {
        case .ready: 0
        case .unlocking(let left): left * ChestRarity.rushPerPeriod
        case .locked: chest.rarity.unlockPeriods * ChestRarity.rushPerPeriod
        }
    }

    /// Why this chest can't start unlocking (nil: it can).
    func unlockRefusal(_ chestId: Int, in state: GameState) -> String? {
        guard let chest = state.chests.first(where: { $0.id == chestId }) else { return "Coffre introuvable" }
        guard chestStatus(chest, in: state) == .locked else { return "Déjà lancé" }
        if unlockingChest(in: state) != nil { return "Un coffre se déverrouille déjà" }
        return nil
    }

    /// Why this chest can't be opened right now with money (nil: it can).
    func rushRefusal(_ chestId: Int, in state: GameState) -> String? {
        guard !state.isOver, let chest = state.chests.first(where: { $0.id == chestId }) else { return "Coffre introuvable" }
        // Never down to 0: an empty wallet ends the career.
        if state.stats.argent <= rushCost(chest, in: state) { return "Pas assez d'argent" }
        return nil
    }

    /// Adds a chest to a free slot. Returns false (and says so) when the four slots are full.
    @discardableResult
    func grantChest(_ rarity: ChestRarity, in state: inout GameState, outcome: inout TurnOutcome) -> Bool {
        guard state.chests.count < Chests.slots else {
            outcome.notes.append("Coffres pleins : pas de nouveau coffre. Ouvre-en un pour faire de la place.")
            return false
        }
        state.chestSerial += 1
        state.chests.append(VictoryChest(id: state.chestSerial, rarity: rarity))
        outcome.chest = rarity
        let periods = rarity.unlockPeriods
        outcome.notes.append("Coffre \(rarity.name) gagné ! (\(periods) période\(periods > 1 ? "s" : "") pour l'ouvrir)")
        return true
    }

    /// The chest a won clash drops: légendaire from a Tournoi boss, otherwise drawn (the same for the same career and chest).
    func chestRarity(for clash: ClashState, in state: GameState) -> ChestRarity {
        if tournamentBoss(for: clash) != nil { return .legendaire }
        let value = Int(GameEngine.fnv("\(state.id.uuidString)-coffre-\(state.chestSerial + 1)-\(clash.opponentId)") % 1000)
        return Chests.roll(Chests.odds(wild: clash.isWild, boss: clash.isBoss), value: value)
    }

    /// Starts the countdown of a waiting chest.
    func startUnlocking(_ chestId: Int, in state: inout GameState) throws {
        guard unlockRefusal(chestId, in: state) == nil,
              let index = state.chests.firstIndex(where: { $0.id == chestId }) else { throw GameEngineError.requirementNotMet }
        state.chests[index].unlockStartedTurn = state.turn
    }

    /// Opens a ready chest: its contents go straight to the career.
    func openChest(_ chestId: Int, in state: inout GameState) throws -> ChestLoot {
        guard !state.isOver, let chest = state.chests.first(where: { $0.id == chestId }),
              chestStatus(chest, in: state) == .ready else { throw GameEngineError.requirementNotMet }
        return loot(chest, in: &state)
    }

    /// Opens a chest now, for money.
    func rushChest(_ chestId: Int, in state: inout GameState) throws -> ChestLoot {
        guard rushRefusal(chestId, in: state) == nil,
              let chest = state.chests.first(where: { $0.id == chestId }) else { throw GameEngineError.cannotBuy }
        state.stats.apply([.argent: -rushCost(chest, in: state)])
        return loot(chest, in: &state)
    }

    /// Techniques a chest can hand out early: those earned by the career itself (artist level only).
    func chestTechniques(in state: GameState) -> [UnlockableTechnique] {
        story.techniques.filter { $0.minArtistLevel != nil && $0.unlock == EventConditions() && !$0.isUnlocked(in: state) }
    }

    private func loot(_ chest: VictoryChest, in state: inout GameState) -> ChestLoot {
        state.chests.removeAll { $0.id == chest.id }
        var rng = SeededGenerator(seed: GameEngine.fnv("\(state.id.uuidString)-ouverture-\(chest.id)"))
        let rarity = chest.rarity
        var loot = ChestLoot(rarity: rarity)
        var money = Int.random(in: rarity.money, using: &rng)

        if Int.random(in: 0..<100, using: &rng) < rarity.wearableChance {
            // The better the chest, the finer the piece.
            let unowned = Wardrobe.items.filter { !state.wardrobe.contains($0.id) }.sorted { $0.price < $1.price }
            let pool = rarity == .or || rarity == .legendaire ? Array(unowned.suffix(max(1, (unowned.count + 1) / 2))) : unowned
            if let item = pool.randomElement(using: &rng) {
                state.wardrobe.insert(item.id)
                wear(item, in: &state)
                loot.wearable = item.id
            } else {
                money += 3
            }
        }
        if Int.random(in: 0..<100, using: &rng) < rarity.techniqueChance,
           let technique = chestTechniques(in: state).randomElement(using: &rng) {
            state.flags.insert(Chests.techniqueFlag(technique.id))
            state.knownTechniques.insert(technique.id)
            state.equippedTechnique = technique.id
            loot.technique = technique.id
            loot.notes.append("Technique débloquée : \(technique.secret.name) !")
        }
        if Int.random(in: 0..<100, using: &rng) < rarity.crewChance,
           let card = Crew.cards(for: state.rapper.city).randomElement(using: &rng) {
            var crewOutcome = TurnOutcome(consequence: "")
            loot.crew = grantCrewCard(id: card.id, from: .chest, in: &state, outcome: &crewOutcome)
            loot.notes += crewOutcome.notes
        }
        loot.money = state.stats.apply([.argent: money])[.argent] ?? 0
        loot.xp = Int.random(in: rarity.xp, using: &rng)
        var outcome = TurnOutcome(consequence: "")
        ArtistLevel.gain(loot.xp, in: &state, outcome: &outcome)
        loot.notes += outcome.notes
        return loot
    }
}
