import XCTest
@testable import GosloRecords

final class FreestyleTests: XCTestCase {
    func testRhymeFamiliesAreCleanAndDistinct() {
        let all = Freestyle.families.flatMap { $0 }
        XCTAssertEqual(all.count, Set(all).count, "un mot dans deux familles")
        for family in Freestyle.families { XCTAssertGreaterThanOrEqual(family.count, 6) }
        XCTAssertTrue(Freestyle.rhymes("bitume", "plume"))
        XCTAssertFalse(Freestyle.rhymes("bitume", "bitume"))
        XCTAssertFalse(Freestyle.rhymes("bitume", "espoir"))
    }

    func testEveryRoundHasExactlyOneRhyme() {
        var rng = SeededGenerator(seed: 3)
        var previous: Freestyle.Round?
        for _ in 0..<200 {
            let round = Freestyle.round(after: previous, using: &rng)
            XCTAssertEqual(round.options.count, Freestyle.choices)
            XCTAssertEqual(round.options.filter { Freestyle.rhymes(round.prompt, $0) }.count, 1, "\(round)")
            XCTAssertTrue(Freestyle.rhymes(round.prompt, round.options[round.answer]))
            if let previous { XCTAssertNotEqual(Freestyle.family(of: previous.prompt), Freestyle.family(of: round.prompt)) }
            previous = round
        }
    }

    func testMoreRhymesHitHarder() {
        XCTAssertEqual(Freestyle.damage(rhymes: 0, level: 5), 0)
        XCTAssertLessThan(Freestyle.damage(rhymes: 2, level: 5), Freestyle.damage(rhymes: 6, level: 5))
        XCTAssertLessThan(Freestyle.damage(rhymes: 6, level: 1), Freestyle.damage(rhymes: 6, level: 9))
        XCTAssertEqual(Freestyle.damage(rhymes: 50, level: 5), Freestyle.damage(rhymes: Freestyle.maxRhymes, level: 5))
    }

    func testFreestyleOncePerClash() throws {
        let rival = CastMember(id: "rival", name: "Rival", role: "",
                               clash: ClashProfile(stats: [.punchline: 3, .flow: 3, .presence: 3, .story: 3]))
        let event = GameEvent(id: "defi", title: "", text: "", location: .studio, choices: [
            EventChoice(label: "Clash", clash: ClashSpec(opponent: "rival", win: ClashResultSpec(consequence: "w"),
                                                         lose: ClashResultSpec(consequence: "l")), consequence: "go"),
            EventChoice(label: "Non", consequence: "non"),
        ])
        let engine = GameEngine(events: [event], cast: [rival])
        var rng = SeededGenerator(seed: 8)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .boomBap))
        _ = try engine.visit(.studio, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
        let before = try XCTUnwrap(state.clash).opponentHype

        let clash = try engine.clashFreestyle(rhymes: 6, in: &state, using: &rng)
        let entry = try XCTUnwrap(clash.log.first { $0.byPlayer })
        XCTAssertEqual(entry.freestyle, 6)
        XCTAssertEqual(entry.impact, .strong)
        XCTAssertEqual(clash.opponentHype, before - entry.damage)
        XCTAssertEqual(clash.playerMeter, entry.damage, "le freestyle remplit la jauge")
        XCTAssertTrue(clash.freestyleUsed)
        XCTAssertNotNil(clash.log.first { !$0.byPlayer }, "l'adversaire répond")
        XCTAssertThrowsError(try engine.clashFreestyle(rhymes: 6, in: &state, using: &rng)) {
            XCTAssertEqual($0 as? GameEngineError, .freestyleUsed)
        }
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(saved.clash?.freestyleUsed, true)
    }
}
