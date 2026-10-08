import XCTest
@testable import GosloRecords

final class StoryTests: XCTestCase {
    private var world = World(events: [])
    private var engine: GameEngine { GameEngine(world: world) }
    private var rng = SeededGenerator(seed: 77)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    // MARK: Data validation

    func testStoryDataIsConsistent() throws {
        let story = world.story
        let castIds = Set(world.cast.map(\.id))
        let storyEvents = Set(story.events.map(\.id))
        let cinematics = Set(story.cinematics.map(\.id))
        let map = try XCTUnwrap(world.map)
        XCTAssertFalse(story.chapters.isEmpty)

        for chapter in story.chapters {
            for id in [chapter.intro, chapter.outro].compactMap({ $0 }) {
                XCTAssertTrue(cinematics.contains(id), "cinématique inconnue : \(id)")
            }
            for objective in chapter.objectives {
                if let event = objective.event {
                    XCTAssertTrue(storyEvents.contains(event), "\(objective.id) : événement inconnu \(event)")
                    XCTAssertNotNil(objective.trigger, "\(objective.id) a un événement mais pas de déclencheur")
                }
                if let npc = objective.trigger?.npc {
                    XCTAssertNotNil(world.district(ofNPC: npc, chapter: chapter.number),
                                    "\(objective.id) : \(npc) n'est dans aucun quartier ouvert au chapitre \(chapter.number)")
                }
                if let location = objective.trigger?.location, location != .reseaux, location != .quartier {
                    XCTAssertFalse(world.districts(with: location, chapter: chapter.number).isEmpty,
                                   "\(objective.id) : pas de porte \(location) ouverte au chapitre \(chapter.number)")
                }
                if let cinematic = objective.cinematic {
                    XCTAssertTrue(cinematics.contains(cinematic), "\(objective.id) : cinématique inconnue")
                }
            }
        }

        for cinematic in story.cinematics {
            for (index, step) in cinematic.steps.enumerated() {
                XCTAssertEqual(step.fieldCount, 1, "\(cinematic.id) étape \(index) : un seul champ attendu")
                for actor in step.actors where actor != "player" {
                    XCTAssertTrue(castIds.contains(actor), "\(cinematic.id) : personnage inconnu \(actor)")
                }
                if let name = step.sound { XCTAssertNotNil(SoundEffect(rawValue: name), "son inconnu : \(name)") }
                for placement in [step.move, step.place].compactMap({ $0 }) {
                    XCTAssertTrue(map.tile(at: placement.point).isWalkable,
                                  "\(cinematic.id) : \(placement.who) placé dans un mur en \(placement.point)")
                }
            }
        }

        let interviewIds = Set(story.interviews.map(\.id))
        for event in story.events {
            XCTAssertTrue((2...3).contains(event.choices.count), event.id)
            for choice in event.choices {
                if let id = choice.interview { XCTAssertTrue(interviewIds.contains(id), "\(event.id) : interview inconnue") }
                if let id = choice.concert { XCTAssertNotNil(story.concert(id), "\(event.id) : concert inconnu") }
                if let id = choice.negotiation { XCTAssertNotNil(story.negotiation(id), "\(event.id) : négociation inconnue") }
                if let id = choice.writing { XCTAssertNotNil(story.writing(id), "\(event.id) : session d'écriture inconnue") }
                if let clash = choice.clash { XCTAssertNotNil(world.cast.first { $0.id == clash.opponent }?.clash) }
            }
        }
        for interview in story.interviews {
            XCTAssertTrue(castIds.contains(interview.host), "\(interview.id) : animateur inconnu")
            XCTAssertFalse(interview.questions.isEmpty)
            for question in interview.questions {
                XCTAssertTrue(question.answers.contains { $0.requires == nil }, "\(interview.id) : question sans réponse libre")
            }
            // The interview must be winnable without any requirement.
            let best = interview.questions.map { $0.answers.filter { $0.requires == nil }.map(\.hype).max() ?? 0 }
            XCTAssertGreaterThanOrEqual(interview.startHype + best.reduce(0, +), interview.passHype,
                                        "\(interview.id) est impossible à réussir sans prérequis")
        }
        for headline in story.radio { XCTAssertFalse(headline.text.isEmpty) }
    }

