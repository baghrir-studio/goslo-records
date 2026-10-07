import XCTest
@testable import GosloRecords

final class MinigameTests: XCTestCase {
    private var world = World(events: [])
    private var engine: GameEngine { GameEngine(world: world) }
    private var rng = SeededGenerator(seed: 404)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    /// Starts the mini-game of the event `eventId` (its first choice).
    private func start(_ eventId: String) throws -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lille, style: .boomBap))
        state.pendingCinematic = nil
        state.currentEventId = eventId
        guard case .minigame = try engine.resolve(choiceAt: 0, in: &state) else {
            XCTFail("\(eventId) ne lance pas de mini-jeu")
            return state
        }
        XCTAssertFalse(engine.canVisit(state), "pas de visite pendant un mini-jeu")
        return state
    }

    // MARK: Data

    func testMinigameDataIsConsistent() {
        let minigames = world.story.minigames
        XCTAssertEqual(Set(minigames.map(\.kind)), [.punchliner, .fuite, .platine, .signing])
        let launched = Set((world.events + world.story.events).flatMap { $0.choices.compactMap(\.minigame) })
        XCTAssertEqual(launched, Set(minigames.map(\.id)), "chaque mini-jeu est lancé par un événement, et seulement les existants")
        for minigame in minigames {
            XCTAssertTrue((0...1).contains(minigame.passScore), minigame.id)
            XCTAssertEqual(minigame.kind == .punchliner, !minigame.rounds.isEmpty, minigame.id)
            XCTAssertEqual(minigame.kind == .signing, minigame.signing != nil, minigame.id)
            for (index, round) in minigame.rounds.enumerated() {
                let label = "\(minigame.id) #\(index)"
                XCTAssertEqual(round.endings.count, PunchlinerEngine.endingCount, "\(label) : il faut 4 fins")
                XCTAssertEqual(round.endings.map(\.score).max(), PunchlinerEngine.bestScore, "\(label) : une vraie punchline")
                XCTAssertEqual(round.endings.filter { $0.score == PunchlinerEngine.bestScore }.count, 1, "\(label) : une seule meilleure fin")
                XCTAssertEqual(round.endings.map(\.score).min(), 0, "\(label) : il faut un flop")
                XCTAssertEqual(Set(round.endings.map(\.text)).count, round.endings.count, "\(label) : fins en double")
                for ending in round.endings {
                    XCTAssertFalse(ending.reaction.isEmpty, label)
                    for gender in Gender.allCases {
                        let shown = TextTemplate.agree(ending.text, gender)
                        XCTAssertLessThanOrEqual(shown.count, 40, "\(label) : « \(shown) » trop long pour un bouton")
                    }
                }
            }
        }
    }

    // MARK: Punchliner

    func testPunchlinerRewardsTheBestLines() throws {
        var state = try start("punchliner_fred")
        while let current = engine.punchlinerRound(in: state) {
            XCTAssertEqual(current.order.sorted(), Array(current.round.endings.indices))
            let best = try XCTUnwrap(current.round.endings.indices.max { current.round.endings[$0].score < current.round.endings[$1].score })
            XCTAssertEqual(try engine.dropPunchline(best, in: &state), current.round.endings[best].reaction)
        }
        XCTAssertEqual(engine.minigameScore(state.minigame!), 1)
        let outcome = try engine.finishMinigame(in: &state)
        XCTAssertNil(state.minigame)
        XCTAssertEqual(outcome.consequence, engine.minigame("punchliner_bunker")!.win.consequence)
    }

    func testPunchlinerMakesAPlayableTrack() throws {
        var state = try start("punchliner_fred")
        while let current = engine.punchlinerRound(in: state) {
            let endings = current.round.endings
            _ = try engine.dropPunchline(endings.indices.max { endings[$0].score < endings[$1].score }, in: &state)
        }
        let running = try XCTUnwrap(state.minigame)
        let track = try XCTUnwrap(engine.track(for: running, rapper: state.rapper))
        XCTAssertEqual(track.lines.count, running.roundCount * 2, "deux lignes par couplet")
        XCTAssertEqual(track.title, "Essoré, mais jamais délavé", "le titre, c'est la première vraie punchline")
        XCTAssertEqual(track.style, state.rapper.style.groove)
        for index in track.lines.indices {
            XCTAssertLessThan(track.lineStart(index) + track.barSeconds, track.song.duration, "la ligne \(index) tient dans le morceau")
        }
        XCTAssertNil(engine.track(for: MinigameState(minigame: try XCTUnwrap(engine.minigame("platine_bobine"))), rapper: state.rapper))
    }

    func testPunchlinerJudging() throws {
        let round = try XCTUnwrap(world.story.minigame("punchliner_banc")?.rounds.first)
        XCTAssertEqual(PunchlinerEngine.judge(nil, in: round).points, 0)
        for (index, ending) in round.endings.enumerated() {
            XCTAssertEqual(PunchlinerEngine.judge(index, in: round).points, ending.score)
        }
        // An ending that isn't on offer is refused, and the round stays the same.
        var state = try start("punchliner_banc")
        XCTAssertThrowsError(try engine.dropPunchline(PunchlinerEngine.endingCount, in: &state))
        XCTAssertEqual(state.minigame?.round, 0)
    }

    func testSilentPunchlinerLoses() throws {
        var state = try start("punchliner_banc")
        while engine.punchlinerRound(in: state) != nil { _ = try engine.dropPunchline(nil, in: &state) }
        let outcome = try engine.finishMinigame(in: &state)
        XCTAssertEqual(outcome.consequence, engine.minigame("punchliner_banc")!.lose.consequence)
    }

    // MARK: Cale la platine

    func testPlatineSwingsThroughOneHundred() {
        for run in 0..<PlatineEngine.runs {
            let period = PlatineEngine.period(run: run)
            XCTAssertEqual(PlatineEngine.pitch(at: 0, run: run), 96, accuracy: 0.01)
            XCTAssertEqual(PlatineEngine.pitch(at: period / 6, run: run), 100, accuracy: 0.01, "100 % au sixième du balancement")
            XCTAssertEqual(PlatineEngine.pitch(at: period / 2, run: run), 112, accuracy: 0.01)
        }
        XCTAssertEqual(PlatineEngine.judge(pitch: 100.2).points, 3)
        XCTAssertEqual(PlatineEngine.judge(pitch: 101.5).points, 2)
        XCTAssertEqual(PlatineEngine.judge(pitch: 96.5).points, 1)
        XCTAssertEqual(PlatineEngine.judge(pitch: 110).points, 0)
    }

    func testPlatinePerfectStopsWin() throws {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lille, style: .boomBap))
        state.pendingCinematic = nil
        state.chapter = 4
        state = try { var s = state; s.currentEventId = "platine_bobine"; _ = try engine.resolve(choiceAt: 0, in: &s); return s }()
        while state.minigame?.isOver == false {
            let run = state.minigame!.round
            _ = try engine.stopPlatine(after: PlatineEngine.period(run: run) / 6, in: &state)
        }
        XCTAssertEqual(engine.minigameScore(state.minigame!), 1)
        let outcome = try engine.finishMinigame(in: &state)
        XCTAssertEqual(outcome.consequence, engine.minigame("platine_bobine")!.win.consequence)
    }

    // MARK: Fuir la foule

    func testChaseCanBeWonAndLost() {
        // Standing still: the crowd catches you (or the clock runs out).
        var idle = CrowdChase(using: &rng)
        while !idle.isOver { idle.step(using: &rng) }
        XCTAssertTrue(idle.caught)
        XCTAssertFalse(idle.escaped)

        // Running straight for the door without looking: about one escape in two (a careful player does better).
        var escapes = 0
        for _ in 0..<200 {
            var chase = CrowdChase(using: &rng)
            var guardSteps = 0
            while !chase.isOver && guardSteps < 200 {
                guardSteps += 1
                let preferred: [Direction] = [.up, chase.player.x < CrowdChase.door.x ? .right : .left, .left, .right]
                if let direction = preferred.first(where: { d in
                    let next = chase.player.moved(d)
                    return CrowdChase.isFree(next) && !chase.fans.contains(next)
                }) { chase.move(direction) }
                if chase.isOver { break }
                // The player moves about twice as fast as the crowd.
                if guardSteps % 2 == 0 { chase.step(using: &rng) }
            }
            if chase.escaped { escapes += 1 }
        }
        print("Fuir la foule — joueur qui fonce : \(escapes)/200")
        XCTAssertGreaterThan(escapes, 60, "la fuite doit être jouable")
        XCTAssertLessThan(escapes, 170, "la foule doit souvent gagner contre un joueur qui fonce")
    }

    func testChaseResultDecidesTheOutcome() throws {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lille, style: .boomBap))
        state.pendingCinematic = nil
        state.flags.insert("concert_reussi")
        state.currentEventId = "fuite_fans"
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertThrowsError(try engine.finishMinigame(in: &state), "pas fini tant que la poursuite n'a pas rendu son verdict")
        try engine.endChase(escaped: true, in: &state)
        let outcome = try engine.finishMinigame(in: &state)
        XCTAssertEqual(outcome.consequence, engine.minigame("fuite_transfo")!.win.consequence)
    }

    func testMinigameSurvivesASave() throws {
        var state = try start("punchliner_fred")
        _ = try engine.dropPunchline(nil, in: &state)
        let restored = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.minigame, state.minigame)
        XCTAssertEqual(restored.minigame?.round, 1)
    }
}
