import Foundation

/// Full state of a career in progress. Codable for autosave.
struct GameState: Codable, Equatable {
    /// 1 turn = 1 semester. 20 semesters = 10 years.
    static let totalTurns = 20
    /// Extra semesters allowed past `totalTurns` while the finale is still to play (5 years of overtime).
    static let overtimeTurns = 10
    /// Visits per semester.
    static let actionsPerTurn = 2
    static let recentMemory = 8
    static let relationRange = 0...100

    var id = UUID()
    var startedAt = Date()
    var rapper: Rapper
    var stats: Stats
    var counters = Counters()
    var skills: Skills
    var flags: Set<String> = []
    /// Relationships with characters (0–100), keyed by cast id.
    var relations: [String: Int] = [:]
    /// Characters already met (shown in the contacts list).
    var metCast: Set<String> = []
    /// Semesters already played (0...20, up to 30 in overtime).
    var turn = 0
    var actionsLeft = GameState.actionsPerTurn
    var seenUniqueEvents: Set<String> = []
    /// Recent event ids, to avoid repeats.
    var recentEvents: [String] = []
    var pendingFollowUp: String?
    /// Event shown and awaiting a choice (kept so a resume shows the same card).
    var currentEventId: String?
    /// Location of the current visit (nil for a follow-up).
    var currentLocation: Location?
    var clash: ClashState?
    var interview: InterviewState?
    var concert: ConcertState?
    var negotiation: NegotiationState?
    var writing: WritingState?
    /// Index of the next step for each quest in progress.
    var questProgress: [String: Int] = [:]
    var completedQuests: Set<String> = []
    var ending: Ending?
    /// Position on the map (nil = spawn point).
    var position: TilePoint?
    var facing: Direction = .down
    var stepsSinceWild = 0
    /// Rivals who already challenged you this semester.
    var challengedThisSemester: Set<String> = []

    // Story
    /// Current chapter (1-based). Past the last written chapter = free play.
    var chapter = 1
    /// Index of the current objective in the chapter.
    var objectiveIndex = 0
    /// Cinematic to play as soon as the player is back on the map.
    var pendingCinematic: String?
    var seenCinematics: Set<String> = []
    /// Collected items (ids from story.json).
    var items: Set<String> = []
    /// Secret technique picked in the notebook: "style", an item id or a technique id (nil = automatic).
    var equippedTechnique: String?
    /// Unlocked techniques already announced to the player.
    var knownTechniques: Set<String> = []

    init(rapper: Rapper, stats: Stats? = nil) {
        self.rapper = rapper
        self.stats = stats ?? rapper.style.startingStats
        self.skills = Skills(xp: rapper.style.startingXP)
    }

    enum CodingKeys: String, CodingKey {
        case id, startedAt, rapper, stats, counters, skills, flags, relations, metCast, turn, actionsLeft
        case seenUniqueEvents, recentEvents, pendingFollowUp, currentEventId, currentLocation, clash, interview, concert, negotiation, writing
        case questProgress, completedQuests, ending, position, facing, stepsSinceWild, challengedThisSemester
        case chapter, objectiveIndex, pendingCinematic, seenCinematics, items, equippedTechnique, knownTechniques
    }

