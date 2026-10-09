import XCTest
@testable import GosloRecords

/// The Punchliner's pool of verses (punchlines.json), and how games draw from it without repeating themselves.
final class PunchlinerVersesTests: XCTestCase {
    private static var cachedDictionary: FrenchDictionary?
    private var world = World(events: [])
    private var dictionary: FrenchDictionary!
    private var engine: GameEngine { GameEngine(world: world) }

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        if PunchlinerVersesTests.cachedDictionary == nil {
            PunchlinerVersesTests.cachedDictionary = try EventLoader.loadDictionary(bundle: Bundle(for: AppModel.self))
        }
        dictionary = PunchlinerVersesTests.cachedDictionary
    }

    private func sounds(_ word: String) -> String { Rhyme.phonemes(word, lexicon: dictionary).joined(separator: " ") }

    private func newState(city: City = .lille) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "T", city: city, style: .boomBap))
        state.pendingCinematic = nil
        return state
    }

    /// Plays a whole Punchliner game (always the real punchline) and returns the verses it dealt.
    @discardableResult
    private func play(_ minigameId: String, in state: inout GameState, rng: inout SeededGenerator) throws -> [String] {
        let minigame = try XCTUnwrap(engine.minigame(minigameId))
        let running = engine.startMinigame(minigame, in: &state, using: &rng)
        let ids = try XCTUnwrap(running.verses)
        var setups: [String] = []
        while let current = engine.punchlinerRound(in: state) {
            setups.append(current.round.setup)
            let endings = current.round.endings
            _ = try engine.dropPunchline(endings.indices.max { endings[$0].score < endings[$1].score }, in: &state)
        }
        XCTAssertEqual(setups.count, minigame.rounds.count)
        XCTAssertEqual(Set(setups).count, setups.count, "un couplet ne revient jamais dans la même partie")
        XCTAssertEqual(engine.minigameScore(try XCTUnwrap(state.minigame)), 1, accuracy: 0.0001)
        state.minigame = nil
        return ids
    }

    // MARK: Data

    func testThePoolIsBigAndVaried() {
        let verses = world.story.verses
        let authored = world.story.minigames.flatMap(\.rounds)
        XCTAssertGreaterThanOrEqual(verses.count + authored.count, 120, "au moins 120 couplets en tout")
        XCTAssertEqual(Set(verses.map(\.id)).count, verses.count, "ids en double")
        XCTAssertEqual(Set(verses.map(\.round.setup)).count, verses.count, "premières lignes en double")
        for tier in 1...PunchlinerDeck.maxTier {
            XCTAssertGreaterThanOrEqual(verses.filter { $0.tier == tier }.count, 25, "palier \(tier)")
        }
        XCTAssertTrue(verses.allSatisfy { (1...PunchlinerDeck.maxTier).contains($0.tier) })
        XCTAssertGreaterThanOrEqual(Set(verses.map(\.theme)).count, 10, "des thèmes variés")
        for city in [City.paris, .marseille, .casablanca] {
            XCTAssertGreaterThanOrEqual(verses.filter { $0.city == city }.count, 5, "des couplets pour \(city.rawValue)")
        }
        // Every punchliner mini-game, at its tier, has many more verses than it plays.
        for minigame in world.story.minigames where minigame.kind == .punchliner {
            let tier = minigame.tier ?? PunchlinerDeck.maxTier
            XCTAssertGreaterThanOrEqual(verses.filter { $0.isOffered(maxTier: tier, city: .lille) }.count, 10 * minigame.rounds.count,
                                        minigame.id)
        }
    }

    func testEveryVerseIsWellFormedAndRhymes() throws {
        for verse in world.story.verses {
            let round = verse.round
            let label = verse.id
            XCTAssertEqual(round.endings.count, PunchlinerEngine.endingCount, "\(label) : il faut 4 fins")
            XCTAssertEqual(round.endings.map(\.score).sorted(), [0, 3, 6, PunchlinerEngine.bestScore], "\(label) : barème")
            XCTAssertEqual(Set(round.endings.map(\.text)).count, 4, "\(label) : fins en double")
            for ending in round.endings {
                XCTAssertFalse(ending.reaction.isEmpty, label)
                for gender in Gender.allCases {
                    let shown = TextTemplate.agree(ending.text, gender)
                    XCTAssertLessThanOrEqual(shown.count, 40, "\(label) : « \(shown) » trop long pour un bouton")
                }
            }
            // The setup's last word is a real word: the player can rhyme on it with their own ending.
            let setupWord = try XCTUnwrap(Rhyme.lastWord(of: round.setup))
            XCTAssertTrue(dictionary.contains(setupWord), "\(label) : « \(setupWord) » n'est pas dans le dictionnaire")
            // The real punchline rhymes, richly or sufficiently, with the setup.
            let best = try XCTUnwrap(round.endings.first { $0.score == PunchlinerEngine.bestScore })
            let bestWord = try XCTUnwrap(Rhyme.lastWord(of: best.text))
            let quality = Rhyme.quality(setupWord, bestWord, lexicon: dictionary)
            XCTAssertGreaterThanOrEqual(quality, .suffisante,
                                        "\(label) : \(setupWord) [\(sounds(setupWord))] / \(bestWord) [\(sounds(bestWord))] → \(quality)")
            // Typed by hand, it is worth at least a sufficient rhyme too.
            XCTAssertGreaterThanOrEqual(PunchlinerEngine.judgeWritten(best.text, in: round, dictionary: dictionary).quality,
                                        .suffisante, label)
            // The decent line rhymes too, a little.
            let decent = try XCTUnwrap(round.endings.first { $0.score == 6 })
            let decentWord = try XCTUnwrap(Rhyme.lastWord(of: decent.text))
            XCTAssertGreaterThanOrEqual(max(Rhyme.quality(setupWord, decentWord, lexicon: dictionary),
                                            Rhyme.quality(bestWord, decentWord, lexicon: dictionary)), .pauvre,
                                        "\(label) : « \(decent.text) » [\(sounds(decentWord))] ne rime pas avec \(setupWord) [\(sounds(setupWord))]")
            // And the flop really doesn't rhyme.
            let flop = try XCTUnwrap(round.endings.first { $0.score == 0 })
            let written = PunchlinerEngine.judgeWritten(flop.text, in: round, dictionary: dictionary)
            XCTAssertEqual(written.points, 0, "\(label) : « \(flop.text) » → \(written.feedback)")
        }
    }

    // MARK: Drawing

    func testDrawPrefersUnseenThenTheLeastRecent() {
        var rng = SeededGenerator(seed: 7)
        let pool = (1...6).map { "v\($0)" }
        // Nothing seen: the preferred ones first, in order, then the pool; never twice the same.
        let first = PunchlinerDeck.draw(count: 4, preferred: ["a", "b"], pool: pool, recent: [], using: &rng)
        XCTAssertEqual(Array(first.prefix(2)), ["a", "b"])
        XCTAssertEqual(Set(first).count, 4)
        // Seen ones come after every unseen one.
        let recent = ["a", "b", "v1", "v2", "v3"]
        let second = PunchlinerDeck.draw(count: 3, preferred: ["a", "b"], pool: pool, recent: recent, using: &rng)
        XCTAssertEqual(Set(second), ["v4", "v5", "v6"])
        // Everything seen: the least recently seen come back first.
        let all = ["v4", "a", "v6", "b", "v1", "v2", "v3", "v5"]
        let third = PunchlinerDeck.draw(count: 3, preferred: ["a", "b"], pool: pool, recent: all, using: &rng)
        XCTAssertEqual(third, ["v4", "a", "v6"])
        // Asking for more than there is: each once.
        XCTAssertEqual(PunchlinerDeck.draw(count: 20, preferred: ["a"], pool: ["a", "v1"], recent: [], using: &rng).count, 2)
    }

    func testRememberMovesToTheEndAndIsCapped() {
        XCTAssertEqual(PunchlinerDeck.remember(["b", "d"], in: ["a", "b", "c"]), ["a", "c", "b", "d"])
        let long = (0..<(PunchlinerDeck.memory + 50)).map { "v\($0)" }
        let kept = PunchlinerDeck.remember(["new"], in: long)
        XCTAssertEqual(kept.count, PunchlinerDeck.memory)
        XCTAssertEqual(kept.last, "new")
        XCTAssertGreaterThan(PunchlinerDeck.memory, world.story.verses.count, "la mémoire couvre tout le pool")
    }

    // MARK: Games

    func testFirstGamePlaysTheStoryVersesThenThePool() throws {
        var state = newState()
        var rng = SeededGenerator(seed: 1)
        let first = try play("punchliner_bunker", in: &state, rng: &rng)
        XCTAssertEqual(first, (0..<3).map { PunchlinerDeck.authoredId("punchliner_bunker", index: $0) },
                       "la première fois, le texte de l'histoire")
        let second = try play("punchliner_bunker", in: &state, rng: &rng)
        XCTAssertTrue(second.allSatisfy { world.story.verse($0) != nil }, "ensuite, le pool : \(second)")
        XCTAssertTrue(Set(first).isDisjoint(with: second))
        XCTAssertEqual(Array(state.seenVerses.suffix(6)), first + second)
    }

    func testVersesDontComeBackUntilThePoolIsExhausted() throws {
        var state = newState()
        var rng = SeededGenerator(seed: 2)
        let minigame = try XCTUnwrap(engine.minigame("punchliner_banc"))
        let tier = try XCTUnwrap(minigame.tier)
        let available = Set(world.story.verses.filter { $0.isOffered(maxTier: tier, city: .lille) }.map(\.id))
            .union(minigame.rounds.indices.map { PunchlinerDeck.authoredId(minigame.id, index: $0) })
        var dealt: [String] = []
        while dealt.count + minigame.rounds.count <= available.count {
            dealt += try play(minigame.id, in: &state, rng: &rng)
        }
        XCTAssertEqual(Set(dealt).count, dealt.count, "aucun couplet ne revient avant d'avoir tout vu")
        XCTAssertTrue(Set(dealt).isSubset(of: available))
        // Then the cycle starts again with the verses seen longest ago.
        let next = try play(minigame.id, in: &state, rng: &rng)
        let leftover = available.subtracting(dealt)
        XCTAssertTrue(leftover.isSubset(of: Set(next)), "les derniers jamais vus d'abord")
        let recycled = next.filter { !leftover.contains($0) }
        XCTAssertEqual(Set(recycled), Set(dealt.prefix(recycled.count)), "puis les plus anciens")
    }

    func testCityVersesStayInTheirCity() throws {
        var rng = SeededGenerator(seed: 3)
        var paris = newState(city: .paris)
        var lille = newState(city: .lille)
        var parisDealt: Set<String> = []
        var lilleDealt: Set<String> = []
        for _ in 0..<30 {
            parisDealt.formUnion(try play("punchliner_bunker", in: &paris, rng: &rng))
            lilleDealt.formUnion(try play("punchliner_bunker", in: &lille, rng: &rng))
        }
        let cityOf = { (id: String) in self.world.story.verse(id)?.city }
        XCTAssertTrue(parisDealt.allSatisfy { cityOf($0) == nil || cityOf($0) == .paris })
        XCTAssertTrue(parisDealt.contains { cityOf($0) == .paris }, "Paris a ses couplets")
        XCTAssertTrue(lilleDealt.allSatisfy { cityOf($0) == nil || cityOf($0) == .lille })
        // The tier is respected.
        XCTAssertTrue(lilleDealt.allSatisfy { (world.story.verse($0)?.tier ?? 0) <= 2 })
    }

    func testArcadeDealsUnseenVersesFromTheRecords() throws {
        let game = try XCTUnwrap(Arcade.game("punchliner"))
        let rapper = Rapper(name: "A", city: .marseille, style: .trap)
        var profile = TrophyCase()
        var dealt: [String] = []
        for _ in 0..<10 {
            var state = try XCTUnwrap(engine.arcadeGame(game, rapper: rapper, seenVerses: profile.punchliner.recentVerses))
            let ids = try XCTUnwrap(state.minigame?.verses)
            dealt += ids
            while let current = engine.punchlinerRound(in: state) {
                _ = try engine.dropPunchline(current.order.first, in: &state)
            }
            let running = try XCTUnwrap(state.minigame)
            _ = profile.recordPunchliner(running, score: Arcade.score(of: running, engine: engine))
            XCTAssertEqual(Array(profile.punchliner.recentVerses.suffix(ids.count)), ids)
        }
        XCTAssertEqual(Set(dealt).count, dealt.count, "dix parties d'arcade, trente couplets différents")
        XCTAssertTrue(dealt.contains { world.story.verse($0)?.tier == 3 }, "l'arcade offre tous les paliers")
    }

    func testOlderGamesAndSavesStillWork() throws {
        // A game saved before the pool (no drawn verses) plays the mini-game's own verses.
        var state = newState()
        let carnet = try XCTUnwrap(engine.minigame("punchliner_carnet"))
        state.minigame = MinigameState(minigame: carnet)
        XCTAssertEqual(engine.punchlinerRound(in: state)?.round, carnet.rounds[0])
        // Saves without the new fields still load.
        let encoded = try JSONEncoder().encode(state)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["seenVerses"] = nil
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.seenVerses, [])
        let record = try JSONDecoder().decode(PunchlinerRecord.self, from: Data(#"{"bestScore": 40, "games": 2}"#.utf8))
        XCTAssertEqual(record.recentVerses, [])
        XCTAssertEqual(record.bestScore, 40)
        // A drawn verse survives a save.
        var rng = SeededGenerator(seed: 4)
        var fresh = newState()
        fresh.seenVerses = (0..<3).map { PunchlinerDeck.authoredId(carnet.id, index: $0) }
        let running = engine.startMinigame(carnet, in: &fresh, using: &rng)
        let reloaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(fresh))
        XCTAssertEqual(reloaded.minigame?.verses, running.verses)
        XCTAssertEqual(engine.punchlinerRound(in: reloaded)?.round, engine.punchlinerRound(in: fresh)?.round)
        XCTAssertNotNil(world.story.verse(try XCTUnwrap(running.verses?.first)))
    }
}
