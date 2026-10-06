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

        refill()
        XCTAssertEqual(try engine.talk(to: "scalpel", in: &state, using: &rng)?.id, "story_stylo")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertTrue(state.items.contains("stylo_rouge"))
        XCTAssertEqual(engine.playerSecret(in: state).name, "L'Annotation")

        refill()
        XCTAssertEqual(try engine.talk(to: "dj_bobine", in: &state, using: &rng)?.id, "story_bobine_dome")
        _ = try engine.resolve(choiceAt: 2, in: &state)

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
        XCTAssertFalse(state.isOver, "la carrière se termine après la cinématique de fin")

        engine.cinematicFinished("ch6_outro", in: &state)
        XCTAssertTrue(state.flags.contains("chapitre_6"))
        XCTAssertEqual(state.ending, .heritier, "le trône revient à l'héritier")
        XCTAssertNil(state.pendingCinematic)
        XCTAssertEqual(state.chapter, 6)
    }
}