    /// Tolerant decoding: fields added in later versions get their default value,
    /// so an older save never gets lost.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rapper = try c.decode(Rapper.self, forKey: .rapper)
        stats = try c.decode(Stats.self, forKey: .stats)
        skills = try c.decodeIfPresent(Skills.self, forKey: .skills) ?? Skills(xp: rapper.style.startingXP)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        counters = try c.decodeIfPresent(Counters.self, forKey: .counters) ?? Counters()
        flags = try c.decodeIfPresent(Set<String>.self, forKey: .flags) ?? []
        relations = try c.decodeIfPresent([String: Int].self, forKey: .relations) ?? [:]
        metCast = try c.decodeIfPresent(Set<String>.self, forKey: .metCast) ?? []
        turn = try c.decodeIfPresent(Int.self, forKey: .turn) ?? 0
        actionsLeft = try c.decodeIfPresent(Int.self, forKey: .actionsLeft) ?? GameState.actionsPerTurn
        seenUniqueEvents = try c.decodeIfPresent(Set<String>.self, forKey: .seenUniqueEvents) ?? []
        recentEvents = try c.decodeIfPresent([String].self, forKey: .recentEvents) ?? []
        pendingFollowUp = try c.decodeIfPresent(String.self, forKey: .pendingFollowUp)
        currentEventId = try c.decodeIfPresent(String.self, forKey: .currentEventId)
        currentLocation = try c.decodeIfPresent(Location.self, forKey: .currentLocation)
        clash = try c.decodeIfPresent(ClashState.self, forKey: .clash)
        interview = try c.decodeIfPresent(InterviewState.self, forKey: .interview)
        concert = try c.decodeIfPresent(ConcertState.self, forKey: .concert)
        negotiation = try c.decodeIfPresent(NegotiationState.self, forKey: .negotiation)
        writing = try c.decodeIfPresent(WritingState.self, forKey: .writing)
        questProgress = try c.decodeIfPresent([String: Int].self, forKey: .questProgress) ?? [:]
        completedQuests = try c.decodeIfPresent(Set<String>.self, forKey: .completedQuests) ?? []
        ending = try c.decodeIfPresent(Ending.self, forKey: .ending)
        position = try c.decodeIfPresent(TilePoint.self, forKey: .position)
        facing = try c.decodeIfPresent(Direction.self, forKey: .facing) ?? .down
        stepsSinceWild = try c.decodeIfPresent(Int.self, forKey: .stepsSinceWild) ?? 0
        challengedThisSemester = try c.decodeIfPresent(Set<String>.self, forKey: .challengedThisSemester) ?? []
        chapter = try c.decodeIfPresent(Int.self, forKey: .chapter) ?? 1
        objectiveIndex = try c.decodeIfPresent(Int.self, forKey: .objectiveIndex) ?? 0
        pendingCinematic = try c.decodeIfPresent(String.self, forKey: .pendingCinematic)
        seenCinematics = try c.decodeIfPresent(Set<String>.self, forKey: .seenCinematics) ?? []
        items = try c.decodeIfPresent(Set<String>.self, forKey: .items) ?? []
        equippedTechnique = try c.decodeIfPresent(String.self, forKey: .equippedTechnique)
        knownTechniques = try c.decodeIfPresent(Set<String>.self, forKey: .knownTechniques) ?? []
    }

    /// Year 1 to 10.
    var year: Int { min(turn / 2 + 1, GameState.totalTurns / 2) }
    /// Semester 1 or 2.
    var semester: Int { turn % 2 + 1 }
    var isOver: Bool { ending != nil }
    var yearsActive: Int { max(1, Int((Double(turn) / 2).rounded(.up))) }
    /// Past semester 20 with the finale still to play (see `GameEngine.turnLimit`).
    var isOvertime: Bool { turn >= GameState.totalTurns }
    /// "ANNÉE 4", or "PROLONGATION" in overtime.
    var periodLabel: String { isOvertime ? "PROLONGATION" : "ANNÉE \(year)" }
    /// "S2", or "3/10" in overtime.
    var semesterLabel: String {
        isOvertime ? "\(turn - GameState.totalTurns + 1)/\(GameState.overtimeTurns)" : "S\(semester)"
    }
    /// Subtitle of the semester card.
    var semesterCardLabel: String {
        isOvertime ? "SEMESTRE \(turn - GameState.totalTurns + 1) SUR \(GameState.overtimeTurns)" : "SEMESTRE \(semester)"
    }

    func relation(_ castId: String) -> Int {
        relations[castId] ?? CastMember.defaultRelation
    }

    @discardableResult
    mutating func changeRelation(_ castId: String, by delta: Int) -> Int {
        let before = relation(castId)
        let after = min(max(before + delta, GameState.relationRange.lowerBound), GameState.relationRange.upperBound)
        relations[castId] = after
        return after - before
    }
}
