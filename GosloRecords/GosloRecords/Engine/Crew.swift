import Foundation

/// Crew cards: the rappers and beatmakers the player meets, collected like trading cards.
/// - A card is earned by beating them in a clash, finishing their quest or recording a feat with them.
///   Each duplicate is a fragment: 2 / 4 / 8 / 16 fragments take the card from level 1 to 5.
/// - Every source is already capped (`Gate`s, one action per clash, one single per period, a quest once),
///   and a clash pays at most one fragment per card per period: there's nothing to farm.
/// - A card in the active crew (3 slots, 4 from `ArtistLevel.Unlock.crew`) gives its perk, which grows gently
///   with its level. The perks plug into existing hooks: the Top, the clash gauge, the counter, the period's
///   upkeep and the buildings' income.
enum CrewRarity: String, Codable, CaseIterable, Comparable {
    case commun, rare, epique, legendaire

    var label: String {
        switch self {
        case .commun: "Commun"
        case .rare: "Rare"
        case .epique: "Épique"
        case .legendaire: "Légendaire"
        }
    }

    private var rank: Int { CrewRarity.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: CrewRarity, rhs: CrewRarity) -> Bool { lhs.rank < rhs.rank }
}

/// What a card does while it's in the active crew.
enum CrewPerk: Equatable {
    /// Singles featuring them pay more streams in the Top (percent).
    case featStreams
    /// The secret technique gauge starts a clash already charged (points).
    case clashMeter
    /// Extra taps counted when you counter a boss's technique.
    case counter
    /// A stat point or two at the end of every period.
    case perPeriod(StatKind)
    /// These buildings pay more (percent).
    case building([Decor])
}

/// One card of the collection, keyed by its cast id.
struct CrewCardSpec: Equatable, Identifiable {
    let id: String
    let rarity: CrewRarity
    /// Short name of the perk ("Parade chirurgicale").
    let perkName: String
    let perk: CrewPerk
    /// Quests whose completion gives the card.
    var quests: [String] = []
    /// Only collectable in these cities (nil: everywhere).
    var cities: [City]? = nil
}

/// A card earned (or a fragment), for the reveal and the consequence notes.
struct CrewGain: Equatable {
    let cardId: String
    let isNew: Bool
    let level: Int
    let leveledUp: Bool
    /// The new card took a free slot of the active crew.
    let joinedCrew: Bool
}

/// Where a card comes from: a clash is the only repeatable source, capped per card and per period.
enum CrewSource {
    case clash, quest, feat, chest
}

/// The player's collection (saved with the career).
struct CrewState: Codable, Equatable {
    /// Owned cards → fragments collected since the card was earned.
    var fragments: [String: Int] = [:]
    /// The active crew, in the order they joined.
    var active: [String] = []
    /// Turn of the last clash that paid each card (one fragment per card per period).
    var clashTurn: [String: Int] = [:]

    init(fragments: [String: Int] = [:], active: [String] = [], clashTurn: [String: Int] = [:]) {
        self.fragments = fragments
        self.active = active
        self.clashTurn = clashTurn
    }

    enum CodingKeys: String, CodingKey { case fragments, active, clashTurn }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fragments = try c.decodeIfPresent([String: Int].self, forKey: .fragments) ?? [:]
        active = try c.decodeIfPresent([String].self, forKey: .active) ?? []
        clashTurn = try c.decodeIfPresent([String: Int].self, forKey: .clashTurn) ?? [:]
    }

    func owns(_ id: String) -> Bool { fragments[id] != nil }
    func level(_ id: String) -> Int { Crew.level(fragments: fragments[id] ?? 0) }
    func isActive(_ id: String) -> Bool { active.contains(id) }

    /// A save from before the crew: the rivals already beaten, the quests already done and the feats already
    /// recorded give their cards (no fragments), and the best ones form the crew.
    static func retroactive(flags: Set<String>, completedQuests: Set<String>, feats: [String]) -> CrewState {
        var crew = CrewState()
        for spec in Crew.catalog {
            let earned = flags.contains("clash_gagne_\(spec.id)") || flags.contains("sauvage_battu_\(spec.id)")
                || spec.quests.contains(where: completedQuests.contains) || feats.contains(spec.id)
            if earned { crew.fragments[spec.id] = 0 }
        }
        crew.active = Crew.catalog.filter { crew.owns($0.id) }
            .sorted { $0.rarity > $1.rarity }
            .prefix(Crew.baseSlots).map(\.id)
        return crew
    }
}

