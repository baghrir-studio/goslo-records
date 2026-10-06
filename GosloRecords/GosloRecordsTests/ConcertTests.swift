import XCTest
@testable import GosloRecords

final class ConcertTests: XCTestCase {
    private var world = World(events: [])
    private var rng = SeededGenerator(seed: 33)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    // MARK: Rules

    func testChartIsDeterministicAndOnTheBeat() {
        let song = ConcertSong(title: "t", bpm: 90, bars: 4, density: 0.5)
        let seed = ConcertEngine.seed("premier_concert", song: 0)
        let chart = ConcertEngine.chart(for: song, seed: seed)
        XCTAssertEqual(chart, ConcertEngine.chart(for: song, seed: seed))
        XCTAssertEqual(ConcertEngine.seed("premier_concert", song: 0), seed, "la graine doit être stable d'un lancement à l'autre")
        // Every downbeat has a note, all notes sit on half-beats after the count-in.
        for bar in 0..<song.bars {
            let downbeat = Double(ConcertEngine.countInBeats + bar * 4) * song.beat
            XCTAssertTrue(chart.contains { abs($0.time - downbeat) < 0.0001 }, "temps fort manquant mesure \(bar)")
        }
        for note in chart {
            let halfBeats = note.time / (song.beat / 2)
            XCTAssertEqual(halfBeats, halfBeats.rounded(), accuracy: 0.0001)
            XCTAssertGreaterThanOrEqual(note.time, Double(ConcertEngine.countInBeats) * song.beat - 0.0001)
            XCTAssertLessThan(note.time, song.duration)
            XCTAssertTrue((0..<ConcertEngine.lanes).contains(note.lane))
        }
        XCTAssertEqual(Set(chart.map(\.id)).count, chart.count)
    }

    func testDensityAddsNotes() {
        let sparse = ConcertEngine.chart(for: ConcertSong(title: "a", bars: 16, density: 0), seed: 1)
        let dense = ConcertEngine.chart(for: ConcertSong(title: "a", bars: 16, density: 1), seed: 1)
        XCTAssertGreaterThan(dense.count, sparse.count)
    }

    func testTimingWindows() {
        XCTAssertEqual(ConcertEngine.judge(offset: 0.03, sceneLevel: 1), .perfect)
        XCTAssertEqual(ConcertEngine.judge(offset: -0.12, sceneLevel: 1), .good)
        XCTAssertNil(ConcertEngine.judge(offset: 0.3, sceneLevel: 10))
        XCTAssertGreaterThan(ConcertEngine.goodWindow(sceneLevel: 10), ConcertEngine.goodWindow(sceneLevel: 1),
                             "la Scène rend le timing plus tolérant")
    }

    func testScoringAndCombo() {
        let concert = Concert(id: "c", venue: "v", startHype: 50, passHype: 60,
                              songs: [ConcertSong(title: "s")], win: InterviewResult(consequence: "w"),
                              lose: InterviewResult(consequence: "l"))
        var running = ConcertState(concert: concert)
        ConcertEngine.apply(Array(repeating: .perfect, count: 12), to: &running)
        XCTAssertEqual(running.combo, 12)
        XCTAssertEqual(running.hype, min(100, 50 + 12 * 4 + 3))
        ConcertEngine.apply(.miss, to: &running)
        XCTAssertEqual(running.combo, 0)
        XCTAssertEqual(running.maxCombo, 12)
        var empty = ConcertState(concert: concert)
        ConcertEngine.apply(Array(repeating: .miss, count: 40), to: &empty)
        XCTAssertEqual(empty.hype, 0)
    }

    // MARK: Data

    func testConcertDataIsValid() throws {
        let concerts = world.story.concerts
        XCTAssertFalse(concerts.isEmpty)
        for concert in concerts {
            XCTAssertFalse(concert.songs.isEmpty, concert.id)
            XCTAssertLessThan(concert.startHype, concert.passHype, concert.id)
            for (index, song) in concert.songs.enumerated() {
                let chart = ConcertEngine.chart(for: song, seed: ConcertEngine.seed(concert.id, song: index))
                XCTAssertGreaterThanOrEqual(chart.count, 8, "\(concert.id) morceau \(index) trop court")
                XCTAssertLessThan(song.duration, 40, "\(concert.id) morceau \(index) trop long")
                if let interlude = song.interlude { XCTAssertGreaterThanOrEqual(interlude.options.count, 2) }
            }
            XCTAssertNil(concert.songs.last?.interlude, "\(concert.id) : pas d'entracte après le dernier morceau")
        }
    }

    // MARK: Balance

