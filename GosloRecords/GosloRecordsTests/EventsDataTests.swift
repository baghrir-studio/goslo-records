import XCTest
@testable import GosloRecords

/// Validates the real data (events.json, cast.json, quests.json),
/// so a JSON edit can't break the game.
final class EventsDataTests: XCTestCase {
    private var world = World(events: [])
    private var events: [GameEvent] { world.events }

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    func testAtLeastThirtyEvents() {
        XCTAssertGreaterThanOrEqual(events.count, 30)
    }

    func testIdsAreUnique() {
        for ids in [events.map(\.id), world.cast.map(\.id), world.quests.map(\.id)] {
            XCTAssertEqual(Set(ids).count, ids.count, "ids en double : \(ids.filter { id in ids.filter { $0 == id }.count > 1 })")
        }
    }

    func testEveryEventHasTwoOrThreeChoicesAndOneAlwaysAvailable() {
        for event in events {
            XCTAssertTrue((2...3).contains(event.choices.count), "\(event.id) a \(event.choices.count) choix")
            XCTAssertTrue(event.choices.contains { $0.requires == nil }, "\(event.id) : tous les choix sont verrouillables")
        }
    }

    func testDrawableEventsHaveALocation() {
        for event in events where event.weight > 0 {
            XCTAssertNotNil(event.location, "\(event.id) peut être tiré mais n'a pas de lieu")
        }
    }

    func testEveryLocationHasARepeatableUnconditionalEvent() {
        for location in Location.allCases {
            let open = events.filter {
                $0.location == location && $0.weight > 0 && !$0.unique && $0.conditions == EventConditions()
            }
            XCTAssertFalse(open.isEmpty, "\(location) n'a aucun événement toujours disponible")
        }
    }

    func testCastReferencesExist() {
        let castIds = Set(world.cast.map(\.id))
        for event in events {
            if let npc = event.npc { XCTAssertTrue(castIds.contains(npc), "\(event.id) : npc inconnu \(npc)") }
            for id in event.conditions.referencedCast {
                XCTAssertTrue(castIds.contains(id), "\(event.id) : condition sur un perso inconnu \(id)")
            }
            for choice in event.choices {
                for id in choice.referencedCast {
                    XCTAssertTrue(castIds.contains(id), "\(event.id) : perso inconnu \(id)")
                }
                if let clash = choice.clash {
                    XCTAssertNotNil(world.cast.first { $0.id == clash.opponent }?.clash,
                                    "\(event.id) : \(clash.opponent) n'a pas de profil de clash")
                }
            }
        }
    }

    func testClashProfilesCoverAllMoves() {
        for member in world.cast {
            guard let profile = member.clash else { continue }
            for move in ClashMove.allCases {
                XCTAssertNotNil(profile.stats[move], "\(member.id) : stat \(move) manquante")
            }
            XCTAssertNotEqual(profile.weakness, profile.resistance, member.id)
        }
    }

    func testFollowUpsPointToExistingEvents() {
        let ids = Set(events.map(\.id))
        for event in events {
            for choice in event.choices {
                if let followUp = choice.followUp {
                    XCTAssertTrue(ids.contains(followUp), "\(event.id) → follow_up inconnu : \(followUp)")
                }
            }
        }
    }

    func testRequiredFlagsCanBeSetSomewhere() {
        var settable = Set((events + world.story.events).flatMap { $0.choices.flatMap(\.setFlags) })
        settable.formUnion(world.story.interviews.flatMap { $0.win.setFlags + $0.lose.setFlags })
        settable.formUnion(world.story.concerts.flatMap { $0.win.setFlags + $0.lose.setFlags })
        settable.formUnion(world.story.negotiations.flatMap { $0.win.setFlags + $0.lose.setFlags })
        settable.formUnion(world.story.writings.flatMap { $0.win.setFlags + $0.lose.setFlags })
        settable.formUnion(world.story.minigames.flatMap { $0.win.setFlags + $0.lose.setFlags })
        settable.formUnion((events + world.story.events).flatMap { $0.choices.compactMap(\.clash).flatMap { $0.win.setFlags + $0.lose.setFlags } })
        settable.formUnion((1...world.story.chapters.count).map { "chapitre_\($0)" })
        settable.formUnion((events + world.story.events).flatMap { $0.choices.compactMap { $0.clash.map { "clash_gagne_\($0.opponent)" } } })
        settable.formUnion(world.quests.map { "quete_\($0.id)" })

        var required: [(String, String)] = events.flatMap { e in e.conditions.requiredFlags.map { (e.id, $0) } }
        for quest in world.quests {
            required += quest.conditions.requiredFlags.map { (quest.id, $0) }
            required += quest.steps.flatMap { $0.conditions.requiredFlags.map { (quest.id, $0) } }
        }
        required += world.story.techniques.flatMap { t in t.unlock.requiredFlags.map { (t.id, $0) } }
        for (owner, flag) in required {
            XCTAssertTrue(settable.contains(flag), "\(owner) requiert « \(flag) », qu'aucun choix ne pose")
        }
    }

