import Foundation

/// Result of an action (choice or clash), shown to the player before moving on.
struct TurnOutcome: Equatable {
    var consequence: String
    /// Stat changes actually applied (after clamping), quest rewards and upkeep included.
    var deltas: [StatKind: Int] = [:]
    var levelUps: [Skill] = []
    var relationChanges: [String: Int] = [:]
    var completedQuests: [Quest] = []
    /// Story objectives completed by this action (labels).
    var completedObjectives: [String] = []
    /// Items received (names).
    var gainedItems: [String] = []
    /// Secret techniques unlocked by this action (names).
    var unlockedTechniques: [String] = []
    /// Finished clash, if the action was one.
    var clash: ClashState?
    /// Finished interview, if the action was one.
    var interview: InterviewState?
    /// Finished concert, if the action was one.
    var concert: ConcertState?
    /// Finished negotiation, if the action was one.
    var negotiation: NegotiationState?
    /// Finished writing session, if the action was one.
    var writing: WritingState?
    /// Finished mini-game, if the action was one.
    var minigame: MinigameState?
    /// True if this action closed the semester (upkeep applied).
    var semesterEnded = false
    /// What the end of the turn brought (bookings, burn-out…), shown under the consequence.
    var notes: [String] = []
    var ending: Ending?

    mutating func add(_ applied: [StatKind: Int]) {
        deltas.merge(applied, uniquingKeysWith: +)
        deltas = deltas.filter { $0.value != 0 }
    }

    mutating func add(levelUps new: [Skill]) {
        for skill in new where !levelUps.contains(skill) { levelUps.append(skill) }
    }
}

/// Result of a choice: either immediate, or a clash to play.
enum Resolution: Equatable {
    case outcome(TurnOutcome)
    case clash(ClashState)
    case interview(InterviewState)
    case concert(ConcertState)
    case negotiation(NegotiationState)
    case writing(WritingState)
    case minigame(MinigameState)
}

enum GameEngineError: Error, Equatable {
    case cannotVisit
    case cannotBuy
    case cannotRecord
    case locationLocked(Location)
    case noCurrentEvent
    case unknownEvent(String)
    case invalidChoice(Int)
    case requirementNotMet
    case noClash
    case clashNotOver
    case secretNotReady
    case noInterview
    case interviewNotOver
    case noConcert
    case concertNotOver
    case noNegotiation
    case negotiationNotOver
    case noWriting
    case writingNotOver
    case noMinigame
    case minigameNotOver
    case gameOver
    case districtLocked(District)
    case freestyleUsed
    case albumNotReady
}

/// A secret technique the player can equip (style, item or unlocked), keyed by where it comes from.
struct EquippableTechnique: Equatable, Identifiable {
    let id: String
    let secret: SecretTechnique
}

/// Pure game rules: map, encounters, choices, clashes, quests, endings.
/// No I/O and no UI; randomness is injected.
struct GameEngine {
    /// Applied at the end of each semester: rent, and the algorithm slowly forgetting you.
    static let semesterUpkeep: [StatKind: Int] = [.argent: -2, .streams: -4]

    /// The algorithm forgets you in proportion to your fame: an unknown rapper has nothing to lose.
    static func upkeep(for stats: Stats) -> [StatKind: Int] {
        var upkeep = semesterUpkeep
        let maxLoss = semesterUpkeep[.streams] ?? 0
        upkeep[.streams] = stats.streams > 40 ? maxLoss : (stats.streams > 20 ? maxLoss / 2 : 0)
        return upkeep
    }
    static let clashRelationPenalty = (win: -15, lose: -5)
    /// Turns before a rival stops you on sight again (a year).
    static let challengeCooldown = GameState.turnsPerYear
    /// The chroniqueur reveals weak spots from this relationship level.
    static let chroniqueurId = "yanis"
    static let scoutingRelation = 60

    /// Used when no event is eligible, so the game never gets stuck.
    static let fallbackEvent = GameEvent(
        id: "_moment_calme",
        title: "Moment calme",
        text: "Rien ne se passe. Tu écris, tu effaces, tu réécris. Le game avance sans toi, mais toi aussi tu avances, un peu.",
        weight: 0,
        choices: [
            EventChoice(label: "Bosser dans l'ombre", effects: [.credibilite: 2, .mental: 2], xp: [.plume: 15],
                        consequence: "Trois couplets, zéro story. Le calme avant la tempête. Ou juste le calme."),
            EventChoice(label: "Poster des stories pour exister", effects: [.streams: 3, .mental: -2], xp: [.business: 15],
                        consequence: "Une story de ton café. 40 vues. L'algorithme te remarque, vaguement."),
        ]
    )

    let world: World
    private let eventIndex: [String: GameEvent]
    private let castIndex: [String: CastMember]

