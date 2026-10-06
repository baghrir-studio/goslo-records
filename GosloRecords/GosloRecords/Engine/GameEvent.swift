import Foundation

/// An event as described in events.json. Optional fields fall back to defaults,
/// so a minimal event only needs id, title, text, location and choices.
struct GameEvent: Codable, Equatable, Identifiable {
    static let defaultWeight = 10

    let id: String
    let title: String
    let text: String
    /// Where the event can happen. nil = follow-up only (weight 0).
    let location: Location?
    /// Character the event features (id from cast.json), shown on the map.
    let npc: String?
    /// Relative draw weight. 0 = never drawn at random (follow-up only).
    let weight: Int
    /// A unique event can happen only once per career.
    let unique: Bool
    let conditions: EventConditions
    let choices: [EventChoice]
    /// Sound played when the card shows up (a SoundEffect name, e.g. "ringtone" for a phone call).
    let sound: String?

    init(id: String, title: String, text: String, location: Location? = nil, npc: String? = nil,
         weight: Int = defaultWeight, unique: Bool = false,
         conditions: EventConditions = EventConditions(), choices: [EventChoice], sound: String? = nil) {
        self.id = id
        self.title = title
        self.text = text
        self.location = location
        self.npc = npc
        self.weight = weight
        self.unique = unique
        self.conditions = conditions
        self.choices = choices
        self.sound = sound
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        text = try c.decode(String.self, forKey: .text)
        location = try c.decodeIfPresent(Location.self, forKey: .location)
        npc = try c.decodeIfPresent(String.self, forKey: .npc)
        weight = try c.decodeIfPresent(Int.self, forKey: .weight) ?? GameEvent.defaultWeight
        unique = try c.decodeIfPresent(Bool.self, forKey: .unique) ?? false
        conditions = try c.decodeIfPresent(EventConditions.self, forKey: .conditions) ?? EventConditions()
        choices = try c.decode([EventChoice].self, forKey: .choices)
        sound = try c.decodeIfPresent(String.self, forKey: .sound)
    }
}

struct EventConditions: Codable, Equatable {
    var minYear: Int?
    var maxYear: Int?
    var requiredFlags: [String] = []
    var excludedFlags: [String] = []
    var minStats: [StatKind: Int] = [:]
    var maxStats: [StatKind: Int] = [:]
    var minCounters: [CounterKind: Int] = [:]
    /// Minimum skill levels (1–10).
    var minSkills: [Skill: Int] = [:]
    /// Relationship thresholds with characters (0–100), keyed by cast id.
    var minRelations: [String: Int] = [:]
    var maxRelations: [String: Int] = [:]
    /// Story chapter bounds (inclusive).
    var minChapter: Int?
    var maxChapter: Int?

    enum CodingKeys: String, CodingKey {
        case minYear = "min_year"
        case maxYear = "max_year"
        case requiredFlags = "required_flags"
        case excludedFlags = "excluded_flags"
        case minStats = "min_stats"
        case maxStats = "max_stats"
        case minCounters = "min_counters"
        case minSkills = "min_skills"
        case minRelations = "min_relations"
        case maxRelations = "max_relations"
        case minChapter = "min_chapter"
        case maxChapter = "max_chapter"
    }

