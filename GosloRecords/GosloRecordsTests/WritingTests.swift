import XCTest
@testable import GosloRecords

final class WritingTests: XCTestCase {
    private var world = World(events: [])
    private var rng = SeededGenerator(seed: 505)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    private func sample(attack: Int = 10) -> Writing {
        Writing(id: "w", partner: "scalpel", title: "t", duel: true, startScore: 50, passScore: 60, timeoutPenalty: 7,
                rounds: [WritingRound(attack: WritingAttack(line: "a", damage: attack), setup: "s",
                                      options: [WritingOption(line: "l", score: 15, reaction: "r")])],
                win: InterviewResult(consequence: "w"), lose: InterviewResult(consequence: "l"))
    }

    // MARK: Rules

    func testAttackLandsOnlyOnce() {
        let data = sample()
        var state = WritingState(writing: data)
        WritingEngine.applyAttack(of: data.rounds[0], to: &state)
        WritingEngine.applyAttack(of: data.rounds[0], to: &state)
        XCTAssertEqual(state.score, 40)
        WritingEngine.write(data.rounds[0].options[0], index: 0, in: data.rounds[0], timeoutPenalty: 7, to: &state)
        XCTAssertEqual(state.score, 55)
        XCTAssertEqual(state.log.last?.attackDelta, -10)
        XCTAssertEqual(state.log.last?.scoreDelta, 15)
        XCTAssertTrue(state.isOver)
        XCTAssertFalse(state.passed)
    }

    func testWritingWithoutAnsweringTheAttackStillAppliesIt() {
        let data = sample()
        var state = WritingState(writing: data)
        WritingEngine.write(nil, index: nil, in: data.rounds[0], timeoutPenalty: 7, to: &state)
        XCTAssertEqual(state.score, 33, "attaque + trou noir")
        XCTAssertNil(state.log.last?.option)
    }

