import Foundation

/// Raids, Clash of Clans style: a building left full (its money at the cap) for a whole period tempts a rival.
/// At the end of a period they may tag it or break in: half of what it held goes with them, and the building
/// earns nothing until the player walks up and beats them in a clash. Everything is decided at period end,
/// from the save and a generator seeded with the career and the turn (no clock, no server).

/// What the rival did to the building.
enum RaidKind: String, Codable, CaseIterable {
    /// Graffiti all over the front.
    case tag
    /// A broken window, the till emptied.
    case braquage

    /// "a tagué", "a braqué".
    var verb: String {
        switch self {
        case .tag: "a tagué"
        case .braquage: "a braqué"
        }
    }

    /// For the map and the building's card.
    var label: String {
        switch self {
        case .tag: "TAGUÉ"
        case .braquage: "BRAQUÉ"
        }
    }

    /// What the rival says when you walk up to them.
    var taunt: String {
        switch self {
        case .tag: "Joli mur. Il manquait juste ma signature. Tu veux ton argent ? Viens le chercher au micro."
        case .braquage: "Ta caisse ? Je l'ai mise à l'abri. Tu la veux ? Bats-moi, devant tout le monde."
        }
    }
}

/// A rival holding one of the player's buildings (at most one at a time).
struct Raid: Codable, Equatable {
    /// `PlacedDecor.id` of the building hit.
    let buildingId: Int
    let district: District
    /// Cast id of the rival.
    let rival: String
    let kind: RaidKind
    /// Money taken from the building, held until the clash.
    let stolen: Int
    /// Where the rival stands, next to the building (nil: no free tile around it; the building's card still
    /// lets you challenge them).
    let spot: TilePoint?
    /// Periods it has lasted so far: at `Raids.duration` the rival leaves with the money.
    var periods: Int = 0

    init(buildingId: Int, district: District, rival: String, kind: RaidKind, stolen: Int, spot: TilePoint?, periods: Int = 0) {
        self.buildingId = buildingId
        self.district = district
        self.rival = rival
        self.kind = kind
        self.stolen = stolen
        self.spot = spot
        self.periods = periods
    }

    private enum CodingKeys: String, CodingKey { case buildingId, district, rival, kind, stolen, spot, periods }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        buildingId = try c.decode(Int.self, forKey: .buildingId)
        district = try c.decodeIfPresent(District.self, forKey: .district) ?? .bloc
        rival = try c.decode(String.self, forKey: .rival)
        kind = try c.decodeIfPresent(RaidKind.self, forKey: .kind) ?? .tag
        stolen = try c.decodeIfPresent(Int.self, forKey: .stolen) ?? 0
        spot = try c.decodeIfPresent(TilePoint.self, forKey: .spot)
        periods = try c.decodeIfPresent(Int.self, forKey: .periods) ?? 0
    }

    /// Periods left before the rival leaves with the money.
    var periodsLeft: Int { max(0, Raids.duration - periods) }
}

enum Raids {
    /// No raid before this artist level.
    static let minLevel = 3
    /// Periods a raid lasts if the player never shows up.
    static let duration = 3
    /// Periods of calm after a raid ends (won, lost or timed out) before the next one.
    static let cooldown = 2
    /// Chance per full building and per period: low with one building, a bit higher with a bigger neighbourhood.
    static let baseChance = 0.06
    static let chancePerBuilding = 0.02
    static let maxChance = 0.2
    /// Each defence in the district (a boxing gym, a surveillance camera) halves it.
    static let defenceFactor = 0.5
    /// A won raid clash pays back the stolen money plus this small bonus (a quarter of it, 1 to `maxBonus`).
    static let maxBonus = 4
    /// Marks a raid clash (`ClashSpec.win.setFlags`); never stored in `GameState.flags`.
    static let clashFlag = "raid_repousse"
    /// Story bosses who don't do street jobs.
    static let excludedRivals: Set<String> = ["le_baron"]

