import Foundation

/// Places on the map. Raw values are the keys used in events.json.
enum Location: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case studio
    case label
    case media
    case quartier
    case reseaux
    case scene
    case chezToi = "chez_toi"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .studio: "Le Bunker"
        case .label: "goslo records"
        case .media: "goslo radio"
        case .quartier: "Le quartier"
        case .reseaux: "Ton téléphone"
        case .scene: "La scène"
        case .chezToi: "Chez toi"
        }
    }

    var kind: String {
        switch self {
        case .studio: "Studio"
        case .label: "Label"
        case .media: "Médias"
        case .quartier: "La rue"
        case .reseaux: "Réseaux"
        case .scene: "Concerts"
        case .chezToi: "Repos"
        }
    }

    /// XP earned just by going there.
    var visitXP: [Skill: Int] {
        switch self {
        case .studio: [.flow: 20]
        case .label: [.business: 20]
        case .media: [.business: 10, .plume: 10]
        case .quartier: [.plume: 15, .scene: 5]
        case .reseaux: [.business: 15, .flow: 5]
        case .scene: [.scene: 25]
        case .chezToi: [.plume: 20]
        }
    }

    /// Unlock condition (nil = always open).
    var unlock: EventConditions? {
        switch self {
        case .scene: EventConditions(minCounters: [.projets: 1])
        case .label: EventConditions(minChapter: 2)
        default: nil
        }
    }

    var lockedHint: String {
        switch self {
        case .scene: "Sors un projet pour qu'on te programme."
        case .label: "La laverie est fermée. Un mot sur la porte : « De retour bientôt. — Momo »"
        default: ""
        }
    }
}

/// A recurring character (cast.json). Every character is fictional.
struct CastMember: Codable, Equatable, Identifiable {
    static let defaultRelation = 50

    let id: String
    let name: String
    let role: String
    let bio: String
    let startRelation: Int
    /// nil = this character can't be clashed.
    let clash: ClashProfile?
    /// Random opponent in the terrain vague (not shown in the contacts).
    let wild: Bool
    let look: CharacterLook
    /// Secret technique in a clash (a generic one if missing).
    let secret: SecretTechnique?
    /// Small talk once they have nothing new to say (they take turns, see `GameEngine.smallTalk`).
    let idle: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, role, bio, clash, wild, look, secret, idle
        case startRelation = "start_relation"
    }

    init(id: String, name: String, role: String, bio: String = "", startRelation: Int = defaultRelation,
         clash: ClashProfile? = nil, wild: Bool = false, look: CharacterLook = CharacterLook(),
         secret: SecretTechnique? = nil, idle: [String] = []) {
        self.idle = idle
        self.id = id
        self.name = name
        self.role = role
        self.bio = bio
        self.startRelation = startRelation
        self.clash = clash
        self.wild = wild
        self.look = look
        self.secret = secret
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        role = try c.decode(String.self, forKey: .role)
        bio = try c.decodeIfPresent(String.self, forKey: .bio) ?? ""
        startRelation = try c.decodeIfPresent(Int.self, forKey: .startRelation) ?? CastMember.defaultRelation
        clash = try c.decodeIfPresent(ClashProfile.self, forKey: .clash)
        wild = try c.decodeIfPresent(Bool.self, forKey: .wild) ?? false
        look = try c.decodeIfPresent(CharacterLook.self, forKey: .look) ?? CharacterLook()
        secret = try c.decodeIfPresent(SecretTechnique.self, forKey: .secret)
        idle = try c.decodeIfPresent([String].self, forKey: .idle) ?? []
    }
}

/// An opponent's clash profile. Stats run 1–10, like the player's levels.
/// How the player counters a boss's secret technique.
enum CounterStyle: String, Codable {
    /// Tap as fast as you can.
    case mash
    /// Scalpel: tap the words marked in red, avoid the others.
    case pen
    /// Tap when the ring lands on the beat.
    case beat
}

