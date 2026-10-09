import XCTest
@testable import GosloRecords

/// Victory chests (four slots, unlocked in periods) and permanent leagues (trophies with floors).
final class ChestsLeaguesTests: XCTestCase {
    private let weak = CastMember(id: "faible", name: "Faible", role: "",
                                  clash: ClashProfile(stats: [.punchline: 1, .flow: 1, .presence: 1, .story: 1]), wild: true)
    private let strong = CastMember(id: "costaud", name: "Costaud", role: "",
                                    clash: ClashProfile(stats: [.punchline: 9, .flow: 9, .presence: 9, .story: 9]))
    private let boss = CastMember(id: "boss_tournoi", name: "Boss", role: "",
                                  clash: ClashProfile(stats: [.punchline: 6, .flow: 6, .presence: 6, .story: 6]))
    private let rapide = UnlockableTechnique(id: "technique_niveau", secret: SecretTechnique(name: "La Test", line: "Bim."),
                                             minArtistLevel: 8)

    private func engine() -> GameEngine {
        let story = Story(techniques: [rapide], tournament: [
            TournamentBoss(opponent: "boss_tournoi", minArtistLevel: 1, technique: "technique_niveau",
                           win: ClashResultSpec(consequence: "gagné"), lose: ClashResultSpec(consequence: "perdu")),
        ])
        return GameEngine(world: World(events: [
            GameEvent(id: "maison", title: "", text: "", location: .chezToi,
                      choices: [EventChoice(label: "Dormir", effects: [:], consequence: "ok")]),
        ], cast: [weak, strong, boss], story: story))
    }