    init(world: World) {
        self.world = world
        var index = Dictionary((world.events + world.story.events).map { ($0.id, $0) },
                               uniquingKeysWith: { first, _ in first })
        index[GameEngine.fallbackEvent.id] = GameEngine.fallbackEvent
        eventIndex = index
        castIndex = Dictionary(world.cast.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    init(events: [GameEvent], cast: [CastMember] = [], quests: [Quest] = []) {
        self.init(world: World(events: events, cast: cast, quests: quests))
    }

    var events: [GameEvent] { world.events }

    func event(withId id: String) -> GameEvent? { eventIndex[id] }
    func castMember(_ id: String) -> CastMember? { castIndex[id] }

    func newGame(rapper: Rapper) -> GameState {
        var state = GameState(rapper: rapper)
        for member in world.cast {
            state.relations[member.id] = member.startRelation
        }
        state.pendingCinematic = world.story.chapter(1)?.intro
        if let heritage = rapper.heritage { applyHeritage(heritage, to: &state) }
        refreshChallenges(in: &state)
        return state
    }

    // MARK: - Map

    func isUnlocked(_ location: Location, in state: GameState) -> Bool {
        guard location.unlock?.isSatisfied(by: state) ?? true else { return false }
        // The story always gets through; otherwise some doors wait for the artist level.
        return ArtistLevel.level(xp: state.artistXP) >= location.minArtistLevel || storyEvent(at: location, in: state) != nil
    }

    /// Going back to the same place again and again in a year pays less and less (no farming).
    static let freshVisits = 2

    func fatigue(at location: Location?, in state: GameState) -> Double {
        guard let location, location != .chezToi else { return 1 }
        let visits = state.visitsThisYear[location.rawValue, default: 0]
        return visits <= GameEngine.freshVisits ? 1 : max(0.25, 1 - 0.25 * Double(visits - GameEngine.freshVisits))
    }

    /// The player can pick a location (no card awaiting, no clash, actions left).
    func canVisit(_ state: GameState) -> Bool {
        !state.isOver && state.currentEventId == nil && state.clash == nil && state.interview == nil && state.concert == nil && state.negotiation == nil
            && state.writing == nil && state.minigame == nil
            && state.pendingFollowUp == nil && state.actionsLeft > 0
    }

    func isEligible(_ event: GameEvent, in state: GameState) -> Bool {
        event.weight > 0
            && !(event.unique && state.seenUniqueEvents.contains(event.id))
            && event.conditions.isSatisfied(by: state)
    }

    func eligibleEvents(at location: Location, in state: GameState) -> [GameEvent] {
        world.events.filter { $0.location == location && isEligible($0, in: state) }
    }

    /// Characters you can run into at this location right now.
    func charactersPresent(at location: Location, in state: GameState) -> [CastMember] {
        var seen = Set<String>()
        return eligibleEvents(at: location, in: state).compactMap { event in
            guard let npc = event.npc, let member = castIndex[npc], seen.insert(npc).inserted else { return nil }
            return member
        }
    }

    // MARK: - Characters on the map

    /// Events available with this character right now (any location).
    func events(featuring castId: String, in state: GameState) -> [GameEvent] {
        world.events.filter { $0.npc == castId && isEligible($0, in: state) }
    }

    private func isChallenge(_ event: GameEvent, by castId: String) -> Bool {
        event.choices.contains { $0.clash?.opponent == castId }
    }

    /// The rival can challenge you (a clash event with them is available).
    func canChallenge(_ castId: String, in state: GameState) -> Bool {
        guard canVisit(state), !state.challengedThisSemester.contains(castId) else { return false }
        if let trigger = currentObjective(in: state)?.trigger, trigger.npc == castId, trigger.spot { return true }
        // Outside the story, a rival only stops you once a year: talk to them if you want more.
        if let last = state.challengedAt[castId], state.turn - last < GameEngine.challengeCooldown { return false }
        return events(featuring: castId, in: state).contains { isChallenge($0, by: castId) }
    }

    /// Talk to a character: plays one of their events (1 action).
    /// Returns nil, without spending anything, if they have nothing to offer.
    func talk<R: RandomNumberGenerator>(to castId: String, challenge: Bool = false, in state: inout GameState,
                                        using rng: inout R) throws -> GameEvent? {
        guard canVisit(state) else { throw GameEngineError.cannotVisit }
        if let story = storyEvent(forNPC: castId, in: state) {
            if challenge { state.challengedThisSemester.insert(castId) }
            if currentObjective(in: state)?.free != true { state.actionsLeft -= 1 }
            state.currentLocation = story.location
            state.currentEventId = story.id
            state.metCast.insert(castId)
            return story
        }
        var pool = events(featuring: castId, in: state)
        if challenge {
            pool = pool.filter { isChallenge($0, by: castId) }
        } else if hasTalked(to: castId, in: state) {
            // Already talked since the story last moved: only what still matters (a first-time scene, a quest lead).
            pool = pool.filter { isImportant($0, in: state) }
        }
        guard let event = GameEngine.weightedPick(GameEngine.freshest(pool, in: state), using: &rng) else { return nil }

        if challenge {
            state.challengedThisSemester.insert(castId)
            state.challengedAt[castId] = state.turn
        }
        state.talkedAt[castId] = progressKey(in: state)
        state.actionsLeft -= 1
        state.currentLocation = event.location
        state.currentEventId = event.id
        state.metCast.insert(castId)
        return event
    }

    /// Events never played first, then the ones not played lately, then anything.
    static func freshest(_ pool: [GameEvent], in state: GameState) -> [GameEvent] {
        let unseen = pool.filter { !state.seenEvents.contains($0.id) }
        if !unseen.isEmpty { return unseen }
        let notRecent = pool.filter { !state.recentEvents.contains($0.id) }
        return notRecent.isEmpty ? pool : notRecent
    }

    /// Where the story stands: the chapter's objective and the quests. Moves when something important happens.
    func progressKey(in state: GameState) -> String {
        "\(state.chapter).\(state.objectiveIndex)|\(state.completedQuests.count).\(state.questProgress.values.reduce(0, +))"
    }

    /// This character already had their say since the story last moved.
    func hasTalked(to castId: String, in state: GameState) -> Bool {
        state.talkedAt[castId] == progressKey(in: state)
    }

    /// Worth playing even after a chat: a one-time scene not seen yet, or one that sets a flag the story or a quest waits for.
    func isImportant(_ event: GameEvent, in state: GameState) -> Bool {
        if event.unique && !state.seenUniqueEvents.contains(event.id) { return true }
        let awaited = awaitedFlags(in: state)
        return event.choices.contains { !Set($0.setFlags).isDisjoint(with: awaited) }
    }

    /// Flags the current objective or an active quest step still needs.
    func awaitedFlags(in state: GameState) -> Set<String> {
        var conditions = activeQuests(in: state).compactMap { currentStep(of: $0, in: state)?.conditions }
        if let objective = currentObjective(in: state) { conditions.append(objective.conditions) }
        return Set(conditions.flatMap(\.requiredFlags)).subtracting(state.flags)
    }

    /// Small talk when a character has nothing new: their own lines in turn, then a nudge toward the objective.
    func smallTalk(with castId: String, in state: inout GameState) -> [String] {
        let member = castMember(castId)
        let count = state.smallTalk[castId, default: 0]
        state.smallTalk[castId] = count + 1
        var lines: [String]
        if let moment = takeFreshMoment(of: castId, in: &state) {
            // Something happened in the story since: they talk about that first.
            lines = ["« \(moment) »"]
        } else if count % 3 == 2, let memory = memoryLine(for: castId, in: state) {
            lines = ["« \(memory) »"]
        } else if let idle = member?.idle, !idle.isEmpty {
            lines = ["« \(idle[count % idle.count]) »"]
        } else if let taunts = member?.clash?.taunts, !taunts.isEmpty {
            lines = ["« \(taunts[count % taunts.count]) »"]
        } else {
            let generic = ["Repasse plus tard, je suis sous l'eau.", "On se capte bientôt, promis.", "J'ai rien de neuf pour toi, {frère|ma sœur}."]
            lines = ["« \(generic[count % generic.count]) »"]
        }
        if let objective = currentObjective(in: state), objective.trigger?.npc != castId {
            lines.append("En attendant : \(objective.label.prefix(1).lowercased() + objective.label.dropFirst()).")
        }
        return lines.map { TextTemplate.render($0, for: state.rapper) }
    }

    /// The newest story line (cast.json "moments") this character can say now and hasn't said yet.
    func freshMoment(of castId: String, in state: GameState) -> Int? {
        guard let moments = castMember(castId)?.moments else { return nil }
        return moments.indices.last { index in
            !state.flags.contains(CastMoment.heardFlag(castId, index)) && moments[index].conditions.isSatisfied(by: state)
        }
    }

    /// Says the fresh story line, if any: it won't be said again.
    func takeFreshMoment(of castId: String, in state: inout GameState) -> String? {
        guard let index = freshMoment(of: castId, in: state), let member = castMember(castId) else { return nil }
        state.flags.insert(CastMoment.heardFlag(castId, index))
        return member.moments[index].text
    }

    // MARK: - Quests

    func isQuestActive(_ quest: Quest, in state: GameState) -> Bool {
        !state.completedQuests.contains(quest.id) && quest.conditions.isSatisfied(by: state)
    }

    func activeQuests(in state: GameState) -> [Quest] {
        world.quests.filter { isQuestActive($0, in: state) }
    }

    func currentStep(of quest: Quest, in state: GameState) -> QuestStep? {
        let index = state.questProgress[quest.id, default: 0]
        return quest.steps.indices.contains(index) ? quest.steps[index] : nil
    }

    /// Locations pointed to by the current steps of active quests.
    func questMarkers(in state: GameState) -> Set<Location> {
        Set(activeQuests(in: state).compactMap { currentStep(of: $0, in: state)?.location })
    }

    // MARK: - Encounters

    /// Spends an action and draws an encounter at that location.
    func visit<R: RandomNumberGenerator>(_ location: Location, in state: inout GameState,
                                         using rng: inout R) throws -> GameEvent {
        guard canVisit(state) else { throw GameEngineError.cannotVisit }
        guard isUnlocked(location, in: state) else { throw GameEngineError.locationLocked(location) }

        let chosen: GameEvent
        var free = false
        if let story = storyEvent(at: location, in: state) {
            chosen = story
            free = currentObjective(in: state)?.free == true
        } else {
            let eligible = eligibleEvents(at: location, in: state)
            chosen = GameEngine.weightedPick(GameEngine.freshest(eligible, in: state), using: &rng) ?? GameEngine.fallbackEvent
        }

        // A story scene (`Objective.free`) doesn't spend an action.
        if !free { state.actionsLeft -= 1 }
        if storyEvent(at: location, in: state) == nil || chosen.id != storyEvent(at: location, in: state)?.id {
            state.visitsThisYear[location.rawValue, default: 0] += 1
        }
        state.currentLocation = location
        state.currentEventId = chosen.id
        if let npc = chosen.npc { state.metCast.insert(npc) }
        return chosen
    }

    /// Shows the pending follow-up (no action spent).
    func takeFollowUp(in state: inout GameState) -> GameEvent? {
        guard let id = state.pendingFollowUp, let event = eventIndex[id] else {
            state.pendingFollowUp = nil
            return nil
        }
        state.pendingFollowUp = nil
        state.currentLocation = nil
        state.currentEventId = event.id
        if let npc = event.npc { state.metCast.insert(npc) }
        return event
    }

    /// Event awaiting a choice (resume).
    func currentEvent(in state: GameState) -> GameEvent? {
        state.currentEventId.flatMap { eventIndex[$0] }
    }

    static func weightedPick<R: RandomNumberGenerator>(_ events: [GameEvent], using rng: inout R) -> GameEvent? {
        let total = events.reduce(0) { $0 + max(0, $1.weight) }
        guard total > 0 else { return nil }
        var roll = Int.random(in: 0..<total, using: &rng)
        for event in events {
            roll -= max(0, event.weight)
            if roll < 0 { return event }
        }
        return events.last
    }

    // MARK: - Choices

    func resolve(choiceAt choiceIndex: Int, in state: inout GameState) throws -> Resolution {
        guard !state.isOver else { throw GameEngineError.gameOver }
        guard let eventId = state.currentEventId else { throw GameEngineError.noCurrentEvent }
        guard let event = eventIndex[eventId] else { throw GameEngineError.unknownEvent(eventId) }
        guard event.choices.indices.contains(choiceIndex) else { throw GameEngineError.invalidChoice(choiceIndex) }
        let choice = event.choices[choiceIndex]
        guard choice.isAvailable(in: state) else { throw GameEngineError.requirementNotMet }

        var outcome = TurnOutcome(consequence: choice.consequence)
        let tired = fatigue(at: state.currentLocation, in: state)
        let effects = tired < 1 ? choice.effects.mapValues { $0 > 0 ? max(1, Int((Double($0) * tired).rounded())) : $0 } : choice.effects
        outcome.add(state.applyStats(effects))
        if tired < 1, choice.effects.values.contains(where: { $0 > 0 }) {
            outcome.notes.append("Ici, tout le monde t'a déjà vu cette année : ça rapporte moins. Va voir ailleurs.")
        }
        state.flags.subtract(choice.clearFlags)
        state.flags.formUnion(choice.setFlags)
        for (counter, amount) in choice.counters {
            state.counters.increment(counter, by: amount)
        }
        for (castId, delta) in choice.relations {
            let applied = state.changeRelation(castId, by: delta)
            if applied != 0 { outcome.relationChanges[castId, default: 0] += applied }
        }
        for id in choice.giveItems where !state.items.contains(id) {
            state.items.insert(id)
            outcome.gainedItems.append(story.item(id)?.name ?? id)
            // A new item with a technique gets equipped right away.
            if story.item(id)?.secret != nil { state.equippedTechnique = id }
        }
        let visitXP = state.currentLocation?.visitXP ?? [:]
        outcome.add(levelUps: state.skills.gain(visitXP.merging(choice.xp, uniquingKeysWith: +)))

        if event.unique { state.seenUniqueEvents.insert(event.id) }
        state.seenEvents.insert(event.id)
        state.recentEvents = Array((state.recentEvents + [event.id]).suffix(GameState.recentMemory))
        state.pendingFollowUp = choice.followUp
        state.currentEventId = nil
        state.currentLocation = nil

        if choice.skipTurns > 0 {
            state.turn = state.freeCareer ? state.turn + choice.skipTurns : min(state.turn + choice.skipTurns, turnLimit(in: state) - 1)
            state.actionsLeft = 0
        }

        if let spec = choice.clash, castIndex[spec.opponent]?.clash != nil,
           EndingResolver.prematureEnding(for: state.stats) == nil {
            var clash = ClashState(spec: spec)
            clash.playerMeter = startingMeter(in: state)
            clash.crowdFavorite = ClashTactics.crowdFavorite(in: state.district)
            state.clash = clash
            return .clash(clash)
        }
        if let id = choice.interview, let interview = world.story.interview(id),
           EndingResolver.prematureEnding(for: state.stats) == nil {
            let running = InterviewState(interview: interview)
            state.interview = running
            return .interview(running)
        }
        if let id = choice.concert, let concert = story.concert(id),
           EndingResolver.prematureEnding(for: state.stats) == nil {
            let running = ConcertState(concert: concert)
            state.concert = running
            return .concert(running)
        }
        if let id = choice.negotiation, let negotiation = story.negotiation(id),
           EndingResolver.prematureEnding(for: state.stats) == nil {
            let running = NegotiationState(negotiation: negotiation)
            state.negotiation = running
            return .negotiation(running)
        }
        if let id = choice.writing, let writing = story.writing(id),
           EndingResolver.prematureEnding(for: state.stats) == nil {
            let running = WritingState(writing: writing)
            state.writing = running
            return .writing(running)
        }
        if let id = choice.minigame, let minigame = story.minigame(id),
           EndingResolver.prematureEnding(for: state.stats) == nil {
            let running = MinigameState(minigame: minigame)
            state.minigame = running
            return .minigame(running)
        }
        return .outcome(finishAction(outcome, in: &state))
    }

    // MARK: - Interviews

    func interview(_ id: String) -> Interview? { world.story.interview(id) }

    /// Answers the current question (nil = time ran out). Returns the updated interview.
    func answerInterview(_ answerIndex: Int?, in state: inout GameState) throws -> InterviewState {
        guard var running = state.interview, let interview = interview(running.id) else { throw GameEngineError.noInterview }
        guard !running.isOver else { return running }
        let question = interview.questions[running.questionIndex]
        var delta = -interview.timeoutPenalty
        var reaction = "Blanc à l'antenne. Trois secondes de silence, c'est très long à la radio."
        if let answerIndex {
            guard question.answers.indices.contains(answerIndex) else { throw GameEngineError.invalidChoice(answerIndex) }
            let answer = question.answers[answerIndex]
            guard answer.isAvailable(in: state) else { throw GameEngineError.requirementNotMet }
            delta = answer.hype
            reaction = answer.reaction
            state.applyStats(answer.effects)
            for (castId, change) in answer.relations { state.changeRelation(castId, by: change) }
        }
        let before = running.hype
        running.hype = min(max(running.hype + delta, InterviewState.hypeRange.lowerBound), InterviewState.hypeRange.upperBound)
        running.log.append(InterviewLogEntry(question: running.questionIndex, answer: answerIndex,
                                             hypeDelta: running.hype - before, reaction: reaction))
        running.questionIndex += 1
        state.interview = running
        return running
    }

    /// Applies the result of a finished interview (the action was spent by the choice that started it).
    func finishInterview(in state: inout GameState) throws -> TurnOutcome {
        guard let running = state.interview, let interview = interview(running.id) else { throw GameEngineError.noInterview }
        guard running.isOver else { throw GameEngineError.interviewNotOver }
        let result = running.passed ? interview.win : interview.lose
        var outcome = TurnOutcome(consequence: result.consequence)
        outcome.interview = running
        outcome.add(state.applyStats(result.effects))
        outcome.add(levelUps: state.skills.gain(result.xp))
        state.flags.formUnion(result.setFlags)
        for (castId, delta) in result.relations {
            let applied = state.changeRelation(castId, by: delta)
            if applied != 0 { outcome.relationChanges[castId, default: 0] += applied }
        }
        state.interview = nil
        return finishAction(outcome, in: &state)
    }

    // MARK: - Concerts

    func concert(_ id: String) -> Concert? { story.concert(id) }

    /// Notes of the current song.
    func concertChart(in state: GameState) -> [ConcertNote] {
        guard let running = state.concert, let concert = concert(running.id),
              concert.songs.indices.contains(running.songIndex) else { return [] }
        return ConcertEngine.chart(for: concert.songs[running.songIndex],
                                   seed: ConcertEngine.seed(running.id, song: running.songIndex))
    }

    /// Commits a played song. Then either its interlude waits, or the next song starts.
    func concertSongFinished(_ judgments: [ConcertJudgment], in state: inout GameState) throws -> ConcertState {
        guard var running = state.concert, let concert = concert(running.id) else { throw GameEngineError.noConcert }
        guard !running.isOver, !running.inInterlude else { return running }
        ConcertEngine.apply(judgments, to: &running)
        if concert.songs[running.songIndex].interlude != nil {
            running.inInterlude = true
        } else {
            running.songIndex += 1
        }
        state.concert = running
        return running
    }

    /// Answers the interlude after a song. Returns the reaction text.
    func concertInterlude(_ optionIndex: Int, in state: inout GameState) throws -> String {
        guard var running = state.concert, let concert = concert(running.id),
              running.inInterlude, let interlude = concert.songs[running.songIndex].interlude else {
            throw GameEngineError.noConcert
        }
        guard interlude.options.indices.contains(optionIndex) else { throw GameEngineError.invalidChoice(optionIndex) }
        let option = interlude.options[optionIndex]
        running.hype = min(max(running.hype + option.hype, ConcertState.hypeRange.lowerBound),
                           ConcertState.hypeRange.upperBound)
        running.inInterlude = false
        running.songIndex += 1
        state.concert = running
        return option.reaction
    }

    func finishConcert(in state: inout GameState) throws -> TurnOutcome {
        guard let running = state.concert, let concert = concert(running.id) else { throw GameEngineError.noConcert }
        guard running.isOver else { throw GameEngineError.concertNotOver }
        let result = running.passed ? concert.win : concert.lose
        var outcome = TurnOutcome(consequence: result.consequence)
        outcome.concert = running
        outcome.add(state.applyStats(result.effects))
        outcome.add(levelUps: state.skills.gain(result.xp))
        state.flags.formUnion(result.setFlags)
        for (castId, delta) in result.relations {
            let applied = state.changeRelation(castId, by: delta)
            if applied != 0 { outcome.relationChanges[castId, default: 0] += applied }
        }
        state.concert = nil
        return finishAction(outcome, in: &state)
    }

    // MARK: - Negotiations

    func negotiation(_ id: String) -> Negotiation? { story.negotiation(id) }

    func negotiate(_ optionIndex: Int, in state: inout GameState) throws -> NegotiationState {
        guard var running = state.negotiation, let negotiation = negotiation(running.id) else {
            throw GameEngineError.noNegotiation
        }
        guard !running.isOver else { return running }
        let clause = negotiation.clauses[running.clauseIndex]
        guard clause.options.indices.contains(optionIndex) else { throw GameEngineError.invalidChoice(optionIndex) }
        let option = clause.options[optionIndex]
        guard option.isAvailable(in: state) else { throw GameEngineError.requirementNotMet }
        NegotiationEngine.apply(option, optionIndex: optionIndex, businessLevel: clashLevels(in: state)(.business),
                                to: &running)
        state.negotiation = running
        return running
    }

    func finishNegotiation(in state: inout GameState) throws -> TurnOutcome {
        guard let running = state.negotiation, let negotiation = negotiation(running.id) else {
            throw GameEngineError.noNegotiation
        }
        guard running.isOver else { throw GameEngineError.negotiationNotOver }
        let result = running.passed ? negotiation.win : negotiation.lose
        var outcome = TurnOutcome(consequence: result.consequence)
        outcome.negotiation = running
        outcome.add(state.applyStats(result.effects))
        outcome.add(levelUps: state.skills.gain(result.xp))
        state.flags.formUnion(result.setFlags)
        for (castId, delta) in result.relations {
            let applied = state.changeRelation(castId, by: delta)
            if applied != 0 { outcome.relationChanges[castId, default: 0] += applied }
        }
        state.negotiation = nil
        return finishAction(outcome, in: &state)
    }

    // MARK: - Writing sessions

    func writing(_ id: String) -> Writing? { story.writing(id) }

    func currentWritingRound(in state: GameState) -> WritingRound? {
        guard let running = state.writing, let writing = writing(running.id),
              writing.rounds.indices.contains(running.roundIndex) else { return nil }
        return writing.rounds[running.roundIndex]
    }

    /// Seconds the player gets for the current couplet.
    func writingTime(in state: GameState) -> Double {
        guard let round = currentWritingRound(in: state) else { return 0 }
        return WritingEngine.time(for: round, plumeLevel: state.skills.level(.plume))
    }

    /// The opponent's line lands (no-op without an attack, or if it already landed).
    func writingAttack(in state: inout GameState) throws -> WritingState {
        guard var running = state.writing else { throw GameEngineError.noWriting }
        guard let round = currentWritingRound(in: state) else { return running }
        WritingEngine.applyAttack(of: round, to: &running)
        state.writing = running
        return running
    }

    /// Your second line. nil = the timer ran out.
    func writeLine(_ optionIndex: Int?, in state: inout GameState) throws -> WritingState {
        guard var running = state.writing, let writing = writing(running.id) else { throw GameEngineError.noWriting }
        guard let round = currentWritingRound(in: state) else { return running }
        var option: WritingOption?
        if let optionIndex {
            guard round.options.indices.contains(optionIndex) else { throw GameEngineError.invalidChoice(optionIndex) }
            guard round.options[optionIndex].isAvailable(in: state) else { throw GameEngineError.requirementNotMet }
            option = round.options[optionIndex]
        }
        WritingEngine.write(option, index: optionIndex, in: round, timeoutPenalty: writing.timeoutPenalty, to: &running)
        state.writing = running
        return running
    }

    func finishWriting(in state: inout GameState) throws -> TurnOutcome {
        guard let running = state.writing, let writing = writing(running.id) else { throw GameEngineError.noWriting }
        guard running.isOver else { throw GameEngineError.writingNotOver }
        let result = running.passed ? writing.win : writing.lose
        var outcome = TurnOutcome(consequence: result.consequence)
        outcome.writing = running
        outcome.add(state.applyStats(result.effects))
        outcome.add(levelUps: state.skills.gain(result.xp))
        state.flags.formUnion(result.setFlags)
        for (castId, delta) in result.relations {
            let applied = state.changeRelation(castId, by: delta)
            if applied != 0 { outcome.relationChanges[castId, default: 0] += applied }
        }
        state.writing = nil
        return finishAction(outcome, in: &state)
    }

    // MARK: - Mini-games

    func minigame(_ id: String) -> Minigame? { story.minigame(id) ?? (id == Arcade.beatbox.id ? Arcade.beatbox : nil) }

    /// Punchliner: the round being played, and the order its endings are shown in (stable).
    func punchlinerRound(in state: GameState) -> (round: PunchlinerRound, order: [Int])? {
        guard let running = state.minigame, running.kind == .punchliner, let minigame = minigame(running.id),
              minigame.rounds.indices.contains(running.round) else { return nil }
        let round = minigame.rounds[running.round]
        return (round, PunchlinerEngine.order(for: round, seed: PunchlinerEngine.seed(running.id, round: running.round)))
    }

    /// Punchliner: the player picks an ending (nil = the timer ran out). Returns the reaction.
    func dropPunchline(_ choice: Int?, in state: inout GameState) throws -> String {
        guard var running = state.minigame, let current = punchlinerRound(in: state) else {
            throw GameEngineError.noMinigame
        }
        if let choice, !current.round.endings.indices.contains(choice) { throw GameEngineError.invalidChoice(choice) }
        let (points, reaction) = PunchlinerEngine.judge(choice, in: current.round)
        let ending = choice.map { current.round.endings[$0].text } ?? "…"
        let verse = [current.round.setup, "\(current.round.lead) \(ending)"].map { TextTemplate.render($0, for: state.rapper) }
        running.lyrics = (running.lyrics ?? []) + verse
        if points >= PunchlinerEngine.bestScore, running.hook == nil, let choice {
            running.hook = TextTemplate.render(current.round.endings[choice].text, for: state.rapper)
        }
        running.points += points
        running.log.append(reaction)
        running.round += 1
        state.minigame = running
        return reaction
    }

    /// Cale la platine: the player stopped the fader `elapsed` seconds into the current run.
    func stopPlatine(after elapsed: Double, in state: inout GameState) throws -> (pitch: Double, reaction: String) {
        guard var running = state.minigame, running.kind == .platine, !running.isOver else { throw GameEngineError.noMinigame }
        let pitch = PlatineEngine.pitch(at: max(0, elapsed), run: running.round)
        let (points, reaction) = PlatineEngine.judge(pitch: pitch)
        running.points += points
        running.log.append(reaction)
        running.round += 1
        state.minigame = running
        return (pitch, reaction)
    }

    /// Signing: the artists on offer, and the budget this player has.
    func signingOffer(in state: GameState) -> (spec: SigningSpec, budget: Int)? {
        guard let running = state.minigame, running.kind == .signing,
              let spec = minigame(running.id)?.signing else { return nil }
        return (spec, SigningEngine.budget(spec, businessLevel: state.skills.level(.business)))
    }

    /// Signing: the player signs these artists. Returns what happens to each of them.
    func sign(_ ids: [String], in state: inout GameState) throws -> [String] {
        guard var running = state.minigame, !running.isOver, let offer = signingOffer(in: state) else {
            throw GameEngineError.noMinigame
        }
        guard SigningEngine.isAffordable(ids, in: offer.spec, businessLevel: state.skills.level(.business)) else {
            throw GameEngineError.invalidChoice(ids.count)
        }
        let reveals = ids.compactMap { id in offer.spec.artists.first { $0.id == id }?.reveal }
        running.signed = ids
        running.points = SigningEngine.points(ids, in: offer.spec)
        running.log = reveals
        running.round = 1
        state.minigame = running
        return reveals
    }

    /// Fuir la foule: the chase screen reports how it ended.
    func endChase(escaped: Bool, in state: inout GameState) throws {
        guard var running = state.minigame, running.kind == .fuite else { throw GameEngineError.noMinigame }
        running.escaped = escaped
        state.minigame = running
    }

    /// Score from 0 to 1.
    func minigameScore(_ running: MinigameState) -> Double {
        switch running.kind {
        case .punchliner:
            let best = minigame(running.id).map(PunchlinerEngine.maxPoints) ?? 0
            return best > 0 ? Double(running.points) / Double(best) : 0
        case .platine:
            return Double(running.points) / Double(PlatineEngine.runs * PlatineEngine.maxPoints)
        case .beatbox:
            return Double(running.points) / Double(BeatboxEngine.rounds)
        case .fuite:
            return running.escaped == true ? 1 : 0
        case .signing:
            let target = minigame(running.id)?.signing?.target ?? 0
            return target > 0 ? min(1, Double(running.points) / Double(target)) : 0
        }
    }

    func finishMinigame(in state: inout GameState) throws -> TurnOutcome {
        guard let running = state.minigame, let minigame = minigame(running.id) else { throw GameEngineError.noMinigame }
        guard running.isOver else { throw GameEngineError.minigameNotOver }
        let result = minigameScore(running) >= minigame.passScore ? minigame.win : minigame.lose
        var outcome = TurnOutcome(consequence: result.consequence)
        outcome.minigame = running
        outcome.add(state.applyStats(result.effects))
        outcome.add(levelUps: state.skills.gain(result.xp))
        state.flags.formUnion(result.setFlags)
        for (castId, delta) in result.relations {
            let applied = state.changeRelation(castId, by: delta)
            if applied != 0 { outcome.relationChanges[castId, default: 0] += applied }
        }
        if let hook = running.hook, !state.hooks.contains(hook) { state.hooks.append(hook) }
        state.minigame = nil
        return finishAction(outcome, in: &state)
    }

    // MARK: - Story

    var story: Story { world.story }

    func currentChapter(in state: GameState) -> Chapter? { story.chapter(state.chapter) }

    func currentObjective(in state: GameState) -> Objective? {
        guard let chapter = currentChapter(in: state), chapter.objectives.indices.contains(state.objectiveIndex) else {
            return nil
        }
        return chapter.objectives[state.objectiveIndex]
    }

    /// Story event triggered by going through this door, if the current objective wants it.
    func storyEvent(at location: Location, in state: GameState) -> GameEvent? {
        guard let objective = currentObjective(in: state), objective.trigger?.location == location,
              let id = objective.event else { return nil }
        return eventIndex[id]
    }

    /// Story event triggered by talking to this character.
    func storyEvent(forNPC castId: String, in state: GameState) -> GameEvent? {
        guard let objective = currentObjective(in: state), objective.trigger?.npc == castId,
              let id = objective.event else { return nil }
        return eventIndex[id]
    }

    /// Advances objectives whose conditions hold; queues their cinematics and the chapter outro.
    func applyStoryProgress(_ outcome: inout TurnOutcome, in state: inout GameState) {
        guard let chapter = currentChapter(in: state) else { return }
        while chapter.objectives.indices.contains(state.objectiveIndex) {
            let objective = chapter.objectives[state.objectiveIndex]
            guard objective.conditions.isSatisfied(by: state) else { return }
            state.objectiveIndex += 1
            outcome.completedObjectives.append(objective.label)
            if let cinematic = objective.cinematic { state.pendingCinematic = cinematic }
        }
        // Chapter done: the outro plays, then `cinematicFinished` opens the next chapter.
        if let outro = chapter.outro, !state.seenCinematics.contains(outro) {
            state.pendingCinematic = outro
        } else {
            closeChapter(in: &state)
        }
    }

    /// To call when a cinematic has been watched to the end.
    func cinematicFinished(_ id: String, in state: inout GameState) {
        state.seenCinematics.insert(id)
        if state.pendingCinematic == id { state.pendingCinematic = nil }
        if let chapter = currentChapter(in: state), chapter.outro == id,
           state.objectiveIndex >= chapter.objectives.count {
            closeChapter(in: &state)
        }
    }

    private func closeChapter(in state: inout GameState) {
        let finale = currentChapter(in: state)?.isFinale ?? false
        state.flags.insert("chapitre_\(state.chapter)")
        if finale {
            state.pendingCinematic = nil
            if state.freeCareer {
                // The player decides: hang up the mic as a legend, or keep clashing the new generation.
                state.finaleChoicePending = true
            } else {
                // The story is over: the career ends on its best note.
                state.ending = EndingResolver.finalEnding(for: state)
            }
            return
        }
        state.chapter += 1
        state.objectiveIndex = 0
        if let intro = currentChapter(in: state)?.intro { state.pendingCinematic = intro }
    }

    /// The finale hasn't been played yet.
    func isStoryUnfinished(in state: GameState) -> Bool {
        guard let finale = story.chapters.first(where: \.isFinale) else { return false }
        return !state.flags.contains("chapitre_\(finale.number)")
    }

    /// The last chapter, once the one before it is done (the epilogue after the throne).
    /// It's played outside the clock: semesters no longer pass, so the time limit can't cut it short.
    func isInEpilogue(_ state: GameState) -> Bool {
        guard let finale = story.chapters.first(where: \.isFinale), finale.number > 1 else { return false }
        return state.chapter == finale.number && isStoryUnfinished(in: state)
            && state.flags.contains("chapitre_\(finale.number - 1)")
    }

    /// Semester at which the career ends. The limit waits for the story: while the finale is still to play,
    /// the career goes into overtime, up to `GameState.overtimeTurns` more semesters.
    func turnLimit(in state: GameState) -> Int {
        GameState.totalTurns + (isStoryUnfinished(in: state) ? GameState.overtimeTurns : 0)
    }

    /// goslo radio headlines that fit the current state.
    func radioHeadlines(in state: GameState) -> [String] {
        story.radio.filter { $0.conditions.isSatisfied(by: state) }.map(\.text)
    }

    // MARK: - Clashes

    /// The opponent's profile if the chroniqueur briefed you, nil otherwise.
    func scoutingReport(for opponentId: String, in state: GameState) -> ClashProfile? {
        guard state.relation(GameEngine.chroniqueurId) >= GameEngine.scoutingRelation else { return nil }
        return castIndex[opponentId]?.clash
    }

    func clashMove<R: RandomNumberGenerator>(_ move: ClashMove, in state: inout GameState,
                                             using rng: inout R) throws -> ClashState {
        guard var clash = state.clash else { throw GameEngineError.noClash }
        guard !clash.isOver else { return clash }
        // A boss technique left uncountered lands in full before the next round.
        if clash.pendingCounter != nil {
            ClashEngine.resolveCounter(&clash, taps: 0)
            state.clash = clash
            if clash.isOver { return clash }
        }
        guard let opponent = castIndex[clash.opponentId], let profile = opponent.clash else {
            throw GameEngineError.noClash
        }
        if move == .story {
            // Your own move never costs you the game: credibility stops at 1 during a clash.
            let cost = min(ClashState.storyCredCost, max(0, state.stats.credibilite - 1))
            state.stats.apply([.credibilite: -cost])
        }
        let level = clashLevels(for: clash, in: state)
        ClashEngine.playRound(&clash, playerMove: move, playerLevel: level,
                              opponent: profile.scaled(by: clash.levelBonus), opponentName: opponent.name,
                              opponentSecret: opponent.secret, callbacks: callbacks(for: clash, in: state), using: &rng)
        state.clash = clash
        return clash
    }

    /// Freestyle (once per clash): `rhymes` chained against the clock hit the opponent, who answers as usual.
    func clashFreestyle<R: RandomNumberGenerator>(rhymes: Int, in state: inout GameState, using rng: inout R) throws -> ClashState {
        guard var clash = state.clash else { throw GameEngineError.noClash }
        guard !clash.isOver else { return clash }
        guard !clash.freestyleUsed else { throw GameEngineError.freestyleUsed }
        if clash.pendingCounter != nil {
            ClashEngine.resolveCounter(&clash, taps: 0)
            state.clash = clash
            if clash.isOver { return clash }
        }
        guard let opponent = castIndex[clash.opponentId], let profile = opponent.clash else {
            throw GameEngineError.noClash
        }
        if rhymes >= Freestyle.maxRhymes { state.flags.insert(AchievementRules.freestyleFlag) }
        ClashEngine.playRound(&clash, playerMove: .punchline, playerFreestyle: rhymes, playerLevel: clashLevels(for: clash, in: state),
                              opponent: profile.scaled(by: clash.levelBonus), opponentName: opponent.name,
                              opponentSecret: opponent.secret, callbacks: callbacks(for: clash, in: state), using: &rng)
        state.clash = clash
        return clash
    }

    /// Triggers the player's secret technique (gauge full, once per clash), charged in rhythm at `charge` (0…1).
    /// Without a charge it hits at its base power.
    func clashSecret<R: RandomNumberGenerator>(charge: Double? = nil, in state: inout GameState, using rng: inout R) throws -> ClashState {
        guard var clash = state.clash else { throw GameEngineError.noClash }
        guard !clash.isOver else { return clash }
        if clash.pendingCounter != nil {
            ClashEngine.resolveCounter(&clash, taps: 0)
            state.clash = clash
            if clash.isOver { return clash }
        }
        guard clash.playerSecretReady else { throw GameEngineError.secretNotReady }
        guard let opponent = castIndex[clash.opponentId], let profile = opponent.clash else {
            throw GameEngineError.noClash
        }
        let level = clashLevels(for: clash, in: state)
        if let charge, charge >= AchievementRules.perfectCharge { state.flags.insert(AchievementRules.chargeFlag) }
        ClashEngine.playRound(&clash, playerMove: .presence, playerSecret: playerSecret(in: state), playerCharge: charge,
                              playerLevel: level, opponent: profile.scaled(by: clash.levelBonus),
                              opponentName: opponent.name, opponentSecret: opponent.secret,
                              callbacks: callbacks(for: clash, in: state), using: &rng)
        state.clash = clash
        return clash
    }

    /// The player tapped `taps` times against the boss's technique: it lands, softened.
    func counterSecret(taps: Int, in state: inout GameState) throws -> ClashState {
        guard var clash = state.clash else { throw GameEngineError.noClash }
        ClashEngine.resolveCounter(&clash, taps: taps)
        state.clash = clash
        return clash
    }

    // MARK: - Items

    func ownedItems(in state: GameState) -> [Item] {
        (story.items + Shop.gear.map(\.item)).filter { state.items.contains($0.id) }
    }

    /// The secret technique: the one picked in the notebook, otherwise the last owned item that has one,
    /// otherwise the style's.
    func playerSecret(in state: GameState) -> SecretTechnique {
        if let id = state.equippedTechnique, let chosen = availableTechniques(in: state).first(where: { $0.id == id }) {
            return chosen.secret
        }
        return ownedItems(in: state).last { $0.secret != nil }?.secret ?? state.rapper.style.secret
    }

    /// Techniques the player can equip: the style's, those of owned items, and those unlocked so far.
    func availableTechniques(in state: GameState) -> [EquippableTechnique] {
        [EquippableTechnique(id: GameEngine.styleTechniqueId, secret: state.rapper.style.secret)]
            + ownedItems(in: state).compactMap { item in item.secret.map { EquippableTechnique(id: item.id, secret: $0) } }
            + story.techniques.filter { $0.unlock.isSatisfied(by: state) }.map { EquippableTechnique(id: $0.id, secret: $0.secret) }
    }

    static let styleTechniqueId = "style"

    func equipTechnique(_ id: String, in state: inout GameState) {
        guard availableTechniques(in: state).contains(where: { $0.id == id }) else { return }
        state.equippedTechnique = id
    }

    /// Announces (and equips) techniques whose unlock conditions just came true.
    private func applyTechniqueUnlocks(_ outcome: inout TurnOutcome, in state: inout GameState) {
        for technique in story.techniques
        where !state.knownTechniques.contains(technique.id) && technique.unlock.isSatisfied(by: state) {
            state.knownTechniques.insert(technique.id)
            state.equippedTechnique = technique.id
            outcome.unlockedTechniques.append(technique.secret.name)
        }
    }

    /// Bonus levels from items for a move.
    func itemBonus(for move: ClashMove, in state: GameState) -> Int {
        ownedItems(in: state).reduce(0) { $0 + $1.clashBonus[move, default: 0] }
    }

    /// Effective level per skill in a clash (skill level + item bonuses, capped at 10).
    func clashLevels(in state: GameState) -> (Skill) -> Int {
        let skills = state.skills
        let difficulty = state.difficulty.clashLevelBonus
        let bonus = Dictionary(uniqueKeysWithValues: ClashMove.allCases.map { ($0.skill, itemBonus(for: $0, in: state) + difficulty) })
        return { skill in max(1, min(Skills.maxLevel, skills.level(skill) + bonus[skill, default: 0])) }
    }

    var wildOpponents: [CastMember] { world.cast.filter { $0.wild && $0.clash != nil } }

    /// Who you can bump into in this city's terrain vague. The locals turn up twice as often as the
    /// characters you meet everywhere.
    func wildOpponents(in city: City) -> [CastMember] {
        let pool = wildOpponents.filter { $0.belongs(to: city) }
        return pool + pool.filter { $0.cities != nil }
    }

    /// Starts a wild clash in the terrain vague (no action spent).
    func startWildClash<R: RandomNumberGenerator>(in state: inout GameState, using rng: inout R) -> ClashState? {
        guard !state.isOver, state.currentEventId == nil, state.clash == nil,
              var opponent = wildOpponents(in: state.rapper.city).randomElement(using: &rng) else { return nil }
        // Now and then, a rare local turns up instead (the pigeon of Lille…).
        if let rare = Secrets.rareWild[state.rapper.city].flatMap({ castMember($0) }), rare.clash != nil,
           Int.random(in: 0..<Secrets.rareWildOdds, using: &rng) == 0 {
            opponent = rare
        }
        let spec = ClashSpec(
            opponent: opponent.id,
            win: ClashResultSpec(effects: GameEngine.wildRewards.win,
                                 consequence: "\(opponent.name) repart la tête basse. Trois passants ont filmé, un a mis la musique.",
                                 setFlags: ["sauvage_battu_\(opponent.id)"]),
            lose: ClashResultSpec(effects: GameEngine.wildRewards.lose,
                                  consequence: "\(opponent.name) t'a mis à l'amende devant tout le monde. Ton ego boite jusqu'à chez toi.")
        )
        var clash = ClashState(spec: spec, isWild: true, levelBonus: (state.year - 1) / 2)
        clash.playerMeter = startingMeter(in: state)
        clash.crowdFavorite = ClashTactics.crowdFavorite(in: state.district)
        state.clash = clash
        state.stepsSinceWild = 0
        return clash
    }

    /// Fleeing is only possible in the terrain vague.
    func fleeWildClash(in state: inout GameState) -> Bool {
        guard let clash = state.clash, clash.isWild else { return false }
        state.clash = nil
        return true
    }

    static let wildRewards = (win: [StatKind.streams: 2, .credibilite: 1], lose: [StatKind.mental: -5])
    static let wildXP = (win: 25, lose: 8)

    /// Applies the result of a finished clash.
    /// Levels gained against a boss per lost clash, up to `maxBossExperience`.
    static let maxBossExperience = 2

    /// Extra levels against this opponent: losing to a boss teaches you their game.
    func bossExperience(against opponentId: String, in state: GameState) -> Int {
        min(GameEngine.maxBossExperience, state.bossLosses[opponentId, default: 0])
    }

    /// Clash levels for the running clash, boss experience included.
    func clashLevels(for clash: ClashState, in state: GameState) -> (Skill) -> Int {
        let base = clashLevels(in: state)
        let bonus = clash.isBoss ? bossExperience(against: clash.opponentId, in: state) : 0
        return { skill in min(Skills.maxLevel, base(skill) + bonus) }
    }

    func finishClash(in state: inout GameState) throws -> TurnOutcome {
        guard let clash = state.clash else { throw GameEngineError.noClash }
        guard clash.isOver else { throw GameEngineError.clashNotOver }
        if clash.isWild { return finishWildClash(clash, in: &state) }

        let won = clash.playerWon
        let result = won ? clash.spec.win : clash.spec.lose
        var outcome = TurnOutcome(consequence: result.consequence)
        outcome.clash = clash
        outcome.add(state.applyStats(result.effects))
        state.flags.formUnion(result.setFlags)
        state.counters.increment(.beefs)
        if won {
            ArtistLevel.gain(15, in: &state, outcome: &outcome)
            state.counters.increment(.clashsGagnes)
            state.flags.insert("clash_gagne_\(clash.opponentId)")
        }
        let penalty = won ? GameEngine.clashRelationPenalty.win : GameEngine.clashRelationPenalty.lose
        let applied = state.changeRelation(clash.opponentId, by: penalty)
        if applied != 0 { outcome.relationChanges[clash.opponentId] = applied }
        outcome.add(levelUps: state.skills.gain(won ? [.plume: 20, .flow: 20] : [.plume: 10]))
        if !won && clash.isBoss {
            let before = bossExperience(against: clash.opponentId, in: state)
            state.bossLosses[clash.opponentId, default: 0] += 1
            if bossExperience(against: clash.opponentId, in: state) > before {
                let name = castMember(clash.opponentId)?.name ?? "ce boss"
                outcome.consequence += " Tu as appris de ta défaite : +1 niveau contre \(name) au prochain clash."
            }
        }

        state.clash = nil
        return finishAction(outcome, in: &state)
    }

    /// A wild clash only grants XP and small effects: no beef, no time passing.
    private func finishWildClash(_ clash: ClashState, in state: inout GameState) -> TurnOutcome {
        let won = clash.playerWon
        var outcome = TurnOutcome(consequence: won ? clash.spec.win.consequence : clash.spec.lose.consequence)
        outcome.clash = clash
        outcome.add(state.applyStats(won ? clash.spec.win.effects : clash.spec.lose.effects))
        if won {
            ArtistLevel.gain(4, in: &state, outcome: &outcome)
            state.counters.increment(.victoiresTerrain)
            state.flags.formUnion(clash.spec.win.setFlags)
        }
        let amount = won ? GameEngine.wildXP.win : GameEngine.wildXP.lose
        let gains = Dictionary(uniqueKeysWithValues: clash.movesUsed.map { ($0.skill, amount) })
        outcome.add(levelUps: state.skills.gain(gains))
        state.clash = nil
        applyQuestProgress(&outcome, in: &state)
        applyStoryProgress(&outcome, in: &state)
        checkChallenges(&outcome, in: &state)
        state.ending = EndingResolver.prematureEnding(for: state.stats)
        outcome.ending = state.ending
        return outcome
    }

    // MARK: - End of action

    /// Quests, early ending, and end of semester when actions run out.
    func finishAction(_ outcome: TurnOutcome, in state: inout GameState) -> TurnOutcome {
        var outcome = outcome
        applyQuestProgress(&outcome, in: &state)
        applyStoryProgress(&outcome, in: &state)
        applyTechniqueUnlocks(&outcome, in: &state)
        refreshChallenges(in: &state)
        checkChallenges(&outcome, in: &state)

        var ending = EndingResolver.prematureEnding(for: state.stats)
        if ending == nil && state.pendingFollowUp == nil && state.actionsLeft <= 0 {
            let turnEnd = Economy.turnEnd(for: state)
            outcome.add(state.stats.apply(turnEnd.effects))
            outcome.notes += turnEnd.notes
            if state.freeCareer { outcome.add(state.stats.apply(GameEngine.agingUpkeep(turn: state.turn))) }
            outcome.add(sellAlbums(in: &state))
            payChart(&outcome, in: &state)
            outcome.add(decorIncome(in: &state))
            checkChallenges(&outcome, in: &state)
            let limit = turnLimit(in: state)
            if !isInEpilogue(state) { state.turn = state.freeCareer ? state.turn + 1 : min(state.turn + 1, limit) }
            // Burn-out: one action only.
            state.actionsLeft = state.stats.mental < Economy.burnout ? 1 : GameState.actionsPerTurn
            if state.isNewYear { state.visitsThisYear = [:] }
            refreshChallenges(in: &state)
            state.challengedThisSemester = []
            outcome.semesterEnded = true
            ending = EndingResolver.prematureEnding(for: state.stats)
                ?? (!state.freeCareer && state.turn >= limit ? EndingResolver.finalEnding(for: state) : nil)
        }
        state.ending = ending
        outcome.ending = ending
        return outcome
    }

    /// Advances steps whose conditions hold (in order) and pays out completed quests.
    func applyQuestProgress(_ outcome: inout TurnOutcome, in state: inout GameState) {
        for quest in world.quests where isQuestActive(quest, in: state) {
            var step = state.questProgress[quest.id, default: 0]
            while quest.steps.indices.contains(step), quest.steps[step].conditions.isSatisfied(by: state) {
                step += 1
            }
            state.questProgress[quest.id] = step
            if step >= quest.steps.count {
                state.completedQuests.insert(quest.id)
                state.flags.insert("quete_\(quest.id)")
                outcome.add(state.applyStats(quest.reward.effects))
                outcome.add(levelUps: state.skills.gain(quest.reward.xp))
                outcome.completedQuests.append(quest)
            }
        }
    }
}
