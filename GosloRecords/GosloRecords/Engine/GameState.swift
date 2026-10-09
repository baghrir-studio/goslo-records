import Foundation

/// Full state of a career in progress. Codable for autosave.
struct GameState: Codable, Equatable {
    /// 1 turn = 1 semester. 20 semesters = 10 years.
    static let totalTurns = 20
    /// Extra semesters allowed past `totalTurns` while the finale is still to play (5 years of overtime).
    static let overtimeTurns = 10
    /// Visits per semester.
    static let actionsPerTurn = 2
    /// Turns in a year of career (the year shown to the player; `year` stays the engine's pace for events).
    static let turnsPerYear = 6
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
    /// Every event already played: the ones never seen come first.
    var seenEvents: Set<String> = []
    /// Story progress (`GameEngine.progressKey`) when each character last had something to say:
    /// until it moves on, talking to them again only gets small talk.
    var talkedAt: [String: String] = [:]
    /// How many times each character made small talk (their lines take turns).
    var smallTalk: [String: Int] = [:]
    /// The player's best punchlines, oldest first: the titles of their tracks, quoted back by the cast.
    var hooks: [String] = []
    /// Punchliner verses already played, oldest first: the ones never seen are drawn first (`PunchlinerDeck`).
    var seenVerses: [String] = []
    /// Albums released, in order (sales keep coming in for a few semesters).
    var albums: [Album] = []
    /// Free career: no time limit. It ends on a defeat or when the player hangs up the mic (`GameEngine.retire`).
    var freeCareer = false
    /// Turn each rival last challenged you on sight (they come back once a year at most).
    var challengedAt: [String: Int] = [:]
    /// Turn each shop service was last bought.
    var boughtAt: [String: Int] = [:]
    /// Singles released, in order (they race in the Top goslo radio).
    var singles: [Single] = []
    /// Artist XP (`ArtistLevel`).
    var artistXP = 0
    /// The season's challenges, and the season they were drawn for (-1: none yet).
    var challenges: [Challenge] = []
    var challengeSeason = -1
    /// Best rank of a single in the Top this season.
    var seasonBestRank: Int?
    /// Decorations on the map, by spot id (`MapPlot`, older saves).
    var decor: [String: Decor] = [:]
    /// Decorations and buildings put where the player chose.
    var placed: [PlacedDecor] = []
    /// Clothes bought in the shop (worn ones: `Rapper.wearing`).
    var wardrobe: Set<String> = []
    /// Visits per place this year (they pay less after a few: `GameEngine.fatigue`).
    var visitsThisYear: [String: Int] = [:]
    /// Rewarded uses of each gated source (`Gate`) this period, and this year (reset in `finishAction`).
    var gatePeriodUses: [String: Int] = [:]
    var gateYearUses: [String: Int] = [:]
    /// The gated source the current event came from (the bench scales its rewards with progress).
    var currentGate: Gate?
    /// The finale is played: the player picks between retiring as a legend and carrying on.
    var finaleChoicePending = false
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
    var minigame: MinigameState?
    /// Index of the next step for each quest in progress.
    var questProgress: [String: Int] = [:]
    var completedQuests: Set<String> = []
    var ending: Ending?
    /// Position on the map (nil = spawn point).
    var position: TilePoint?
    var facing: Direction = .down
    /// District the player is in (`position` is on its map).
    var district: District = .bloc
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
    /// Lost boss clashes, by opponent: each defeat teaches you their game (see `GameEngine.bossExperience`).
    var bossLosses: [String: Int] = [:]
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
        case minigame
        case questProgress, completedQuests, ending, position, facing, district, stepsSinceWild, challengedThisSemester
        case chapter, objectiveIndex, pendingCinematic, seenCinematics, items, equippedTechnique, knownTechniques, bossLosses
        case seenEvents, talkedAt, smallTalk, hooks, seenVerses, albums, freeCareer, finaleChoicePending
        case challengedAt, boughtAt, singles, artistXP, challenges, challengeSeason, seasonBestRank, decor, visitsThisYear, wardrobe, placed
        case gatePeriodUses, gateYearUses, currentGate
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
        minigame = try c.decodeIfPresent(MinigameState.self, forKey: .minigame)
        questProgress = try c.decodeIfPresent([String: Int].self, forKey: .questProgress) ?? [:]
        completedQuests = try c.decodeIfPresent(Set<String>.self, forKey: .completedQuests) ?? []
        ending = try c.decodeIfPresent(Ending.self, forKey: .ending)
        position = try c.decodeIfPresent(TilePoint.self, forKey: .position)
        facing = try c.decodeIfPresent(Direction.self, forKey: .facing) ?? .down
        district = try c.decodeIfPresent(District.self, forKey: .district) ?? .bloc
        stepsSinceWild = try c.decodeIfPresent(Int.self, forKey: .stepsSinceWild) ?? 0
        challengedThisSemester = try c.decodeIfPresent(Set<String>.self, forKey: .challengedThisSemester) ?? []
        chapter = try c.decodeIfPresent(Int.self, forKey: .chapter) ?? 1
        objectiveIndex = try c.decodeIfPresent(Int.self, forKey: .objectiveIndex) ?? 0
        pendingCinematic = try c.decodeIfPresent(String.self, forKey: .pendingCinematic)
        seenCinematics = try c.decodeIfPresent(Set<String>.self, forKey: .seenCinematics) ?? []
        items = try c.decodeIfPresent(Set<String>.self, forKey: .items) ?? []
        bossLosses = try c.decodeIfPresent([String: Int].self, forKey: .bossLosses) ?? [:]
        equippedTechnique = try c.decodeIfPresent(String.self, forKey: .equippedTechnique)
        knownTechniques = try c.decodeIfPresent(Set<String>.self, forKey: .knownTechniques) ?? []
        seenEvents = try c.decodeIfPresent(Set<String>.self, forKey: .seenEvents) ?? Set(recentEvents)
        talkedAt = try c.decodeIfPresent([String: String].self, forKey: .talkedAt) ?? [:]
        smallTalk = try c.decodeIfPresent([String: Int].self, forKey: .smallTalk) ?? [:]
        hooks = try c.decodeIfPresent([String].self, forKey: .hooks) ?? []
        seenVerses = try c.decodeIfPresent([String].self, forKey: .seenVerses) ?? []
        albums = try c.decodeIfPresent([Album].self, forKey: .albums) ?? []
        freeCareer = try c.decodeIfPresent(Bool.self, forKey: .freeCareer) ?? false
        finaleChoicePending = try c.decodeIfPresent(Bool.self, forKey: .finaleChoicePending) ?? false
        challengedAt = try c.decodeIfPresent([String: Int].self, forKey: .challengedAt) ?? [:]
        boughtAt = try c.decodeIfPresent([String: Int].self, forKey: .boughtAt) ?? [:]
        singles = try c.decodeIfPresent([Single].self, forKey: .singles) ?? []
        artistXP = try c.decodeIfPresent(Int.self, forKey: .artistXP) ?? 0
        challenges = try c.decodeIfPresent([Challenge].self, forKey: .challenges) ?? []
        challengeSeason = try c.decodeIfPresent(Int.self, forKey: .challengeSeason) ?? -1
        seasonBestRank = try c.decodeIfPresent(Int.self, forKey: .seasonBestRank)
        decor = try c.decodeIfPresent([String: Decor].self, forKey: .decor) ?? [:]
        visitsThisYear = try c.decodeIfPresent([String: Int].self, forKey: .visitsThisYear) ?? [:]
        wardrobe = try c.decodeIfPresent(Set<String>.self, forKey: .wardrobe) ?? []
        placed = try c.decodeIfPresent([PlacedDecor].self, forKey: .placed) ?? []
        gatePeriodUses = try c.decodeIfPresent([String: Int].self, forKey: .gatePeriodUses) ?? [:]
        gateYearUses = try c.decodeIfPresent([String: Int].self, forKey: .gateYearUses) ?? [:]
        currentGate = try c.decodeIfPresent(Gate.self, forKey: .currentGate)
    }

    /// Year 1 to 10 (no cap in a free career).
    var year: Int { freeCareer ? turn / 2 + 1 : min(turn / 2 + 1, GameState.totalTurns / 2) }
    /// Semester 1 or 2.
    var semester: Int { turn % 2 + 1 }
    var isOver: Bool { ending != nil }
    var yearsActive: Int { max(1, Int((Double(turn) / Double(GameState.turnsPerYear)).rounded(.up))) }
    /// The year of career shown to the player: one every `turnsPerYear` turns.
    var careerYear: Int { turn / GameState.turnsPerYear + 1 }
    /// How far into the current year (0…1), actions included.
    var yearProgress: Double {
        let done = (turn % GameState.turnsPerYear) * GameState.actionsPerTurn + (GameState.actionsPerTurn - min(actionsLeft, GameState.actionsPerTurn))
        return min(1, max(0, Double(done) / Double(GameState.turnsPerYear * GameState.actionsPerTurn)))
    }
    /// This turn starts a new year (the year card shows).
    var isNewYear: Bool { turn > 0 && turn % GameState.turnsPerYear == 0 }
    /// Past semester 20 with the finale still to play (see `GameEngine.turnLimit`).
    var isOvertime: Bool { turn >= GameState.totalTurns }
    /// "ANNÉE 4", or "PROLONGATION" in overtime.
    var periodLabel: String { isOvertime && !freeCareer ? "PROLONGATION" : "ANNÉE \(careerYear)" }
    /// "S2", or "3/10" in overtime.
    var semesterLabel: String {
        isOvertime && !freeCareer ? "\(turn - GameState.totalTurns + 1)/\(GameState.overtimeTurns)" : "S\(semester)"
    }
    /// Subtitle of the semester card.
    var semesterCardLabel: String {
        isOvertime && !freeCareer ? "SEMESTRE \(turn - GameState.totalTurns + 1) SUR \(GameState.overtimeTurns)" : "UNE ANNÉE DE PLUS"
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