    private func game(_ engine: GameEngine) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Coffre", city: .lyon, style: .trap))
        state.pendingCinematic = nil
        state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 60)
        return state
    }

    /// Plays out a clash already decided: `won` or lost.
    private func finish(_ spec: ClashSpec, won: Bool, wild: Bool = false, _ engine: GameEngine,
                        _ state: inout GameState) throws -> TurnOutcome {
        var clash = ClashState(spec: spec, isWild: wild)
        if won { clash.opponentHype = 0 } else { clash.playerHype = 0 }
        state.clash = clash
        if !wild { state.actionsLeft = max(state.actionsLeft, 2) }
        return try engine.finishClash(in: &state)
    }

    private func spec(_ opponent: String, boss: Bool = false) -> ClashSpec {
        ClashSpec(opponent: opponent, win: ClashResultSpec(consequence: "oui"), lose: ClashResultSpec(consequence: "non"), boss: boss)
    }

    private func endPeriod(_ engine: GameEngine, _ state: inout GameState) throws {
        var rng = SeededGenerator(seed: 3)
        let turn = state.turn
        while state.turn == turn {
            _ = try engine.visit(.chezToi, in: &state, using: &rng)
            _ = try engine.resolve(choiceAt: 0, in: &state)
        }
    }

    // MARK: Chests

    func testAWinGrantsAChestUntilTheFourSlotsAreFull() throws {
        let engine = engine()
        var state = game(engine)
        // Already at the top: no league chest gets in the way.
        state.trophies = League.icone.threshold
        state.bestLeague = .icone
        for index in 0..<Chests.slots {
            let outcome = try finish(spec("costaud"), won: true, engine, &state)
            XCTAssertNotNil(outcome.chest)
            XCTAssertEqual(state.chests.count, index + 1)
        }
        let full = try finish(spec("costaud"), won: true, engine, &state)
        XCTAssertNil(full.chest)
        XCTAssertEqual(state.chests.count, Chests.slots)
        XCTAssertTrue(full.notes.contains { $0.hasPrefix("Coffres pleins") })

        // A defeat never gives a chest.
        state.chests = []
        let lost = try finish(spec("costaud"), won: false, engine, &state)
        XCTAssertNil(lost.chest)
        XCTAssertTrue(state.chests.isEmpty)
    }

    func testTournamentBossesGiveALegendaryChest() throws {
        let engine = engine()
        var state = game(engine)
        let boss = try XCTUnwrap(engine.story.tournament.first)
        let outcome = try finish(boss.spec, won: true, engine, &state)
        XCTAssertEqual(outcome.chest, .legendaire)
    }

    func testUnpaidTerrainWinsGiveNoChestAndNoTrophies() throws {
        let engine = engine()
        var state = game(engine)
        let cap = Gate.terrain.perPeriod(level: 1)
        for _ in 0..<cap { _ = try finish(spec("faible"), won: true, wild: true, engine, &state) }
        XCTAssertEqual(state.chests.count, min(cap, Chests.slots))
        state.chests = []
        let trophies = state.trophies
        let friendly = try finish(spec("faible"), won: true, wild: true, engine, &state)
        XCTAssertNil(friendly.chest)
        XCTAssertTrue(state.chests.isEmpty)
        XCTAssertEqual(state.trophies, trophies)
        let friendlyLoss = try finish(spec("faible"), won: false, wild: true, engine, &state)
        XCTAssertNil(friendlyLoss.trophies)
        XCTAssertEqual(state.trophies, trophies, "un match amical ne coûte rien non plus")
    }

    func testChestsUnlockInPeriodsOneAtATime() throws {
        let engine = engine()
        var state = game(engine)
        var outcome = TurnOutcome(consequence: "")
        engine.grantChest(.argent, in: &state, outcome: &outcome)
        engine.grantChest(.bronze, in: &state, outcome: &outcome)
        let argent = state.chests[0], bronze = state.chests[1]
        XCTAssertEqual(engine.chestStatus(argent, in: state), .locked)
        XCTAssertThrowsError(try engine.openChest(argent.id, in: &state), "pas encore prêt")

        try engine.startUnlocking(argent.id, in: &state)
        XCTAssertEqual(engine.chestStatus(state.chests[0], in: state), .unlocking(2))
        XCTAssertNotNil(engine.unlockRefusal(bronze.id, in: state), "un seul coffre à la fois")
        XCTAssertThrowsError(try engine.startUnlocking(bronze.id, in: &state))

        try endPeriod(engine, &state)
        XCTAssertEqual(engine.chestStatus(state.chests[0], in: state), .unlocking(1))
        XCTAssertFalse(engine.hasReadyChest(in: state))
        try endPeriod(engine, &state)
        XCTAssertEqual(engine.chestStatus(state.chests[0], in: state), .ready)
        XCTAssertTrue(engine.hasReadyChest(in: state))
        // A ready chest doesn't block the next one.
        XCTAssertNil(engine.unlockRefusal(bronze.id, in: state))

        let loot = try engine.openChest(argent.id, in: &state)
        XCTAssertEqual(loot.rarity, .argent)
        XCTAssertEqual(state.chests.map(\.id), [bronze.id])
        XCTAssertThrowsError(try engine.openChest(argent.id, in: &state), "ouvert une seule fois")
    }

    func testRushingCostsMoneyPerPeriodLeft() throws {
        let engine = engine()
        var state = game(engine)
        var outcome = TurnOutcome(consequence: "")
        engine.grantChest(.or, in: &state, outcome: &outcome)
        let chest = state.chests[0]
        XCTAssertEqual(engine.rushCost(chest, in: state), 3 * ChestRarity.rushPerPeriod)
        try engine.startUnlocking(chest.id, in: &state)
        try endPeriod(engine, &state)
        state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 60)
        XCTAssertEqual(engine.rushCost(state.chests[0], in: state), 2 * ChestRarity.rushPerPeriod)

        let loot = try engine.rushChest(chest.id, in: &state)
        XCTAssertEqual(state.stats.argent, 50 - 2 * ChestRarity.rushPerPeriod + loot.money)
        XCTAssertTrue(state.chests.isEmpty)

        // Never down to an empty wallet.
        engine.grantChest(.legendaire, in: &state, outcome: &outcome)
        state.stats = Stats(streams: 50, credibilite: 50, argent: 12, mental: 60)
        XCTAssertEqual(engine.rushRefusal(state.chests[0].id, in: state), "Pas assez d'argent")
        XCTAssertThrowsError(try engine.rushChest(state.chests[0].id, in: &state))
    }

    func testChestContentsStayWithinBounds() throws {
        let engine = engine()
        for rarity in ChestRarity.allCases {
            for _ in 0..<40 {
                var state = game(engine)
                var outcome = TurnOutcome(consequence: "")
                engine.grantChest(rarity, in: &state, outcome: &outcome)
                let wardrobe = state.wardrobe
                let loot = try engine.rushChest(state.chests[0].id, in: &state)
                XCTAssertTrue(rarity.xp.contains(loot.xp))
                XCTAssertGreaterThanOrEqual(loot.money, rarity.money.lowerBound)
                XCTAssertLessThanOrEqual(loot.money, rarity.money.upperBound + 3)
                if let item = loot.wearable {
                    XCTAssertFalse(wardrobe.contains(item), "toujours une pièce qu'on n'a pas")
                    XCTAssertTrue(state.wardrobe.contains(item))
                }
                if rarity == .legendaire { XCTAssertNotNil(loot.wearable, "un légendaire a toujours une fringue") }
                if rarity == .bronze { XCTAssertNil(loot.wearable); XCTAssertNil(loot.technique) }
                XCTAssertTrue(Stats.range.contains(state.stats.argent))
            }
        }
    }

    func testAChestCanUnlockACareerTechniqueEarly() throws {
        let engine = engine()
        var found = false
        for _ in 0..<60 where !found {
            var state = game(engine)
            var outcome = TurnOutcome(consequence: "")
            engine.grantChest(.legendaire, in: &state, outcome: &outcome)
            let loot = try engine.rushChest(state.chests[0].id, in: &state)
            if loot.technique == "technique_niveau" {
                found = true
                XCTAssertTrue(engine.availableTechniques(in: state).contains { $0.id == "technique_niveau" })
                XCTAssertTrue(engine.chestTechniques(in: state).isEmpty, "pas deux fois la même")
            }
        }
        XCTAssertTrue(found, "35 % par coffre légendaire")
    }

    func testLegendaryChestsCanDropCrewCards() throws {
        let engine = engine()
        var cards = 0
        for _ in 0..<40 {
            var state = game(engine)
            var outcome = TurnOutcome(consequence: "")
            engine.grantChest(.legendaire, in: &state, outcome: &outcome)
            let loot = try engine.rushChest(state.chests[0].id, in: &state)
            if let gain = loot.crew {
                cards += 1
                XCTAssertTrue(state.crew.owns(gain.cardId))
            }
        }
        XCTAssertGreaterThan(cards, 0, "50 % par coffre légendaire")
    }

    // MARK: Trophies and leagues

    func testWinsGiveMoreAgainstStrongerOpponents() {
        let easy = Trophies.delta(won: true, wild: false, boss: false, gap: -3)
        let hard = Trophies.delta(won: true, wild: false, boss: false, gap: 3)
        XCTAssertGreaterThan(hard, easy)
        XCTAssertGreaterThan(easy, 0)
        XCTAssertLessThan(Trophies.delta(won: false, wild: false, boss: false, gap: 0), 0)
        XCTAssertLessThan(abs(Trophies.delta(won: false, wild: false, boss: false, gap: 3)),
                          abs(Trophies.delta(won: false, wild: false, boss: false, gap: -3)), "perdre contre plus fort coûte moins")
    }

    func testTrophiesFromClashes() throws {
        let engine = engine()
        var state = game(engine)
        let won = try finish(spec("costaud"), won: true, engine, &state)
        let gained = try XCTUnwrap(won.trophies)
        XCTAssertGreaterThan(gained, 0)
        XCTAssertEqual(state.trophies, gained)
        state.trophies = 100
        let lost = try finish(spec("faible"), won: false, engine, &state)
        XCTAssertLessThan(try XCTUnwrap(lost.trophies), 0)
        XCTAssertLessThan(state.trophies, 100)
    }

    func testLossesNeverGoBelowTheLeagueFloor() throws {
        let engine = engine()
        var state = game(engine)
        var outcome = TurnOutcome(consequence: "")
        engine.changeTrophies(by: League.or.threshold + 5, in: &state, outcome: &outcome)
        XCTAssertEqual(state.bestLeague, .or)
        for _ in 0..<5 { _ = try finish(spec("faible"), won: false, engine, &state) }
        XCTAssertEqual(state.trophies, League.or.threshold)
        XCTAssertEqual(state.league, .or)
        // Bronze has no floor above zero.
        var rookie = game(engine)
        let lost = try finish(spec("faible"), won: false, engine, &rookie)
        XCTAssertEqual(rookie.trophies, 0)
        XCTAssertEqual(lost.trophies, 0)
    }

    func testReachingALeaguePaysOnce() throws {
        let engine = engine()
        var state = game(engine)
        var first = TurnOutcome(consequence: "")
        engine.changeTrophies(by: League.argent.threshold, in: &state, outcome: &first)
        XCTAssertEqual(first.league, .argent)
        XCTAssertEqual(first.deltas[.argent], League.argent.reward.money)
        XCTAssertEqual(state.chests.map(\.rarity), [.argent])
        XCTAssertTrue(first.notes.contains { $0.hasPrefix("LIGUE ARGENT") })
        XCTAssertEqual(state.leagueTitle, League.argent.title)

        // Down and back up: no second reward.
        state.trophies = League.argent.threshold + 10
        var again = TurnOutcome(consequence: "")
        engine.changeTrophies(by: -10, in: &state, outcome: &again)
        engine.changeTrophies(by: 10, in: &state, outcome: &again)
        XCTAssertNil(again.league)
        XCTAssertEqual(state.chests.count, 1)

        // A big jump pays every league on the way, chests paid cash once the slots are full.
        var jump = TurnOutcome(consequence: "")
        engine.changeTrophies(by: League.icone.threshold, in: &state, outcome: &jump)
        XCTAssertEqual(jump.league, .icone)
        XCTAssertEqual(state.bestLeague, .icone)
        XCTAssertEqual(state.chests.count, Chests.slots)
        XCTAssertEqual(jump.notes.filter { $0.hasPrefix("LIGUE") }.count, League.allCases.count - 2)
    }

    func testLeagueThresholdsClimb() {
        let thresholds = League.allCases.map(\.threshold)
        XCTAssertEqual(thresholds, thresholds.sorted())
        XCTAssertEqual(Set(thresholds).count, thresholds.count)
        XCTAssertEqual(League.of(trophies: 0), .bronze)
        XCTAssertEqual(League.of(trophies: 99_999), .icone)
    }

    func testOldSavesLoad() throws {
        let engine = engine()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(game(engine))) as? [String: Any])
        for key in ["chests", "chestSerial", "trophies", "bestLeague"] { json[key] = nil }
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.chests.isEmpty)
        XCTAssertEqual(old.chestSerial, 0)
        XCTAssertEqual(old.trophies, 0)
        XCTAssertEqual(old.bestLeague, .bronze)

        // And the new fields round-trip.
        var state = game(engine)
        var outcome = TurnOutcome(consequence: "")
        engine.changeTrophies(by: League.or.threshold, in: &state, outcome: &outcome)
        try engine.startUnlocking(state.chests[0].id, in: &state)
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.chests, state.chests)
        XCTAssertEqual(decoded.trophies, state.trophies)
        XCTAssertEqual(decoded.bestLeague, .or)
    }
}