enum Crew {
    /// Fragments needed for each next level (1→2, 2→3, 3→4, 4→5).
    static let fragmentsPerLevel = [2, 4, 8, 16]
    static var maxLevel: Int { fragmentsPerLevel.count + 1 }
    static let baseSlots = 3
    static let maxSlots = 4
    /// The perks of one stat, all cards together, stop here each period.
    static let periodCap = 4

    static func level(fragments: Int) -> Int {
        var level = 1, left = fragments
        for need in fragmentsPerLevel where left >= need {
            left -= need
            level += 1
        }
        return level
    }

    /// Fragments toward the next level: (have, need), nil at the top level.
    static func progress(fragments: Int) -> (have: Int, need: Int)? {
        var left = fragments
        for need in fragmentsPerLevel {
            if left < need { return (left, need) }
            left -= need
        }
        return nil
    }

    /// Total fragments for the top level (more are useless).
    static var maxFragments: Int { fragmentsPerLevel.reduce(0, +) }

    /// The perk's strength at a card level (percent or points, see `CrewPerk`).
    static func value(_ perk: CrewPerk, level: Int) -> Int {
        let index = min(max(level, 1), maxLevel) - 1
        switch perk {
        case .featStreams: return [20, 25, 30, 40, 50][index]
        case .clashMeter: return [5, 6, 8, 10, 12][index]
        case .counter: return [2, 3, 4, 5, 6][index]
        case .perPeriod: return [1, 1, 2, 2, 3][index]
        case .building: return [15, 20, 25, 30, 40][index]
        }
    }

    /// What the perk does at that level, for the card ("+20 % de streams sur vos feats").
    static func perkText(_ spec: CrewCardSpec, level: Int) -> String {
        let v = value(spec.perk, level: level)
        switch spec.perk {
        case .featStreams: return "+\(v) % de streams sur les singles en feat avec cette carte"
        case .clashMeter: return "Ta jauge de technique secrète démarre chaque clash à +\(v)"
        case .counter: return "+\(v) tapes comptées quand tu contres la technique d'un boss"
        case .perPeriod(let kind): return "+\(v) \(kind.label.lowercased()) à chaque fin de période"
        case .building(let decors):
            return "+\(v) % de revenus pour " + decors.map(\.shortName).joined(separator: " et ")
        }
    }

    // MARK: The collection