    private func play(_ concertId: String, hitRate: Double, perfectShare: Double = 0, interlude: Int = 0) throws -> ConcertState {
        let engine = GameEngine(world: world)
        let concert = try XCTUnwrap(engine.concert(concertId))
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lille, style: .trap))
        state.concert = ConcertState(concert: concert)
        while let running = state.concert, !running.isOver {
            if running.inInterlude {
                _ = try engine.concertInterlude(interlude, in: &state)
            } else {
                let judgments: [ConcertJudgment] = engine.concertChart(in: state).map { _ in
                    let roll = Double.random(in: 0..<1, using: &rng)
                    if roll >= hitRate { return .miss }
                    return Double.random(in: 0..<1, using: &rng) < perfectShare ? .perfect : .good
                }
                _ = try engine.concertSongFinished(judgments, in: &state)
            }
        }
        return try XCTUnwrap(state.concert)
    }

    func testDomeIsTheHardestShow() throws {
        XCTAssertTrue(try play("le_dome", hitRate: 1, perfectShare: 1).passed, "un sans-faute gagne")
        XCTAssertTrue(try play("le_dome", hitRate: 0.95, perfectShare: 0.5).passed, "un très bon joueur gagne")
        XCTAssertFalse(try play("le_dome", hitRate: 0.7, perfectShare: 0.2, interlude: 2).passed,
                       "un joueur approximatif qui rate ses interludes ne remplit pas le Dôme")
        XCTAssertFalse(try play("le_dome", hitRate: 0.5).passed)
    }

    func testFirstConcertBalance() throws {
        XCTAssertTrue(try play("premier_concert", hitRate: 1, perfectShare: 1).passed, "un sans-faute gagne")
        XCTAssertTrue(try play("premier_concert", hitRate: 0.9, perfectShare: 0.3).passed, "un bon joueur gagne")
        XCTAssertFalse(try play("premier_concert", hitRate: 0.5).passed, "taper au hasard ne suffit pas")
        XCTAssertFalse(try play("premier_concert", hitRate: 0).passed)
    }

    // MARK: Chapter 3

    func testChapterThreePlaythrough() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .lyon, style: .melancolique))
        state.chapter = 3
        state.pendingCinematic = nil
        state.flags = ["chapitre_1", "chapitre_2", "signe_goslo", "sous_contrat"]
        state.counters.increment(.projets)
        state.stats = Stats(streams: 45, credibilite: 55, argent: 40, mental: 60)
        func refill() { if state.actionsLeft == 0 { state.actionsLeft = GameState.actionsPerTurn } }

        XCTAssertEqual(engine.currentObjective(in: state)?.id, "setlist")
        XCTAssertEqual(try engine.visit(.chezToi, in: &state, using: &rng).id, "story_setlist")
        _ = try engine.resolve(choiceAt: 0, in: &state)

        refill()
        XCTAssertTrue(try XCTUnwrap(world.map).forChapter(3).npcs.contains { $0.id == "dj_bobine" })
        XCTAssertFalse(try XCTUnwrap(world.map).forChapter(2).npcs.contains { $0.id == "dj_bobine" })
        XCTAssertEqual(try engine.talk(to: "dj_bobine", in: &state, using: &rng)?.id, "story_dj")
        _ = try engine.resolve(choiceAt: 0, in: &state)

        refill()
        XCTAssertEqual(try engine.visit(.studio, in: &state, using: &rng).id, "story_repet")
        _ = try engine.resolve(choiceAt: 0, in: &state)

        refill()
        XCTAssertEqual(try engine.visit(.reseaux, in: &state, using: &rng).id, "story_promo")
        _ = try engine.resolve(choiceAt: 2, in: &state)
        XCTAssertTrue(state.flags.contains("billets_fantomes"))

        refill()
        XCTAssertEqual(try engine.visit(.scene, in: &state, using: &rng).id, "story_balance")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "concert")

        // Boss: the concert. First a failed one, then the retry.
        refill()
        XCTAssertEqual(try engine.visit(.scene, in: &state, using: &rng).id, "story_concert")
        guard case .concert = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de concert") }
        XCTAssertFalse(engine.canVisit(state), "on ne se balade pas pendant un concert")
        while let running = state.concert, !running.isOver {
            if running.inInterlude { _ = try engine.concertInterlude(2, in: &state) }
            else { _ = try engine.concertSongFinished(engine.concertChart(in: state).map { _ in .miss }, in: &state) }
        }
        let flop = try engine.finishConcert(in: &state)
        XCTAssertFalse(try XCTUnwrap(flop.concert).passed)
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "concert", "on peut retenter le concert")

        refill()
        XCTAssertEqual(try engine.visit(.scene, in: &state, using: &rng).id, "story_concert")
        _ = try engine.resolve(choiceAt: 1, in: &state)
        while let running = state.concert, !running.isOver {
            if running.inInterlude { _ = try engine.concertInterlude(0, in: &state) }
            else { _ = try engine.concertSongFinished(engine.concertChart(in: state).map { _ in .perfect }, in: &state) }
        }
        let show = try engine.finishConcert(in: &state)
        XCTAssertTrue(try XCTUnwrap(show.concert).passed)
        XCTAssertTrue(state.flags.contains("concert_reussi"))
        XCTAssertEqual(state.pendingCinematic, "ch3_outro")
        engine.cinematicFinished("ch3_outro", in: &state)
        XCTAssertEqual(state.chapter, 4)
        XCTAssertTrue(state.flags.contains("chapitre_3"))
    }

    func testConcertSurvivesSaveAndLoad() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .drill))
        state.concert = ConcertState(concert: try XCTUnwrap(engine.concert("premier_concert")))
        _ = try engine.concertSongFinished([.perfect, .good], in: &state)
        let data = try JSONEncoder().encode(state)
        let loaded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(loaded.concert, state.concert)
        XCTAssertTrue(loaded.concert?.inInterlude ?? false)
    }
}
