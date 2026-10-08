import XCTest
@testable import GosloRecords

/// Each city's terrain vague has its own characters, and everyone can pick a build.
final class LocalsTests: XCTestCase {
    func testEveryCityHasItsOwnWildOpponents() throws {
        let engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
        let everywhere = engine.wildOpponents.filter { $0.cities == nil }
        XCTAssertFalse(everywhere.isEmpty)
        for city in City.allCases {
            let pool = engine.wildOpponents(in: city)
            let locals = Set(pool.filter { $0.cities != nil }.map(\.id))
            XCTAssertGreaterThanOrEqual(locals.count, 2, "\(city) : au moins deux adversaires locaux")
            XCTAssertTrue(pool.allSatisfy { $0.belongs(to: city) }, "\(city) : un adversaire d'une autre ville")
            XCTAssertTrue(everywhere.allSatisfy { member in pool.contains { $0.id == member.id } })
            for local in pool where local.cities != nil {
                XCTAssertNotNil(local.secret?.fx, "\(local.id) : technique sans animation")
                XCTAssertGreaterThanOrEqual(local.clash?.taunts.count ?? 0, 3, "\(local.id) : provocations")
            }
        }
    }

    func testWildClashesPickLocals() throws {
        let engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
        var rng = SeededGenerator(seed: 21)
        var met = Set<String>()
        for _ in 0..<200 {
            var state = engine.newGame(rapper: Rapper(name: "R", city: .marseille, style: .trap))
            state.pendingCinematic = nil
            if let clash = engine.startWildClash(in: &state, using: &rng) { met.insert(clash.opponentId) }
        }
        XCTAssertTrue(met.contains("mamie_petanque") || met.contains("minot_vieux_port"))
        XCTAssertFalse(met.contains("josee_poutine"), "pas de Montréalaise à Marseille")
    }

    func testBuildIsPickedAndSaved() throws {
        let rapper = Rapper(name: "R", city: .lille, style: .drill, build: .heavy)
        XCTAssertEqual(rapper.look.build, .heavy)
        XCTAssertEqual(Rapper(name: "R", city: .lille, style: .drill).look.build, .regular)
        XCTAssertEqual(try JSONDecoder().decode(Rapper.self, from: JSONEncoder().encode(rapper)).look.build, .heavy)
        let old = try JSONDecoder().decode(CharacterLook.self, from: Data(##"{"skin": "#c68642"}"##.utf8))
        XCTAssertEqual(old.build, .regular)
    }
}
