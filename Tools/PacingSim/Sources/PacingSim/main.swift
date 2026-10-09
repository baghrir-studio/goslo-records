import Foundation

// Story pacing simulator: plays thousands of careers with a player who follows the story,
// and measures how many reach the finale before the semester limit.
//
//   swift run -c release PacingSim [careers per profile] [path/to/Resources]
//   TRACE=1 also prints every story action and every premature ending.

/// How well the simulated player handles the mini-games.
struct Profile {
    let name: String
    /// Chance to play the opponent's weak spot in a clash (otherwise a random move).
    let clashSkill: Double
    /// Chance to pick the best answer / line / option (otherwise a random available one).
    let pickBest: Double
    /// Chance to let an interview or writing timer run out.
    let timeout: Double
    /// Concert: chance of a perfect, then a good (the rest are misses).
    let perfect: Double
    let good: Double
    /// Wild clashes per action, from walking through the grass between doors.
    let wildPerAction: Double

    static let all = [
        Profile(name: "expert", clashSkill: 0.95, pickBest: 0.95, timeout: 0.02, perfect: 0.70, good: 0.25, wildPerAction: 0.3),
        Profile(name: "moyen", clashSkill: 0.65, pickBest: 0.70, timeout: 0.06, perfect: 0.45, good: 0.38, wildPerAction: 0.3),
        Profile(name: "débutant", clashSkill: 0.35, pickBest: 0.45, timeout: 0.12, perfect: 0.30, good: 0.42, wildPerAction: 0.3),
    ]
}

struct Result {
    var ending: Ending?
    /// Story finished (the finale closed the career).
    var finished: Bool
    var chapterReached: Int
    var turn: Int
    var storyActions = 0
    var retries = 0
    var fillerActions = 0
    var stuck = false
    // Economy.
    var level = 1
    /// Money at the start of S5, S10, S15 (absent: the career ended before).
    var money: [Int: Int] = [:]
    var buildings = 0
    var firstBuildTurn: Int?
    var upgrades = 0
    var collected = 0
    /// Synergies at work on the map at the end.
    var synergies = 0
    var spent = 0
}

let trace = ProcessInfo.processInfo.environment["TRACE"] != nil
/// NOBUILD=1 plays without buying buildings (the economy baseline).
let builds = ProcessInfo.processInfo.environment["NOBUILD"] == nil

final class Player {
    let engine: GameEngine
    let profile: Profile
    var rng: SeededGenerator
    var state: GameState
    var result = Result(ending: nil, finished: false, chapterReached: 1, turn: 0)
    /// Objectives already attempted once (a second attempt is a retry).
    var attempted: Set<String> = []

    init(engine: GameEngine, profile: Profile, seed: UInt64) {
        self.engine = engine
        self.profile = profile
        rng = SeededGenerator(seed: seed)
        let style = Style.allCases[Int(seed % UInt64(Style.allCases.count))]
        state = engine.newGame(rapper: Rapper(name: "Sim", city: .paris, style: style))
    }

    func chance(_ p: Double) -> Bool { Double.random(in: 0..<1, using: &rng) < p }

    // MARK: Main loop

    func play() -> Result {
        var guardCounter = 0
        var lastTurn = state.turn
        while !state.isOver {
            guardCounter += 1
            if guardCounter > 2_000 { result.stuck = true; break }
            if state.turn != lastTurn {
                lastTurn = state.turn
                if [5, 10, 15].contains(state.turn + 1) { result.money[state.turn + 1] = state.stats.argent }
                if builds { manageBuildings() }
            }
            if let cinematic = state.pendingCinematic {
                engine.cinematicFinished(cinematic, in: &state)
                continue
            }
            if state.pendingFollowUp != nil {
                if let event = engine.takeFollowUp(in: &state) { resolve(event) }
                continue
            }
            takeAction()
        }
        result.ending = state.ending
        result.finished = state.flags.contains("chapitre_\(engine.story.chapters.map(\.number).max() ?? 0)")
        result.chapterReached = state.chapter
        result.turn = state.turn
        result.level = ArtistLevel.level(xp: state.artistXP)
        result.synergies = state.placed.reduce(0) { $0 + engine.income(of: $1, in: state).synergies.count }
        return result
    }

