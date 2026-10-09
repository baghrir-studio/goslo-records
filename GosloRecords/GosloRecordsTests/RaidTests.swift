import XCTest
@testable import GosloRecords

/// Raids: a rival hits a building left full, holds half its money, and gives it back only to a clash.
final class RaidTests: XCTestCase {
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
    }

    /// Level 5, Lil Sauge met, a snack in Le Bloc (placed where the rules allow it).
    private func game() throws -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Proprio", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 3
        state.stats = Stats(streams: 50, credibilite: 50, argent: 99, mental: 60)
        state.artistXP = ArtistLevel.thresholds[4]
        state.metCast.insert("lil_sauge")
        state.challenges = []
        state.challengeSeason = Challenges.season(of: state.turn)
        let map = try XCTUnwrap(engine.currentMap(in: state))
        let anchors = (0..<map.height).flatMap { y in (0..<map.width).map { TilePoint(x: $0, y: y) } }
        let spot = try XCTUnwrap(anchors.first { engine.placementRefusal(.snack, at: $0, in: state, player: map.spawn) == nil })
        try engine.place(.snack, at: spot, in: &state, player: map.spawn)
        state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 60)
        return state
    }

    private func fill(_ state: inout GameState) {
        state.placed[0].stored = engine.income(of: state.placed[0], in: state).storageCap
    }

    /// A state whose period end brings a raid on the snack (the first turn whose roll hits).
    private func raided() throws -> GameState {
        var state = try game()
        fill(&state)
        for turn in 0..<400 {
            var probe = state
            probe.turn = turn
            if engine.rollRaid(among: engine.fullBuildings(in: probe), in: probe) != nil {
                _ = engine.raidsAtPeriodEnd(wasFull: engine.fullBuildings(in: probe), in: &probe)
                return probe
            }
        }
        throw XCTSkip("aucun raid en 400 tours")
    }

    func testOnlyAFullBuildingTempts() throws {
        var state = try game()
        state.placed[0].stored = 1
        XCTAssertTrue(engine.fullBuildings(in: state).isEmpty, "pas plein : rien à voler")
        fill(&state)
        XCTAssertEqual(engine.fullBuildings(in: state), [state.placed[0].id])
        XCTAssertNil(engine.rollRaid(among: [], in: state), "plein depuis moins d'une période : pas de raid")
    }

    func testNoRaidBeforeLevelThree() throws {
        var state = try game()
        fill(&state)
        state.artistXP = ArtistLevel.thresholds[1]
        XCTAssertEqual(engine.raidChance(for: state.placed[0], in: state), 0)
        XCTAssertNotNil(engine.raidBlocker(in: state))
        for turn in 0..<200 {
            state.turn = turn
            XCTAssertTrue(engine.raidsAtPeriodEnd(wasFull: engine.fullBuildings(in: state), in: &state).isEmpty)
        }
        XCTAssertNil(state.raid)
    }

    func testNoRaidWithoutAMetRival() throws {
        var state = try game()
        state.metCast = ["momo"]
        XCTAssertEqual(engine.raidBlocker(in: state), "aucun rival")
    }

    func testChanceIsLowAndGrowsWithBuildings() throws {
        var state = try game()
        let alone = engine.raidChance(for: state.placed[0], in: state)
        XCTAssertGreaterThan(alone, 0)
        XCTAssertLessThanOrEqual(alone, 0.1, "peu de risque au début")
        state.placed += (2...6).map { PlacedDecor(id: $0, decor: .barbier, district: .hauts, x: 2 * $0, y: 5) }
        let more = engine.raidChance(for: state.placed[0], in: state)
        XCTAssertGreaterThan(more, alone)
        XCTAssertLessThanOrEqual(more, Raids.maxChance)
    }

    func testDefencesHalveTheChance() throws {
        var state = try game()
        let base = engine.raidChance(for: state.placed[0], in: state)
        state.placed.append(PlacedDecor(id: 50, decor: .camera, district: .bloc, x: 0, y: 0))
        XCTAssertEqual(engine.raidChance(for: state.placed[0], in: state), base * 0.5, accuracy: 1e-9)
        state.placed.append(PlacedDecor(id: 51, decor: .salleBoxe, district: .bloc, x: 0, y: 0))
        // The gym counts as a building: the base goes up a little, then both defences halve it.
        let withGym = min(Raids.maxChance, Raids.baseChance + Raids.chancePerBuilding)
        XCTAssertEqual(engine.raidChance(for: state.placed[0], in: state), withGym * 0.25, accuracy: 1e-9)
        // A defence in another district doesn't help here.
        state.placed.removeAll { $0.id >= 50 }
        state.placed.append(PlacedDecor(id: 52, decor: .camera, district: .centre, x: 0, y: 0))
        XCTAssertEqual(engine.raidChance(for: state.placed[0], in: state), base, accuracy: 1e-9)
        XCTAssertFalse(Decor.camera.isBuilding)
        XCTAssertEqual(Decor.camera.minLevel, Raids.minLevel)
    }

    func testRaidIsDeterministicAndHoldsHalfTheMoney() throws {
        let state = try game()
        var full = state
        fill(&full)
        let cap = full.placed[0].stored
        let first = try raided()
        let again = try raided()
        XCTAssertEqual(first.raid, again.raid, "même partie, même tour : même raid")
        let raid = try XCTUnwrap(first.raid)
        XCTAssertEqual(raid.rival, "lil_sauge", "un rival déjà croisé")
        XCTAssertEqual(raid.stolen, cap / 2)
        XCTAssertEqual(first.placed[0].stored, cap - cap / 2, "le reste attend toujours")
        let spot = try XCTUnwrap(raid.spot, "le rival se poste à côté")
        XCTAssertFalse(first.placed[0].tiles.contains(spot))
        XCTAssertTrue(engine.isBlockedByDecor(spot, in: first), "on ne lui passe pas à travers")
        XCTAssertEqual(engine.raidRival(at: spot, in: first), raid)
        let map = try XCTUnwrap(engine.currentMap(in: first))
        XCTAssertTrue(engine.keepsEverythingReachable(on: map, blocked: engine.decorTiles(in: .bloc, state: first, blockingOnly: true),
                                                      from: map.arrival), "il ne coupe aucun passage")
        XCTAssertNotNil(engine.moveRefusal(first.placed[0].id, to: first.placed[0].anchor, in: first, player: map.spawn))
        XCTAssertTrue(try XCTUnwrap(engine.raidObjective(in: first)).hasPrefix("Lil Sauge a "))
        XCTAssertTrue(engine.periodObjectives(in: first).contains { $0.hasPrefix("Lil Sauge a ") }, "dans le briefing")
    }

    func testProductionPausedAndOneRaidAtATime() throws {
        var state = try raided()
        state.placed.append(PlacedDecor(id: 9, decor: .barbier, district: .bloc, x: 0, y: 0, stored: 30))
        let before = state.placed[0].stored
        _ = engine.decorIncome(in: &state)
        XCTAssertEqual(state.placed[0].stored, before, "braqué : il ne rapporte rien")
        let raid = state.raid
        for turn in 0..<400 where state.raid == raid {
            state.turn = turn
            fill(&state)
            XCTAssertTrue(engine.raidsAtPeriodEnd(wasFull: engine.fullBuildings(in: state), in: &state).isEmpty
                          || state.raid == nil)
            if let current = state.raid { XCTAssertEqual(current.buildingId, raid?.buildingId, "un seul raid à la fois") }
        }
    }

    func testIgnoredRaidEndsAfterThreePeriods() throws {
        var state = try raided()
        let argent = state.stats.argent
        for _ in 1..<Raids.duration {
            XCTAssertTrue(engine.raidsAtPeriodEnd(wasFull: [], in: &state).isEmpty)
            XCTAssertNotNil(state.raid)
        }
        let notes = engine.raidsAtPeriodEnd(wasFull: [], in: &state)
        XCTAssertNil(state.raid, "le rival repart avec l'argent")
        XCTAssertTrue(notes[0].contains("Lil Sauge"))
        XCTAssertEqual(state.stats.argent, argent)
        XCTAssertNotNil(engine.raidBlocker(in: state), "un peu de calme avant le prochain")
        // The building earns again.
        state.placed[0].stored = 0
        _ = engine.decorIncome(in: &state)
        XCTAssertGreaterThan(state.placed[0].stored, 0)
    }

    func testRaidThroughAWholePeriodEnd() throws {
        var state = try game()
        state.freeCareer = true
        fill(&state)
        var hit = false
        for _ in 0..<300 where !hit {
            fill(&state)
            state.actionsLeft = 0
            state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 60)
            _ = engine.finishAction(TurnOutcome(consequence: ""), in: &state)
            hit = state.raid != nil
        }
        XCTAssertTrue(hit, "un bâtiment toujours plein finit par se faire braquer")
    }

    func testWinGivesTheMoneyBackWithACappedBonus() throws {
        var state = try raided()
        let raid = try XCTUnwrap(state.raid)
        let argent = state.stats.argent
        XCTAssertNil(engine.raidClashRefusal(in: state))
        let actions = state.actionsLeft
        let clash = try engine.startRaidClash(in: &state)
        XCTAssertEqual(clash.opponentId, raid.rival)
        XCTAssertEqual(state.actionsLeft, actions, "défendre son bien ne coûte pas d'action")
        state.clash?.opponentHype = 0
        let outcome = try engine.finishClash(in: &state)
        let bonus = Raids.bonus(stolen: raid.stolen)
        XCTAssertLessThanOrEqual(bonus, Raids.maxBonus)
        XCTAssertEqual(state.stats.argent, argent + raid.stolen + bonus)
        XCTAssertNil(state.raid)
        XCTAssertNil(state.clash)
        XCTAssertFalse(outcome.semesterEnded)
        XCTAssertTrue(outcome.notes.contains { $0.hasPrefix("Tu récupères") })
        XCTAssertFalse(state.flags.contains(Raids.clashFlag))
        // Nothing left to farm: no raid, no clash.
        XCTAssertNotNil(engine.raidClashRefusal(in: state))
        XCTAssertThrowsError(try engine.startRaidClash(in: &state))
    }

    func testLossLosesTheMoneyButCleansTheBuilding() throws {
        var state = try raided()
        let argent = state.stats.argent
        let mental = state.stats.mental
        _ = try engine.startRaidClash(in: &state)
        state.clash?.playerHype = 0
        _ = try engine.finishClash(in: &state)
        XCTAssertEqual(state.stats.argent, argent, "l'argent volé est perdu, rien de plus")
        XCTAssertEqual(state.stats.mental, mental, "pas de double peine")
        XCTAssertNil(state.raid)
        state.placed[0].stored = 0
        _ = engine.decorIncome(in: &state)
        XCTAssertGreaterThan(state.placed[0].stored, 0, "il remarche")
    }

    func testChallengeOnlyInTheRightDistrict() throws {
        var state = try raided()
        state.district = .centre
        XCTAssertEqual(engine.raidClashRefusal(in: state), "Va dans Le Bloc")
        XCTAssertNil(engine.raidRival(at: try XCTUnwrap(state.raid?.spot), in: state))
    }

    func testSellingARaidedBuildingEndsTheRaid() throws {
        var state = try raided()
        engine.sell(state.placed[0].id, in: &state)
        XCTAssertNil(state.raid)
    }

    func testOldSavesLoad() throws {
        let state = try raided()
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data).raid, state.raid)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["raid"] = nil
        json["raidEndedTurn"] = nil
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.raid)
        XCTAssertNil(old.raidEndedTurn)
        // A raid saved without its later fields.
        let bare = #"{"buildingId": 3, "rival": "lil_sauge"}"#
        let raid = try JSONDecoder().decode(Raid.self, from: Data(bare.utf8))
        XCTAssertEqual(raid.periods, 0)
        XCTAssertEqual(raid.kind, .tag)
        XCTAssertNil(raid.spot)
    }

    func testPossessive() {
        XCTAssertEqual(Raids.possessive(Decor.snack.shortName), "ton snack")
        XCTAssertEqual(Raids.possessive(Decor.salleBoxe.shortName), "ta salle de boxe")
        XCTAssertEqual(Raids.possessive(Decor.labelInde.shortName), "ton label")
    }
}
