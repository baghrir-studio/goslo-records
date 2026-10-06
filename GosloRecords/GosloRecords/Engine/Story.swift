import Foundation

/// The main storyline (story.json): chapters made of objectives, story events,
/// cinematics, interviews and goslo radio headlines.
struct Story: Codable, Equatable {
    var chapters: [Chapter]
    var events: [GameEvent]
    var cinematics: [Cinematic]
    var interviews: [Interview]
    var radio: [RadioHeadline]
    var items: [Item]
    var concerts: [Concert]
    var negotiations: [Negotiation]
    var writings: [Writing]
    /// Secret techniques the player unlocks along the story (one per boss).
    var techniques: [UnlockableTechnique]

    init(chapters: [Chapter] = [], events: [GameEvent] = [], cinematics: [Cinematic] = [],
         interviews: [Interview] = [], radio: [RadioHeadline] = [], items: [Item] = [], concerts: [Concert] = [],
         negotiations: [Negotiation] = [], writings: [Writing] = [], techniques: [UnlockableTechnique] = []) {
        self.chapters = chapters
        self.events = events
        self.cinematics = cinematics
        self.interviews = interviews
        self.radio = radio
        self.items = items
        self.concerts = concerts
        self.negotiations = negotiations
        self.writings = writings
        self.techniques = techniques
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chapters = try c.decodeIfPresent([Chapter].self, forKey: .chapters) ?? []
        events = try c.decodeIfPresent([GameEvent].self, forKey: .events) ?? []
        cinematics = try c.decodeIfPresent([Cinematic].self, forKey: .cinematics) ?? []
        interviews = try c.decodeIfPresent([Interview].self, forKey: .interviews) ?? []
        radio = try c.decodeIfPresent([RadioHeadline].self, forKey: .radio) ?? []
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        concerts = try c.decodeIfPresent([Concert].self, forKey: .concerts) ?? []
        negotiations = try c.decodeIfPresent([Negotiation].self, forKey: .negotiations) ?? []
        writings = try c.decodeIfPresent([Writing].self, forKey: .writings) ?? []
        techniques = try c.decodeIfPresent([UnlockableTechnique].self, forKey: .techniques) ?? []
    }

    func chapter(_ number: Int) -> Chapter? { chapters.first { $0.number == number } }
    func cinematic(_ id: String) -> Cinematic? { cinematics.first { $0.id == id } }
    func interview(_ id: String) -> Interview? { interviews.first { $0.id == id } }
    func item(_ id: String) -> Item? { items.first { $0.id == id } }
    func concert(_ id: String) -> Concert? { concerts.first { $0.id == id } }
    func negotiation(_ id: String) -> Negotiation? { negotiations.first { $0.id == id } }
    func writing(_ id: String) -> Writing? { writings.first { $0.id == id } }
}

struct Chapter: Codable, Equatable, Identifiable {
    let number: Int
    let title: String
    /// Cinematic played when the chapter starts / once all objectives are done.
    let intro: String?
    let outro: String?
    let objectives: [Objective]
    /// Last chapter of the story: finishing it ends the career.
    let finale: Bool?

    var id: Int { number }
    var isFinale: Bool { finale ?? false }
}

/// A story step. It's done when its `conditions` hold. The `trigger` says where
/// the story event `event` happens (a door, or a character to talk to).
struct Objective: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let hint: String
    let trigger: StoryTrigger?
    let event: String?
    let conditions: EventConditions
    /// Cinematic played once the objective is done.
    let cinematic: String?

    init(id: String, label: String, hint: String = "", trigger: StoryTrigger? = nil, event: String? = nil,
         conditions: EventConditions, cinematic: String? = nil) {
        self.id = id
        self.label = label
        self.hint = hint
        self.trigger = trigger
        self.event = event
        self.conditions = conditions
        self.cinematic = cinematic
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        hint = try c.decodeIfPresent(String.self, forKey: .hint) ?? ""
        trigger = try c.decodeIfPresent(StoryTrigger.self, forKey: .trigger)
        event = try c.decodeIfPresent(String.self, forKey: .event)
        conditions = try c.decode(EventConditions.self, forKey: .conditions)
        cinematic = try c.decodeIfPresent(String.self, forKey: .cinematic)
    }
}

struct StoryTrigger: Codable, Equatable {
    /// Going through this door plays the story event.
    let location: Location?
    /// Talking to this character plays the story event.
    let npc: String?
    /// The character challenges you when they see you (trainer style).
    let spot: Bool

    init(location: Location? = nil, npc: String? = nil, spot: Bool = false) {
        self.location = location
        self.npc = npc
        self.spot = spot
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        location = try c.decodeIfPresent(Location.self, forKey: .location)
        npc = try c.decodeIfPresent(String.self, forKey: .npc)
        spot = try c.decodeIfPresent(Bool.self, forKey: .spot) ?? false
    }
}