    // MARK: Buildings

    /// A player who builds: at each new period, picks up what the buildings made, then buys the best building
    /// they can afford while keeping a cushion (placed where it starts the most synergies), or else upgrades one.
    func manageBuildings() {
        for item in state.placed { result.collected += engine.collect(item.id, in: &state) }
        let cushion = 25
        let level = ArtistLevel.level(xp: state.artistXP)
        func value(_ income: [StatKind: Int]) -> Double {
            income.reduce(0) { $0 + Double($1.value) * ($1.key == .argent ? 1 : 0.6) }
        }
        let affordable = Decor.allCases.filter { $0.isBuilding && level >= $0.minLevel && state.stats.argent - $0.price >= cushion }
        if !affordable.isEmpty, let map = engine.currentMap(in: state) {
            let player = map.spawn
            let anchors = (0..<map.height).flatMap { y in (0..<map.width).map { TilePoint(x: $0, y: y) } }
            // Worth: what it pays, plus the synergies it could start, minus a little for each copy already owned.
            func score(_ decor: Decor) -> Double {
                let synergies = anchors.lazy.map { self.engine.placementSynergies(decor, at: $0, in: self.state).count }.max() ?? 0
                let copies = state.placed.filter { $0.decor == decor }.count
                return value(decor.perTurn) + Double(synergies) - Double(copies)
            }
            let scored = affordable.map { ($0, score($0)) }
            let best = scored.max { ($0.1, $0.0.price) < ($1.1, $1.0.price) }!.0
            let ranked = anchors.map { ($0, engine.placementSynergies(best, at: $0, in: state).count) }
                .sorted { $0.1 > $1.1 }
            if let pick = ranked.first(where: { engine.placementRefusal(best, at: $0.0, in: state, player: player) == nil }),
               (try? engine.place(best, at: pick.0, in: &state, player: player)) != nil {
                result.buildings += 1
                result.spent += best.price
                if result.firstBuildTurn == nil { result.firstBuildTurn = state.turn }
                if trace { print("S\(state.turn + 1) construit \(best.name) (\(pick.1) synergies)") }
                return
            }
        }
        // Nothing new to build: upgrade the building that pays most.
        let upgradable = state.placed.filter { item in
            engine.upgradeRefusal(item.id, in: state) == nil
                && state.stats.argent - (item.decor.upgradeCost(from: item.level) ?? 999) >= cushion
        }
        if let item = upgradable.max(by: { value($0.perTurn) < value($1.perTurn) }),
           let cost = item.decor.upgradeCost(from: item.level), (try? engine.upgrade(item.id, in: &state)) != nil {
            result.upgrades += 1
            result.spent += cost
        }
    }

    var requiredFlags: Set<String> {
        Set(engine.currentObjective(in: state)?.conditions.requiredFlags ?? [])
    }

    func takeAction() {
        // Walking between doors crosses the grass now and then (free).
        if chance(profile.wildPerAction) { wildClash() }
        if state.isOver { return }

        guard let objective = engine.currentObjective(in: state) else {
            // Past the last chapter (should not happen: the finale ends the career).
            filler(); return
        }
        // Stats in the red: a sensible player takes care of them first.
        if let low = lowestStat(), state.stats[low] < 12 {
            filler(); return
        }
        if let trigger = objective.trigger {
            let event: GameEvent?
            if let npc = trigger.npc {
                event = try? engine.talk(to: npc, challenge: trigger.spot, in: &state, using: &rng)
            } else if let location = trigger.location, engine.isUnlocked(location, in: state) {
                event = try? engine.visit(location, in: &state, using: &rng)
            } else {
                event = nil
            }
            if trace { print("S\(state.turn + 1) a\(state.actionsLeft) ch\(state.chapter) \(objective.id) -> \(event?.id ?? "nil")") }
            if let event, event.id == objective.event {
                result.storyActions += 1
                if !attempted.insert(objective.id).inserted { result.retries += 1 }
                resolve(event)
                return
            }
            if let event { resolve(event); result.fillerActions += 1; return }
            filler()
        } else if objective.conditions.minCounters[.victoiresTerrain] != nil {
            // Terrain vague: wild clashes until the counter is reached (no action spent).
            var tries = 0
            while engine.currentObjective(in: state)?.id == objective.id, !state.isOver, tries < 30 {
                wildClash(); tries += 1
                var outcome = TurnOutcome(consequence: "")
                engine.applyStoryProgress(&outcome, in: &state)
            }
            if engine.currentObjective(in: state)?.id == objective.id { filler() }
        } else {
            filler()
        }
    }

