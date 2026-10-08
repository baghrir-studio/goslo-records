import XCTest
@testable import GosloRecords

/// Singles, the Top goslo radio, the season's challenges and the artist level.
final class ChartTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func game() -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Topo", city: .lyon, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 3
        state.stats = Stats(streams: 50, credibilite: 50, argent: 60, mental: 60)
        state.hooks = ["le bitume est mon costume"]
        // No challenge paying out in the middle of a test.
        state.challenges = []
        state.challengeSeason = Challenges.season(of: state.turn)
        return state
    }

    func testTheTopIsTenTracksBestFirst() {
        let top = engine.chart(in: game())
        XCTAssertEqual(top.count, ChartRules.size)
        XCTAssertEqual(top.map(\.score), top.map(\.score).sorted(by: >))
        XCTAssertEqual(engine.chart(in: game()), top, "le même Top pour le même moment")
    }

    func testRecordingASingle() throws {
        var state = game()
        var early = state
        early.chapter = 1
        XCTAssertNotNil(engine.studioRefusal(in: early), "pas de studio au prologue")
        XCTAssertNil(engine.studioRefusal(in: state))

        let source = try XCTUnwrap(engine.singleCandidates(in: state).first { $0.id == "refrain_0" })
        let actions = state.actionsLeft
        let argent = state.stats.argent
        _ = try engine.releaseSingle(sourceId: source.id, perfectTakes: 4, clip: true, feat: nil, in: &state)
        let single = try XCTUnwrap(state.singles.first)
        XCTAssertEqual(single.quality, min(10, source.quality + 2), "4 prises parfaites : +2")
        XCTAssertFalse(single.clip, "le clip se débloque au niveau 2")
        XCTAssertEqual(state.stats.argent, argent - ChartRules.studioPrice)
        XCTAssertEqual(state.actionsLeft, actions - 1)
        XCTAssertFalse(engine.singleCandidates(in: state).contains { $0.id == source.id }, "déjà sorti")
        XCTAssertNotNil(engine.studioRefusal(in: state), "un single par période")
        XCTAssertThrowsError(try engine.releaseSingle(sourceId: "refrain_0", perfectTakes: 4, clip: false, feat: nil, in: &state))

        XCTAssertEqual(ChartRules.quality(material: 6, perfectTakes: 0, feat: false), 4)
        XCTAssertEqual(ChartRules.quality(material: 6, perfectTakes: 2, feat: true), 7)
        XCTAssertEqual(ChartRules.quality(material: 10, perfectTakes: 4, feat: true), 10)
    }

    func testAGoodSingleClimbsAndPays() throws {
        var state = game()
        state.stats = Stats(streams: 80, credibilite: 70, argent: 60, mental: 60)
        state.singles = [Single(id: 1, title: "Tube", sourceId: "x", quality: 10, releasedTurn: state.turn, clip: true, feat: "yanis")]
        let top = engine.chart(in: state)
        let rank = try XCTUnwrap(top.firstIndex { $0.singleId == 1 }) + 1
        var outcome = TurnOutcome(consequence: "")
        let before = state.stats
        engine.payChart(&outcome, in: &state)
        XCTAssertEqual(state.singles[0].ranks, [rank])
        XCTAssertEqual(state.seasonBestRank, rank)
        XCTAssertGreaterThan(state.stats.streams, before.streams)
        XCTAssertGreaterThan(state.artistXP, 0)
        XCTAssertTrue(outcome.notes.contains { $0.contains("Top goslo radio") })

        // Old singles fall out of the race.
        state.turn += ChartRules.lifespan
        XCTAssertFalse(engine.chart(in: state).contains { $0.singleId == 1 })
    }

    func testArtistLevels() {
        XCTAssertEqual(ArtistLevel.level(xp: 0), 1)
        XCTAssertEqual(ArtistLevel.level(xp: 60), 2)
        XCTAssertEqual(ArtistLevel.level(xp: 99_999), ArtistLevel.maxLevel)
        XCTAssertEqual(ArtistLevel.titles.count, ArtistLevel.maxLevel)
        XCTAssertEqual(ArtistLevel.thresholds, ArtistLevel.thresholds.sorted())
        var state = game()
        var outcome = TurnOutcome(consequence: "")
        XCTAssertFalse(ArtistLevel.unlocks(.clip, in: state))
        ArtistLevel.gain(60, in: &state, outcome: &outcome)
        XCTAssertTrue(ArtistLevel.unlocks(.clip, in: state))
        XCTAssertTrue(outcome.notes.contains { $0.hasPrefix("NIVEAU 2") })
    }

    func testSeasonChallenges() throws {
        var state = game()
        state.challengeSeason = -1
        engine.refreshChallenges(in: &state)
        XCTAssertEqual(state.challenges.count, 3)
        XCTAssertEqual(Set(state.challenges.map(\.id)).count, 3)
        let drawn = state.challenges
        engine.refreshChallenges(in: &state)
        XCTAssertEqual(state.challenges, drawn, "même saison, mêmes défis")

        // Make one of them met, and it pays.
        state.challenges = [Challenge(kind: .refrain, target: 1, baseline: state.hooks.count)]
        state.hooks.append("encore un refrain")
        var outcome = TurnOutcome(consequence: "")
        let argent = state.stats.argent
        engine.checkChallenges(&outcome, in: &state)
        XCTAssertTrue(state.challenges[0].done)
        XCTAssertEqual(state.artistXP, Challenges.reward.xp)
        XCTAssertGreaterThan(state.stats.argent, argent)
        engine.checkChallenges(&outcome, in: &state)
        XCTAssertEqual(state.artistXP, Challenges.reward.xp, "payé une seule fois")

        state.turn += Challenges.seasonTurns
        engine.refreshChallenges(in: &state)
        XCTAssertNotEqual(state.challengeSeason, 0)
        XCTAssertFalse(state.challenges.contains { $0.done }, "nouvelle saison, nouveaux défis")
    }

    func testOldSavesLoad() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(game())) as? [String: Any])
        for key in ["singles", "artistXP", "challenges", "challengeSeason", "seasonBestRank"] { json[key] = nil }
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.singles.isEmpty)
        XCTAssertEqual(old.artistXP, 0)
        XCTAssertEqual(old.challengeSeason, -1)
    }
}
