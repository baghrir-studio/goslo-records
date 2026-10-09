import XCTest
@testable import GosloRecords

/// The period briefing: what the closing turn paid, by source, and the few goals for the next one.
final class BriefingTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func game() -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Brief", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 3
        state.stats = Stats(streams: 50, credibilite: 50, argent: 40, mental: 60)
        state.challenges = []
        state.challengeSeason = Challenges.season(of: state.turn)
        return state
    }

    func testClosingATurnSplitsWhatItPaid() throws {
        var state = game()
        state.placed = [PlacedDecor(id: 1, decor: .foodTruck, district: .bloc, x: 0, y: 0)]
        state.flags.insert(RadioDeal.flag)
        state.singles = [Single(id: 1, title: "Tube", sourceId: "x", quality: 10, releasedTurn: state.turn, clip: true, feat: nil)]
        state.actionsLeft = 0

        let outcome = engine.finishAction(TurnOutcome(consequence: ""), in: &state)
        XCTAssertTrue(outcome.semesterEnded)
        let period = try XCTUnwrap(outcome.period)
        XCTAssertEqual(period.rent, Difficulty.normal.rent)
        XCTAssertEqual(period.upkeep[.argent], -Difficulty.normal.rent, "respect moyen : ni booking ni malus")
        XCTAssertEqual(period.income[.argent], 3, "goslo radio (l'argent du food truck attend sur place)")
        XCTAssertEqual(state.placed[0].stored, 2)
        XCTAssertEqual(period.income[.credibilite], 1, "goslo radio")
        XCTAssertGreaterThan(period.chart[.argent] ?? 0, 0, "le Top paie")
        XCTAssertEqual(period.chartNotes.count, 1)
        XCTAssertTrue(period.chartNotes[0].contains("Tube"))
        XCTAssertEqual(period.earned, 3 + (period.chart[.argent] ?? 0))
        XCTAssertTrue(engine.periodObjectives(in: state).contains("Ramasse 2 d'argent dans tes bâtiments"))
        XCTAssertEqual(period.net[.argent], period.earned - period.rent)
    }

    func testAnActionThatDoesntCloseTheTurnHasNoSummary() {
        var state = game()
        state.actionsLeft = 1
        let outcome = engine.finishAction(TurnOutcome(consequence: ""), in: &state)
        XCTAssertFalse(outcome.semesterEnded)
        XCTAssertNil(outcome.period)
    }

    func testTitleFollowsTheYear() {
        var state = game()
        state.turn = 1
        XCTAssertEqual(engine.periodBriefing(in: state, summary: nil).title, "Nouvelle période")
        state.turn = GameState.turnsPerYear
        XCTAssertEqual(engine.periodBriefing(in: state, summary: nil).title, "Nouvelle année")
    }

    func testObjectivesMixStoryChallengesAndMoney() throws {
        var state = game()
        state.challenges = [
            Challenge(kind: .clashes, target: 2, baseline: state.counters[.clashsGagnes]),
            Challenge(kind: .refrain, target: 1, baseline: state.hooks.count, done: true),
            Challenge(kind: .meet, target: 2, baseline: state.metCast.count),
        ]
        state.stats[.argent] = 20
        let objectives = engine.periodObjectives(in: state)
        XCTAssertEqual(objectives.count, PeriodBriefing.maxObjectives)
        let story = try XCTUnwrap(engine.currentObjective(in: state))
        XCTAssertTrue(objectives[0].hasPrefix(story.label), "l'histoire d'abord")
        XCTAssertEqual(objectives[1], "Gagne 2 clashs (0/2)")
        XCTAssertTrue(objectives[2].hasSuffix("encore 6 d'argent"), objectives[2])
        XCTAssertFalse(objectives.contains { $0.contains("refrain") }, "un défi réussi ne revient pas")

        // Nothing to save for: the other challenges fill the list.
        state.stats[.argent] = 99
        state.items.formUnion(Shop.gear.map(\.id))
        let rich = engine.periodObjectives(in: state)
        XCTAssertEqual(rich.count, 3)
        XCTAssertTrue(rich[2].hasPrefix("Rencontre 2"))
    }

    func testSavingGoalIsTheCheapestThingOutOfReach() throws {
        var state = game()
        state.stats[.argent] = 20
        let first = try XCTUnwrap(engine.savingGoal(in: state))
        XCTAssertEqual(first.missing, 6, "matos à 25 : il faut 26 pour ne pas finir à 0")

        // A big artist with all the gear saves for a building.
        state.artistXP = ArtistLevel.thresholds[RadioDeal.minLevel - 1]
        state.items.formUnion(Shop.gear.map(\.id))
        state.stats[.argent] = 70
        let building = try XCTUnwrap(engine.savingGoal(in: state))
        XCTAssertEqual(building.name, Decor.boutiqueMerch.name)
        XCTAssertEqual(building.missing, Decor.boutiqueMerch.price + 1 - 70)

        // Already put down: the next one is goslo radio.
        state.placed = [PlacedDecor(id: 1, decor: .boutiqueMerch, district: .bloc, x: 0, y: 0)]
        XCTAssertEqual(engine.savingGoal(in: state)?.name, "goslo radio")
        state.flags.insert(RadioDeal.flag)
        XCTAssertNil(engine.savingGoal(in: state))
    }
}