    static func bonus(stolen: Int) -> Int { min(maxBonus, max(1, stolen / 4)) }

    /// "le snack" → "ton snack", "la salle de boxe" → "ta salle de boxe".
    static func possessive(_ shortName: String) -> String {
        if shortName.hasPrefix("le ") { return "ton " + shortName.dropFirst(3) }
        if shortName.hasPrefix("la ") { return "ta " + shortName.dropFirst(3) }
        return shortName
    }

    static func capitalized(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }
}

extension GameEngine {
    // MARK: Who and where

    /// Rivals who can raid: met, clashable, from the story's cast (not the terrain vague's passers-by, not the
    /// Tournoi's bosses).
    func raidRivals(in state: GameState) -> [CastMember] {
        let bosses = Set(story.tournament.map(\.opponent))
        return world.cast.filter { member in
            member.clash != nil && !member.wild && member.cities == nil && state.metCast.contains(member.id)
                && !bosses.contains(member.id) && !Raids.excludedRivals.contains(member.id)
        }.sorted { $0.id < $1.id }
    }

    /// The building a raid holds, if any.
    func raidedBuilding(in state: GameState) -> PlacedDecor? {
        state.raid.flatMap { raid in state.placed.first { $0.id == raid.buildingId } }
    }

    func isRaided(_ id: Int, in state: GameState) -> Bool { state.raid?.buildingId == id }

    /// The rival standing on this tile of the current district, if any.
    func raidRival(at point: TilePoint, in state: GameState) -> Raid? {
        guard let raid = state.raid, raid.district == state.district, raid.spot == point else { return nil }
        return raid
    }

    /// Buildings full for the whole period that is ending (their money at the cap before this period's income).
    func fullBuildings(in state: GameState) -> Set<Int> {
        Set(state.placed.filter { item in
            let cap = income(of: item, in: state).storageCap
            return cap > 0 && item.stored >= cap && !isRaided(item.id, in: state)
        }.map(\.id))
    }

    /// Chance that a rival raids this building at the end of the period (if it's been left full).
    func raidChance(for item: PlacedDecor, in state: GameState) -> Double {
        guard ArtistLevel.level(xp: state.artistXP) >= Raids.minLevel else { return 0 }
        let buildings = state.placed.filter(\.decor.isBuilding).count
        var chance = min(Raids.maxChance, Raids.baseChance + Raids.chancePerBuilding * Double(max(0, buildings - 1)))
        let around = state.placed.filter { $0.district == item.district }.map(\.decor)
        if around.contains(.salleBoxe) { chance *= Raids.defenceFactor }
        if around.contains(.camera) { chance *= Raids.defenceFactor }
        return chance
    }

    /// Why no raid can start at this period's end (nil: one may).
    func raidBlocker(in state: GameState) -> String? {
        if ArtistLevel.level(xp: state.artistXP) < Raids.minLevel { return "niveau" }
        if state.raid != nil { return "raid en cours" }
        if let ended = state.raidEndedTurn, state.turn - ended < Raids.cooldown { return "calme" }
        if raidRivals(in: state).isEmpty { return "aucun rival" }
        return nil
    }

