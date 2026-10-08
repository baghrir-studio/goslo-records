import XCTest
@testable import GosloRecords

/// Combos, tells and counters, and the crowd's favourite move.
final class TacticsTests: XCTestCase {
    private let profile = ClashProfile(stats: [.punchline: 4, .flow: 4, .presence: 4, .story: 4])

    private func clash() -> ClashState {
        ClashState(spec: ClashSpec(opponent: "r", win: ClashResultSpec(consequence: "w"), lose: ClashResultSpec(consequence: "l")))
    }

    private func round(_ state: inout ClashState, _ move: ClashMove, seed: UInt64 = 1) {
        var rng = SeededGenerator(seed: seed)
        ClashEngine.playRound(&state, playerMove: move, playerLevel: { _ in 5 }, opponent: profile,
                              opponentName: "R", using: &rng)
    }

    func testEveryMoveHasOneCounterAndCombosAreDistinct() {
        XCTAssertEqual(Set(ClashMove.allCases.map(\.counter)), Set(ClashMove.allCases))
        for move in ClashMove.allCases { XCTAssertNotEqual(move.counter, move) }
        XCTAssertEqual(Set(ClashCombo.all.map { "\($0.first)-\($0.then)" }).count, ClashCombo.all.count)
        XCTAssertTrue(ClashCombo.all.allSatisfy { $0.multiplier > 1 })
    }

    func testComboLandsStrongAndNeverMisses() {
        for seed in UInt64(1)...30 {
            var state = clash()
            round(&state, .flow, seed: seed)
            round(&state, .punchline, seed: seed &* 7)
            let entry = state.log.last { $0.byPlayer }!
            XCTAssertEqual(entry.combo, "Mise en place")
            XCTAssertEqual(entry.impact, .strong)
            XCTAssertGreaterThan(entry.damage, 0)
        }
    }

    func testReadingTheTellParries() {
        var state = clash()
        state.nextOpponentMove = .punchline
        round(&state, ClashMove.punchline.counter)
        let answer = state.log.last { !$0.byPlayer }!
        XCTAssertEqual(answer.move, .punchline, "l'adversaire joue ce qu'il a annoncé")
        XCTAssertEqual(answer.parried, true)
        XCTAssertNotNil(state.nextOpponentMove, "le prochain coup est déjà annoncé")

        var open = clash()
        open.nextOpponentMove = .punchline
        round(&open, .flow)
        XCTAssertNil(open.log.last { !$0.byPlayer }!.parried)
    }

    func testEachDistrictHasItsCrowd() {
        XCTAssertEqual(Set(District.allCases.map { ClashTactics.crowdFavorite(in: $0) }).count, District.allCases.count)
        let first = ClashTactics.telegraphed(clash(), profile: ClashProfile(stats: [.punchline: 2, .flow: 9, .presence: 3, .story: 1]))
        XCTAssertEqual(first, .flow, "au premier tour, on annonce son meilleur coup")
    }

    func testOldSavesLoad() throws {
        let spec = ClashSpec(opponent: "x", win: ClashResultSpec(consequence: "w"), lose: ClashResultSpec(consequence: "l"))
        let specJSON = String(data: try JSONEncoder().encode(spec), encoding: .utf8)!
        let json = #"{"spec":\#(specJSON),"playerHype":80,"opponentHype":70,"round":2,"log":[]}"#
        let old = try JSONDecoder().decode(ClashState.self, from: Data(json.utf8))
        XCTAssertNil(old.lastPlayerMove)
        XCTAssertNil(old.crowdFavorite)
    }
}