    func testZeroWeightEventsAreReachableAsFollowUps() {
        let followUps = Set(events.flatMap { $0.choices.compactMap(\.followUp) })
        for event in events where event.weight == 0 {
            XCTAssertTrue(followUps.contains(event.id), "\(event.id) a un poids de 0 et n'est jamais déclenché")
        }
    }

    func testTextsAreNotEmpty() {
        for event in events {
            XCTAssertFalse(event.title.isEmpty, event.id)
            XCTAssertFalse(event.text.isEmpty, event.id)
            for choice in event.choices {
                XCTAssertFalse(choice.label.isEmpty, event.id)
                XCTAssertFalse(choice.consequence.isEmpty, event.id)
            }
        }
        for quest in world.quests {
            XCTAssertFalse(quest.steps.isEmpty, quest.id)
        }
    }

    func testEventSoundsExist() {
        for event in events + world.story.events {
            guard let sound = event.sound else { continue }
            XCTAssertNotNil(SoundEffect(rawValue: sound), "\(event.id) : son inconnu « \(sound) »")
        }
        XCTAssertTrue((events + world.story.events).contains { $0.sound == SoundEffect.ringtone.rawValue },
                      "au moins un appel doit sonner")
    }

    func testUnknownKeysAreRejected() {
        let badStat = #"{"events":[{"id":"x","title":"t","text":"t","location":"studio","choices":[{"label":"a","effects":{"stremas":5},"consequence":"c"}]}]}"#
        XCTAssertThrowsError(try EventLoader.load(from: Data(badStat.utf8)))
        let badLocation = #"{"events":[{"id":"x","title":"t","text":"t","location":"plage","choices":[{"label":"a","consequence":"c"}]}]}"#
        XCTAssertThrowsError(try EventLoader.load(from: Data(badLocation.utf8)))
    }

    func testMinimalEventUsesDefaults() throws {
        let json = #"{"events":[{"id":"x","title":"t","text":"t","location":"studio","choices":[{"label":"a","consequence":"c"}]}]}"#
        let event = try XCTUnwrap(EventLoader.load(from: Data(json.utf8)).first)
        XCTAssertEqual(event.weight, GameEvent.defaultWeight)
        XCTAssertFalse(event.unique)
        XCTAssertNil(event.npc)
        XCTAssertEqual(event.choices[0].effects, [:])
        XCTAssertNil(event.choices[0].clash)
    }