    /// A free tile next to the building where the rival can stand without cutting any way through.
    func raidSpot(for item: PlacedDecor, in state: GameState) -> TilePoint? {
        guard let map = world.map(for: item.district)?.forChapter(state.chapter, flags: state.flags,
                                                                  level: ArtistLevel.level(xp: state.artistXP)) else { return nil }
        let size = item.decor.footprint
        let top = item.y - size.height + 1
        // Below first (in front of it, where the player walks up), then the sides, then behind.
        var candidates = (item.x..<(item.x + size.width)).map { TilePoint(x: $0, y: item.y + 1) }
        candidates += (top...item.y).reversed().flatMap { [TilePoint(x: item.x - 1, y: $0), TilePoint(x: item.x + size.width, y: $0)] }
        candidates += (item.x..<(item.x + size.width)).map { TilePoint(x: $0, y: top - 1) }
        let taken = decorTiles(in: item.district, state: state)
        let plotted = Set(map.decorPlots.filter { state.decor[$0.id] != nil }.map(\.point))
        let blocking = decorTiles(in: item.district, state: state, blockingOnly: true)
        let player = state.district == item.district ? state.position : nil
        for tile in candidates {
            guard map.tile(at: tile).isWalkable, map.tile(at: tile) != .door, map.tile(at: tile) != .metro,
                  map.door(at: tile) == nil, map.metro != tile, map.npc(at: tile) == nil,
                  tile != map.spawn, tile != map.arrival, tile != player,
                  !taken.contains(tile), !plotted.contains(tile) else { continue }
            if state.rapper.city == .casablanca, item.district == .bloc, OverworldRules.blockedByScenery(tile, in: .casablanca) { continue }
            if keepsEverythingReachable(on: map, blocked: blocking.union([tile]), from: map.arrival) { return tile }
        }
        return nil
    }

    // MARK: Period end

    /// End of a period (called by `finishAction`, after the buildings paid): an ongoing raid ticks (the rival
    /// leaves after `Raids.duration` periods), or a rival may hit one of the buildings that sat full all period.
    /// Returns the lines to show.
    func raidsAtPeriodEnd(wasFull: Set<Int>, in state: inout GameState) -> [String] {
        if var raid = state.raid {
            guard let item = state.placed.first(where: { $0.id == raid.buildingId }) else {
                state.raid = nil
                return []
            }
            raid.periods += 1
            guard raid.periods >= Raids.duration else {
                state.raid = raid
                return []
            }
            state.raid = nil
            state.raidEndedTurn = state.turn
            let name = castMember(raid.rival)?.name ?? "Le rival"
            let building = Raids.possessive(item.decor.shortName)
            return ["\(name) en a eu marre d'attendre et a filé avec les \(raid.stolen) d'argent. \(Raids.capitalized(building)) rouvre."]
        }
        guard raidBlocker(in: state) == nil, let raid = rollRaid(among: wasFull, in: state),
              let index = state.placed.firstIndex(where: { $0.id == raid.buildingId }) else { return [] }
        state.placed[index].stored -= raid.stolen
        state.raid = raid
        let name = castMember(raid.rival)?.name ?? "Un rival"
        let building = Raids.possessive(state.placed[index].decor.shortName)
        return ["\(name) \(raid.kind.verb) \(building) (\(raid.district.name)) et garde \(raid.stolen) d'argent. "
                + "Va lui régler son compte : tu as \(Raids.duration) périodes."]
    }

    /// The raid this period's end brings, if any: one roll per building left full (the fullest first),
    /// from a generator seeded with the career and the turn, so the same save always gives the same answer.
    func rollRaid(among wasFull: Set<Int>, in state: GameState) -> Raid? {
        let rivals = raidRivals(in: state)
        guard !rivals.isEmpty else { return nil }
        var rng = SeededGenerator(seed: GameEngine.fnv("raid|\(state.id.uuidString)|\(state.turn)"))
        let targets = state.placed.filter { wasFull.contains($0.id) && $0.stored >= 2 }
            .sorted { ($0.stored, -$0.id) > ($1.stored, -$1.id) }
        for item in targets {
            let roll = Double.random(in: 0..<1, using: &rng)
            guard roll < raidChance(for: item, in: state) else { continue }
            let rival = rivals[Int.random(in: 0..<rivals.count, using: &rng)]
            let kind = RaidKind.allCases[Int.random(in: 0..<RaidKind.allCases.count, using: &rng)]
            return Raid(buildingId: item.id, district: item.district, rival: rival.id, kind: kind,
                        stolen: item.stored / 2, spot: raidSpot(for: item, in: state))
        }
        return nil
    }

    // MARK: The clash