    // MARK: Events

    func lowestStat() -> StatKind? {
        StatKind.allCases.min { state.stats[$0] < state.stats[$1] }
    }

    /// Does this choice (or what it starts) set one of the current objective's flags?
    func advances(_ choice: EventChoice, depth: Int = 0) -> Bool {
        let wanted = requiredFlags
        if wanted.isEmpty { return false }
        var flags = Set(choice.setFlags)
        let story = engine.story
        if let clash = choice.clash { flags.formUnion(clash.win.setFlags); flags.insert("clash_gagne_\(clash.opponent)") }
        if let id = choice.interview, let i = story.interview(id) { flags.formUnion(i.win.setFlags) }
        if let id = choice.concert, let c = story.concert(id) { flags.formUnion(c.win.setFlags) }
        if let id = choice.negotiation, let n = story.negotiation(id) { flags.formUnion(n.win.setFlags) }
        if let id = choice.writing, let w = story.writing(id) { flags.formUnion(w.win.setFlags) }
        if !flags.isDisjoint(with: wanted) { return true }
        if depth < 3, let next = choice.followUp, let event = engine.event(withId: next) {
            return event.choices.contains { $0.isAvailable(in: state) && advances($0, depth: depth + 1) }
        }
        return false
    }

    /// Value of a choice for a player looking after their stats.
    func comfort(_ choice: EventChoice) -> Double {
        var value = 0.0
        for (kind, delta) in choice.effects {
            let level = Double(state.stats[kind])
            value += Double(delta) * (level < 30 ? 3 : 1)
        }
        if choice.skipTurns > 0 { value -= 100 }
        return value
    }

    func resolve(_ event: GameEvent) {
        let available = event.choices.indices.filter { event.choices[$0].isAvailable(in: state) }
        guard !available.isEmpty else { return }
        let advancing = available.filter { advances(event.choices[$0]) }
        let index: Int
        if let first = advancing.first {
            index = first
        } else {
            index = available.max { comfort(event.choices[$0]) < comfort(event.choices[$1]) }!
        }
        let before = state.stats
        guard let resolution = try? engine.resolve(choiceAt: index, in: &state) else { return }
        play(resolution)
        if trace, state.ending?.isPremature == true {
            print("PREMATURE \(state.ending!) S\(state.turn + 1) ch\(state.chapter) after \(event.id)#\(index) \(before) -> \(state.stats)")
        }
    }

    func play(_ resolution: Resolution) {
        switch resolution {
        case .outcome: break
        case .clash: playClash(); _ = try? engine.finishClash(in: &state)
        case .interview: playInterview(); _ = try? engine.finishInterview(in: &state)
        case .concert: playConcert(); _ = try? engine.finishConcert(in: &state)
        case .negotiation: playNegotiation(); _ = try? engine.finishNegotiation(in: &state)
        case .writing: playWriting(); _ = try? engine.finishWriting(in: &state)
        case .minigame: playMinigame(); _ = try? engine.finishMinigame(in: &state)
        }
    }