    init(minYear: Int? = nil, maxYear: Int? = nil, requiredFlags: [String] = [], excludedFlags: [String] = [],
         minStats: [StatKind: Int] = [:], maxStats: [StatKind: Int] = [:], minCounters: [CounterKind: Int] = [:],
         minSkills: [Skill: Int] = [:], minRelations: [String: Int] = [:], maxRelations: [String: Int] = [:],
         minChapter: Int? = nil, maxChapter: Int? = nil) {
        self.minYear = minYear
        self.maxYear = maxYear
        self.requiredFlags = requiredFlags
        self.excludedFlags = excludedFlags
        self.minStats = minStats
        self.maxStats = maxStats
        self.minCounters = minCounters
        self.minSkills = minSkills
        self.minRelations = minRelations
        self.maxRelations = maxRelations
        self.minChapter = minChapter
        self.maxChapter = maxChapter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minYear = try c.decodeIfPresent(Int.self, forKey: .minYear)
        maxYear = try c.decodeIfPresent(Int.self, forKey: .maxYear)
        requiredFlags = try c.decodeIfPresent([String].self, forKey: .requiredFlags) ?? []
        excludedFlags = try c.decodeIfPresent([String].self, forKey: .excludedFlags) ?? []
        minStats = try c.decodeIfPresent([StatKind: Int].self, forKey: .minStats) ?? [:]
        maxStats = try c.decodeIfPresent([StatKind: Int].self, forKey: .maxStats) ?? [:]
        minCounters = try c.decodeIfPresent([CounterKind: Int].self, forKey: .minCounters) ?? [:]
        minSkills = try c.decodeIfPresent([Skill: Int].self, forKey: .minSkills) ?? [:]
        minRelations = try c.decodeIfPresent([String: Int].self, forKey: .minRelations) ?? [:]
        maxRelations = try c.decodeIfPresent([String: Int].self, forKey: .maxRelations) ?? [:]
        minChapter = try c.decodeIfPresent(Int.self, forKey: .minChapter)
        maxChapter = try c.decodeIfPresent(Int.self, forKey: .maxChapter)
    }

    /// All bounds are inclusive.
    func isSatisfied(by state: GameState) -> Bool {
        if let minYear, state.year < minYear { return false }
        if let maxYear, state.year > maxYear { return false }
        if let minChapter, state.chapter < minChapter { return false }
        if let maxChapter, state.chapter > maxChapter { return false }
        if !requiredFlags.allSatisfy(state.flags.contains) { return false }
        if excludedFlags.contains(where: state.flags.contains) { return false }
        if minStats.contains(where: { state.stats[$0.key] < $0.value }) { return false }
        if maxStats.contains(where: { state.stats[$0.key] > $0.value }) { return false }
        if minCounters.contains(where: { state.counters[$0.key] < $0.value }) { return false }
        if minSkills.contains(where: { state.skills.level($0.key) < $0.value }) { return false }
        if minRelations.contains(where: { state.relation($0.key) < $0.value }) { return false }
        if maxRelations.contains(where: { state.relation($0.key) > $0.value }) { return false }
        return true
    }

    /// Cast ids referenced (used to validate the data).
    var referencedCast: Set<String> {
        Set(minRelations.keys).union(maxRelations.keys)
    }
}

/// Requirement for picking a choice. The choice is still shown, but locked.
struct ChoiceRequirement: Codable, Equatable {
    var skills: [Skill: Int] = [:]
    var relations: [String: Int] = [:]
    var stats: [StatKind: Int] = [:]

    init(skills: [Skill: Int] = [:], relations: [String: Int] = [:], stats: [StatKind: Int] = [:]) {
        self.skills = skills
        self.relations = relations
        self.stats = stats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skills = try c.decodeIfPresent([Skill: Int].self, forKey: .skills) ?? [:]
        relations = try c.decodeIfPresent([String: Int].self, forKey: .relations) ?? [:]
        stats = try c.decodeIfPresent([StatKind: Int].self, forKey: .stats) ?? [:]
    }

    func isMet(by state: GameState) -> Bool {
        skills.allSatisfy { state.skills.level($0.key) >= $0.value }
            && relations.allSatisfy { state.relation($0.key) >= $0.value }
            && stats.allSatisfy { state.stats[$0.key] >= $0.value }
    }
}

struct EventChoice: Codable, Equatable {
    let label: String
    let effects: [StatKind: Int]
    let setFlags: [String]
    let clearFlags: [String]
    let counters: [CounterKind: Int]
    /// Skill XP gained.
    let xp: [Skill: Int]
    /// Relationship changes, keyed by cast id.
    let relations: [String: Int]
    let requires: ChoiceRequirement?
    /// Starts a turn-based clash after the choice.
    let clash: ClashSpec?
    /// Starts an interview (id from story.json) after the choice.
    let interview: String?
    /// Items (ids from story.json) received.
    let giveItems: [String]
    /// Starts a concert (id from story.json) after the choice.
    let concert: String?
    /// Starts a negotiation (id from story.json) after the choice.
    let negotiation: String?
    /// Starts a writing session (id from story.json) after the choice.
    let writing: String?
    let consequence: String
    /// Id of an event shown right after this choice (costs no action).
    let followUp: String?
    /// Extra semesters skipped (e.g. a hiatus). 0 = normal turn.
    let skipTurns: Int
    /// Starts a mini-game (id from story.json "minigames") after the choice.
    let minigame: String?