    /// Simulates 1,000 random careers on the real data: they always
    /// end, stats stay in bounds, and every event can be reached.
    func testRandomCareersAlwaysTerminateWithinBounds() throws {
        let engine = GameEngine(world: world)
        var rng = SeededGenerator(seed: 2026)
        var seen = Set<String>()
        var endings = Set<Ending>()
        let maxSteps = GameState.totalTurns * GameState.actionsPerTurn * 3

        // Most careers start from scratch; some start from a mid-game save so later chapters get played too.
        func start(_ i: Int) -> GameState {
            var state = engine.newGame(rapper: Rapper(name: "Sim", city: .allCases[i % 8], style: .allCases[i % 4]))
            guard i >= 1_000 else { return state }
            let chapter = i < 1_150 ? 4 : (i < 1_300 ? 5 : 6)
            state.chapter = chapter
            state.pendingCinematic = nil
            state.flags = Set((1..<chapter).map { "chapitre_\($0)" } + ["signe_goslo", "sous_contrat", "concert_reussi"])
            if chapter >= 5 { state.flags.insert("contrat_signe") }
            if chapter >= 6 { state.flags.formUnion(["scalpel_battu", "single_ecrit"]) }
            state.counters.increment(.projets)
            state.stats = Stats(streams: 50, credibilite: 50, argent: 45, mental: 65)
            state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 60 * chapter) }))
            return state
        }

        for i in 0..<1_450 {
            var state = start(i)
            var steps = 0
            while !state.isOver {
                // Walking through the terrain vague: a wild clash now and then (no action spent).
                if Int.random(in: 0..<100, using: &rng) < 30, engine.startWildClash(in: &state, using: &rng) != nil {
                    while try !engine.clashMove(ClashMove.allCases.randomElement(using: &rng)!, in: &state, using: &rng).isOver {}
                    _ = try engine.finishClash(in: &state)
                    if let cinematic = state.pendingCinematic { engine.cinematicFinished(cinematic, in: &state) }
                    if state.isOver { break }
                }
                let event: GameEvent
                if let followUp = engine.takeFollowUp(in: &state) {
                    event = followUp
                } else if let npc = engine.currentObjective(in: state)?.trigger?.npc, Bool.random(using: &rng),
                          let story = try engine.talk(to: npc, in: &state, using: &rng) {
                    // Like a player following the story: go and talk to the objective's character.
                    event = story
                } else if let place = engine.currentObjective(in: state)?.trigger?.location, Bool.random(using: &rng),
                          engine.isUnlocked(place, in: state) {
                    // Like a player following the story: go where the objective is.
                    event = try engine.visit(place, in: &state, using: &rng)
                } else {
                    let open = Location.allCases.filter { engine.isUnlocked($0, in: state) }
                    event = try engine.visit(open.randomElement(using: &rng)!, in: &state, using: &rng)
                }
                seen.insert(event.id)
                let available = event.choices.indices.filter { event.choices[$0].isAvailable(in: state) }
                switch try engine.resolve(choiceAt: available.randomElement(using: &rng)!, in: &state) {
                case .clash(let started):
                    let weakness = engine.castMember(started.opponentId)?.clash?.weakness
                    while true {
                        if state.clash?.playerSecretReady == true {
                            if try engine.clashSecret(in: &state, using: &rng).isOver { break }
                            continue
                        }
                        let move = (Int.random(in: 0..<10, using: &rng) < 6 ? weakness : nil) ?? ClashMove.allCases.randomElement(using: &rng)!
                        if try engine.clashMove(move, in: &state, using: &rng).isOver { break }
                    }
                    _ = try engine.finishClash(in: &state)
                case .interview(var running):
                    while !running.isOver {
                        let answers = engine.interview(running.id)!.questions[running.questionIndex].answers
                        let open = answers.indices.filter { answers[$0].isAvailable(in: state) }
                        running = try engine.answerInterview(open.randomElement(using: &rng), in: &state)
                    }
                    _ = try engine.finishInterview(in: &state)
                case .concert:
                    // An average player: 80 % of notes hit.
                    while let running = state.concert, !running.isOver {
                        if running.inInterlude {
                            _ = try engine.concertInterlude(0, in: &state)
                        } else {
                            let notes = engine.concertChart(in: state)
                            let judgments = notes.map { _ in Int.random(in: 0..<10, using: &rng) < 8 ? ConcertJudgment.good : .miss }
                            _ = try engine.concertSongFinished(judgments, in: &state)
                        }
                    }
                    _ = try engine.finishConcert(in: &state)
                case .negotiation(var running):
                    while !running.isOver {
                        let options = engine.negotiation(running.id)!.clauses[running.clauseIndex].options
                        let open = options.indices.filter { options[$0].isAvailable(in: state) }
                        running = try engine.negotiate(open.randomElement(using: &rng)!, in: &state)
                    }
                    _ = try engine.finishNegotiation(in: &state)
                case .minigame(let running):
                    switch running.kind {
                    case .punchliner:
                        while let current = engine.punchlinerRound(in: state) {
                            let count = Int.random(in: 0...4, using: &rng)
                            _ = try engine.dropPunchline(Array(current.tiles.shuffled(using: &rng).prefix(count)), in: &state)
                        }
                    case .platine:
                        while state.minigame?.isOver == false {
                            _ = try engine.stopPlatine(after: Double.random(in: 0...6, using: &rng), in: &state)
                        }
                    case .fuite:
                        try engine.endChase(escaped: Bool.random(using: &rng), in: &state)
                    case .signing:
                        // A random affordable pair, or a single artist.
                        let offer = try XCTUnwrap(engine.signingOffer(in: state))
                        let ids = offer.spec.artists.map(\.id)
                        let options = ids.flatMap { a in ids.map { [a, $0] } }.filter { $0[0] != $0[1] } + ids.map { [$0] }
                        let affordable = options.filter {
                            SigningEngine.isAffordable($0, in: offer.spec, businessLevel: state.skills.level(.business))
                        }
                        _ = try engine.sign(affordable.randomElement(using: &rng)!, in: &state)
                    }
                    _ = try engine.finishMinigame(in: &state)
                case .writing:
                    while let running = state.writing, !running.isOver {
                        let options = engine.currentWritingRound(in: state)!.options
                        let open = options.indices.filter { options[$0].isAvailable(in: state) }
                        let pick = Int.random(in: 0..<10, using: &rng) == 0 ? nil : open.randomElement(using: &rng)
                        _ = try engine.writeLine(pick, in: &state)
                    }
                    _ = try engine.finishWriting(in: &state)
                case .outcome:
                    break
                }
                if let cinematic = state.pendingCinematic { engine.cinematicFinished(cinematic, in: &state) }
                for kind in StatKind.allCases {
                    XCTAssertTrue(Stats.range.contains(state.stats[kind]))
                }
                steps += 1
                XCTAssertLessThanOrEqual(steps, maxSteps, "carrière qui ne se termine pas")
                if steps > maxSteps { break }
            }
            if let ending = state.ending { endings.insert(ending) }
        }

        XCTAssertTrue(seen.contains("story_ring"), "aucune carrière simulée n'a atteint le boss du chapitre 1")
        let storyIds = Set(world.story.events.map(\.id))
        XCTAssertEqual(seen.subtracting([GameEngine.fallbackEvent.id]).subtracting(storyIds), Set(events.map(\.id)),
                       "Événements jamais tirés : \(Set(events.map(\.id)).subtracting(seen))")
        XCTAssertGreaterThanOrEqual(endings.count, 8, "Trop peu de fins atteintes : \(endings)")
    }
}