    /// An action that isn't the story: the place that best patches the weakest stat.
    func filler() {
        guard engine.canVisit(state) else { return }
        result.fillerActions += 1
        let low = lowestStat() ?? .mental
        let preferred: [StatKind: Location] = [.mental: .chezToi, .argent: .label, .credibilite: .quartier, .streams: .reseaux]
        var location = preferred[low] ?? .chezToi
        if !engine.isUnlocked(location, in: state) { location = .chezToi }
        // The street and the phone go through their gates (`Gate.bench`, `Gate.phone`), like in the app.
        let gated: GatedVisit?
        switch location {
        case .quartier: gated = try? engine.sitOnBench(in: &state, using: &rng)
        case .reseaux: gated = try? engine.checkPhone(in: &state, using: &rng)
        default: gated = (try? engine.visit(location, in: &state, using: &rng)).map(GatedVisit.event)
        }
        switch gated {
        case .event(let event)?: resolve(event)
        case .closed?:
            guard let event = try? engine.visit(.chezToi, in: &state, using: &rng) else { return }
            resolve(event)
        case nil: return
        }
    }

    // MARK: Mini-games

    func wildClash() {
        guard engine.startWildClash(in: &state, using: &rng) != nil else { return }
        playClash()
        _ = try? engine.finishClash(in: &state)
    }

    func playClash() {
        guard let opponent = state.clash.flatMap({ engine.castMember($0.opponentId) }) else { return }
        let weakness = opponent.clash?.weakness ?? .punchline
        while let clash = state.clash, !clash.isOver {
            if clash.playerSecretReady && chance(profile.clashSkill) {
                _ = try? engine.clashSecret(in: &state, using: &rng)
                continue
            }
            var move = chance(profile.clashSkill) ? weakness : ClashMove.allCases.randomElement(using: &rng)!
            // Story Insta costs credibility: nobody sane plays it into a "Vendu" ending.
            if move == .story && state.stats.credibilite <= ClashState.storyCredCost * 3 { move = .punchline }
            if (try? engine.clashMove(move, in: &state, using: &rng)) == nil { break }
        }
    }

    func playInterview() {
        while let running = state.interview, !running.isOver, let interview = engine.interview(running.id) {
            let answers = interview.questions[running.questionIndex].answers
            let available = answers.indices.filter { answers[$0].isAvailable(in: state) }
            var pick: Int? = nil
            if !chance(profile.timeout), !available.isEmpty {
                pick = chance(profile.pickBest)
                    ? available.max { answers[$0].hype < answers[$1].hype }
                    : available.randomElement(using: &rng)
            }
            if (try? engine.answerInterview(pick, in: &state)) == nil { break }
        }
    }

    func playConcert() {
        while let running = state.concert, !running.isOver, let concert = engine.concert(running.id) {
            if running.inInterlude {
                let options = concert.songs[running.songIndex].interlude?.options ?? []
                let pick = chance(profile.pickBest)
                    ? options.indices.max { options[$0].hype < options[$1].hype } ?? 0
                    : Int.random(in: 0..<max(1, options.count), using: &rng)
                if (try? engine.concertInterlude(pick, in: &state)) == nil { break }
            } else {
                let judgments: [ConcertJudgment] = engine.concertChart(in: state).map { _ in
                    let roll = Double.random(in: 0..<1, using: &rng)
                    return roll < profile.perfect ? .perfect : (roll < profile.perfect + profile.good ? .good : .miss)
                }
                if (try? engine.concertSongFinished(judgments, in: &state)) == nil { break }
            }
        }
    }

