import XCTest
@testable import GosloRecords

/// Barriers against farming (`Gate`): progress gates, cooldowns per period and per year, rewards applied once.
final class GatesTests: XCTestCase {
    private let wildOne = CastMember(id: "sauvage", name: "Sauvage", role: "",
                                     clash: ClashProfile(stats: [.punchline: 1, .flow: 1, .presence: 1, .story: 1]), wild: true)
    private var rng = SeededGenerator(seed: 21)

    private func engine() -> GameEngine {
        GameEngine(events: [
            GameEvent(id: "banc", title: "", text: "", location: .quartier,
                      choices: [EventChoice(label: "Écouter", effects: [.credibilite: 10], xp: [.plume: 40], consequence: "ok")]),
            GameEvent(id: "dm", title: "", text: "", location: .reseaux,
                      choices: [EventChoice(label: "Poster", effects: [.streams: 4], consequence: "ok")]),
        ], cast: [wildOne])
    }

    private func game(_ engine: GameEngine, chapter: Int = 2) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Banc", city: .lyon, style: .trap))
        state.pendingCinematic = nil
        state.chapter = chapter
        state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 60)
        return state
    }

    /// Spends the actions left in the period at home, so the next period starts.
    private func endPeriod(_ engine: GameEngine, _ state: inout GameState) throws {
        let turn = state.turn
        while state.turn == turn {
            _ = try engine.visit(.chezToi, in: &state, using: &rng)
            _ = try engine.resolve(choiceAt: 0, in: &state)
            state.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 60)
        }
    }

    func testTheBenchPaysOncePerPeriod() throws {
        let engine = engine()
        var state = game(engine)
        guard case .event(let event) = try engine.sitOnBench(in: &state, using: &rng) else { return XCTFail("le banc est libre") }
        XCTAssertEqual(event.id, "banc")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(state.stats.credibilite, 60)
        XCTAssertEqual(state.actionsLeft, GameState.actionsPerTurn - 1)

        // Second sit in the same period: a line, no action, nothing paid.
        let again = try engine.sitOnBench(in: &state, using: &rng)
        XCTAssertEqual(again, .closed(["Le banc est occupé. Repasse la période prochaine."]))
        XCTAssertEqual(state.actionsLeft, GameState.actionsPerTurn - 1)
        XCTAssertEqual(state.stats.credibilite, 60)
        XCTAssertNil(state.currentEventId)

        // Next period: the bench is free again.
        try endPeriod(engine, &state)
        guard case .event = try engine.sitOnBench(in: &state, using: &rng) else { return XCTFail("nouvelle période") }
    }

    func testSkippingTheDialogueCannotPayTwice() throws {
        let engine = engine()
        var state = game(engine)
        _ = try engine.sitOnBench(in: &state, using: &rng)
        XCTAssertThrowsError(try engine.sitOnBench(in: &state, using: &rng), "une rencontre à la fois")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertThrowsError(try engine.resolve(choiceAt: 0, in: &state), "le choix est appliqué une seule fois")
        XCTAssertEqual(state.stats.credibilite, 60)
    }

    func testTheBenchPaysMoreWithProgressNotRepetition() throws {
        let engine = engine()
        var rookie = game(engine)
        _ = try engine.sitOnBench(in: &rookie, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &rookie)

        var veteran = game(engine)
        veteran.artistXP = ArtistLevel.thresholds[5]
        _ = try engine.sitOnBench(in: &veteran, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &veteran)

        XCTAssertEqual(rookie.stats.credibilite - 50, 10)
        XCTAssertEqual(veteran.stats.credibilite - 50, 15, "niveau 6 : +50 %")
        XCTAssertGreaterThan(veteran.skills.xp(.plume), rookie.skills.xp(.plume))
        XCTAssertNil(veteran.currentGate, "le bonus ne vaut que pour la rencontre du banc")
    }

    func testThePhoneHasAPeriodAndAYearlyCap() throws {
        let engine = engine()
        var state = game(engine)
        for period in 0..<Gate.phone.perYear! {
            guard case .event = try engine.checkPhone(in: &state, using: &rng) else { return XCTFail("période \(period)") }
            _ = try engine.resolve(choiceAt: 0, in: &state)
            if case .event = try engine.checkPhone(in: &state, using: &rng) { XCTFail("une fois par période") }
            try endPeriod(engine, &state)
        }
        XCTAssertLessThan(state.turn, GameState.turnsPerYear)
        XCTAssertEqual(try engine.checkPhone(in: &state, using: &rng), .closed([Gate.phone.spentLine(yearly: true)]))
        while state.turn < GameState.turnsPerYear { try endPeriod(engine, &state) }
        guard case .event = try engine.checkPhone(in: &state, using: &rng) else { return XCTFail("nouvelle année") }
    }

    func testTheTerrainVaguePaysOnlyTheFirstDuelsOfThePeriod() throws {
        let engine = engine()
        var state = game(engine)
        state.skills.gain([.flow: 900])
        let cap = Gate.terrain.perPeriod(level: 1)
        XCTAssertLessThan(cap, Gate.terrain.perPeriod(level: 3), "plus de duels payés avec le niveau")
        for duel in 0...cap {
            let streams = state.stats.streams, xp = state.artistXP
            _ = try XCTUnwrap(engine.startWildClash(in: &state, using: &rng))
            while try !engine.clashMove(.flow, in: &state, using: &rng).isOver {}
            let outcome = try engine.finishClash(in: &state)
            XCTAssertTrue(try XCTUnwrap(outcome.clash).playerWon)
            if duel < cap {
                XCTAssertGreaterThan(state.stats.streams, streams)
                XCTAssertGreaterThan(state.artistXP, xp)
            } else {
                XCTAssertEqual(state.stats.streams, streams, "plus rien à gagner cette période")
                XCTAssertEqual(state.artistXP, xp)
                XCTAssertTrue(outcome.notes.contains(Gate.terrain.spentLine(yearly: false)))
            }
        }
        XCTAssertEqual(state.counters[.victoiresTerrain], cap + 1, "les victoires comptent quand même pour l'histoire")
    }

    func testHappeningsWaitForChapterTwoAndPayOncePerPeriod() throws {
        let engine = engine()
        var early = game(engine, chapter: 1)
        XCTAssertEqual(engine.gateStatus(.happening, in: early), .locked("Chapitre 2 requis pour ça."))
        XCTAssertTrue(engine.takeSelfie(in: &early, using: &rng).changes.isEmpty)

        var state = game(engine)
        XCTAssertFalse(engine.takeSelfie(in: &state, using: &rng).changes.isEmpty)
        XCTAssertTrue(engine.takeSelfie(in: &state, using: &rng).changes.isEmpty, "une seule par période")
        XCTAssertThrowsError(try engine.startStreetBeatbox(in: &state))
        try endPeriod(engine, &state)
        XCTAssertNoThrow(try engine.startStreetBeatbox(in: &state))
    }

    func testRepeatedVisitsTireTheXPToo() throws {
        let engine = engine()
        var fresh = game(engine)
        _ = try engine.visit(.quartier, in: &fresh, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &fresh)

        var farmed = game(engine)
        farmed.visitsThisYear[Location.quartier.rawValue] = 10
        _ = try engine.visit(.quartier, in: &farmed, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &farmed)
        XCTAssertLessThan(farmed.skills.xp(.plume), fresh.skills.xp(.plume))
    }

    func testGateCountersAreSavedAndOldSavesLoad() throws {
        let engine = engine()
        var state = game(engine)
        _ = try engine.sitOnBench(in: &state, using: &rng)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(decoded.gatePeriodUses, [Gate.bench.rawValue: 1])
        XCTAssertEqual(decoded.currentGate, .bench)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["gatePeriodUses"] = nil
        json["gateYearUses"] = nil
        json["currentGate"] = nil
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.gatePeriodUses, [:])
        XCTAssertNil(old.currentGate)
    }
}
