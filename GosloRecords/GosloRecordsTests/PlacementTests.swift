import XCTest
@testable import GosloRecords

/// Putting decorations and buildings where you want on the map, and buying goslo radio.
final class PlacementTests: XCTestCase {
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
    }

    private func game() -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Bâtisseur", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 3
        state.stats = Stats(streams: 50, credibilite: 50, argent: 99, mental: 50)
        state.artistXP = 100_000
        return state
    }

    /// Every free tile of Le Bloc where a decoration could go, with its anchor.
    private func freeSpots(for decor: Decor, in state: GameState, player: TilePoint) -> [TilePoint] {
        guard let map = engine.currentMap(in: state) else { return [] }
        return (0..<map.height).flatMap { y in (0..<map.width).map { TilePoint(x: $0, y: y) } }
            .filter { engine.placementRefusal(decor, at: $0, in: state, player: player) == nil }
    }

    func testSmallDecorGoesOnAnyFreeTile() throws {
        var state = game()
        let map = try XCTUnwrap(engine.currentMap(in: state))
        let player = map.spawn
        let spots = freeSpots(for: .palmier, in: state, player: player)
        XCTAssertGreaterThan(spots.count, 50, "beaucoup d'endroits possibles")
        for spot in spots.prefix(40) {
            XCTAssertNil(map.door(at: spot))
            XCTAssertNotEqual(spot, player)
        }
        let spot = try XCTUnwrap(spots.first)
        try engine.place(.palmier, at: spot, in: &state, player: player)
        XCTAssertEqual(state.placed.count, 1)
        XCTAssertEqual(state.stats.argent, 99 - Decor.palmier.price)
        XCTAssertEqual(engine.placementRefusal(.palmier, at: spot, in: state, player: player), "Il y a déjà quelque chose")
        XCTAssertFalse(engine.isBlockedByDecor(spot, in: state), "un palmier, on passe à côté sans souci")
    }

    func testBuildingsNeverCutTheWay() throws {
        var state = game()
        let map = try XCTUnwrap(engine.currentMap(in: state))
        let player = map.spawn
        // Fill the district with studios wherever they're allowed: every door and character stays reachable.
        for _ in 0..<30 {
            guard let spot = freeSpots(for: .studioPerso, in: state, player: player).first else { break }
            state.stats = Stats(streams: 50, credibilite: 50, argent: 99, mental: 50)
            try engine.place(.studioPerso, at: spot, in: &state, player: player)
        }
        XCTAssertGreaterThan(state.placed.count, 0)
        let blocked = engine.decorTiles(in: state.district, state: state, blockingOnly: true)
        XCTAssertTrue(engine.keepsEverythingReachable(on: map, blocked: blocked, from: player))
        let building = try XCTUnwrap(state.placed.first)
        XCTAssertEqual(building.tiles.count, 4, "2 × 2")
        XCTAssertTrue(engine.isBlockedByDecor(building.anchor, in: state), "un bâtiment bloque le passage")
    }

    func testPlacementIsGatedAndPays() throws {
        var state = game()
        state.artistXP = 0
        let map = try XCTUnwrap(engine.currentMap(in: state))
        XCTAssertEqual(engine.placementRefusal(.boutiqueMerch, at: map.spawn, in: state, player: map.spawn),
                       "Niveau \(Decor.boutiqueMerch.minLevel) requis")
        state = game()
        let spot = try XCTUnwrap(freeSpots(for: .boutiqueMerch, in: state, player: map.spawn).first)
        try engine.place(.boutiqueMerch, at: spot, in: &state, player: map.spawn)
        state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 50)
        // A period when the neighbourhood doesn't ask for merch (no double pay).
        state.turn = try XCTUnwrap((0..<7).first { !Neighbourhood.demand(turn: $0).boosted.contains(.boutiqueMerch) })
        let income = engine.decorIncome(in: &state)
        XCTAssertNil(income[.argent], "l'argent attend dans la boutique")
        XCTAssertEqual(state.placed[0].stored, Decor.boutiqueMerch.perTurn[.argent], "la boutique rapporte chaque période")
        XCTAssertEqual(engine.collect(state.placed[0].id, in: &state), 4)
        XCTAssertEqual(state.stats.argent, 54)
        XCTAssertEqual(state.placed[0].stored, 0)
        XCTAssertTrue(Decor.allCases.filter(\.isBuilding).allSatisfy { $0.price >= 30 }, "les bâtiments sont chers")
    }

    func testBuyingGosloRadio() throws {
        var state = game()
        state.artistXP = 0
        XCTAssertEqual(RadioDeal.refusal(in: state), "Niveau \(RadioDeal.minLevel) requis")
        state = game()
        try engine.buyRadio(in: &state)
        XCTAssertTrue(state.flags.contains(RadioDeal.flag))
        XCTAssertEqual(RadioDeal.refusal(in: state), "Elle est déjà à toi")
        let single = Single(id: 1, title: "T", sourceId: "x", quality: 8, releasedTurn: state.turn, clip: false, feat: nil)
        var plain = state
        plain.flags.remove(RadioDeal.flag)
        XCTAssertGreaterThan(engine.singleScore(single, in: state), engine.singleScore(single, in: plain), "ta radio pousse tes sons")
    }

    func testMoneyWaitsButNotForever() throws {
        var state = game()
        let map = try XCTUnwrap(engine.currentMap(in: state))
        let spot = try XCTUnwrap(freeSpots(for: .studioPerso, in: state, player: map.spawn).first)
        try engine.place(.studioPerso, at: spot, in: &state, player: map.spawn)
        for _ in 0..<10 { engine.decorIncome(in: &state) }
        XCTAssertEqual(state.placed[0].stored, 6, "trois périodes au maximum : passe récupérer")
    }

    func testUpgradeMoveAndSell() throws {
        var state = game()
        let map = try XCTUnwrap(engine.currentMap(in: state))
        let spots = freeSpots(for: .studioPerso, in: state, player: map.spawn)
        try engine.place(.studioPerso, at: try XCTUnwrap(spots.first), in: &state, player: map.spawn)
        let id = state.placed[0].id

        state.stats = Stats(streams: 50, credibilite: 50, argent: 99, mental: 50)
        let cost = try XCTUnwrap(Decor.studioPerso.upgradeCost(from: 1))
        try engine.upgrade(id, in: &state)
        XCTAssertEqual(state.placed[0].level, 2)
        XCTAssertEqual(state.stats.argent, 99 - cost)
        XCTAssertEqual(state.placed[0].perTurn[.argent], 3, "×1,5 au niveau 2")
        state.stats = Stats(streams: 50, credibilite: 50, argent: 99, mental: 50)
        try engine.upgrade(id, in: &state)
        XCTAssertEqual(state.placed[0].perTurn[.argent], 4, "×2 au niveau 3")
        XCTAssertEqual(engine.upgradeRefusal(id, in: state), "Niveau max")

        // Moving is free, and its old spot doesn't count as taken.
        let before = state.stats.argent
        let target = try XCTUnwrap(spots.last { engine.moveRefusal(id, to: $0, in: state, player: map.spawn) == nil })
        XCTAssertNotEqual(target, state.placed[0].anchor)
        XCTAssertNil(engine.moveRefusal(id, to: state.placed[0].anchor, in: state, player: map.spawn))
        try engine.move(id, to: target, in: &state, player: map.spawn)
        XCTAssertEqual(state.placed[0].anchor, target)
        XCTAssertEqual(state.placed[0].level, 3)
        XCTAssertEqual(state.stats.argent, before)

        state.stats = Stats(streams: 50, credibilite: 50, argent: 10, mental: 50)
        let invested = state.placed[0].invested
        engine.sell(id, in: &state)
        XCTAssertTrue(state.placed.isEmpty)
        XCTAssertEqual(state.stats.argent, 10 + invested / 2)
        XCTAssertNil(Decor.palmier.upgradeCost(from: 1), "les petites décos ne s'améliorent pas")
    }

    func testOldSavesLoad() throws {
        var placed = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(
            PlacedDecor(id: 1, decor: .sono, district: .bloc, x: 3, y: 4))) as? [String: Any])
        placed["level"] = nil; placed["stored"] = nil; placed["invested"] = nil
        let oldItem = try JSONDecoder().decode(PlacedDecor.self, from: JSONSerialization.data(withJSONObject: placed))
        XCTAssertEqual(oldItem.level, 1)
        XCTAssertEqual(oldItem.invested, Decor.sono.price)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(game())) as? [String: Any])
        json["placed"] = nil
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.placed.isEmpty)
    }
}