    /// Why the player can't challenge the raider now (nil: they can).
    func raidClashRefusal(in state: GameState) -> String? {
        guard let raid = state.raid, raidedBuilding(in: state) != nil else { return "Personne à défier" }
        guard castMember(raid.rival)?.clash != nil else { return "Personne à défier" }
        if state.isOver || state.clash != nil || state.currentEventId != nil || state.pendingFollowUp != nil {
            return "Pas maintenant"
        }
        if state.district != raid.district { return "Va dans \(raid.district.name)" }
        return nil
    }

    /// Challenges the raider (no action spent: you're defending your own). `finishClash` settles the raid.
    func startRaidClash(in state: inout GameState) throws -> ClashState {
        guard raidClashRefusal(in: state) == nil, let raid = state.raid else { throw GameEngineError.requirementNotMet }
        let name = castMember(raid.rival)?.name ?? "Le rival"
        let spec = ClashSpec(
            opponent: raid.rival,
            win: ClashResultSpec(consequence: "\(name) rend l'argent et file s'acheter un seau d'eau.",
                                 setFlags: [Raids.clashFlag]),
            lose: ClashResultSpec(consequence: "\(name) repart avec l'argent sous le bras.")
        )
        var clash = ClashState(spec: spec)
        clash.playerMeter = startingMeter(in: state)
        clash.crowdFavorite = ClashTactics.crowdFavorite(in: state.district)
        state.clash = clash
        return clash
    }

    func isRaidClash(_ clash: ClashState) -> Bool { clash.spec.win.setFlags.contains(Raids.clashFlag) }

    /// Settles a raid clash. Won: the stolen money back plus a small bonus. Lost: the money is gone.
    /// Either way the building is cleaned and earns again. No time passes, nothing else is paid.
    func finishRaidClash(_ clash: ClashState, in state: inout GameState) -> TurnOutcome {
        let won = clash.playerWon
        var outcome = TurnOutcome(consequence: won ? clash.spec.win.consequence : clash.spec.lose.consequence)
        outcome.clash = clash
        state.clash = nil
        guard let raid = state.raid else { return outcome }
        let building = raidedBuilding(in: state).map { Raids.possessive($0.decor.shortName) } ?? "ton bâtiment"
        if won {
            let bonus = Raids.bonus(stolen: raid.stolen)
            outcome.add(state.stats.apply([.argent: raid.stolen + bonus]))
            outcome.notes.append("Tu récupères \(raid.stolen) d'argent, +\(bonus) de dédommagement. "
                                 + "\(Raids.capitalized(building)) est nickel : le quartier a vu qui commande ici.")
        } else {
            outcome.notes.append("Les \(raid.stolen) d'argent sont perdus. Au moins, le nettoyage est fait : \(building) rouvre.")
        }
        let amount = won ? GameEngine.wildXP.win : GameEngine.wildXP.lose
        outcome.add(levelUps: state.skills.gain(Dictionary(uniqueKeysWithValues: clash.movesUsed.map { ($0.skill, amount) })))
        state.raid = nil
        state.raidEndedTurn = state.turn
        applyQuestProgress(&outcome, in: &state)
        applyStoryProgress(&outcome, in: &state)
        checkChallenges(&outcome, in: &state)
        state.ending = EndingResolver.prematureEnding(for: state.stats)
        outcome.ending = state.ending
        return outcome
    }

    /// The raid as a goal for the period briefing ("Lil Sauge a tagué ton snack : va lui régler son compte").
    func raidObjective(in state: GameState) -> String? {
        guard let raid = state.raid, let item = raidedBuilding(in: state) else { return nil }
        let name = castMember(raid.rival)?.name ?? "Un rival"
        let left = raid.periodsLeft
        return "\(name) \(raid.kind.verb) \(Raids.possessive(item.decor.shortName)) : va lui régler son compte "
            + "(\(raid.district.name), encore \(left) période\(left > 1 ? "s" : ""))"
    }
}