    func playNegotiation() {
        guard let running = state.negotiation, let negotiation = engine.negotiation(running.id) else { return }
        let business = engine.clashLevels(in: state)(.business)
        // Best line: the plan that maximises royalties without a walkout (brute force over the clauses).
        func best(from current: NegotiationState) -> (royalties: Int, first: Int?) {
            if current.isOver { return (current.passed ? current.royalties : -1, nil) }
            let options = negotiation.clauses[current.clauseIndex].options
            var top: (Int, Int?) = (-2, nil)
            for i in options.indices where options[i].isAvailable(in: state) {
                var next = current
                NegotiationEngine.apply(options[i], optionIndex: i, businessLevel: business, to: &next)
                let score = best(from: next).royalties
                if score > top.0 { top = (score, i) }
            }
            return top
        }
        while let current = state.negotiation, !current.isOver {
            let options = negotiation.clauses[current.clauseIndex].options
            let available = options.indices.filter { options[$0].isAvailable(in: state) }
            let pick = chance(profile.pickBest) ? (best(from: current).first ?? available[0])
                                                : available.randomElement(using: &rng)!
            if (try? engine.negotiate(pick, in: &state)) == nil { break }
        }
    }

    func playMinigame() {
        guard let running = state.minigame else { return }
        switch running.kind {
        case .punchliner:
            while let current = engine.punchlinerRound(in: state) {
                let endings = current.round.endings
                let best = endings.indices.max { endings[$0].score < endings[$1].score }
                let choice = chance(profile.pickBest) ? best : endings.indices.randomElement(using: &rng)
                if (try? engine.dropPunchline(choice, in: &state)) == nil { break }
            }
        case .platine:
            while state.minigame?.isOver == false {
                // The fader crosses 100 % at a quarter of a swing; a good player stops close to it.
                let period = PlatineEngine.period(run: state.minigame!.round)
                let aim = period * 0.165 + Double.random(in: -0.25...0.25, using: &rng) * (1.2 - profile.pickBest)
                if (try? engine.stopPlatine(after: aim, in: &state)) == nil { break }
            }
        case .fuite:
            try? engine.endChase(escaped: chance(profile.pickBest), in: &state)
        case .beatbox:
            // Each pattern is longer: a good player keeps up a little longer.
            while state.minigame?.isOver == false {
                if (try? engine.beatbox(repeated: chance(profile.pickBest), in: &state)) == nil { break }
            }
        case .signing:
            // A careful player signs the best affordable pair; the others pick any affordable one.
            guard let offer = engine.signingOffer(in: state) else { break }
            let ids = offer.spec.artists.map(\.id)
            let business = state.skills.level(.business)
            let pairs = ids.flatMap { a in ids.map { [a, $0] } }.filter { $0[0] < $0[1] }
                .filter { SigningEngine.isAffordable($0, in: offer.spec, businessLevel: business) }
            let best = pairs.max { SigningEngine.points($0, in: offer.spec) < SigningEngine.points($1, in: offer.spec) }
            if let pick = chance(profile.pickBest) ? best : pairs.randomElement(using: &rng) {
                _ = try? engine.sign(pick, in: &state)
            }
        }
    }

    func playWriting() {
        while let running = state.writing, !running.isOver {
            guard let round = engine.currentWritingRound(in: state) else { break }
            _ = try? engine.writingAttack(in: &state)
            let available = round.options.indices.filter { round.options[$0].isAvailable(in: state) }
            var pick: Int? = nil
            if !chance(profile.timeout), !available.isEmpty {
                pick = chance(profile.pickBest)
                    ? available.max { round.options[$0].score < round.options[$1].score }
                    : available.randomElement(using: &rng)
            }
            if (try? engine.writeLine(pick, in: &state)) == nil { break }
        }
    }
}

// MARK: - Run

let arguments = CommandLine.arguments
let careers = arguments.count > 1 ? Int(arguments[1]) ?? 2_000 : 2_000
let resources = arguments.count > 2
    ? URL(fileURLWithPath: arguments[2])
    : URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../GosloRecords/GosloRecords/Resources").standardized

func data(_ name: String) throws -> Data { try Data(contentsOf: resources.appendingPathComponent("\(name).json")) }

let world = World(events: try EventLoader.load(from: data("events")),
                  cast: try EventLoader.loadCast(from: data("cast")),
                  quests: try EventLoader.loadQuests(from: data("quests")),
                  map: try EventLoader.loadMap(from: data("map")),
                  story: try EventLoader.loadStory(from: data("story")))
