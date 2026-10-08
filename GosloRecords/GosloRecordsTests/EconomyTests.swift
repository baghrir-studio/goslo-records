import XCTest
@testable import GosloRecords

/// Difficulty, gains that shrink near the top, consequences at the end of a turn, the shop, and rivals
/// who don't stop you every time.
final class EconomyTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func game(_ difficulty: Difficulty = .normal) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Éco", city: .paris, style: .trap, difficulty: difficulty))
        state.pendingCinematic = nil
        return state
    }

    func testGainsShrinkNearTheTop() {
        XCTAssertEqual(Economy.tuned(10, at: 40, difficulty: .normal), 10, "sous 60, on garde tout")
        XCTAssertLessThan(Economy.tuned(10, at: 85, difficulty: .normal), 6, "à 85, beaucoup moins")
        XCTAssertGreaterThanOrEqual(Economy.tuned(10, at: 99, difficulty: .normal), 1, "toujours au moins 1")
        XCTAssertEqual(Economy.tuned(-10, at: 90, difficulty: .normal), -10, "les pertes ne rétrécissent pas")

        var state = game()
        state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 50)
        for _ in 0..<6 { state.applyStats([.streams: 15]) }
        XCTAssertLessThan(state.stats.streams, 95, "plus question de maxer en quelques choix")
    }

    func testDifficultyScalesGainsLossesRentAndClashes() {
        XCTAssertGreaterThan(Economy.tuned(10, at: 30, difficulty: .facile), Economy.tuned(10, at: 30, difficulty: .difficile))
        XCTAssertLessThan(Economy.tuned(-10, at: 30, difficulty: .difficile), Economy.tuned(-10, at: 30, difficulty: .facile))
        XCTAssertLessThan(Difficulty.facile.rent, Difficulty.difficile.rent)
        XCTAssertEqual(game().difficulty, .normal, "Normal par défaut")

        let easy = engine.clashLevels(in: game(.facile))(.plume), hard = engine.clashLevels(in: game(.difficile))(.plume)
        XCTAssertGreaterThan(easy, hard)
    }

    func testTurnEndHasConsequences() {
        var state = game()
        state.stats = Stats(streams: 50, credibilite: 10, argent: 50, mental: 50)
        let low = Economy.turnEnd(for: state)
        XCTAssertLessThan(low.effects[.argent]!, -state.difficulty.rent, "respect au plus bas : plus de bookings")
        XCTAssertFalse(low.notes.isEmpty)

        state.stats = Stats(streams: 50, credibilite: 80, argent: 50, mental: 50)
        XCTAssertGreaterThan(Economy.turnEnd(for: state).effects[.argent]!, 0, "le respect paie")
    }

    func testBurnOutLeavesOneAction() throws {
        let plain = GameEvent(id: "e", title: "e", text: "", location: .studio, npc: nil, weight: 10, unique: false,
                              conditions: EventConditions(), choices: [EventChoice(label: "c", consequence: "ok")])
        let small = GameEngine(events: [plain])
        var rng = SeededGenerator(seed: 3)
        var state = small.newGame(rapper: Rapper(name: "B", city: .paris, style: .trap))
        state.chapter = 2
        state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: Economy.burnout - 5)
        for _ in 0..<GameState.actionsPerTurn {
            _ = try small.visit(.studio, in: &state, using: &rng)
            _ = try small.resolve(choiceAt: 0, in: &state)
        }
        XCTAssertEqual(state.turn, 1)
        XCTAssertEqual(state.actionsLeft, 1, "burn-out : une seule action")
    }

    func testShopSellsGearAndServices() throws {
        var state = game()
        state.stats = Stats(streams: 40, credibilite: 40, argent: 60, mental: 30)
        let mic = try XCTUnwrap(Shop.offer("micro_pro"))
        let before = engine.clashLevels(in: state)(.scene)
        try engine.buy(mic, in: &state)
        XCTAssertEqual(state.stats.argent, 60 - mic.price)
        XCTAssertEqual(engine.clashLevels(in: state)(.scene), min(Skills.maxLevel, before + 1), "+1 en présence")
        XCTAssertEqual(Shop.refusal(mic, in: state), "Déjà à toi")
        XCTAssertTrue(engine.ownedItems(in: state).contains { $0.id == "micro_pro" }, "visible dans le carnet")

        let psy = try XCTUnwrap(Shop.offer("psy"))
        try engine.buy(psy, in: &state)
        XCTAssertGreaterThan(state.stats.mental, 30)
        XCTAssertEqual(Shop.refusal(psy, in: state), "Une fois par an")
        state.turn += GameState.turnsPerYear
        XCTAssertNil(Shop.refusal(psy, in: state))

        state.stats = Stats(streams: 40, credibilite: 40, argent: psy.price, mental: 30)
        XCTAssertEqual(Shop.refusal(psy, in: state), "Pas assez d'argent", "jamais ton dernier euro")
        XCTAssertThrowsError(try engine.buy(psy, in: &state))
        XCTAssertEqual(Set(Shop.offers.map(\.id)).count, Shop.offers.count)
        XCTAssertTrue(Set(Shop.gear.map(\.id)).isDisjoint(with: world.story.items.map(\.id)))
    }

    func testRivalsStopYouOnceAYear() {
        var state = game()
        state.chapter = 3
        let rival = "big_kliks"
        state.challengedAt[rival] = state.turn
        XCTAssertFalse(engine.canChallenge(rival, in: state), "pas deux fois dans l'année")
        state.turn += GameState.turnsPerYear
        state.challengedThisSemester = []
        state.challengedAt[rival] = state.turn - GameState.turnsPerYear
        // Once the cooldown is over, only the usual rules apply.
        let usual = engine.canChallenge(rival, in: state)
        state.challengedAt[rival] = nil
        XCTAssertEqual(engine.canChallenge(rival, in: state), usual)
    }

    func testYearsAreLongerAndOldSavesLoad() throws {
        var state = game()
        state.turn = GameState.turnsPerYear - 1
        XCTAssertEqual(state.careerYear, 1)
        XCTAssertFalse(state.isNewYear)
        state.turn = GameState.turnsPerYear
        XCTAssertEqual(state.careerYear, 2)
        XCTAssertTrue(state.isNewYear)
        XCTAssertEqual(state.periodLabel, "ANNÉE 2")

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["challengedAt"] = nil
        json["boughtAt"] = nil
        var rapper = try XCTUnwrap(json["rapper"] as? [String: Any])
        rapper["difficultyChoice"] = nil
        json["rapper"] = rapper
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.difficulty, .normal)
        XCTAssertTrue(old.challengedAt.isEmpty)
    }

    func testTheRadioWaitsForTheArtistLevel() {
        var state = game()
        state.chapter = 3
        XCTAssertFalse(engine.isUnlocked(.media, in: state), "pas de radio au niveau 1")
        state.artistXP = ArtistLevel.thresholds[Location.media.minArtistLevel - 1]
        XCTAssertTrue(engine.isUnlocked(.media, in: state))
        XCTAssertFalse(Location.media.lockedHint.isEmpty)
    }

    func testFarmingAPlacePaysLess() {
        var state = game()
        XCTAssertEqual(engine.fatigue(at: .studio, in: state), 1)
        state.visitsThisYear[Location.studio.rawValue] = GameEngine.freshVisits + 2
        XCTAssertLessThan(engine.fatigue(at: .studio, in: state), 1, "trop de passages : ça rapporte moins")
        XCTAssertEqual(engine.fatigue(at: .chezToi, in: state), 1, "chez toi, on se repose sans compter")
        state.visitsThisYear[Location.studio.rawValue] = 50
        XCTAssertGreaterThan(engine.fatigue(at: .studio, in: state), 0)
    }
}