// MARK: - Cinematics

struct Cinematic: Codable, Equatable, Identifiable {
    let id: String
    let steps: [CinematicStep]
}

/// One cinematic step. Exactly one field is set.
struct CinematicStep: Codable, Equatable {
    struct Line: Codable, Equatable {
        /// "player" or a cast id.
        let who: String
        let text: String
    }

    struct Title: Codable, Equatable {
        let text: String
        let subtitle: String?
    }

    struct Placement: Codable, Equatable {
        let who: String
        let x: Int
        let y: Int
        let facing: Direction?

        var point: TilePoint { TilePoint(x: x, y: y) }
    }

    struct Facing: Codable, Equatable {
        let who: String
        let facing: Direction
    }

    var narration: String?
    var say: Line?
    var title: Title?
    /// Walks in straight lines (x then y) to the target.
    var move: Placement?
    /// Places a character (or the player) without walking.
    var place: Placement?
    var despawn: String?
    var face: Facing?
    /// "!" bubble above a character.
    var exclaim: String?
    /// Camera centered on a tile; `camera_reset` brings it back to the player.
    var camera: TilePoint?
    var cameraReset: Bool?
    /// true = fade to black, false = fade back in.
    var fade: Bool?
    var wait: Double?
    /// Name of a SoundEffect.
    var sound: String?

    enum CodingKeys: String, CodingKey {
        case narration, say, title, move, place, despawn, face, exclaim, camera, fade, wait, sound
        case cameraReset = "camera_reset"
    }

    init(narration: String? = nil, say: Line? = nil, title: Title? = nil, move: Placement? = nil,
         place: Placement? = nil, despawn: String? = nil, face: Facing? = nil, exclaim: String? = nil,
         camera: TilePoint? = nil, cameraReset: Bool? = nil, fade: Bool? = nil, wait: Double? = nil, sound: String? = nil) {
        self.narration = narration
        self.say = say
        self.title = title
        self.move = move
        self.place = place
        self.despawn = despawn
        self.face = face
        self.exclaim = exclaim
        self.camera = camera
        self.cameraReset = cameraReset
        self.fade = fade
        self.wait = wait
        self.sound = sound
    }

    /// Number of fields set (data validation: must be 1).
    var fieldCount: Int {
        [narration != nil, say != nil, title != nil, move != nil, place != nil, despawn != nil, face != nil,
         exclaim != nil, camera != nil, cameraReset != nil, fade != nil, wait != nil, sound != nil].filter { $0 }.count
    }

    /// Characters referenced (data validation).
    var actors: [String] {
        [say?.who, move?.who, place?.who, despawn, face?.who, exclaim].compactMap { $0 }
    }
}

// MARK: - Interviews

/// A radio/TV interview: timed questions, answers move the audience gauge.
struct Interview: Codable, Equatable, Identifiable {
    let id: String
    /// Cast id of the host.
    let host: String
    let show: String
    let intro: String
    let startHype: Int
    let passHype: Int
    let timeoutPenalty: Int
    let questions: [InterviewQuestion]
    let win: InterviewResult
    let lose: InterviewResult
    /// Boss interview: special banner, harsher host.
    let boss: Bool

    enum CodingKeys: String, CodingKey {
        case id, host, show, intro, questions, win, lose, boss
        case startHype = "start_hype"
        case passHype = "pass_hype"
        case timeoutPenalty = "timeout_penalty"
    }

    init(id: String, host: String, show: String, intro: String = "", startHype: Int = 30, passHype: Int = 60,
         timeoutPenalty: Int = 12, questions: [InterviewQuestion], win: InterviewResult, lose: InterviewResult,
         boss: Bool = false) {
        self.id = id
        self.host = host
        self.show = show
        self.intro = intro
        self.startHype = startHype
        self.passHype = passHype
        self.timeoutPenalty = timeoutPenalty
        self.questions = questions
        self.win = win
        self.lose = lose
        self.boss = boss
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        host = try c.decode(String.self, forKey: .host)
        show = try c.decode(String.self, forKey: .show)
        intro = try c.decodeIfPresent(String.self, forKey: .intro) ?? ""
        startHype = try c.decodeIfPresent(Int.self, forKey: .startHype) ?? 30
        passHype = try c.decodeIfPresent(Int.self, forKey: .passHype) ?? 60
        timeoutPenalty = try c.decodeIfPresent(Int.self, forKey: .timeoutPenalty) ?? 12
        questions = try c.decode([InterviewQuestion].self, forKey: .questions)
        win = try c.decode(InterviewResult.self, forKey: .win)
        lose = try c.decode(InterviewResult.self, forKey: .lose)
        boss = try c.decodeIfPresent(Bool.self, forKey: .boss) ?? false
    }
}

