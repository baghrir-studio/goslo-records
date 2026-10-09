import XCTest
@testable import GosloRecords

/// The Moroccan-flag djellaba in the Fringues tab, and the services that do more than stat changes:
/// each one pays once, then waits for its yearly cooldown (or a level), so none of them can be farmed.
final class ShopServicesTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])
    private var rng = SeededGenerator(seed: 7)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func game(city: City = .paris) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Boutique", city: city, style: .boomBap))
        state.pendingCinematic = nil
        state.chapter = 3
        state.stats = Stats(streams: 40, credibilite: 40, argent: 90, mental: 40)
        state.artistXP = 10_000
        state.challenges = []
        state.challengeSeason = Challenges.season(of: state.turn)
        return state
    }

    private func service(_ id: String) throws -> ShopOffer { try XCTUnwrap(Shop.offer(id)) }

    /// Buys it, checks it can't be bought again this year, then that it can a year later.
    private func assertYearly(_ offer: ShopOffer, _ state: inout GameState, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Shop.refusal(offer, in: state), "Une fois par an", file: file, line: line)
        XCTAssertThrowsError(try engine.buy(offer, in: &state), file: file, line: line)
        state.turn += GameState.turnsPerYear
        state.stats = Stats(streams: state.stats.streams, credibilite: state.stats.credibilite, argent: 90, mental: state.stats.mental)
        state.actionsLeft = GameState.actionsPerTurn
        XCTAssertNil(Shop.refusal(offer, in: state), file: file, line: line)
    }

    // MARK: Djellaba

    func testTheDjellabaIsSoldGatedAndWorn() throws {
        let djellaba = try XCTUnwrap(Wardrobe.item("djellaba_maghrib"))
        XCTAssertEqual(djellaba.slot, .top)
        XCTAssertEqual(djellaba.city, .casablanca)
        XCTAssertLessThan(djellaba.price, 80)

        var state = game()
        state.artistXP = ArtistLevel.thresholds[djellaba.minLevel - 2]
        XCTAssertEqual(Wardrobe.refusal(djellaba, in: state), "Niveau \(djellaba.minLevel) requis")
        XCTAssertThrowsError(try engine.buy(djellaba, in: &state))

        state.artistXP = ArtistLevel.thresholds[djellaba.minLevel - 1]
        try engine.buy(djellaba, in: &state)
        XCTAssertEqual(state.stats.argent, 90 - djellaba.price)
        let look = state.rapper.look
        XCTAssertEqual(look.outfit, .djellaba)
        XCTAssertEqual(look.top, "#c1272d", "le rouge du drapeau")
        XCTAssertEqual(look.bottom, look.top, "la robe descend jusqu'aux chevilles")
        XCTAssertEqual(Wardrobe.refusal(djellaba, in: state), "Déjà à toi")

        try engine.buy(try XCTUnwrap(Wardrobe.item("veste_cuir")), in: &state)
        XCTAssertEqual(state.rapper.wearing, ["veste_cuir"], "une seule tenue à la fois")
        XCTAssertFalse(CharacterLook.Outfit.djellaba.isPickable, "elle s'achète, elle ne se choisit pas à la création")
    }

    func testTheDjellabaIsPutForwardInCasablanca() throws {
        XCTAssertEqual(Wardrobe.items(for: .casablanca).first?.id, "djellaba_maghrib")
        XCTAssertNotEqual(Wardrobe.items(for: .paris).first?.id, "djellaba_maghrib")
        XCTAssertEqual(Set(Wardrobe.items(for: .casablanca).map(\.id)), Set(Wardrobe.items.map(\.id)), "en vente partout")
        // A save wearing it reloads as is.
        var state = game(city: .casablanca)
        try engine.buy(try XCTUnwrap(Wardrobe.item("djellaba_maghrib")), in: &state)
        let reloaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(reloaded.rapper.look.outfit, .djellaba)
    }

    // MARK: Services

    func testEveryServiceHasAPriceACooldownAndNoMoneyBack() {
        XCTAssertGreaterThanOrEqual(Shop.services.count, 9)
        XCTAssertEqual(Set(Shop.offers.map(\.id)).count, Shop.offers.count)
        for offer in Shop.services {
            XCTAssertLessThan(offer.price, 80, offer.id)
            guard case .service(let effects) = offer.kind else { return XCTFail(offer.id) }
            XCTAssertLessThanOrEqual(effects[.argent, default: 0], 0, "\(offer.id) : rien à revendre")
            var state = game()
            XCTAssertNil(Shop.refusal(offer, in: state), offer.id)
            XCTAssertNoThrow(try engine.buy(offer, in: &state), offer.id)
            XCTAssertNotNil(Shop.refusal(offer, in: state), "\(offer.id) : pas deux fois de suite")
        }
    }

    func testLevelsGateTheBigServices() throws {
        var state = game()
        state.artistXP = 0
        for id in ["coach_vocal", "attache_presse", "masterclass", "avocat", "clip_real", "manager"] {
            let offer = try service(id)
            XCTAssertGreaterThan(offer.minLevel, 1, id)
            XCTAssertEqual(Shop.refusal(offer, in: state), "Niveau \(offer.minLevel) requis", id)
        }
        XCTAssertNil(Shop.refusal(try service("hammam"), in: state), "le hammam, c'est pour tout le monde")
    }

    func testHammamAndPress() throws {
        var state = game()
        let hammam = try service("hammam")
        try engine.buy(hammam, in: &state)
        XCTAssertGreaterThan(state.stats.mental, 40)
        assertYearly(hammam, &state)

        state = game()
        let press = try service("attache_presse")
        try engine.buy(press, in: &state)
        XCTAssertGreaterThan(state.stats.credibilite, 40)
        XCTAssertGreaterThan(state.stats.streams, 40)
        assertYearly(press, &state)
    }

    func testMasterclassTeachesAPlumeLevel() throws {
        var state = game()
        let before = state.skills.level(.plume)
        let masterclass = try service("masterclass")
        try engine.buy(masterclass, in: &state)
        XCTAssertEqual(state.skills.level(.plume), min(Skills.maxLevel, before + 1))
        assertYearly(masterclass, &state)
    }

    func testTheManagerGivesOneMoreAction() throws {
        var state = game()
        let manager = try service("manager")
        let actions = state.actionsLeft
        try engine.buy(manager, in: &state)
        XCTAssertEqual(state.actionsLeft, actions + 1)
        assertYearly(manager, &state)
        state.actionsLeft = 0
        XCTAssertEqual(Shop.refusal(manager, in: state), "Pas maintenant", "pas d'action en plus hors période")
    }

    func testTheVocalCoachLastsOneClash() throws {
        var state = game()
        state.skills = Skills()
        let coach = try service("coach_vocal")
        try engine.buy(coach, in: &state)
        XCTAssertEqual(Shop.refusal(coach, in: state), "Déjà réservé")

        _ = try XCTUnwrap(engine.startWildClash(in: &state, using: &rng))
        let clash = try XCTUnwrap(state.clash)
        let base = engine.clashLevels(in: state)
        XCTAssertEqual(engine.clashLevels(for: clash, in: state)(.flow), base(.flow) + 1, "+1 à tous les coups")
        while try !engine.clashMove(.flow, in: &state, using: &rng).isOver {}
        let outcome = try engine.finishClash(in: &state)
        XCTAssertTrue(outcome.notes.contains(GameEngine.coachSpentLine))
        XCTAssertFalse(engine.hasPerk(.coachVocal, in: state), "un seul clash")
        assertYearly(coach, &state)
    }

    func testTheDirectorShootsTheNextClip() throws {
        var state = game()
        state.artistXP = ArtistLevel.thresholds[3]  // Level 4: the director, but the clip is unlocked anyway.
        state.hooks = ["le bitume est mon costume"]
        let director = try service("clip_real")
        try engine.buy(director, in: &state)
        let argent = state.stats.argent
        let source = try XCTUnwrap(engine.singleCandidates(in: state).first)
        _ = try engine.releaseSingle(sourceId: source.id, perfectTakes: 2, clip: false, feat: nil, in: &state)
        let single = try XCTUnwrap(state.singles.last)
        XCTAssertTrue(single.clip, "clip offert")
        XCTAssertEqual(single.quality, min(10, ChartRules.quality(material: source.quality, perfectTakes: 2, feat: false) + 1))
        XCTAssertEqual(state.stats.argent, argent - ChartRules.studioPrice, "le clip ne se paie pas")
        XCTAssertFalse(engine.hasPerk(.clipReal, in: state), "un seul single")
        assertYearly(director, &state)
    }

    func testTheLawyerTakesTheNextLosses() throws {
        let choice = EventChoice(label: "c", effects: [.argent: -10, .credibilite: -5, .streams: 3], consequence: "aïe")
        let event = GameEvent(id: "galere", title: "galere", text: "", location: .studio, choices: [choice])
        let engine = GameEngine(events: [event])
        var state = engine.newGame(rapper: Rapper(name: "Boutique", city: .paris, style: .boomBap))
        state.pendingCinematic = nil
        state.chapter = 2
        state.stats = Stats(streams: 40, credibilite: 40, argent: 90, mental: 40)
        state.artistXP = 10_000
        state.actionsLeft = 5  // No end of period (and its upkeep) in the middle of the test.
        let lawyer = try service("avocat")
        try engine.buy(lawyer, in: &state)
        XCTAssertEqual(Shop.refusal(lawyer, in: state), "Déjà réservé")

        var stats = state.stats
        _ = try engine.visit(.studio, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(state.stats.argent, stats.argent, "l'avocat a tout réglé")
        XCTAssertEqual(state.stats.credibilite, stats.credibilite)
        XCTAssertGreaterThan(state.stats.streams, stats.streams, "les gains restent")
        XCTAssertFalse(engine.hasPerk(.avocat, in: state))

        stats = state.stats
        _ = try engine.visit(.studio, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertLessThan(state.stats.credibilite, stats.credibilite, "une seule galère")
        assertYearly(lawyer, &state)
    }
}