    func testScoreIsClamped() {
        let data = sample(attack: 80)
        var state = WritingState(writing: data)
        WritingEngine.applyAttack(of: data.rounds[0], to: &state)
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.attackDelta, -50)
    }

    func testPlumeBuysTime() {
        let round = WritingRound(setup: "s", time: 8, options: [])
        XCTAssertEqual(WritingEngine.time(for: round, plumeLevel: 1), 8)
        XCTAssertEqual(WritingEngine.time(for: round, plumeLevel: 5), 10)
    }

    func testWritingSurvivesSaveAndLoad() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .drill))
        state.writing = WritingState(writing: try XCTUnwrap(engine.writing("duel_scalpel")))
        _ = try engine.writingAttack(in: &state)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(loaded.writing, state.writing)
        XCTAssertTrue(loaded.writing?.attacked ?? false, "l'attaque déjà reçue ne se rejoue pas à la reprise")
        XCTAssertFalse(engine.canVisit(loaded), "on ne se balade pas pendant un duel")
    }

    // MARK: Data and balance

    func testWritingDataIsValid() throws {
        let castIds = Set(world.cast.map(\.id))
        XCTAssertFalse(world.story.writings.isEmpty)
        for data in world.story.writings {
            XCTAssertTrue(castIds.contains(data.partner), "\(data.id) : partenaire inconnu")
            XCTAssertFalse(data.rounds.isEmpty)
            for (index, round) in data.rounds.enumerated() {
                XCTAssertEqual(round.attack != nil, data.duel, "\(data.id) couplet \(index) : attaque seulement en duel")
                XCTAssertTrue((2...4).contains(round.options.count), "\(data.id) couplet \(index)")
                XCTAssertTrue(round.options.contains { $0.requires == nil }, "\(data.id) couplet \(index) sans option libre")
                XCTAssertTrue(round.options.contains { $0.score < 0 || $0.score <= 4 }, "\(data.id) couplet \(index) : il faut un piège")
            }
            // Winnable without any requirement.
            let damage = data.rounds.compactMap(\.attack?.damage).reduce(0, +)
            let best = data.rounds.map { $0.options.filter { $0.requires == nil }.map(\.score).max() ?? 0 }.reduce(0, +)
            XCTAssertGreaterThanOrEqual(data.startScore - damage + best, data.passScore, "\(data.id) impossible sans prérequis")
        }
    }

    /// Share of all paths (every option of every round) that pass, with a given Plume level.
    private func passRate(_ id: String, plume: Int) throws -> Double {
        let data = try XCTUnwrap(world.story.writing(id))
        var passed = 0, total = 0
        func explore(_ state: WritingState) {
            if state.isOver {
                total += 1
                if state.passed { passed += 1 }
                return
            }
            let round = data.rounds[state.roundIndex]
            for (index, option) in round.options.enumerated()
            where (option.requires?.skills[.plume] ?? 0) <= plume {
                var next = state
                WritingEngine.write(option, index: index, in: round, timeoutPenalty: data.timeoutPenalty, to: &next)
                explore(next)
            }
        }
        explore(WritingState(writing: data))
        return Double(passed) / Double(total)
    }

    func testScalpelDuelIsHardButFair() throws {
        let rookie = try passRate("duel_scalpel", plume: 1)
        let writer = try passRate("duel_scalpel", plume: 5)
        print("Duel Scalpel — plume 1: \(rookie), plume 5: \(writer)")
        XCTAssertGreaterThan(rookie, 0)
        XCTAssertLessThan(rookie, 0.3, "boss trop facile au hasard")
        XCTAssertGreaterThan(writer, rookie, "la plume doit aider")
    }

    func testStudioSessionIsForgivingButNotFree() throws {
        let rate = try passRate("session_single", plume: 1)
        print("Session single — plume 1: \(rate)")
        XCTAssertGreaterThan(rate, 0.25)
        XCTAssertLessThan(rate, 0.8)
    }

    // MARK: Chapter 5, played by the engine

    func testChapterFivePlaythrough() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .lyon, style: .melancolique))
        state.chapter = 5
        state.pendingCinematic = nil
        state.flags = ["chapitre_1", "chapitre_2", "chapitre_3", "chapitre_4", "signe_goslo", "contrat_signe"]
        state.counters.increment(.projets)
        state.stats = Stats(streams: 55, credibilite: 55, argent: 50, mental: 70)
        state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 260) }))
        func refill() { if state.actionsLeft == 0 { state.actionsLeft = GameState.actionsPerTurn } }
        let map = try XCTUnwrap(world.map).forChapter(5, flags: state.flags)
        XCTAssertEqual(map.npcs.filter { $0.id == "victor_contrat" }.count, 1, "Victor revient, une seule fois")

        XCTAssertEqual(engine.currentObjective(in: state)?.id, "image")
        XCTAssertEqual(try engine.talk(to: "victor_contrat", in: &state, using: &rng)?.id, "story_image")
        _ = try engine.resolve(choiceAt: 2, in: &state)
        XCTAssertTrue(state.flags.contains("image_rimes"))

        // The single: a bad take first, then the good one.
        refill()
        XCTAssertEqual(try engine.visit(.studio, in: &state, using: &rng).id, "story_single")
        guard case .writing = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de session") }
        while let running = state.writing, !running.isOver { _ = try engine.writeLine(nil, in: &state) }
        let flop = try engine.finishWriting(in: &state)
        XCTAssertFalse(try XCTUnwrap(flop.writing).passed)
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "single", "on peut refaire la prise")
        refill()
        _ = try engine.visit(.studio, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
        while let running = state.writing, !running.isOver { _ = try engine.writeLine(0, in: &state) }
        XCTAssertTrue(try XCTUnwrap(try engine.finishWriting(in: &state).writing).passed)

        refill()
        XCTAssertEqual(try engine.visit(.reseaux, in: &state, using: &rng).id, "story_sortie")
        _ = try engine.resolve(choiceAt: 1, in: &state)

        // Le Conteur: a clash, retried until won.
        refill()
        XCTAssertEqual(try engine.talk(to: "le_conteur", in: &state, using: &rng)?.id, "story_conteur")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        let weakness = try XCTUnwrap(engine.castMember("le_conteur")?.clash?.weakness)
        while !state.flags.contains("conteur_ch5") {
            while !(state.clash?.isOver ?? true) {
                if state.clash!.playerSecretReady { _ = try engine.clashSecret(in: &state, using: &rng) }
                else { _ = try engine.clashMove(weakness, in: &state, using: &rng) }
            }
            _ = try engine.finishClash(in: &state)
            if !state.flags.contains("conteur_ch5") {
                refill()
                _ = try engine.talk(to: "le_conteur", in: &state, using: &rng)
                _ = try engine.resolve(choiceAt: 0, in: &state)
            }
        }

        refill()
        XCTAssertEqual(try engine.visit(.media, in: &state, using: &rng).id, "story_autopsie")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(state.pendingCinematic, "defi_scalpel")
        engine.cinematicFinished("defi_scalpel", in: &state)

        // Boss: Scalpel spots you. Losing doesn't skip it; the best lines win.
        refill()
        XCTAssertTrue(engine.canChallenge("scalpel", in: state))
        XCTAssertEqual(try engine.talk(to: "scalpel", challenge: true, in: &state, using: &rng)?.id, "story_duel")
        guard case .writing = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de duel") }
        while let running = state.writing, !running.isOver { _ = try engine.writeLine(2, in: &state) }
        XCTAssertFalse(try XCTUnwrap(try engine.finishWriting(in: &state).writing).passed)
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "duel")

        refill()
        _ = try engine.talk(to: "scalpel", in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 1, in: &state)
        let best = [0, 0, 0, 1, 0]
        while let running = state.writing, !running.isOver {
            _ = try engine.writingAttack(in: &state)
            _ = try engine.writeLine(best[running.roundIndex], in: &state)
        }
        let duel = try engine.finishWriting(in: &state)
        XCTAssertTrue(try XCTUnwrap(duel.writing).passed)
        XCTAssertTrue(state.flags.contains("scalpel_battu"))
        XCTAssertTrue(state.flags.contains("clash_gagne_scalpel"), "compte pour le bilan de carrière")
        XCTAssertEqual(state.pendingCinematic, "ch5_outro")
        engine.cinematicFinished("ch5_outro", in: &state)
        XCTAssertEqual(state.chapter, 6)
        XCTAssertTrue(state.flags.contains("chapitre_5"))
    }
}
