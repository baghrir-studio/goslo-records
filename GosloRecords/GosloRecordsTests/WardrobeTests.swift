import XCTest
@testable import GosloRecords

/// Clothes from the shop (worn on the character) and decorations on the map.
final class WardrobeTests: XCTestCase {
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
    }

    private func game() -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Fringue", city: .paris, style: .boomBap))
        state.pendingCinematic = nil
        state.stats = Stats(streams: 40, credibilite: 40, argent: 80, mental: 40)
        state.artistXP = 10_000
        return state
    }

    func testBuyingAPiecePutsItOn() throws {
        var state = game()
        let chain = try XCTUnwrap(Wardrobe.item("chaine_or"))
        try engine.buy(chain, in: &state)
        XCTAssertTrue(state.rapper.look.chain, "on la voit sur le perso")
        XCTAssertEqual(state.rapper.look.accent, "#ffd84d")
        XCTAssertEqual(state.stats.argent, 80 - chain.price)
        XCTAssertEqual(Wardrobe.refusal(chain, in: state), "Déjà à toi")

        engine.wear(chain, in: &state)
        XCTAssertFalse(state.rapper.wearing?.contains("chaine_or") ?? false, "on peut la retirer")
        engine.wear(chain, in: &state)
        XCTAssertTrue(state.rapper.wearing?.contains("chaine_or") ?? false)
    }

    func testOnePiecePerSlot() throws {
        var state = game()
        try engine.buy(try XCTUnwrap(Wardrobe.item("survet_goslo")), in: &state)
        try engine.buy(try XCTUnwrap(Wardrobe.item("veste_cuir")), in: &state)
        XCTAssertEqual(state.rapper.wearing, ["veste_cuir"], "une seule veste à la fois")
        XCTAssertEqual(state.rapper.look.outfit, .jacket)
        XCTAssertEqual(Set(Wardrobe.items.map(\.id)).count, Wardrobe.items.count)
    }

    func testLevelAndMoneyGateTheShop() throws {
        var state = game()
        state.artistXP = 0
        let jacket = try XCTUnwrap(Wardrobe.items.first { $0.minLevel > 1 })
        XCTAssertNotNil(Wardrobe.refusal(jacket, in: state))
        XCTAssertThrowsError(try engine.buy(jacket, in: &state))
        XCTAssertNotNil(engine.decorRefusal(.statueMicro, plot: "nulle_part", in: state))
    }

    func testOldSavesLoad() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(game())) as? [String: Any])
        json["wardrobe"] = nil
        json["decor"] = nil
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.wardrobe.isEmpty)
        XCTAssertTrue(old.decor.isEmpty)
    }
}
