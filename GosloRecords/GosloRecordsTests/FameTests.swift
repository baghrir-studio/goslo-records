import XCTest
@testable import GosloRecords

/// The career leaves marks: quotes, posters, guests at the big shows.
final class FameTests: XCTestCase {
    private var world = World(events: [])
    private var engine: GameEngine { GameEngine(world: world) }

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    private func newGame() -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lille, style: .boomBap))
        state.pendingCinematic = nil
        return state
    }

    func testRivalsQuoteYourLinesButStrangersDont() {
        var state = newGame()
        state.hooks = ["essoré, mais jamais délavé"]
        let rival = ClashState(spec: ClashSpec(opponent: "scalpel", win: ClashResultSpec(consequence: ""),
                                               lose: ClashResultSpec(consequence: "")), isWild: false)
        XCTAssertTrue(engine.callbacks(for: rival, in: state).contains { $0.contains("jamais délavé") })
        let stranger = ClashState(spec: rival.spec, isWild: true)
        XCTAssertTrue(engine.callbacks(for: stranger, in: state).isEmpty)
    }

    func testFriendsTalkAboutYourLatestTrack() {
        var state = newGame()
        XCTAssertNil(engine.memoryLine(for: "yanis", in: state))
        state.hooks = ["un", "deux"]
        XCTAssertTrue(engine.memoryLine(for: "yanis", in: state)?.contains("« deux »") == true)
    }

    func testPostersFollowTheStreams() {
        var state = newGame()
        state.stats = Stats(streams: 10, credibilite: 30, argent: 30, mental: 60)
        XCTAssertEqual(engine.fame(in: state), 0)
        state.stats = Stats(streams: 80, credibilite: 30, argent: 30, mental: 60)
        XCTAssertEqual(engine.fame(in: state), 3)
        XCTAssertFalse(engine.hasFresco(in: state))
        state.flags.insert("clash_gagne_le_baron")
        XCTAssertTrue(engine.hasFresco(in: state))
    }

    func testEveryoneYouMetComesToTheDome() {
        var state = newGame()
        state.metCast = ["momo", "fred", "scalpel", "kolosse"]
        let guests = engine.concertGuests("le_dome", in: state).map(\.id)
        XCTAssertTrue(Set(["momo", "fred", "scalpel", "kolosse"]).isSubset(of: Set(guests)))
        XCTAssertTrue(guests.contains("maman"), "ta mère est toujours là")
        XCTAssertLessThanOrEqual(guests.count, 10)
    }
}
