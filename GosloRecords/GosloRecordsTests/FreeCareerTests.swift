import XCTest
@testable import GosloRecords

/// Free career: no clock ends it, only a defeat or the player hanging up the mic.
final class FreeCareerTests: XCTestCase {
    private var rng = SeededGenerator(seed: 11)

    private func simpleEngine() -> GameEngine {
        GameEngine(events: [GameEvent(id: "e", title: "", text: "", location: .studio, choices: [
            EventChoice(label: "Ok", consequence: "ok"),
        ])])
    }

    private func spendSemester(_ engine: GameEngine, _ state: inout GameState) throws {
        state.actionsLeft = 1
        _ = try engine.visit(.studio, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
    }

    func testTheClockNeverEndsAFreeCareer() throws {
        let engine = simpleEngine()
        var state = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.freeCareer = true
        state.stats = Stats(streams: 80, credibilite: 80, argent: 80, mental: 80)
        state.turn = GameState.totalTurns + GameState.overtimeTurns + 3
        try spendSemester(engine, &state)
        XCTAssertNil(state.ending, "aucune limite de temps")
        XCTAssertEqual(state.turn, GameState.totalTurns + GameState.overtimeTurns + 4)
        XCTAssertEqual(state.year, (GameState.totalTurns + GameState.overtimeTurns + 4) / 2 + 1)
        XCTAssertEqual(state.periodLabel, "ANNÉE \(state.year)")
        XCTAssertTrue(engine.canVisit(state))
    }

    func testStayingOnTopGetsHarder() {
        XCTAssertTrue(GameEngine.agingUpkeep(turn: GameState.totalTurns - 1).isEmpty, "rien avant l'année 10")
        let late = GameEngine.agingUpkeep(turn: GameState.totalTurns + 12)[.streams] ?? 0
        let early = GameEngine.agingUpkeep(turn: GameState.totalTurns)[.streams] ?? 0
        XCTAssertLessThan(late, early)
        XCTAssertGreaterThanOrEqual(GameEngine.agingUpkeep(turn: 500)[.streams] ?? 0, -6, "plafonné")
    }

    func testDefeatStillEndsIt() throws {
        let engine = GameEngine(events: [GameEvent(id: "e", title: "", text: "", location: .studio, choices: [
            EventChoice(label: "Ok", effects: [.mental: -100], consequence: "ok"),
        ])])
        var state = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.freeCareer = true
        try spendSemester(engine, &state)
        XCTAssertEqual(state.ending?.isPremature, true)
    }

    func testRetireWhenYouWant() throws {
        let engine = simpleEngine()
        var state = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.freeCareer = true
        state.stats = Stats(streams: 80, credibilite: 80, argent: 20, mental: 20)
        _ = try engine.visit(.studio, in: &state, using: &rng)
        XCTAssertFalse(engine.canRetire(state), "pas au milieu d'une carte")
        XCTAssertThrowsError(try engine.retire(in: &state))
        _ = try engine.resolve(choiceAt: 0, in: &state)
        try engine.retire(in: &state)
        XCTAssertEqual(state.ending, .legende)
        XCTAssertFalse(engine.canRetire(state))
    }

    func testFinaleOffersTheChoice() throws {
        let engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
        let finale = try XCTUnwrap(engine.story.chapters.first(where: \.isFinale))
        let outro = try XCTUnwrap(finale.outro)
        func atTheEnd(free: Bool) -> GameState {
            var state = engine.newGame(rapper: Rapper(name: "R", city: .lyon, style: .drill))
            state.freeCareer = free
            state.chapter = finale.number
            state.objectiveIndex = finale.objectives.count
            state.flags = Set((1..<finale.number).map { "chapitre_\($0)" })
            state.pendingCinematic = outro
            return state
        }
        var classic = atTheEnd(free: false)
        engine.cinematicFinished(outro, in: &classic)
        XCTAssertTrue(classic.isOver, "mode classique : la finale termine la carrière")

        var free = atTheEnd(free: true)
        engine.cinematicFinished(outro, in: &free)
        XCTAssertFalse(free.isOver)
        XCTAssertTrue(free.finaleChoicePending)
        var stays = free
        engine.keepGoing(in: &stays)
        XCTAssertFalse(stays.finaleChoicePending)
        XCTAssertTrue(stays.flags.contains(GameEngine.freeCareerFlag))
        XCTAssertFalse(stays.isOver)
        try engine.retire(in: &free)
        XCTAssertTrue(free.isOver)
        XCTAssertFalse(free.ending?.isPremature ?? true)
    }

    func testOldSavesDecodeWithTheClock() throws {
        let engine = simpleEngine()
        let state = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["freeCareer"] = nil
        json["finaleChoicePending"] = nil
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(old.freeCareer)
        XCTAssertFalse(old.finaleChoicePending)
    }
}
