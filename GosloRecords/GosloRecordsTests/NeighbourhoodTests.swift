import XCTest
@testable import GosloRecords

/// The neighbourhood businesses, their synergies and the period's demand.
final class NeighbourhoodTests: XCTestCase {
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
    }

    private let newBuildings: [Decor] = [.snack, .barbier, .salleBoxe, .disquaire, .radioPirate, .labelInde, .fresqueGeante]

    private func game() -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Bâtisseur", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 3
        state.stats = Stats(streams: 50, credibilite: 50, argent: 99, mental: 50)
        state.artistXP = 100_000
        return state
    }

    /// A turn whose demand doesn't touch these decorations.
    private func quietTurn(for decors: [Decor]) throws -> Int {
        try XCTUnwrap((0..<7).first { turn in Neighbourhood.demand(turn: turn).boosted.allSatisfy { !decors.contains($0) } })
    }

    func testThereIsAlwaysANextBuilding() {
        XCTAssertGreaterThanOrEqual(newBuildings.count, 6)
        let buildings = Decor.allCases.filter(\.isBuilding)
        for level in 2...ArtistLevel.maxLevel {
            XCTAssertTrue(buildings.contains { $0.minLevel == level }, "un bâtiment se débloque au niveau \(level)")
        }
        for decor in newBuildings {
            XCTAssertTrue(decor.isBuilding)
            XCTAssertLessThan(decor.price, 90, "\(decor) : il faut pouvoir se le payer (argent plafonné à 100)")
            XCTAssertFalse(decor.perTurn.isEmpty)
            XCTAssertFalse(decor.name.isEmpty)
            XCTAssertFalse(decor.pitch.isEmpty)
            XCTAssertFalse(Neighbourhood.partners(of: decor).isEmpty, "\(decor) a au moins une synergie")
            XCTAssertNotNil(decor.upgradeCost(from: 1))
            XCTAssertLessThan(decor.upgradeCost(from: 2) ?? 0, 100, "le dernier niveau reste payable")
        }
        // Each one more expensive with the level.
        let sorted = newBuildings.sorted { $0.minLevel < $1.minLevel }
        XCTAssertEqual(sorted.map(\.price), sorted.map(\.price).sorted())
    }

    func testNewBuildingsAreGatedPlacedAndPay() throws {
        for decor in newBuildings {
            var state = game()
            let map = try XCTUnwrap(engine.currentMap(in: state))
            state.artistXP = decor.minLevel >= 2 ? ArtistLevel.thresholds[decor.minLevel - 2] : 0
            XCTAssertEqual(engine.placementRefusal(decor, at: map.spawn, in: state, player: map.spawn), "Niveau \(decor.minLevel) requis")
            state.artistXP = ArtistLevel.thresholds[decor.minLevel - 1]
            let anchors = (0..<map.height).flatMap { y in (0..<map.width).map { TilePoint(x: $0, y: y) } }
            let spot = try XCTUnwrap(anchors.first { engine.placementRefusal(decor, at: $0, in: state, player: map.spawn) == nil },
                                     "\(decor) trouve une place dans le Bloc")
            try engine.place(decor, at: spot, in: &state, player: map.spawn)
            XCTAssertEqual(state.stats.argent, 99 - decor.price)
            let item = state.placed[0]
            XCTAssertEqual(item.tiles.count, decor.footprint.width * decor.footprint.height)
            XCTAssertTrue(engine.isBlockedByDecor(item.anchor, in: state))
            XCTAssertTrue(engine.keepsEverythingReachable(on: map, blocked: engine.decorTiles(in: state.district, state: state,
                                                                                             blockingOnly: true), from: map.spawn))

            state.turn = try quietTurn(for: [decor])
            state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 50)
            let income = engine.decorIncome(in: &state)
            XCTAssertEqual(state.placed[0].stored, decor.perTurn[.argent] ?? 0, "\(decor) : l'argent attend sur place")
            for (kind, value) in decor.perTurn where kind != .argent {
                XCTAssertEqual(income[kind], value, "\(decor) : \(kind)")
            }
        }
    }

    func testNeighboursBoostEachOther() throws {
        var state = game()
        state.turn = try quietTurn(for: [.barbier, .boutiqueMerch])
        let barbier = PlacedDecor(id: 1, decor: .barbier, district: .bloc, x: 5, y: 10)
        // One tile between the barber's right edge (x 6) and the shop (x 8): neighbours.
        let merch = PlacedDecor(id: 2, decor: .boutiqueMerch, district: .bloc, x: 8, y: 10)
        state.placed = [barbier, merch]
        let income = engine.income(of: barbier, in: state)
        XCTAssertEqual(income.synergies.map(\.partner), [.boutiqueMerch])
        XCTAssertEqual(income.total[.argent], 3, "2 + 1 de synergie")
        XCTAssertEqual(income.storageCap, 9)

        // Too far, or in another district: nothing.
        state.placed = [barbier, PlacedDecor(id: 2, decor: .boutiqueMerch, district: .bloc, x: 9, y: 10)]
        XCTAssertTrue(engine.income(of: barbier, in: state).synergies.isEmpty)
        state.placed = [barbier, PlacedDecor(id: 2, decor: .boutiqueMerch, district: .centre, x: 8, y: 10)]
        XCTAssertTrue(engine.income(of: barbier, in: state).synergies.isEmpty)

        // At the end of the period, the bonus lands in the barber's till.
        state.placed = [barbier, merch]
        engine.decorIncome(in: &state)
        XCTAssertEqual(state.placed[0].stored, 3)
        XCTAssertEqual(state.placed[1].stored, 4, "la boutique n'a pas de synergie avec le barbier")

        // The studio next to the label: more streams.
        state.placed = [PlacedDecor(id: 1, decor: .studioPerso, district: .bloc, x: 2, y: 5),
                        PlacedDecor(id: 2, decor: .labelInde, district: .bloc, x: 4, y: 5)]
        state.turn = try quietTurn(for: [.studioPerso, .labelInde])
        XCTAssertEqual(engine.income(of: state.placed[0], in: state).total[.streams], 2)
        XCTAssertEqual(engine.income(of: state.placed[1], in: state).total[.argent], (Decor.labelInde.perTurn[.argent] ?? 0) + 1)
    }

    func testTheGhostTellsTheSynergies() throws {
        var state = game()
        state.placed = [PlacedDecor(id: 1, decor: .boutiqueMerch, district: state.district, x: 8, y: 10)]
        let lines = engine.placementSynergies(.barbier, at: TilePoint(x: 5, y: 10), in: state)
        XCTAssertEqual(lines, ["+1 argent : synergie avec la boutique de merch"])
        // A stage next to the shop: the shop is the one that gains.
        let given = engine.placementSynergies(.scenePleinAir, at: TilePoint(x: 5, y: 10), in: state)
        XCTAssertEqual(given, ["+1 argent pour la boutique de merch"])
        XCTAssertTrue(engine.placementSynergies(.barbier, at: TilePoint(x: 20, y: 10), in: state).isEmpty)
        // Moving the shop itself never counts it as its own neighbour.
        XCTAssertTrue(engine.placementSynergies(.boutiqueMerch, at: TilePoint(x: 8, y: 10), in: state, moving: 1).isEmpty)
    }

    func testDemandComesRoundAndDoubles() throws {
        let seen = Set((0..<Neighbourhood.demands.count).map { Neighbourhood.demand(turn: $0).id })
        XCTAssertEqual(seen.count, Neighbourhood.demands.count, "chaque demande revient une fois par cycle")
        XCTAssertEqual(Neighbourhood.demand(turn: 3), Neighbourhood.demand(turn: 3 + Neighbourhood.demands.count))
        XCTAssertNotEqual(Neighbourhood.demand(turn: 0), Neighbourhood.demand(turn: 1), "ça change chaque période")

        var state = game()
        let hungry = try XCTUnwrap((0..<7).first { Neighbourhood.demand(turn: $0).id == "faim" })
        state.turn = hungry
        state.placed = [PlacedDecor(id: 1, decor: .snack, district: .bloc, x: 2, y: 5),
                        PlacedDecor(id: 2, decor: .salleBoxe, district: .bloc, x: 20, y: 5)]
        let snack = Decor.snack.perTurn[.argent] ?? 0
        XCTAssertTrue(engine.income(of: state.placed[0], in: state).boosted)
        engine.decorIncome(in: &state)
        XCTAssertEqual(state.placed[0].stored, snack * 2, "le quartier a faim : le snack rapporte double")
        state.turn = hungry + 1
        engine.decorIncome(in: &state)
        XCTAssertEqual(state.placed[0].stored, snack * 3, "la période d'après, retour à la normale")
        // Stored money never shrinks below what's waiting, even past the usual cap.
        for _ in 0..<5 { engine.decorIncome(in: &state) }
        XCTAssertEqual(state.placed[0].stored, max(snack * 3, engine.income(of: state.placed[0], in: state).storageCap))
    }

    func testBriefingShowsTheDemandOnceYouCanBuild() {
        var state = game()
        XCTAssertEqual(engine.periodBriefing(in: state, summary: nil).demand, Neighbourhood.demand(turn: state.turn).line)
        state.artistXP = 0
        XCTAssertNil(engine.periodBriefing(in: state, summary: nil).demand, "niveau 1 sans bâtiment : pas encore")
    }

    func testOldSavesAndNewBuildingsRoundTrip() throws {
        // A save from before the neighbourhood: buildings without the new fields load, and nothing new is stored.
        var state = game()
        state.placed = [PlacedDecor(id: 1, decor: .studioPerso, district: .bloc, x: 3, y: 6, level: 2, stored: 3)]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var placed = try XCTUnwrap((json["placed"] as? [[String: Any]])?.first)
        placed["invested"] = nil
        json["placed"] = [placed]
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.placed.first?.decor, .studioPerso)
        XCTAssertEqual(old.placed.first?.stored, 3)
        XCTAssertEqual(old.placed.first?.invested, Decor.studioPerso.price)

        // The new ones save and load.
        state.placed = newBuildings.enumerated().map { PlacedDecor(id: $0.offset + 1, decor: $0.element, district: .bloc, x: $0.offset * 4, y: 6) }
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(back.placed, state.placed)
    }
}
