import XCTest
@testable import GosloRecords

/// Street happenings: where they show up, the selfie, the beatboxer's challenge.
final class HappeningsTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])
    private var rng = SeededGenerator(seed: 12)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func game() -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Rue", city: .marseille, style: .drill))
        state.pendingCinematic = nil
        state.chapter = 3
        state.stats = Stats(streams: 40, credibilite: 40, argent: 40, mental: 40)
        return state
    }

    func testHappeningsShowUpOnFreeTilesNearby() throws {
        let map = try XCTUnwrap(world.map).forChapter(3)
        for _ in 0..<200 {
            let player = map.spawn
            guard let spot = Happenings.spot(near: player, on: map, city: .marseille, using: &rng) else { continue }
            let distance = abs(spot.x - player.x) + abs(spot.y - player.y)
            XCTAssertTrue(Happenings.distance.contains(distance))
            XCTAssertTrue(OverworldRules.canStep(to: spot, on: map))
            XCTAssertNil(map.door(at: spot))
            XCTAssertNotEqual(map.metro, spot)
        }
        XCTAssertNotEqual(Happenings.pick(canClash: false, using: &rng), .cypher, "pas de cypher sans adversaire")
    }

    func testSelfieCostsNoActionAndCheersYouUp() {
        var state = game()
        let actions = state.actionsLeft
        let selfie = engine.takeSelfie(in: &state, using: &rng)
        XCTAssertEqual(state.actionsLeft, actions)
        XCTAssertGreaterThan(state.stats.streams, 40)
        XCTAssertGreaterThan(state.stats.mental, 40)
        XCTAssertFalse(selfie.line.isEmpty)
        XCTAssertGreaterThan(state.artistXP, 0)
    }

    func testTheBeatboxerChallengesYouForFree() throws {
        var state = game()
        let actions = state.actionsLeft
        _ = try engine.startStreetBeatbox(in: &state)
        XCTAssertEqual(state.minigame?.kind, .beatbox)
        for _ in 0..<BeatboxEngine.rounds { try engine.beatbox(repeated: true, in: &state) }
        let outcome = try engine.finishMinigame(in: &state)
        XCTAssertNil(state.minigame)
        XCTAssertEqual(state.actionsLeft, actions, "le défi de rue ne coûte pas d'action")
        XCTAssertGreaterThan(outcome.deltas[.streams] ?? 0, 0, "réussi : ça tourne")
    }
}
