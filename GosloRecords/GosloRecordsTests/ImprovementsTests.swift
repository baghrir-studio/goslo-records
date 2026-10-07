import XCTest
@testable import GosloRecords

/// Second TestFlight round: boss experience, stat hints, concert calibration, boss counters.
final class ImprovementsTests: XCTestCase {
    private var world = World(events: [])
    private var engine: GameEngine { GameEngine(world: world) }
    private var rng = SeededGenerator(seed: 2027)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    // MARK: Boss experience

    /// Plays Kevlar Jr.'s boss clash with a beginner until it's lost.
    private func loseToKevlar(_ state: inout GameState) throws -> TurnOutcome {
        let event = try XCTUnwrap(world.story.events.first { $0.id == "story_ring" })
        let spec = try XCTUnwrap(event.choices[0].clash)
        while true {
            state.clash = ClashState(spec: spec)
            state.actionsLeft = GameState.actionsPerTurn
            state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 60)
            while !(state.clash?.isOver ?? true) {
                if let pending = state.clash?.pendingCounter, pending.damage >= 0 {
                    _ = try engine.counterSecret(taps: 0, in: &state)
                } else {
                    _ = try engine.clashMove(.presence, in: &state, using: &rng)
                }
            }
            let outcome = try engine.finishClash(in: &state)
            if outcome.clash?.playerWon == false { return outcome }
        }
    }

    func testLosingToABossTeachesYouTheirGame() throws {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .boomBap))
        state.pendingCinematic = nil
        let event = try XCTUnwrap(world.story.events.first { $0.id == "story_ring" })
        let clash = ClashState(spec: try XCTUnwrap(event.choices[0].clash))
        let before = engine.clashLevels(for: clash, in: state)

        let first = try loseToKevlar(&state)
        XCTAssertEqual(engine.bossExperience(against: "kevlar_jr", in: state), 1)
        XCTAssertTrue(first.consequence.contains("Tu as appris"), first.consequence)
        let after = engine.clashLevels(for: clash, in: state)
        for skill in Skill.allCases where before(skill) < Skills.maxLevel {
            XCTAssertEqual(after(skill), before(skill) + 1, "\(skill)")
        }

        _ = try loseToKevlar(&state)
        let third = try loseToKevlar(&state)
        XCTAssertEqual(engine.bossExperience(against: "kevlar_jr", in: state), GameEngine.maxBossExperience,
                       "l'expérience plafonne")
        XCTAssertFalse(third.consequence.contains("Tu as appris"), "plus de message une fois au plafond")
        XCTAssertEqual(engine.bossExperience(against: "lingot", in: state), 0, "l'expérience vaut pour ce boss seulement")
    }

    func testOldSaveWithoutBossLossesStillLoads() throws {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        state.bossLosses = ["kevlar_jr": 2]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        XCTAssertNotNil(json.removeValue(forKey: "bossLosses"))
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.bossLosses, [:])
    }

    // MARK: Stat hints

    func testStatHintsShowWhichStatsMoveButNotTheDirection() throws {
        let json = #"{"label":"a","effects":{"streams":2,"argent":-8,"mental":0},"consequence":"c"}"#
        let choice = try JSONDecoder().decode(EventChoice.self, from: Data(json.utf8))
        let hints = choice.statHints
        XCTAssertEqual(hints.map(\.kind), [.streams, .argent], "mental à 0 n'est pas montré")
        XCTAssertEqual(hints.map(\.size), [1, 2], "un gros effet donne un gros point")
    }

    // MARK: Concert calibration

    func testCalibrationFindsTheLatency() throws {
        let interval = ConcertEngine.calibrationInterval
        // Two sloppy warm-up taps, then taps 60 ms late with a little jitter.
        let jitter = [0.01, -0.012, 0.004, 0.0, -0.006, 0.009, -0.003, 0.002]
        let taps = [interval + 0.2, 2 * interval - 0.15] + jitter.enumerated().map { index, noise in
            Double(index + 3) * interval + 0.06 + noise
        }
        let latency = try XCTUnwrap(ConcertEngine.latency(taps: taps))
        XCTAssertEqual(latency, 0.06, accuracy: 0.012)
        XCTAssertNil(ConcertEngine.latency(taps: [0.6, 1.2, 1.8, 2.4]), "pas assez de tapes après l'échauffement")
        let late = (1...8).map { Double($0) * interval + 0.29 }
        XCTAssertLessThanOrEqual(abs(try XCTUnwrap(ConcertEngine.latency(taps: late))), ConcertEngine.maxLatency)
    }

    // MARK: Boss counters

    func testBossesHaveTheirOwnCounter() {
        let styles = Dictionary(uniqueKeysWithValues: world.cast.compactMap { member in member.clash.map { (member.id, $0.counter) } })
        XCTAssertEqual(styles["scalpel"], .pen)
        XCTAssertEqual(styles["kolosse"], .beat)
        XCTAssertEqual(styles["le_baron"], .beat)
        XCTAssertEqual(styles["kevlar_jr"], .mash)
        XCTAssertEqual(ClashState.counterEquivalentTaps(score: 1), ClashState.counterTaps)
        XCTAssertEqual(ClashState.counterEquivalentTaps(score: 0), 0)
        XCTAssertEqual(ClashState.counterEquivalentTaps(score: -1), 0, "trop d'erreurs ne pénalise pas en dessous de zéro")
        XCTAssertEqual(ClashState.counterEquivalentTaps(score: 2), ClashState.counterTaps)
    }
}
