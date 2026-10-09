import XCTest
@testable import GosloRecords

/// Punchliner's personal records, the rhymes kept for the share card, and the crowd's mood.
final class PunchlinerRecordsTests: XCTestCase {
    private static var cachedDictionary: FrenchDictionary?
    private var world = World(events: [])
    private var dictionary: FrenchDictionary!
    private var engine: GameEngine { GameEngine(world: world) }

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        if PunchlinerRecordsTests.cachedDictionary == nil {
            PunchlinerRecordsTests.cachedDictionary = try EventLoader.loadDictionary(bundle: Bundle(for: AppModel.self))
        }
        dictionary = PunchlinerRecordsTests.cachedDictionary
    }

    private func carnet() throws -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lille, style: .boomBap))
        state.pendingCinematic = nil
        state.minigame = MinigameState(minigame: try XCTUnwrap(engine.minigame("punchliner_carnet")))
        return state
    }

    private func finished(points: Int, rich: Int = 0, rhyme: RhymePair? = nil) throws -> MinigameState {
        var running = MinigameState(minigame: try XCTUnwrap(engine.minigame("punchliner_carnet")))
        running.round = running.roundCount
        running.points = points
        running.richRhymes = rich
        running.bestRhyme = rhyme
        return running
    }

    // MARK: Crowd

    func testCrowdMoodFollowsTheLine() {
        XCTAssertEqual(PunchlinerEngine.crowdMood(points: PunchlinerEngine.bestScore), .hype, "vraie punchline ou rime riche")
        XCTAssertEqual(PunchlinerEngine.crowdMood(points: PunchlinerEngine.points(for: .riche)), .hype)
        XCTAssertEqual(PunchlinerEngine.crowdMood(points: PunchlinerEngine.points(for: .suffisante)), .nod)
        XCTAssertEqual(PunchlinerEngine.crowdMood(points: PunchlinerEngine.points(for: .pauvre)), .meh)
        XCTAssertEqual(PunchlinerEngine.crowdMood(points: 0), .meh, "flop ou trou noir")
        // Every proposed ending: the punchline makes the crowd jump, the flop crosses its arms.
        for round in engine.minigame("punchliner_carnet")?.rounds ?? [] {
            let moods = round.endings.sorted { $0.score > $1.score }.map { PunchlinerEngine.crowdMood(points: $0.score) }
            XCTAssertEqual(moods.first, .hype)
            XCTAssertEqual(moods.last, .meh)
        }
    }

    // MARK: Rhymes written during a game

    func testWrittenRhymesAreCountedAndTheBestIsKept() throws {
        var state = try carnet()
        let rich = try engine.dropWrittenPunchline("avec mes rimes en guise de revolver", dictionary: dictionary, in: &state)
        XCTAssertEqual(rich.quality, .riche)
        var running = try XCTUnwrap(state.minigame)
        XCTAssertEqual(running.richRhymes, 1)
        XCTAssertEqual(running.bestRhyme?.ending, "avec mes rimes en guise de revolver")
        XCTAssertEqual(running.bestRhyme?.quality, .riche)
        XCTAssertEqual(running.bestRhyme?.word, rich.word)
        XCTAssertEqual(running.bestRhyme?.target, rich.target)

        // An unknown word and a blank change nothing.
        _ = try engine.dropWrittenPunchline("blarf", dictionary: dictionary, in: &state)
        _ = try engine.dropPunchline(nil, in: &state)
        running = try XCTUnwrap(state.minigame)
        XCTAssertEqual(running.richRhymes, 1)
        XCTAssertEqual(running.bestRhyme?.ending, "avec mes rimes en guise de revolver")
    }

    func testOnlyRealRhymesMakeAPair() {
        let unknown = WrittenEnding(text: "blarf", word: "blarf", target: "hiver", quality: .riche, known: false,
                                    feedback: "", reaction: "")
        XCTAssertNil(RhymePair(unknown))
        let none = WrittenEnding(text: "le chat", word: "chat", target: "hiver", quality: .aucune, known: true,
                                 feedback: "", reaction: "")
        XCTAssertNil(RhymePair(none))
        let poor = WrittenEnding(text: "un ver", word: "ver", target: "hiver", quality: .pauvre, known: true,
                                 feedback: "", reaction: "")
        XCTAssertEqual(RhymePair(poor)?.quality, .pauvre)
    }

    func testRicherRhymeWinsThenLongerWord() {
        let poor = RhymePair(ending: "ami", word: "ami", target: "pari", quality: .pauvre)
        let rich = RhymePair(ending: "la passion", word: "passion", target: "nation", quality: .riche)
        let longer = RhymePair(ending: "l'explosion", word: "explosion", target: "nation", quality: .riche)
        XCTAssertTrue(poor.beats(nil))
        XCTAssertTrue(rich.beats(poor))
        XCTAssertFalse(poor.beats(rich))
        XCTAssertTrue(longer.beats(rich), "à qualité égale, le mot le plus long")
        XCTAssertFalse(rich.beats(rich))
    }

    // MARK: Records

    func testRecordsKeepTheBestAndAddUpRichRhymes() throws {
        var trophies = TrophyCase()
        let rich = RhymePair(ending: "la passion", word: "passion", target: "nation", quality: .riche)
        let first = try XCTUnwrap(trophies.recordPunchliner(try finished(points: 20, rich: 2, rhyme: rich), score: 50))
        XCTAssertTrue(first.newBestScore)
        XCTAssertEqual(first.previousBest, 0)
        XCTAssertTrue(first.newBestRhyme)
        XCTAssertEqual(trophies.punchliner.bestScore, 50)
        XCTAssertEqual(trophies.punchliner.richRhymes, 2)
        XCTAssertEqual(trophies.punchliner.bestRhyme, rich)
        XCTAssertEqual(trophies.punchliner.games, 1)

        // A worse game: no record, but its rich rhymes still count.
        let poor = RhymePair(ending: "ami", word: "ami", target: "pari", quality: .pauvre)
        let second = try XCTUnwrap(trophies.recordPunchliner(try finished(points: 8, rich: 1, rhyme: poor), score: 20))
        XCTAssertFalse(second.newBestScore)
        XCTAssertFalse(second.newBestRhyme)
        XCTAssertEqual(second.previousBest, 50)
        XCTAssertEqual(trophies.punchliner.bestScore, 50)
        XCTAssertEqual(trophies.punchliner.richRhymes, 3)
        XCTAssertEqual(trophies.punchliner.bestRhyme, rich)

        // Equal to the record is not a new record.
        XCTAssertFalse(try XCTUnwrap(trophies.recordPunchliner(try finished(points: 20), score: 50)).newBestScore)
        let third = try XCTUnwrap(trophies.recordPunchliner(try finished(points: 40), score: 100))
        XCTAssertTrue(third.newBestScore)
        XCTAssertEqual(trophies.punchliner.bestScore, 100)
        XCTAssertEqual(trophies.punchliner.games, 4)
    }

    func testABlankFirstGameIsNoRecord() throws {
        var trophies = TrophyCase()
        let blank = try XCTUnwrap(trophies.recordPunchliner(try finished(points: 0), score: 0))
        XCTAssertFalse(blank.newBestScore)
        XCTAssertEqual(trophies.punchliner.games, 1)
    }

    func testOnlyFinishedPunchlinersAreRecorded() throws {
        var trophies = TrophyCase()
        var running = try finished(points: 10)
        running.round = 0
        XCTAssertNil(trophies.recordPunchliner(running, score: 30), "partie pas finie")
        let platine = try XCTUnwrap(engine.minigame("platine_bobine"))
        var other = MinigameState(minigame: platine)
        other.round = other.roundCount
        XCTAssertNil(trophies.recordPunchliner(other, score: 100), "autre mini-jeu")
        XCTAssertEqual(trophies.punchliner, PunchlinerRecord())
    }

    func testRecordsSurviveSavingAndOldProfilesLoad() throws {
        var trophies = TrophyCase()
        let rich = RhymePair(ending: "la passion", word: "passion", target: "nation", quality: .riche)
        _ = trophies.recordPunchliner(try finished(points: 30, rich: 3, rhyme: rich), score: 75)
        let data = try JSONEncoder().encode(trophies)
        XCTAssertEqual(try JSONDecoder().decode(TrophyCase.self, from: data), trophies)

        // A profile saved before the records: they start empty, nothing else is lost.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["punchliner"] = nil
        let old = try JSONDecoder().decode(TrophyCase.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.punchliner, PunchlinerRecord())
        XCTAssertEqual(old.daily, trophies.daily)

        // A game in progress saved before the rhyme tracking still loads.
        var state = try carnet()
        _ = try engine.dropWrittenPunchline("avec mes rimes en guise de revolver", dictionary: dictionary, in: &state)
        var running = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state.minigame)) as? [String: Any])
        running["richRhymes"] = nil
        running["bestRhyme"] = nil
        let loaded = try JSONDecoder().decode(MinigameState.self, from: JSONSerialization.data(withJSONObject: running))
        XCTAssertNil(loaded.bestRhyme)
        XCTAssertEqual(loaded.round, 1)
    }

    func testDailyStreakRecordIsAlreadyKept() {
        var daily = DailyRecord()
        daily.finish(on: "2026-01-01", won: true, yesterday: "2025-12-31")
        daily.finish(on: "2026-01-02", won: true, yesterday: "2026-01-01")
        daily.finish(on: "2026-01-03", won: false, yesterday: "2026-01-02")
        XCTAssertEqual(daily.best, 2, "le meilleur Clash du jour reste affiché sur l'écran de résultat")
    }
}