let engine = GameEngine(world: world)
let objectives = world.story.chapters.reduce(0) { $0 + $1.objectives.count }
print("Histoire : \(world.story.chapters.count) chapitres, \(objectives) objectifs. Carrière : \(GameState.totalTurns) semestres × \(GameState.actionsPerTurn) actions = \(GameState.totalTurns * GameState.actionsPerTurn) actions.")
print("\(careers) carrières par profil.\n")

func pct(_ n: Int, _ total: Int) -> String { String(format: "%5.1f %%", 100 * Double(n) / Double(max(total, 1))) }

for profile in Profile.all {
    var results: [Result] = []
    for i in 0..<careers {
        results.append(Player(engine: engine, profile: profile, seed: UInt64(i * 7919 + 17)).play())
    }
    let finished = results.filter(\.finished)
    let premature = results.filter { $0.ending?.isPremature ?? false }
    let survival = results.filter { !$0.finished && !($0.ending?.isPremature ?? false) }
    print("── \(profile.name) ──")
    print("  histoire finie      : \(pct(finished.count, careers))")
    print("    dont en prolongation (après S\(GameState.totalTurns)) : \(pct(finished.filter { $0.turn >= GameState.totalTurns }.count, careers))")
    print("  fin « survie »      : \(pct(survival.count, careers))  (limite de semestres atteinte avant la finale)")
    print("  fin prématurée      : \(pct(premature.count, careers))")
    if results.contains(where: \.stuck) { print("  bloquées            : \(results.filter(\.stuck).count)") }
    var chapters: [Int: Int] = [:]
    for r in survival { chapters[r.chapterReached, default: 0] += 1 }
    print("  chapitre atteint par les « survie » : \(chapters.sorted { $0.key < $1.key }.map { "ch\($0.key): \($0.value)" }.joined(separator: ", "))")
    var prematureEndings: [String: Int] = [:]
    for r in premature { prematureEndings[r.ending!.rawValue, default: 0] += 1 }
    if !prematureEndings.isEmpty { print("  fins prématurées    : \(prematureEndings.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))") }
    let mean = { (xs: [Int]) in xs.isEmpty ? 0 : Double(xs.reduce(0, +)) / Double(xs.count) }
    print(String(format: "  moyenne : %.1f actions d'histoire (dont %.1f retentatives), %.1f actions hors histoire",
                 mean(results.map(\.storyActions)), mean(results.map(\.retries)), mean(results.map(\.fillerActions))))
    if !finished.isEmpty {
        let turns = finished.map(\.turn).sorted()
        let p90 = turns[min(turns.count - 1, turns.count * 9 / 10)]
        print("  semestre de la finale (histoire finie) : médiane \(turns[turns.count / 2] + 1), 90e centile \(p90 + 1), max \(turns.last! + 1)")
    }
    let median = { (xs: [Int]) in xs.isEmpty ? 0 : xs.sorted()[xs.count / 2] }
    var levels: [Int: Int] = [:]
    for r in results { levels[r.level, default: 0] += 1 }
    print("  niveau d'artiste en fin de carrière : \(levels.sorted { $0.key < $1.key }.map { "niv\($0.key): \($0.value)" }.joined(separator: ", "))")
    print("  argent (médiane) : début S5 \(median(results.compactMap { $0.money[5] })), S10 \(median(results.compactMap { $0.money[10] })), S15 \(median(results.compactMap { $0.money[15] }))")
    if builds {
        let firsts = results.compactMap(\.firstBuildTurn)
        print(String(format: "  bâtiments : %.1f construits, %.1f améliorations, %.0f dépensés, %.0f ramassés, %.1f synergies actives (moyennes)",
                     mean(results.map(\.buildings)), mean(results.map(\.upgrades)), mean(results.map(\.spent)),
                     mean(results.map(\.collected)), mean(results.map(\.synergies))))
        print("  premier bâtiment : \(pct(firsts.count, careers)) des carrières, au semestre \(median(firsts) + 1) (médiane)")
    }
    print("")
}