    static let catalog: [CrewCardSpec] = [
        // Légendaire: the story's big names.
        CrewCardSpec(id: "le_baron", rarity: .legendaire, perkName: "Story-troll", perk: .clashMeter, quests: ["trone"]),
        CrewCardSpec(id: "scalpel", rarity: .legendaire, perkName: "Parade chirurgicale", perk: .counter, quests: ["plume_or"]),
        CrewCardSpec(id: "le_conteur", rarity: .legendaire, perkName: "Diss en épisodes", perk: .perPeriod(.credibilite)),
        CrewCardSpec(id: "orphee", rarity: .legendaire, perkName: "Album surprise", perk: .featStreams),
        // Épique
        CrewCardSpec(id: "kolosse", rarity: .epique, perkName: "Mur du quartier", perk: .counter),
        CrewCardSpec(id: "kevlar_jr", rarity: .epique, perkName: "Champion de battle", perk: .clashMeter, quests: ["revenants"]),
        CrewCardSpec(id: "saphir", rarity: .epique, perkName: "Reine du freestyle", perk: .clashMeter),
        CrewCardSpec(id: "nitro_nina", rarity: .epique, perkName: "Drill à 200 à l'heure", perk: .featStreams),
        CrewCardSpec(id: "diva_decibel", rarity: .epique, perkName: "Refrain XXL", perk: .featStreams),
        CrewCardSpec(id: "algo_rythme", rarity: .epique, perkName: "L'algorithme t'aime", perk: .perPeriod(.streams)),
        // Rare
        CrewCardSpec(id: "lil_sauge", rarity: .rare, perkName: "Feat opportuniste", perk: .featStreams),
        CrewCardSpec(id: "ptit_sauge", rarity: .rare, perkName: "Petit frère vénère", perk: .clashMeter, quests: ["freres_sauge"]),
        CrewCardSpec(id: "madame_rature", rarity: .rare, perkName: "Correction au stylo rouge", perk: .counter),
        CrewCardSpec(id: "ptit_wifi", rarity: .rare, perkName: "Nouvelle génération", perk: .perPeriod(.streams)),
        CrewCardSpec(id: "big_kliks", rarity: .rare, perkName: "4 millions d'abonnés", perk: .perPeriod(.streams)),
        CrewCardSpec(id: "lingot", rarity: .rare, perkName: "Bling-bling", perk: .perPeriod(.argent)),
        CrewCardSpec(id: "lil_croon", rarity: .rare, perkName: "Autotune magique", perk: .featStreams),
        CrewCardSpec(id: "fred", rarity: .rare, perkName: "Ingé son du Bunker", perk: .building([.studioPerso]),
                     quests: ["premier_projet"]),
        CrewCardSpec(id: "petit_sami", rarity: .rare, perkName: "Prod sur un ordi qui chauffe",
                     perk: .building([.studioPerso, .labelInde]), quests: ["prod_sami", "gamin_dome"]),
        CrewCardSpec(id: "papy_groove", rarity: .rare, perkName: "Bacs à vinyles", perk: .building([.disquaire, .sono]),
                     quests: ["face_b_papy"]),
        CrewCardSpec(id: "dj_bobine", rarity: .rare, perkName: "Une seule platine, mais quelle platine",
                     perk: .building([.scenePleinAir, .radioPirate]), quests: ["grande_scene"]),
        CrewCardSpec(id: "zoe_bombe", rarity: .rare, perkName: "Bombe de peinture", perk: .building([.fresque, .fresqueGeante]),
                     quests: ["fresque_zoe"]),
        CrewCardSpec(id: "zanga", rarity: .rare, perkName: "La voix des petits taxis", perk: .perPeriod(.mental),
                     quests: ["defi_casablanca"], cities: [.casablanca]),
        // Commun: the Tournoi's rungs and the terrain vague's regulars.
        CrewCardSpec(id: "lil_karaoke", rarity: .commun, perkName: "Micro karaoké", perk: .perPeriod(.mental)),
        CrewCardSpec(id: "tonton_mixtape", rarity: .commun, perkName: "Mixtape 2003", perk: .perPeriod(.credibilite)),
        CrewCardSpec(id: "coach_burpee", rarity: .commun, perkName: "Échauffement", perk: .perPeriod(.mental)),
        CrewCardSpec(id: "maitre_objection", rarity: .commun, perkName: "Objection !", perk: .counter),
        CrewCardSpec(id: "npc_404", rarity: .commun, perkName: "Bug du système", perk: .clashMeter),
        CrewCardSpec(id: "le_sommelier", rarity: .commun, perkName: "Rimes millésimées", perk: .perPeriod(.credibilite)),
        CrewCardSpec(id: "la_duchesse", rarity: .commun, perkName: "Argent de famille", perk: .perPeriod(.argent)),
        CrewCardSpec(id: "beatmaker_relou", rarity: .commun, perkName: "Une prod de fou", perk: .building([.sono])),
        CrewCardSpec(id: "rappeur_soiree", rarity: .commun, perkName: "Freestyle de fin de soirée", perk: .perPeriod(.mental)),
    ]

    private static let index = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func spec(_ id: String) -> CrewCardSpec? { index[id] }

    /// The cards a career in this city can collect.
    static func cards(for city: City) -> [CrewCardSpec] {
        catalog.filter { $0.cities?.contains(city) ?? true }
    }

    // MARK: Perks

    /// The active crew's cards, with their level.
    static func active(in state: GameState) -> [(spec: CrewCardSpec, level: Int)] {
        state.crew.active.compactMap { id in spec(id).map { ($0, state.crew.level(id)) } }
    }

    static func meterBonus(in state: GameState) -> Int {
        active(in: state).filter { $0.spec.perk == .clashMeter }.reduce(0) { $0 + value(.clashMeter, level: $1.level) }
    }

    static func counterTaps(in state: GameState) -> Int {
        active(in: state).filter { $0.spec.perk == .counter }.reduce(0) { $0 + value(.counter, level: $1.level) }
    }

    /// Extra share of the streams a single featuring `feat` pays (0.2 = +20 %).
    static func featBonus(_ feat: String?, in state: GameState) -> Double {
        guard let feat, let card = active(in: state).first(where: { $0.spec.id == feat && $0.spec.perk == .featStreams }) else {
            return 0
        }
        return Double(value(.featStreams, level: card.level)) / 100
    }

    /// Extra share of a building's income (0.15 = +15 %).
    static func buildingBonus(_ decor: Decor, in state: GameState) -> Double {
        active(in: state).reduce(0) { total, card in
            guard case .building(let decors) = card.spec.perk, decors.contains(decor) else { return total }
            return total + Double(value(card.spec.perk, level: card.level)) / 100
        }
    }