struct InterviewQuestion: Codable, Equatable {
    let text: String
    /// Seconds to answer before dead air.
    let time: Double
    let answers: [InterviewAnswer]

    init(text: String, time: Double = 10, answers: [InterviewAnswer]) {
        self.text = text
        self.time = time
        self.answers = answers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        time = try c.decodeIfPresent(Double.self, forKey: .time) ?? 10
        answers = try c.decode([InterviewAnswer].self, forKey: .answers)
    }
}

struct InterviewAnswer: Codable, Equatable {
    let label: String
    let hype: Int
    let reaction: String
    let effects: [StatKind: Int]
    let relations: [String: Int]
    let requires: ChoiceRequirement?

    init(label: String, hype: Int, reaction: String, effects: [StatKind: Int] = [:], relations: [String: Int] = [:],
         requires: ChoiceRequirement? = nil) {
        self.label = label
        self.hype = hype
        self.reaction = reaction
        self.effects = effects
        self.relations = relations
        self.requires = requires
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        hype = try c.decode(Int.self, forKey: .hype)
        reaction = try c.decode(String.self, forKey: .reaction)
        effects = try c.decodeIfPresent([StatKind: Int].self, forKey: .effects) ?? [:]
        relations = try c.decodeIfPresent([String: Int].self, forKey: .relations) ?? [:]
        requires = try c.decodeIfPresent(ChoiceRequirement.self, forKey: .requires)
    }

    func isAvailable(in state: GameState) -> Bool { requires?.isMet(by: state) ?? true }
}

struct InterviewResult: Codable, Equatable {
    let effects: [StatKind: Int]
    let xp: [Skill: Int]
    let relations: [String: Int]
    let setFlags: [String]
    let consequence: String

    enum CodingKeys: String, CodingKey {
        case effects, xp, relations, consequence
        case setFlags = "set_flags"
    }

    init(effects: [StatKind: Int] = [:], xp: [Skill: Int] = [:], relations: [String: Int] = [:],
         setFlags: [String] = [], consequence: String) {
        self.effects = effects
        self.xp = xp
        self.relations = relations
        self.setFlags = setFlags
        self.consequence = consequence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effects = try c.decodeIfPresent([StatKind: Int].self, forKey: .effects) ?? [:]
        xp = try c.decodeIfPresent([Skill: Int].self, forKey: .xp) ?? [:]
        relations = try c.decodeIfPresent([String: Int].self, forKey: .relations) ?? [:]
        setFlags = try c.decodeIfPresent([String].self, forKey: .setFlags) ?? []
        consequence = try c.decode(String.self, forKey: .consequence)
    }
}

struct InterviewLogEntry: Codable, Equatable {
    let question: Int
    /// nil = no answer in time.
    let answer: Int?
    let hypeDelta: Int
    let reaction: String
}

/// Interview in progress (saved with the game).
struct InterviewState: Codable, Equatable {
    static let hypeRange = 0...100

    let id: String
    var hype: Int
    var questionIndex = 0
    var log: [InterviewLogEntry] = []
    let questionCount: Int
    let passHype: Int

    init(interview: Interview) {
        id = interview.id
        hype = interview.startHype
        questionCount = interview.questions.count
        passHype = interview.passHype
    }

    var isOver: Bool { questionIndex >= questionCount }
    var passed: Bool { hype >= passHype }
}

// MARK: - goslo radio

/// A headline in the "Flash goslo radio" ticker.
struct RadioHeadline: Codable, Equatable {
    let text: String
    let conditions: EventConditions

    init(text: String, conditions: EventConditions = EventConditions()) {
        self.text = text
        self.conditions = conditions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        conditions = try c.decodeIfPresent(EventConditions.self, forKey: .conditions) ?? EventConditions()
    }
}

// MARK: - Items

/// A collectible (La Mythique, Fred's drill…): passive clash bonus, and maybe a secret technique.
/// A secret technique won along the story: it unlocks once `unlock` holds (usually a boss beaten).
struct UnlockableTechnique: Codable, Equatable, Identifiable {
    let id: String
    let secret: SecretTechnique
    let unlock: EventConditions
}

struct Item: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let description: String
    /// Bonus levels per clash move while you own the item.
    let clashBonus: [ClashMove: Int]
    /// Replaces the player's secret technique.
    let secret: SecretTechnique?

    enum CodingKeys: String, CodingKey {
        case id, name, description, secret
        case clashBonus = "clash_bonus"
    }

    init(id: String, name: String, description: String = "", clashBonus: [ClashMove: Int] = [:],
         secret: SecretTechnique? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.clashBonus = clashBonus
        self.secret = secret
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        clashBonus = try c.decodeIfPresent([ClashMove: Int].self, forKey: .clashBonus) ?? [:]
        secret = try c.decodeIfPresent(SecretTechnique.self, forKey: .secret)
    }
}
