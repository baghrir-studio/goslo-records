import XCTest
@testable import GosloRecords

final class FinaleTests: XCTestCase {
    private var world = World(events: [])
    private var rng = SeededGenerator(seed: 606)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    func testOnlyTheLastChapterIsTheFinale() {
        let chapters = world.story.chapters
        XCTAssertEqual(chapters.filter(\.isFinale).map(\.number), [chapters.map(\.number).max()!])
    }

    func testRedPenHelpsAgainstTheBaron() throws {
        let pen = try XCTUnwrap(world.story.item("stylo_rouge"))
        XCTAssertEqual(pen.clashBonus[.punchline], 2)
        XCTAssertEqual(world.cast.first { $0.id == "le_baron" }?.clash?.weakness, .punchline,
                       "le stylo rouge doit viser la faiblesse du Baron")
        XCTAssertNotNil(pen.secret)
    }

    func testBaronBossIsTheHardestClash() throws {
        let engine = GameEngine(world: world)
        let event = try XCTUnwrap(world.story.events.first { $0.id == "story_baron_clash" })
        let spec = try XCTUnwrap(event.choices[0].clash)
        func winRate(smart: Bool, pen: Bool) throws -> Double {
            var wins = 0
            let runs = 600
            for i in 0..<runs {
                var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: Style.allCases[i % 4]))
                // Roughly where a player stands in chapter 6.
                state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 300) }))
                if pen { state.items.insert("stylo_rouge") }
                state.clash = ClashState(spec: spec)
                while !(state.clash?.isOver ?? true) {
                    if smart && state.clash!.playerSecretReady {
                        _ = try engine.clashSecret(in: &state, using: &rng)
                    } else {
                        let move: ClashMove = smart ? .punchline : ClashMove.allCases.randomElement(using: &rng)!
                        _ = try engine.clashMove(move, in: &state, using: &rng)
                    }
                }
                if state.clash!.playerWon { wins += 1 }
            }
            return Double(wins) / Double(runs)
        }
        let withPen = try winRate(smart: true, pen: true)
        let withoutPen = try winRate(smart: true, pen: false)
        let random = try winRate(smart: false, pen: false)
        print("Boss Baron — stratégie + stylo: \(withPen), stratégie seule: \(withoutPen), hasard: \(random)")
        XCTAssertGreaterThan(withPen, 0.5, "boss final trop dur avec la bonne préparation")
        XCTAssertGreaterThan(withPen, withoutPen, "le stylo de Scalpel doit aider")
        XCTAssertLessThan(random, 0.2, "boss final trop facile au hasard")
    }

    func testSemesterLimitWaitsForTheFinale() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .lyon, style: .melancolique))
        state.pendingCinematic = nil
        state.chapter = 6
        state.flags = Set((1...5).map { "chapitre_\($0)" } + ["signe_goslo", "contrat_signe", "scalpel_battu"])
        state.counters.increment(.projets)
        func spendSemester() throws {
            state.stats = Stats(streams: 60, credibilite: 60, argent: 50, mental: 70)
            let semester = state.turn
            while state.turn == semester && !state.isOver {
                // Chez toi is never a chapter 6 objective: the story doesn't move.
                let event = try engine.visit(.chezToi, in: &state, using: &rng)
                let open = event.choices.indices.first { event.choices[$0].isAvailable(in: state) && event.choices[$0].skipTurns == 0 }
                _ = try engine.resolve(choiceAt: try XCTUnwrap(open), in: &state)
                while let followUp = engine.takeFollowUp(in: &state) {
                    _ = try engine.resolve(choiceAt: followUp.choices.firstIndex { $0.isAvailable(in: state) }!, in: &state)
                }
            }
        }

        // Semester 20 ends with the finale still to play: overtime, the career goes on.
        state.turn = GameState.totalTurns - 1
        try spendSemester()
        XCTAssertEqual(state.turn, GameState.totalTurns)
        XCTAssertFalse(state.isOver, "la finale n'est pas jouée : la carrière continue en prolongation")
        XCTAssertTrue(engine.canVisit(state))
        XCTAssertEqual(state.year, GameState.totalTurns / 2)
        XCTAssertEqual(state.periodLabel, "PROLONGATION")
        XCTAssertEqual(state.semesterLabel, "1/\(GameState.overtimeTurns)")

        // Overtime has an end too: a player who never plays the finale gets a survival ending.
        state.turn = GameState.totalTurns + GameState.overtimeTurns - 1
        try spendSemester()
        XCTAssertEqual(state.turn, GameState.totalTurns + GameState.overtimeTurns)
        XCTAssertEqual(state.ending.map(\.isPremature), false)
        XCTAssertEqual(state.chapter, 6)
    }

    func testChapterSixPlaythroughEndsTheCareer() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .lyon, style: .melancolique))
        state.chapter = 6
        state.pendingCinematic = nil
        state.flags = ["chapitre_1", "chapitre_2", "chapitre_3", "chapitre_4", "chapitre_5", "signe_goslo",
                       "contrat_signe", "scalpel_battu"]
        state.counters.increment(.projets)
        state.stats = Stats(streams: 60, credibilite: 60, argent: 50, mental: 70)
        state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 300) }))
        func refill() { if state.actionsLeft == 0 { state.actionsLeft = GameState.actionsPerTurn } }

        XCTAssertEqual(try engine.visit(.label, in: &state, using: &rng).id, "story_dome")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(state.pendingCinematic, "baron_provoc")
        engine.cinematicFinished("baron_provoc", in: &state)

        // Lucien's funeral. The Baron was there too, at the back.
        refill()
        XCTAssertEqual(try engine.talk(to: "momo", in: &state, using: &rng)?.id, "story_adieu_lucien")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertTrue(state.items.contains("carnet_lucien"))
        XCTAssertEqual(try XCTUnwrap(engine.takeFollowUp(in: &state)).id, "story_baron_obseques")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertTrue(state.flags.isSuperset(of: ["adieu_lucien", "baron_respect"]))
        XCTAssertEqual(state.pendingCinematic, "banc_vide")
        engine.cinematicFinished("banc_vide", in: &state)
        XCTAssertFalse(try XCTUnwrap(world.map).forChapter(6, flags: state.flags).npcs.contains { $0.id == "lucien" },
                       "le banc de Lucien est vide")
        // Never went up to the Baron's: Momo has no photo to ask about, the story moves on.
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "stylo")

        refill()
        XCTAssertEqual(try engine.talk(to: "scalpel", in: &state, using: &rng)?.id, "story_stylo")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertTrue(state.items.contains("stylo_rouge"))
        XCTAssertEqual(engine.playerSecret(in: state).name, "L'Annotation")

        refill()
        XCTAssertEqual(try engine.talk(to: "dj_bobine", in: &state, using: &rng)?.id, "story_bobine_dome")
        _ = try engine.resolve(choiceAt: 2, in: &state)

        // The night before: doubt, goslo radio's night line, then mum's kitchen at dawn.
        refill()
        XCTAssertEqual(try engine.visit(.reseaux, in: &state, using: &rng).id, "story_nuit_blanche")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(try XCTUnwrap(engine.takeFollowUp(in: &state)).id, "story_antenne_nuit")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        let kitchen = try XCTUnwrap(engine.takeFollowUp(in: &state))
        XCTAssertEqual(kitchen.id, "story_cuisine_maman")
        XCTAssertFalse(kitchen.choices[1].isAvailable(in: state), "Lil Sauge n'est pas assez proche pour être dans ton coin")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertTrue(state.flags.isSuperset(of: ["nuit_traversee", "doute_avoue", "coin_maman"]))
        XCTAssertNil(state.pendingFollowUp)
        XCTAssertEqual(state.pendingCinematic, "aube_bloc")
        engine.cinematicFinished("aube_bloc", in: &state)

        // Boss 1: the Baron, retried until he falls.
        refill()
        XCTAssertTrue(engine.canChallenge("le_baron", in: state))
        XCTAssertEqual(try engine.talk(to: "le_baron", challenge: true, in: &state, using: &rng)?.id, "story_baron_clash")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        var attempts = 0
        while !state.flags.contains("baron_tombe") {
            while !(state.clash?.isOver ?? true) {
                if state.clash!.playerSecretReady { _ = try engine.clashSecret(in: &state, using: &rng) }
                else { _ = try engine.clashMove(.punchline, in: &state, using: &rng) }
            }
            _ = try engine.finishClash(in: &state)
            attempts += 1
            XCTAssertLessThan(attempts, 15)
            if !state.flags.contains("baron_tombe") {
                state.stats = Stats(streams: 60, credibilite: 60, argent: 50, mental: 70)
                refill()
                _ = try engine.talk(to: "le_baron", in: &state, using: &rng)
                _ = try engine.resolve(choiceAt: 0, in: &state)
            }
        }
        XCTAssertTrue(state.flags.contains("clash_gagne_le_baron"))

        // Boss 2: the radio face-à-face, best free answers.
        refill()
        XCTAssertEqual(try engine.visit(.media, in: &state, using: &rng).id, "story_face_a_face")
        guard case .interview = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas d'interview") }
        while let running = state.interview, !running.isOver {
            let answers = try XCTUnwrap(engine.interview(running.id)).questions[running.questionIndex].answers
            let best = answers.indices.filter { answers[$0].isAvailable(in: state) }.max { answers[$0].hype < answers[$1].hype }
            _ = try engine.answerInterview(best, in: &state)
        }
        XCTAssertTrue(try XCTUnwrap(try engine.finishInterview(in: &state).interview).passed)

        // Final boss: the Dôme, perfect show.
        refill()
        XCTAssertEqual(try engine.visit(.scene, in: &state, using: &rng).id, "story_dome_concert")
        _ = try engine.resolve(choiceAt: 1, in: &state)
        while let running = state.concert, !running.isOver {
            if running.inInterlude { _ = try engine.concertInterlude(0, in: &state) }
            else { _ = try engine.concertSongFinished(engine.concertChart(in: state).map { _ in .perfect }, in: &state) }
        }
        XCTAssertTrue(try XCTUnwrap(try engine.finishConcert(in: &state).concert).passed)
        XCTAssertEqual(state.pendingCinematic, "ch6_outro")

        // The throne no longer ends the career: the epilogue opens.
        engine.cinematicFinished("ch6_outro", in: &state)
        XCTAssertTrue(state.flags.contains("chapitre_6"))
        XCTAssertFalse(state.isOver, "après le trône, l'épilogue du label")
        XCTAssertEqual(state.chapter, 7)
        XCTAssertEqual(state.pendingCinematic, "ch7_intro")
    }

    // MARK: Epilogue: the label

    /// A career at the start of the epilogue, after beating the Baron.
    private func epilogueStart() -> GameState {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .casablanca, style: .boomBap))
        engine.debugJump(toChapter: 7, in: &state)
        state.flags.insert("clash_gagne_le_baron")
        state.stats = Stats(streams: 60, credibilite: 60, argent: 50, mental: 70)
        engine.cinematicFinished("ch7_intro", in: &state)
        return state
    }

    /// Plays the epilogue, signing `artists` at the auditions.
    private func playEpilogue(signing artists: [String]) throws -> GameState {
        let engine = GameEngine(world: world)
        var state = epilogueStart()
        func refill() { if state.actionsLeft == 0 { state.actionsLeft = GameState.actionsPerTurn } }

        XCTAssertEqual(try engine.visit(.label, in: &state, using: &rng).id, "story_cles")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        refill()
        XCTAssertEqual(try engine.visit(.scene, in: &state, using: &rng).id, "story_auditions")
        guard case .minigame = try engine.resolve(choiceAt: 0, in: &state) else {
            XCTFail("pas d'auditions")
            return state
        }
        XCTAssertEqual(try engine.sign(artists, in: &state).count, artists.count)
        _ = try engine.finishMinigame(in: &state)
        refill()
        XCTAssertEqual(try engine.visit(.media, in: &state, using: &rng).id, "story_label_radio")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(state.pendingCinematic, "ch7_outro")
        XCTAssertFalse(state.isOver, "la carrière se termine après la cinématique de fin")
        engine.cinematicFinished("ch7_outro", in: &state)
        XCTAssertTrue(state.flags.contains("chapitre_7"))
        XCTAssertNil(state.pendingCinematic)
        return state
    }

    /// Reaching the throne on the very last semester still lets you play the epilogue.
    func testTheClockStopsDuringTheEpilogue() throws {
        let engine = GameEngine(world: world)
        var state = epilogueStart()
        state.turn = engine.turnLimit(in: state) - 1
        XCTAssertTrue(engine.isInEpilogue(state))
        for _ in 0..<6 {
            state.actionsLeft = 1
            _ = try engine.visit(.quartier, in: &state, using: &rng)
            let event = try XCTUnwrap(engine.currentEvent(in: state))
            let choice = try XCTUnwrap(event.choices.firstIndex { $0.isAvailable(in: state) && $0.clash == nil
                && $0.minigame == nil && $0.followUp == nil && $0.skipTurns == 0 })
            _ = try engine.resolve(choiceAt: choice, in: &state)
            state.stats = Stats(streams: 60, credibilite: 60, argent: 50, mental: 70)
            XCTAssertNil(state.ending, "la limite de semestres ne coupe pas l'épilogue")
        }
        XCTAssertEqual(state.turn, engine.turnLimit(in: state) - 1, "le temps est figé")
    }

    func testGoodSigningsMakeYouALabelBoss() throws {
        let state = try playEpilogue(signing: ["celeste_k", "petite_brume"])
        XCTAssertEqual(state.ending, .patronDeLabel)
    }

    func testChasingTheBuzzKeepsYouOnTheThrone() throws {
        let state = try playEpilogue(signing: ["tonton_turbo", "junior_ascenseur"])
        XCTAssertEqual(state.ending, .heritier, "label raté : on reste l'héritier du trône")
    }

    func testSigningRespectsBudgetAndContracts() throws {
        let engine = GameEngine(world: world)
        var state = epilogueStart()
        state.skills = Skills(xp: [:])
        _ = try engine.visit(.label, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
        state.actionsLeft = GameState.actionsPerTurn
        _ = try engine.visit(.scene, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
        let offer = try XCTUnwrap(engine.signingOffer(in: state))
        XCTAssertEqual(offer.budget, offer.spec.budget + state.skills.level(.business) * SigningEngine.budgetPerBusinessLevel,
                       "chaque niveau de Business ajoute au budget")
        XCTAssertThrowsError(try engine.sign([], in: &state), "au moins un contrat")
        XCTAssertThrowsError(try engine.sign(["celeste_k", "petite_brume", "junior_ascenseur"], in: &state), "deux contrats au plus")
        XCTAssertThrowsError(try engine.sign(["tonton_turbo", "celeste_k"], in: &state), "hors budget")
        XCTAssertThrowsError(try engine.sign(["celeste_k", "celeste_k"], in: &state), "pas deux fois le même")
        XCTAssertNoThrow(try engine.sign(["junior_ascenseur"], in: &state))
        XCTAssertTrue(state.minigame?.isOver == true)
    }

    /// Buzz alone never makes a label; at least one good pair is always affordable without Business.
    func testSigningBalance() throws {
        let spec = try XCTUnwrap(world.story.minigame("signing_releve")?.signing)
        let ids = spec.artists.map(\.id)
        let pairs = ids.flatMap { a in ids.map { [a, $0] } }.filter { $0[0] < $0[1] }
        for level in 0...Skills.maxLevel {
            let affordable = pairs.filter { SigningEngine.isAffordable($0, in: spec, businessLevel: level) }
            let winners = affordable.filter { SigningEngine.points($0, in: spec) >= spec.target }
            XCTAssertGreaterThanOrEqual(winners.count, 3, "niveau \(level) : trop peu de bons duos")
            XCTAssertLessThan(winners.count, affordable.count, "niveau \(level) : impossible de rater")
            XCTAssertFalse(winners.contains { $0.contains("tonton_turbo") }, "le buzz seul ne fait pas un label")
        }
    }
}