    /// What the crew brings at the end of a period (each stat capped at `periodCap`).
    static func periodEffects(in state: GameState) -> [StatKind: Int] {
        var effects: [StatKind: Int] = [:]
        for card in active(in: state) {
            guard case .perPeriod(let kind) = card.spec.perk else { continue }
            effects[kind, default: 0] += value(card.spec.perk, level: card.level)
        }
        return effects.mapValues { min($0, periodCap) }
    }

    /// A gain bonus: at least +1 when there's a bonus at all.
    static func boosted(_ value: Int, by share: Double) -> Int {
        guard share > 0, value > 0 else { return value }
        return value + max(1, Int((Double(value) * share).rounded()))
    }
}

extension GameEngine {
    /// Slots of the active crew: 3, then 4 from `ArtistLevel.Unlock.crew`.
    func crewSlots(in state: GameState) -> Int {
        ArtistLevel.unlocks(.crew, in: state) ? Crew.maxSlots : Crew.baseSlots
    }

    /// Gives a card, or a fragment if it's already owned. For outside sources (victory chests…): uncapped.
    @discardableResult
    func grantCrewCard(id: String, in state: inout GameState) -> CrewGain? {
        var outcome = TurnOutcome(consequence: "")
        return grantCrewCard(id: id, from: .chest, in: &state, outcome: &outcome)
    }

    /// Gives a card (or a fragment) and writes it in the outcome. A clash pays one fragment per card per period.
    @discardableResult
    func grantCrewCard(id: String, from source: CrewSource, in state: inout GameState, outcome: inout TurnOutcome) -> CrewGain? {
        guard let spec = Crew.spec(id), spec.cities?.contains(state.rapper.city) ?? true else { return nil }
        let name = castMember(id)?.name ?? id
        if source == .clash {
            if state.crew.owns(id), state.crew.clashTurn[id] == state.turn { return nil }
            state.crew.clashTurn[id] = state.turn
        }
        guard let fragments = state.crew.fragments[id] else {
            state.crew.fragments[id] = 0
            let joins = state.crew.active.count < crewSlots(in: state)
            if joins { state.crew.active.append(id) }
            let gain = CrewGain(cardId: id, isNew: true, level: 1, leveledUp: false, joinedCrew: joins)
            outcome.crewCards.append(gain)
            outcome.notes.append("NOUVELLE CARTE : \(name) (\(spec.rarity.label))" + (joins ? ", dans ton crew !" : " ! Place-la dans ton crew depuis le carnet."))
            return gain
        }
        guard fragments < Crew.maxFragments else { return nil }
        let before = Crew.level(fragments: fragments)
        state.crew.fragments[id] = fragments + 1
        let after = Crew.level(fragments: fragments + 1)
        let gain = CrewGain(cardId: id, isNew: false, level: after, leveledUp: after > before, joinedCrew: false)
        outcome.crewCards.append(gain)
        if gain.leveledUp {
            outcome.notes.append("Carte \(name) : NIVEAU \(after) ! \(Crew.perkText(spec, level: after)).")
        } else if let progress = Crew.progress(fragments: fragments + 1) {
            outcome.notes.append("Carte \(name) : +1 fragment (\(progress.have)/\(progress.need)).")
        }
        return gain
    }

    /// Why this card can't join the active crew now (nil: it can).
    func crewJoinRefusal(_ id: String, in state: GameState) -> String? {
        guard state.crew.owns(id) else { return "Carte pas encore gagnée" }
        if state.crew.isActive(id) { return nil }
        let slots = crewSlots(in: state)
        if state.crew.active.count >= slots {
            return slots < Crew.maxSlots ? "Crew complet (4e place au niveau \(ArtistLevel.Unlock.crew.level))" : "Crew complet"
        }
        return nil
    }

    /// Puts a card in the active crew, or takes it out. Returns false if nothing changed.
    @discardableResult
    func setCrewMember(_ id: String, active: Bool, in state: inout GameState) -> Bool {
        if !active {
            guard state.crew.isActive(id) else { return false }
            state.crew.active.removeAll { $0 == id }
            return true
        }
        guard !state.crew.isActive(id), crewJoinRefusal(id, in: state) == nil else { return false }
        state.crew.active.append(id)
        return true
    }

    /// Cards for the quests just completed.
    func grantQuestCards(_ quest: Quest, in state: inout GameState, outcome: inout TurnOutcome) {
        for spec in Crew.catalog where spec.quests.contains(quest.id) {
            grantCrewCard(id: spec.id, from: .quest, in: &state, outcome: &outcome)
        }
    }
}
