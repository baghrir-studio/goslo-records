import XCTest
@testable import GosloRecords

/// The arcade and Beatbox Simon.
final class ArcadeTests: XCTestCase {
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
    }

    func testEveryArcadeGameExistsAndAFewAreFree() throws {
        XCTAssertEqual(Set(Arcade.games.map(\.id)).count, Arcade.games.count)
        XCTAssertGreaterThanOrEqual(Arcade.games.filter { $0.unlockedBy == nil }.count, 3, "quelques jeux gratuits")
        XCTAssertTrue(Arcade.games.contains { $0.unlockedBy != nil }, "les autres se débloquent en jouant")
        let rapper = Rapper(name: "A", city: .paris, style: .trap)
        for game in Arcade.games {
            switch game.mode {
            case .minigame(let id):
                XCTAssertNotNil(engine.minigame(id), game.id)
                XCTAssertNotNil(engine.arcadeGame(game, rapper: rapper)?.minigame, game.id)
            case .concert(let id):
                XCTAssertNotNil(engine.concert(id), game.id)
                XCTAssertNotNil(engine.arcadeGame(game, rapper: rapper)?.concert, game.id)
            case .freestyle:
                break
            }
        }
        var profile = TrophyCase()
        let locked = try XCTUnwrap(Arcade.games.first { $0.unlockedBy != nil })
        XCTAssertFalse(Arcade.isUnlocked(locked, in: profile))
        profile.achievements[locked.unlockedBy!] = Date()
        XCTAssertTrue(Arcade.isUnlocked(locked, in: profile))
    }

    func testRecordsKeepTheBestAndSurviveOldProfiles() throws {
        var profile = TrophyCase()
        let beatbox = try XCTUnwrap(Arcade.game("beatbox"))
        profile.record(arcade: beatbox, score: 4)
        profile.record(arcade: beatbox, score: 2)
        XCTAssertEqual(profile.arcadeBest["beatbox"], 4)
        let fuite = try XCTUnwrap(Arcade.game("fuite"))
        profile.record(arcade: fuite, score: 1)
        profile.record(arcade: fuite, score: 1)
        XCTAssertEqual(profile.arcadeBest["fuite"], 2, "les évasions s'additionnent")
        let back = try JSONDecoder().decode(TrophyCase.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(back.arcadeBest, profile.arcadeBest)
        let old = try JSONDecoder().decode(TrophyCase.self, from: Data(#"{"achievements":{}}"#.utf8))
        XCTAssertTrue(old.arcadeBest.isEmpty)
    }

    func testBeatboxPatternsGrowAndASlipEndsIt() throws {
        var rng = SeededGenerator(seed: 5)
        for _ in 0..<50 {
            let pattern = BeatboxEngine.pattern(using: &rng)
            XCTAssertEqual(pattern.count, BeatboxEngine.maxLength)
            for index in 2..<pattern.count {
                XCTAssertFalse(pattern[index] == pattern[index - 1] && pattern[index] == pattern[index - 2], "jamais 3 fois le même son")
            }
        }
        XCTAssertEqual(BeatboxEngine.length(ofRound: 0), BeatboxEngine.startLength)

        let game = try XCTUnwrap(Arcade.game("beatbox"))
        var state = try XCTUnwrap(engine.arcadeGame(game, rapper: Rapper(name: "B", city: .lyon, style: .trap)))
        try engine.beatbox(repeated: true, in: &state)
        try engine.beatbox(repeated: true, in: &state)
        XCTAssertEqual(state.minigame?.round, 2)
        XCTAssertFalse(state.minigame!.isOver)
        try engine.beatbox(repeated: false, in: &state)
        let running = try XCTUnwrap(state.minigame)
        XCTAssertTrue(running.isOver, "une erreur et c'est fini")
        XCTAssertEqual(Arcade.score(of: running, engine: engine), 2)
        XCTAssertEqual(engine.minigameScore(running), 2 / Double(BeatboxEngine.rounds), accuracy: 0.001)
        XCTAssertThrowsError(try engine.beatbox(repeated: true, in: &state))

        var perfect = try XCTUnwrap(engine.arcadeGame(game, rapper: Rapper(name: "C", city: .lyon, style: .trap)))
        for _ in 0..<BeatboxEngine.rounds { try engine.beatbox(repeated: true, in: &perfect) }
        XCTAssertTrue(perfect.minigame!.isOver)
        XCTAssertEqual(engine.minigameScore(perfect.minigame!), 1)
    }
}