    enum CodingKeys: String, CodingKey {
        case label, effects, counters, consequence, xp, relations, requires, clash, interview, concert, negotiation, writing
        case minigame
        case setFlags = "set_flags"
        case clearFlags = "clear_flags"
        case giveItems = "give_items"
        case followUp = "follow_up"
        case skipTurns = "skip_turns"
    }

    init(label: String, effects: [StatKind: Int] = [:], setFlags: [String] = [], clearFlags: [String] = [],
         counters: [CounterKind: Int] = [:], xp: [Skill: Int] = [:], relations: [String: Int] = [:],
         requires: ChoiceRequirement? = nil, clash: ClashSpec? = nil, interview: String? = nil,
         giveItems: [String] = [], concert: String? = nil, negotiation: String? = nil, writing: String? = nil, consequence: String, followUp: String? = nil,
         skipTurns: Int = 0, minigame: String? = nil) {
        self.label = label
        self.effects = effects
        self.setFlags = setFlags
        self.clearFlags = clearFlags
        self.counters = counters
        self.xp = xp
        self.relations = relations
        self.requires = requires
        self.clash = clash
        self.interview = interview
        self.giveItems = giveItems
        self.concert = concert
        self.negotiation = negotiation
        self.writing = writing
        self.consequence = consequence
        self.followUp = followUp
        self.skipTurns = skipTurns
        self.minigame = minigame
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        effects = try c.decodeIfPresent([StatKind: Int].self, forKey: .effects) ?? [:]
        setFlags = try c.decodeIfPresent([String].self, forKey: .setFlags) ?? []
        clearFlags = try c.decodeIfPresent([String].self, forKey: .clearFlags) ?? []
        counters = try c.decodeIfPresent([CounterKind: Int].self, forKey: .counters) ?? [:]
        xp = try c.decodeIfPresent([Skill: Int].self, forKey: .xp) ?? [:]
        relations = try c.decodeIfPresent([String: Int].self, forKey: .relations) ?? [:]
        requires = try c.decodeIfPresent(ChoiceRequirement.self, forKey: .requires)
        clash = try c.decodeIfPresent(ClashSpec.self, forKey: .clash)
        interview = try c.decodeIfPresent(String.self, forKey: .interview)
        giveItems = try c.decodeIfPresent([String].self, forKey: .giveItems) ?? []
        concert = try c.decodeIfPresent(String.self, forKey: .concert)
        negotiation = try c.decodeIfPresent(String.self, forKey: .negotiation)
        writing = try c.decodeIfPresent(String.self, forKey: .writing)
        consequence = try c.decode(String.self, forKey: .consequence)
        followUp = try c.decodeIfPresent(String.self, forKey: .followUp)
        skipTurns = max(0, try c.decodeIfPresent(Int.self, forKey: .skipTurns) ?? 0)
        minigame = try c.decodeIfPresent(String.self, forKey: .minigame)
    }

    func isAvailable(in state: GameState) -> Bool {
        requires?.isMet(by: state) ?? true
    }

    /// Cast ids referenced (used to validate the data).
    var referencedCast: Set<String> {
        var ids = Set(relations.keys)
        if let requires { ids.formUnion(requires.relations.keys) }
        if let clash { ids.insert(clash.opponent) }
        return ids
    }
}

/// Fills `{nom}` and `{ville}` placeholders in event text.
enum TextTemplate {
    static func render(_ text: String, for rapper: Rapper) -> String {
        text.replacingOccurrences(of: "{nom}", with: rapper.name)
            .replacingOccurrences(of: "{ville}", with: rapper.city.rawValue)
    }
}