    // MARK: Full chapter 1, played by the engine

    func testPrologueOpensDifferentlyInEachCity() throws {
        let prologue = try XCTUnwrap(world.story.cinematic("prologue"))
        var openings = Set<String>()
        var speakers = Set<String>()
        let castIds = Set(world.cast.map(\.id))
        for city in City.allCases {
            let steps = prologue.steps.filter { $0.plays(for: city) }
            let cityLines = steps.filter { $0.cities != nil }
            XCTAssertEqual(cityLines.filter { $0.narration != nil }.count, 1, "\(city) : une narration propre à la ville")
            // Each city has its own neighbour who comes to talk, with their own lines.
            let cityVoices = Set(cityLines.compactMap { $0.say?.who })
            XCTAssertEqual(cityVoices.count, 1, "\(city) : un seul personnage local")
            let speaker = try XCTUnwrap(cityVoices.first)
            XCTAssertTrue(castIds.contains(speaker), "\(city) : \(speaker) n'est pas au casting")
            XCTAssertGreaterThanOrEqual(cityLines.filter { $0.say?.who == speaker }.count, 4, "\(city) : un vrai dialogue")
            XCTAssertTrue(speakers.insert(speaker).inserted, "\(city) : même personnage qu'une autre ville")
            XCTAssertTrue(steps.contains { $0.place?.who == speaker }, "\(city) : \(speaker) doit apparaître avant de marcher")
            let opening = try XCTUnwrap(steps.compactMap(\.narration).first, "\(city)")
            XCTAssertTrue(opening.hasPrefix(city.rawValue), "\(city) : la scène s'ouvre sur le nom de la ville")
            openings.insert(opening)
        }
        XCTAssertEqual(openings.count, City.allCases.count)
    }