struct ClashProfile: Codable, Equatable {
    let stats: [ClashMove: Int]
    let weakness: ClashMove?
    let resistance: ClashMove?
    let taunts: [String]
    let counter: CounterStyle

    init(stats: [ClashMove: Int], weakness: ClashMove? = nil, resistance: ClashMove? = nil, taunts: [String] = [],
         counter: CounterStyle = .mash) {
        self.stats = stats
        self.weakness = weakness
        self.resistance = resistance
        self.taunts = taunts
        self.counter = counter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stats = try c.decode([ClashMove: Int].self, forKey: .stats)
        weakness = try c.decodeIfPresent(ClashMove.self, forKey: .weakness)
        resistance = try c.decodeIfPresent(ClashMove.self, forKey: .resistance)
        taunts = try c.decodeIfPresent([String].self, forKey: .taunts) ?? []
        counter = try c.decodeIfPresent(CounterStyle.self, forKey: .counter) ?? .mash
    }

    func stat(_ move: ClashMove) -> Int {
        min(max(stats[move, default: 1], 1), 10)
    }

    /// Displayed level: average of the stats.
    var level: Int {
        let total = ClashMove.allCases.map(stat).reduce(0, +)
        return max(1, Int((Double(total) / Double(ClashMove.allCases.count)).rounded()))
    }

    /// Profile boosted by `bonus` points (wild opponents get stronger over the years).
    func scaled(by bonus: Int) -> ClashProfile {
        guard bonus > 0 else { return self }
        return ClashProfile(stats: Dictionary(uniqueKeysWithValues: ClashMove.allCases.map { ($0, min(10, stat($0) + bonus)) }),
                            weakness: weakness, resistance: resistance, taunts: taunts)
    }
}

/// A quest (quests.json): ordered steps, each one validated by conditions.
struct Quest: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    /// Availability: the quest only shows up in the journal once these hold.
    let conditions: EventConditions
    let steps: [QuestStep]
    let reward: QuestReward

    init(id: String, title: String, description: String = "", conditions: EventConditions = EventConditions(),
         steps: [QuestStep], reward: QuestReward = QuestReward()) {
        self.id = id
        self.title = title
        self.description = description
        self.conditions = conditions
        self.steps = steps
        self.reward = reward
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        conditions = try c.decodeIfPresent(EventConditions.self, forKey: .conditions) ?? EventConditions()
        steps = try c.decode([QuestStep].self, forKey: .steps)
        reward = try c.decodeIfPresent(QuestReward.self, forKey: .reward) ?? QuestReward()
    }
}

struct QuestStep: Codable, Equatable {
    let label: String
    /// Hint shown on the map (optional).
    let location: Location?
    let conditions: EventConditions

    init(label: String, location: Location? = nil, conditions: EventConditions) {
        self.label = label
        self.location = location
        self.conditions = conditions
    }
}

struct QuestReward: Codable, Equatable {
    let effects: [StatKind: Int]
    let xp: [Skill: Int]
    let text: String

    init(effects: [StatKind: Int] = [:], xp: [Skill: Int] = [:], text: String = "") {
        self.effects = effects
        self.xp = xp
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effects = try c.decodeIfPresent([StatKind: Int].self, forKey: .effects) ?? [:]
        xp = try c.decodeIfPresent([Skill: Int].self, forKey: .xp) ?? [:]
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
    }
}

/// All game data: events, characters, quests.
struct World {
    var events: [GameEvent]
    var cast: [CastMember]
    var quests: [Quest]
    /// Le Bloc, the starting district.
    var map: WorldMap?
    /// The districts that open later (districts.json).
    var districts: [District: WorldMap]
    var story: Story

    init(events: [GameEvent], cast: [CastMember] = [], quests: [Quest] = [], map: WorldMap? = nil,
         districts: [District: WorldMap] = [:], story: Story = Story()) {
        self.events = events
        self.cast = cast
        self.quests = quests
        self.map = map
        self.districts = districts
        self.story = story
    }
}
