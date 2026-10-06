import XCTest
@testable import GosloRecords

final class SecretTechniqueTests: XCTestCase {
    private var rng = SeededGenerator(seed: 12)
    private let rivalSecret = SecretTechnique(name: "Le Coup Test", line: "Ça fait mal.")

    private func setup(boss: Bool = false) throws -> (GameEngine, GameState) {
        let rival = CastMember(id: "rival", name: "Rival", role: "",
                               clash: ClashProfile(stats: [.punchline: 3, .flow: 3, .presence: 3, .story: 3]),
                               secret: rivalSecret)
        let event = GameEvent(id: "defi", title: "", text: "", location: .studio, choices: [
            EventChoice(label: "Clash", clash: ClashSpec(opponent: "rival", win: ClashResultSpec(consequence: "w"),
                                                         lose: ClashResultSpec(consequence: "l"), boss: boss),
                        consequence: "go"),
            EventChoice(label: "Non", consequence: "non"),
        ])
        let engine = GameEngine(events: [event], cast: [rival])
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .melancolique))
        _ = try engine.visit(.studio, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertNotNil(state.clash)
        return (engine, state)
    }

    func testSecretIsLockedUntilTheGaugeIsFull() throws {
        var (engine, state) = try setup()
        XCTAssertFalse(state.clash!.playerSecretReady)
        XCTAssertThrowsError(try engine.clashSecret(in: &state, using: &rng)) {
            XCTAssertEqual($0 as? GameEngineError, .secretNotReady)
        }
    }

    func testGaugeFillsWithDamageDealt() throws {
        var (engine, state) = try setup()
        let clash = try engine.clashMove(.flow, in: &state, using: &rng)
        let dealt = clash.log.filter { $0.byPlayer }.map(\.damage).reduce(0, +)
        XCTAssertEqual(clash.playerMeter, dealt)
        let taken = clash.log.filter { !$0.byPlayer }.map(\.damage).reduce(0, +)
        XCTAssertEqual(clash.opponentMeter, taken)
    }

    func testPlayerSecretHitsHardOnlyOnce() throws {
        var (engine, state) = try setup()
        state.clash!.playerMeter = ClashState.secretThreshold
        let hypeBefore = state.clash!.opponentHype

        let clash = try engine.clashSecret(in: &state, using: &rng)
        let entry = try XCTUnwrap(clash.log.first { $0.byPlayer })
        XCTAssertEqual(entry.secret, Style.melancolique.secret)
        XCTAssertEqual(entry.impact, .strong)
        XCTAssertGreaterThanOrEqual(entry.damage, 22)
        XCTAssertEqual(clash.opponentHype, max(0, hypeBefore - entry.damage))
        XCTAssertTrue(clash.playerSecretUsed)
        XCTAssertFalse(clash.playerSecretReady)
        XCTAssertThrowsError(try engine.clashSecret(in: &state, using: &rng))
    }

    func testOpponentTriggersItsSecretAutomatically() throws {
        var (engine, state) = try setup()
        state.clash!.opponentMeter = ClashState.secretThreshold
        let clash = try engine.clashMove(.flow, in: &state, using: &rng)
        let answer = try XCTUnwrap(clash.log.first { !$0.byPlayer })
        XCTAssertEqual(answer.secret, rivalSecret)
        XCTAssertTrue(clash.opponentSecretUsed)

        let next = try engine.clashMove(.flow, in: &state, using: &rng)
        XCTAssertNil(next.log.last { !$0.byPlayer }?.secret, "une seule fois par clash")
    }

    func testOpponentWithoutSecretGetsTheGenericOne() {
        let secret = ClashLines.defaultSecret(for: "Bob")
        XCTAssertTrue(secret.line.contains("Bob"))
        XCTAssertFalse(secret.name.isEmpty)
    }

    func testOldSavesWithoutGaugesStillLoad() throws {
        let spec = ClashSpec(opponent: "x", win: ClashResultSpec(consequence: "w"), lose: ClashResultSpec(consequence: "l"))
        let specJSON = String(data: try JSONEncoder().encode(spec), encoding: .utf8)!
        let json = #"{"spec":\#(specJSON),"playerHype":80,"opponentHype":70,"round":2,"log":[]}"#
        let clash = try JSONDecoder().decode(ClashState.self, from: Data(json.utf8))
        XCTAssertEqual(clash.playerMeter, 0)
        XCTAssertFalse(clash.playerSecretUsed)
        XCTAssertEqual(clash.playerHype, 80)
    }

    func testEveryClashableCharacterHasAFunnySecret() throws {
        let world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        for member in world.cast where member.clash != nil {
            let secret = try XCTUnwrap(member.secret, "\(member.id) n'a pas de technique secrète")
            XCTAssertFalse(secret.name.isEmpty)
            XCTAssertGreaterThan(secret.line.count, 20, member.id)
        }
        for style in Style.allCases {
            XCTAssertFalse(style.secret.name.isEmpty)
        }
    }

    // MARK: Countering a boss's technique

    /// Fills the boss's gauge, then plays a round so it fires its technique.
    private func bossFires() throws -> (GameEngine, GameState, Int) {
        var (engine, state) = try setup(boss: true)
        state.clash!.opponentMeter = ClashState.secretThreshold
        state.clash!.opponentHype = 1_000
        let before = state.clash!.playerHype
        let clash = try engine.clashMove(.flow, in: &state, using: &rng)
        XCTAssertNotNil(clash.pendingCounter, "la technique du boss attend le contre")
        XCTAssertEqual(clash.playerHype, before, "rien ne tombe avant le contre")
        XCTAssertFalse(clash.isOver)
        return (engine, state, before)
    }

    func testBossTechniqueWaitsForTheCounter() throws {
        var (engine, state, before) = try bossFires()
        let damage = state.clash!.pendingCounter!.damage
        let clash = try engine.counterSecret(taps: ClashState.counterTaps, in: &state)
        XCTAssertNil(clash.pendingCounter)
        let entry = try XCTUnwrap(clash.log.last)
        XCTAssertEqual(entry.secret, rivalSecret)
        XCTAssertEqual(entry.countered, ClashState.counterMaxReduction)
        XCTAssertEqual(entry.damage, Int((Double(damage) * (1 - ClashState.counterMaxReduction)).rounded()))
        XCTAssertEqual(clash.playerHype, before - entry.damage)
    }

    func testCounterScalesWithTaps() {
        XCTAssertEqual(ClashState.counterReduction(taps: 0), 0)
        XCTAssertEqual(ClashState.counterReduction(taps: ClashState.counterTaps / 2), ClashState.counterMaxReduction / 2, accuracy: 0.001)
        XCTAssertEqual(ClashState.counterReduction(taps: ClashState.counterTaps * 3), ClashState.counterMaxReduction)
    }

    func testUncounteredTechniqueLandsInFullBeforeTheNextRound() throws {
        var (engine, state, before) = try bossFires()
        let damage = state.clash!.pendingCounter!.damage
        let clash = try engine.clashMove(.flow, in: &state, using: &rng)
        let secretEntry = try XCTUnwrap(clash.log.first { $0.secret == rivalSecret })
        XCTAssertEqual(secretEntry.damage, damage, "sans contre, la technique fait tous ses dégâts")
        XCTAssertNil(clash.pendingCounter)
        XCTAssertLessThan(clash.playerHype, before)
    }

    func testOrdinaryRivalsAreNotCountered() throws {
        var (engine, state) = try setup()
        state.clash!.opponentMeter = ClashState.secretThreshold
        state.clash!.opponentHype = 1_000
        let clash = try engine.clashMove(.flow, in: &state, using: &rng)
        XCTAssertNil(clash.pendingCounter)
        XCTAssertNotNil(clash.log.first { $0.secret == rivalSecret })
    }

    func testPendingCounterSurvivesASave() throws {
        let (_, state, _) = try bossFires()
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(restored.clash?.pendingCounter, state.clash?.pendingCounter)
    }
}
