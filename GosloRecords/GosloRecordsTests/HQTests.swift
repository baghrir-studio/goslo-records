import XCTest
@testable import GosloRecords

/// The HQ between careers: gold records, rooms, and the head start they give.
final class HQTests: XCTestCase {
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
    }

    func testEveryCareerBringsGoldRecords() {
        var state = engine.newGame(rapper: Rapper(name: "QG", city: .paris, style: .trap))
        XCTAssertGreaterThanOrEqual(HQ.reward(for: state), 1, "même une carrière ratée compte")
        let small = HQ.reward(for: state)
        state.flags.insert("clash_gagne_le_baron")
        state.artistXP = 1_000
        XCTAssertGreaterThan(HQ.reward(for: state), small, "aller loin rapporte plus")
    }

    func testRoomsCostAndCap() {
        var hq = Headquarters()
        XCTAssertNotNil(HQ.refusal(.studio, in: hq))
        hq.discs = 100
        XCTAssertTrue(HQ.upgrade(.radio, in: &hq))
        XCTAssertEqual(HQ.refusal(.radio, in: hq), "Au maximum")
        for _ in 0..<3 { XCTAssertTrue(HQ.upgrade(.studio, in: &hq)) }
        XCTAssertFalse(HQ.upgrade(.studio, in: &hq))
        XCTAssertEqual(hq.discs, 100 - HQRoom.radio.cost(toReach: 1) - (1...3).map { HQRoom.studio.cost(toReach: $0) }.reduce(0, +))
    }

    func testRoomsGiveAHeadStart() {
        var hq = Headquarters()
        hq.rooms = [HQRoom.studio.rawValue: 2, HQRoom.coffre.rawValue: 1, HQRoom.radio.rawValue: 1, HQRoom.vestiaire.rawValue: 2,
                    HQRoom.salon.rawValue: 1, HQRoom.repete.rawValue: 1]
        let plain = engine.newGame(rapper: Rapper(name: "A", city: .lyon, style: .drill))
        var boosted = plain
        HQ.apply(hq, to: &boosted)
        XCTAssertEqual(boosted.artistXP, plain.artistXP + 2 * HQ.studioXP)
        XCTAssertGreaterThan(boosted.stats.argent, plain.stats.argent)
        XCTAssertGreaterThan(boosted.stats.credibilite, plain.stats.credibilite)
        XCTAssertEqual(boosted.wardrobe.count, 2)
        XCTAssertTrue(boosted.flags.contains(HQ.radioFlag))
        XCTAssertGreaterThan(boosted.skills.xp(.plume), plain.skills.xp(.plume))
        var seasoned = boosted
        seasoned.challengeSeason = -1
        engine.refreshChallenges(in: &seasoned)
        XCTAssertEqual(seasoned.challenges.count, 4, "la radio pirate ajoute un défi")
    }

    func testOldProfilesLoad() throws {
        let old = try JSONDecoder().decode(TrophyCase.self, from: Data(#"{"achievements":{}}"#.utf8))
        XCTAssertEqual(old.hq, Headquarters())
    }
}