    func testChapterOnePlaythrough() throws {
        let engine = engine
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .marseille, style: .boomBap))
        XCTAssertEqual(state.pendingCinematic, "prologue")
        engine.cinematicFinished("prologue", in: &state)
        XCTAssertNil(state.pendingCinematic)
        XCTAssertFalse(engine.isUnlocked(.label, in: state), "la laverie est fermée au chapitre 1")

        // 1. The notebook, at home.
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "ecrire")
        XCTAssertNil(engine.storyEvent(forNPC: "lucien", in: state), "Lucien ne doit pas encore déclencher l'histoire")
        XCTAssertEqual(try engine.visit(.chezToi, in: &state, using: &rng).id, "story_carnet")
        guard case .minigame = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de Punchliner") }
        XCTAssertEqual(state.minigame?.id, "punchliner_carnet")
        while let current = engine.punchlinerRound(in: state) {
            let endings = current.round.endings
            _ = try engine.dropPunchline(endings.indices.max { endings[$0].score < endings[$1].score }, in: &state)
        }
        let first = try engine.finishMinigame(in: &state)
        XCTAssertEqual(first.completedObjectives, ["Écris ton premier texte"])

        // 2. Lucien.
        XCTAssertEqual(try engine.talk(to: "lucien", in: &state, using: &rng)?.id, "story_lucien")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "micro_ouvert")

        // 3. Micro Ouvert + interview.
        XCTAssertEqual(try engine.visit(.media, in: &state, using: &rng).id, "story_micro_ouvert")
        guard case .interview = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas d'interview") }
        XCTAssertFalse(engine.canVisit(state), "on ne se balade pas pendant le direct")
        let interview = try XCTUnwrap(engine.interview("micro_ouvert"))
        for question in interview.questions {
            let best = question.answers.indices.filter { question.answers[$0].isAvailable(in: state) }
                .max { question.answers[$0].hype < question.answers[$1].hype }!
            _ = try engine.answerInterview(best, in: &state)
        }
        let radio = try engine.finishInterview(in: &state)
        XCTAssertTrue(try XCTUnwrap(radio.interview).passed)
        XCTAssertTrue(state.flags.isSuperset(of: ["micro_ouvert_fait", "micro_ouvert_reussi", "freestyle_fait"]))
        XCTAssertEqual(state.pendingCinematic, "ton_nom_a_la_radio")
        engine.cinematicFinished("ton_nom_a_la_radio", in: &state)

        // 4. Two wins in the terrain vague.
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "terrain_vague")
        state.skills.gain([.flow: 600, .plume: 600, .scene: 600, .business: 600])
        var wins = 0
        while wins < 2 {
            _ = try XCTUnwrap(engine.startWildClash(in: &state, using: &rng))
            while try !engine.clashMove(.flow, in: &state, using: &rng).isOver {}
            if try engine.finishClash(in: &state).clash?.playerWon == true { wins += 1 }
        }
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "ring")

        // 5. Boss: Kevlar Jr. spots you and challenges you.
        XCTAssertTrue(engine.canChallenge("kevlar_jr", in: state))
        XCTAssertEqual(try engine.talk(to: "kevlar_jr", challenge: true, in: &state, using: &rng)?.id, "story_ring")
        guard case .clash(let boss) = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de boss") }
        XCTAssertTrue(boss.isBoss)
        XCTAssertEqual(boss.rounds, 5)
        while try !engine.clashMove(.story, in: &state, using: &rng).isOver {}
        let end = try engine.finishClash(in: &state)
        XCTAssertTrue(try XCTUnwrap(end.clash).playerWon)
        XCTAssertTrue(end.completedObjectives.contains { $0.contains("Kevlar") })
        XCTAssertEqual(state.pendingCinematic, "ch1_outro")

        // Outro: chapter 2 opens.
        engine.cinematicFinished("ch1_outro", in: &state)
        XCTAssertEqual(state.chapter, 2)
        XCTAssertTrue(state.flags.contains("chapitre_1"))
        XCTAssertTrue(engine.isUnlocked(.label, in: state))
        XCTAssertTrue(try XCTUnwrap(world.map).forChapter(2).npcs.contains { $0.id == "momo" })
        XCTAssertEqual(state.pendingCinematic, "ch2_intro")
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "signature")
    }

    // MARK: Boss balance

    /// The boss must be beatable with a good strategy, without being a formality.
    /// Without a single tap, countering changes nothing: same clashes, same winners as when a boss's
    /// technique landed straight away. Each clash gets its own seed, so both runs see the same dice.
    /// A missed first text still counts: the story never blocks on the notebook.
    func testFirstTextIsWrittenEvenWhenThePunchlinerFails() throws {
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .paris, style: .boomBap))
        engine.cinematicFinished("prologue", in: &state)
        _ = try engine.visit(.chezToi, in: &state, using: &rng)
        guard case .minigame = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de Punchliner") }
        while engine.punchlinerRound(in: state) != nil {
            _ = try engine.dropPunchline(nil, in: &state)
        }
        let outcome = try engine.finishMinigame(in: &state)
        XCTAssertEqual(engine.minigameScore(try XCTUnwrap(outcome.minigame)), 0)
        XCTAssertEqual(outcome.completedObjectives, ["Écris ton premier texte"])
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "lucien")
    }

    func testUncounteredBossTechniqueKeepsTheOldBalance() throws {
        let engine = engine
        for id in ["story_ring", "story_kolosse", "story_baron_clash"] {
            let event = try XCTUnwrap(world.story.events.first { $0.id == id })
            let spec = try XCTUnwrap(event.choices.compactMap(\.clash).first)
            var countered = 0
            for i in 0..<300 {
                func play(immediate: Bool) throws -> ClashState {
                    var dice = SeededGenerator(seed: UInt64(i) &* 2_654_435_761 &+ 1)
                    var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: Style.allCases[i % 4]))
                    state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 60 * (i % 6)) }))
                    state.clash = ClashState(spec: spec)
                    var moves = SeededGenerator(seed: UInt64(i) &+ 99)
                    while !(state.clash?.isOver ?? true) {
                        if state.clash!.pendingCounter != nil {
                            _ = try engine.counterSecret(taps: 0, in: &state)
                            continue
                        }
                        let move = ClashMove.allCases.randomElement(using: &moves)!
                        _ = try engine.clashMove(move, in: &state, using: &dice)
                        if immediate, state.clash!.pendingCounter != nil {
                            _ = try engine.counterSecret(taps: 0, in: &state)
                        }
                    }
                    return state.clash!
                }
                let lazy = try play(immediate: false), now = try play(immediate: true)
                XCTAssertEqual(lazy.playerWon, now.playerWon, "\(id) #\(i)")
                XCTAssertEqual(lazy.playerHype, now.playerHype, "\(id) #\(i)")
                if lazy.log.contains(where: { $0.countered != nil }) { countered += 1 }
            }
            XCTAssertGreaterThan(countered, 0, "\(id) : le boss n'a jamais lancé sa technique")
        }
    }

    func testKevlarBossIsHardButFair() throws {
        let engine = engine
        let ring = try XCTUnwrap(world.story.events.first { $0.id == "story_ring" })
        let spec = try XCTUnwrap(ring.choices[0].clash)
        func winRate(smart: Bool, extraXP: Int) throws -> Double {
            var wins = 0
            let runs = 600
            for i in 0..<runs {
                var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: Style.allCases[i % 4]))
                state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, extraXP) }))
                state.clash = ClashState(spec: spec)
                while !(state.clash?.isOver ?? true) {
                    if smart && state.clash!.playerSecretReady {
                        _ = try engine.clashSecret(in: &state, using: &rng)
                    } else {
                        let move: ClashMove = smart ? .story : ClashMove.allCases.randomElement(using: &rng)!
                        _ = try engine.clashMove(move, in: &state, using: &rng)
                    }
                }
                if state.clash!.playerWon { wins += 1 }
            }
            return Double(wins) / Double(runs)
        }
        // After chapter 1's training (~1 level everywhere).
        let smart = try winRate(smart: true, extraXP: 60)
        let random = try winRate(smart: false, extraXP: 60)
        print("Boss Kevlar Jr. — stratégie: \(smart), hasard: \(random)")
        XCTAssertGreaterThan(smart, 0.45, "boss trop dur")
        XCTAssertLessThan(random, 0.6, "boss trop facile au hasard")
        XCTAssertGreaterThan(smart, random)
    }

    // MARK: Saves and gating

    func testOldSaveWithoutStoryFieldsStillLoads() throws {
        let json = #"{"rapper":{"name":"Vieux","city":"Lyon","style":"Trap"},"stats":{"streams":40,"credibilite":30,"argent":20,"mental":50},"turn":3}"#
        let state = try JSONDecoder().decode(GameState.self, from: Data(json.utf8))
        XCTAssertEqual(state.turn, 3)
        XCTAssertEqual(state.chapter, 1)
        XCTAssertEqual(state.objectiveIndex, 0)
        XCTAssertEqual(state.rapper.skinTone, 2)
        XCTAssertNil(state.interview)
    }

    func testChapterConditions() {
        var state = GameState(rapper: Rapper(name: "T", city: .paris, style: .drill))
        let conditions = EventConditions(minChapter: 2, maxChapter: 3)
        XCTAssertFalse(conditions.isSatisfied(by: state))
        state.chapter = 2
        XCTAssertTrue(conditions.isSatisfied(by: state))
        state.chapter = 4
        XCTAssertFalse(conditions.isSatisfied(by: state))
    }

    func testInterviewTimeoutCostsAudience() throws {
        let engine = engine
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .trap))
        let interview = try XCTUnwrap(engine.interview("micro_ouvert"))
        state.interview = InterviewState(interview: interview)
        let after = try engine.answerInterview(nil, in: &state)
        XCTAssertEqual(after.hype, interview.startHype - interview.timeoutPenalty)
        XCTAssertNil(after.log.last?.answer)
        XCTAssertThrowsError(try engine.finishInterview(in: &state)) {
            XCTAssertEqual($0 as? GameEngineError, .interviewNotOver)
        }
    }

    func testRadioHeadlinesFollowTheStory() {
        let engine = engine
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .trap))
        let before = engine.radioHeadlines(in: state)
        XCTAssertTrue(before.contains { $0.contains("Micro Ouvert") })
        XCTAssertFalse(before.contains { $0.contains("SÉISME") })
        state.flags.insert("clash_gagne_kevlar_jr")
        XCTAssertTrue(engine.radioHeadlines(in: state).contains { $0.contains("SÉISME") })
    }

    // MARK: Chapter 2

    private func chapterTwoState(_ engine: GameEngine) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .lyon, style: .drill))
        state.chapter = 2
        state.flags = ["chapitre_1", "clash_gagne_kevlar_jr"]
        state.pendingCinematic = nil
        state.stats = Stats(streams: 40, credibilite: 50, argent: 40, mental: 60)
        return state
    }

    private func playAll(_ engine: GameEngine, _ state: inout GameState) throws {
        if let cinematic = state.pendingCinematic { engine.cinematicFinished(cinematic, in: &state) }
    }

    func testChapterTwoPlaythrough() throws {
        let engine = engine
        var state = chapterTwoState(engine)

        // 1. Signing at the laverie.
        XCTAssertEqual(try engine.visit(.label, in: &state, using: &rng).id, "story_signature")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertTrue(state.flags.isSuperset(of: ["signe_goslo", "sous_contrat"]))
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "mixtape")

        // 2. Mixtape: Fred's drill replaces the secret technique.
        XCTAssertEqual(try engine.visit(.studio, in: &state, using: &rng).id, "story_mixtape")
        guard case .outcome(let mixtape) = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail() }
        XCTAssertEqual(mixtape.gainedItems, ["La perceuse de Fred"])
        XCTAssertEqual(engine.playerSecret(in: state).name, "La Perceuse")
        XCTAssertTrue(engine.playerSecret(in: state).line.contains("à part des murs"))
        XCTAssertEqual(state.counters[.projets], 1)
        try playAll(engine, &state)

        // 3. Clip in the cousin's car: La Mythique gives +2 Présence.
        XCTAssertEqual(try engine.visit(.label, in: &state, using: &rng).id, "story_clip")
        _ = try engine.resolve(choiceAt: 1, in: &state)
        XCTAssertTrue(state.items.contains("la_mythique"))
        XCTAssertEqual(engine.itemBonus(for: .presence, in: state), 2)
        XCTAssertEqual(engine.clashLevels(in: state)(.scene), state.skills.level(.scene) + 2)
        try playAll(engine, &state)

        // 4. Lingot spots you, you win, he's exiled to Miami (gone from the map).
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "lingot")
        let map = try XCTUnwrap(world.map)
        XCTAssertTrue(map.forChapter(2, flags: state.flags).npcs.contains { $0.id == "lingot" })
        XCTAssertTrue(engine.canChallenge("lingot", in: state))
        XCTAssertEqual(try engine.talk(to: "lingot", challenge: true, in: &state, using: &rng)?.id, "story_lingot")
        guard case .clash = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de clash") }
        state.clash?.opponentHype = 1
        while try !engine.clashMove(.flow, in: &state, using: &rng).isOver {}
        if state.clash?.playerWon != true {
            state.clash?.playerHype = 100
            state.clash?.opponentHype = 0
        }
        _ = try engine.finishClash(in: &state)
        XCTAssertEqual(state.pendingCinematic, "exil_lingot")
        XCTAssertFalse(map.forChapter(2, flags: state.flags).npcs.contains { $0.id == "lingot" }, "Lingot est à Miami")
        try playAll(engine, &state)

        // 5. The American star says no, whatever you do.
        if state.actionsLeft == 0 { state.actionsLeft = GameState.actionsPerTurn }
        XCTAssertEqual(try engine.visit(.reseaux, in: &state, using: &rng).id, "story_feat_us")
        _ = try engine.resolve(choiceAt: 1, in: &state)
        XCTAssertTrue(state.flags.contains("feat_us_refuse"))

        // 6. Boss: Le Grand Débat.
        if state.actionsLeft == 0 { state.actionsLeft = GameState.actionsPerTurn }
        XCTAssertEqual(try engine.visit(.media, in: &state, using: &rng).id, "story_debat")
        guard case .interview(let running) = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail() }
        let debat = try XCTUnwrap(engine.interview(running.id))
        XCTAssertTrue(debat.boss)
        for question in debat.questions {
            let best = question.answers.indices.filter { question.answers[$0].isAvailable(in: state) }
                .max { question.answers[$0].hype < question.answers[$1].hype }!
            _ = try engine.answerInterview(best, in: &state)
        }
        let end = try engine.finishInterview(in: &state)
        XCTAssertTrue(try XCTUnwrap(end.interview).passed)
        XCTAssertEqual(state.pendingCinematic, "ch2_outro")
        engine.cinematicFinished("ch2_outro", in: &state)
        XCTAssertEqual(state.chapter, 3)
        XCTAssertTrue(state.flags.contains("chapitre_2"))
    }

    func testItemsDataIsConsistent() throws {
        let itemIds = Set(world.story.items.map(\.id))
        let given = (world.events + world.story.events).flatMap { $0.choices.flatMap(\.giveItems) }
        for id in given { XCTAssertTrue(itemIds.contains(id), "objet inconnu : \(id)") }
        for id in itemIds { XCTAssertTrue(given.contains(id), "objet jamais donné : \(id)") }
    }

    func testDebatIsHardWithoutTheRightAnswers() throws {
        let debat = try XCTUnwrap(engine.interview("grand_debat"))
        let worst = debat.questions.map { $0.answers.map(\.hype).min() ?? 0 }.reduce(debat.startHype, +)
        XCTAssertLessThan(worst, debat.passHype)
        let middle = debat.questions.map { q in q.answers.filter { $0.requires == nil }.map(\.hype).sorted(by: >)[1] }
            .reduce(debat.startHype, +)
        XCTAssertLessThan(middle, debat.passHype, "le boss ne doit pas se gagner avec des réponses moyennes")
    }

    // MARK: Unlockable techniques

    func testTechniquesDataIsConsistent() {
        let techniques = world.story.techniques
        XCTAssertEqual(techniques.count, 6, "une technique par boss avant le chapitre 5")
        XCTAssertEqual(Set(techniques.map(\.id)).count, techniques.count)
        for technique in techniques {
            XCTAssertFalse(technique.secret.name.isEmpty, technique.id)
            XCTAssertFalse(technique.secret.line.isEmpty, technique.id)
            XCTAssertFalse(technique.secret.prop?.isEmpty ?? true, "\(technique.id) : pas d'animation")
            XCTAssertFalse(technique.unlock.requiredFlags.isEmpty, "\(technique.id) se débloquerait dès le début")
            XCTAssertNotEqual(technique.id, GameEngine.styleTechniqueId)
            XCTAssertNil(world.story.item(technique.id), "\(technique.id) : même id qu'un objet")
        }
    }

    func testBeatingABossUnlocksAndEquipsItsTechnique() throws {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .drill))
        state.pendingCinematic = nil
        XCTAssertEqual(engine.playerSecret(in: state), Style.drill.secret)
        state.flags.insert("clash_gagne_kevlar_jr")
        // Any action announces it.
        let event = try engine.visit(.chezToi, in: &state, using: &rng)
        let choice = try XCTUnwrap(event.choices.firstIndex { $0.isAvailable(in: state) && $0.followUp == nil && $0.skipTurns == 0 && $0.minigame == nil })
        guard case .outcome(let outcome) = try engine.resolve(choiceAt: choice, in: &state) else { return XCTFail() }
        XCTAssertEqual(outcome.unlockedTechniques, ["Le Défilé Retourné"])
        XCTAssertEqual(engine.playerSecret(in: state).name, "Le Défilé Retourné")
        // Announced once only.
        let again = try engine.visit(.chezToi, in: &state, using: &rng)
        let next = try XCTUnwrap(again.choices.firstIndex { $0.isAvailable(in: state) && $0.followUp == nil && $0.skipTurns == 0 && $0.minigame == nil })
        guard case .outcome(let second) = try engine.resolve(choiceAt: next, in: &state) else { return XCTFail() }
        XCTAssertTrue(second.unlockedTechniques.isEmpty)
        // The notebook can switch back to the style's technique, but not to a locked one.
        engine.equipTechnique(GameEngine.styleTechniqueId, in: &state)
        XCTAssertEqual(engine.playerSecret(in: state), Style.drill.secret)
        engine.equipTechnique("clause_police_sept", in: &state)
        XCTAssertEqual(engine.playerSecret(in: state), Style.drill.secret)
        XCTAssertEqual(engine.availableTechniques(in: state).map(\.id), [GameEngine.styleTechniqueId, "defile_retourne"])
    }

    #if DEBUG
    // MARK: Debug shortcuts

    func testDebugJumpLandsOnAPlayableChapter() throws {
        for chapter in world.story.chapters where chapter.number > 1 {
            var state = engine.newGame(rapper: Rapper(name: "Dbg", city: .lyon, style: .trap))
            engine.debugJump(toChapter: chapter.number, in: &state)
            XCTAssertEqual(state.pendingCinematic, chapter.intro)
            if let intro = chapter.intro { engine.cinematicFinished(intro, in: &state) }
            let objective = try XCTUnwrap(engine.currentObjective(in: state))
            XCTAssertEqual(objective.id, chapter.objectives.first?.id)
            let trigger = try XCTUnwrap(objective.trigger, "chapitre \(chapter.number)")
            let event: GameEvent?
            if let npc = trigger.npc {
                XCTAssertNotNil(world.district(ofNPC: npc, chapter: chapter.number, flags: state.flags),
                                "chapitre \(chapter.number) : \(npc) absent des quartiers ouverts")
                event = try engine.talk(to: npc, in: &state, using: &rng)
            } else {
                let location = try XCTUnwrap(trigger.location)
                XCTAssertTrue(engine.isUnlocked(location, in: state), "chapitre \(chapter.number) : \(location) fermé")
                event = try engine.visit(location, in: &state, using: &rng)
            }
            XCTAssertEqual(event?.id, objective.event, "chapitre \(chapter.number)")
            XCTAssertFalse(state.isOver)
        }
    }

    func testDebugLastSemesterShowsTheOvertime() throws {
        var state = engine.newGame(rapper: Rapper(name: "Dbg", city: .lyon, style: .trap))
        state.pendingCinematic = nil
        engine.debugLastSemester(in: &state)
        let event = try engine.visit(.chezToi, in: &state, using: &rng)
        let choice = try XCTUnwrap(event.choices.firstIndex { $0.isAvailable(in: state) && $0.skipTurns == 0 && $0.followUp == nil && $0.minigame == nil })
        _ = try engine.resolve(choiceAt: choice, in: &state)
        XCTAssertTrue(state.isOvertime)
        XCTAssertEqual(state.periodLabel, "PROLONGATION")
        XCTAssertFalse(state.isOver)
    }
    #endif
}
