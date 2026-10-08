import XCTest
@testable import GosloRecords

final class SecretsTests: XCTestCase {
    func testTheHouseCodeDressesYouInGold() {
        let house = Rapper(name: " Goslo ", city: .paris, style: .trap)
        XCTAssertTrue(house.isHouseMember)
        XCTAssertEqual(house.look.top, "#e8c547")
        XCTAssertTrue(house.look.chain)
        XCTAssertFalse(Rapper(name: "Gosling", city: .paris, style: .trap).isHouseMember)
        var state = GameState(rapper: house)
        XCTAssertTrue(AchievementRules.earned(in: state).contains(.maison))
        state.flags = [Secrets.jingleFlag, Secrets.archiveFlag, Secrets.pigeonFlag]
        XCTAssertTrue(AchievementRules.earned(in: state).isSuperset(of: [.auditeur, .archeologue, .roucoulade]))
    }

    func testThePigeonOnlyLivesInLille() throws {
        let engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
        let pigeon = try XCTUnwrap(engine.castMember("pigeon_lille"))
        XCTAssertNotNil(pigeon.clash)
        XCTAssertFalse(pigeon.wild, "rare : il n'est pas dans le tirage normal")
        var rng = SeededGenerator(seed: 5)
        var metInLille = false, metElsewhere = false
        for i in 0..<400 {
            let city: City = i % 2 == 0 ? .lille : .paris
            var state = engine.newGame(rapper: Rapper(name: "R", city: city, style: .trap))
            state.pendingCinematic = nil
            guard let clash = engine.startWildClash(in: &state, using: &rng), clash.opponentId == pigeon.id else { continue }
            if city == .lille { metInLille = true } else { metElsewhere = true }
            XCTAssertTrue(clash.spec.win.setFlags.contains(Secrets.pigeonFlag))
        }
        XCTAssertTrue(metInLille)
        XCTAssertFalse(metElsewhere)
    }

    func testSecretAchievementsAreHidden() {
        XCTAssertTrue(Achievement.roucoulade.isSecret)
        XCTAssertFalse(Achievement.legende.isSecret)
    }
}

final class PhilosopherTests: XCTestCase {
    func testThePhilosopherReadsYourRefrains() throws {
        let engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
        XCTAssertNotNil(engine.castMember(Philosopher.id))
        XCTAssertTrue(try XCTUnwrap(engine.world.map).npcs.contains { $0.id == Philosopher.id }, "il a son banc au Bloc")
        var state = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .boomBap))
        XCTAssertEqual(engine.philosopherReading(in: &state).count, 1, "sans refrain : une invitation")

        state.hooks = ["essoré, mais jamais délavé", "le bitume est mon costume", "j'écris la nuit"]
        let xp = state.skills.xp(.plume)
        let first = engine.philosopherReading(in: &state)
        XCTAssertTrue(first[0].contains("j'écris la nuit"), "le plus récent d'abord")
        XCTAssertEqual(state.skills.xp(.plume), xp + Philosopher.readingXP)
        _ = engine.philosopherReading(in: &state)
        _ = engine.philosopherReading(in: &state)
        XCTAssertEqual(engine.analysedRefrains(in: state), 3)
        XCTAssertTrue(AchievementRules.earned(in: state).contains(.maieutique))
        let again = engine.philosopherReading(in: &state)
        XCTAssertEqual(state.skills.xp(.plume), xp + 3 * Philosopher.readingXP, "pas d'XP pour une relecture")
        XCTAssertTrue(again[1].contains("déjà"))
        XCTAssertEqual(Philosopher.reading(of: "x"), Philosopher.reading(of: "x"), "toujours le même penseur pour le même refrain")
    }
}
