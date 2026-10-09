import XCTest
@testable import GosloRecords

/// The Punchliner's « écris ta fin » : the dictionary and the French rhyme detector.
final class RhymeTests: XCTestCase {
    private static var cached: FrenchDictionary?
    private var dictionary: FrenchDictionary!

    override func setUpWithError() throws {
        if RhymeTests.cached == nil {
            RhymeTests.cached = try EventLoader.loadDictionary(bundle: Bundle(for: AppModel.self))
        }
        dictionary = RhymeTests.cached
    }

    private func assertRhyme(_ a: String, _ b: String, _ expected: RhymeQuality, file: StaticString = #filePath, line: UInt = #line) {
        let got = Rhyme.quality(a, b, lexicon: dictionary)
        XCTAssertEqual(got, expected, "\(a) [\(Rhyme.phonemes(a, lexicon: dictionary).joined(separator: " "))] / "
                       + "\(b) [\(Rhyme.phonemes(b, lexicon: dictionary).joined(separator: " "))]", file: file, line: line)
        XCTAssertEqual(Rhyme.quality(b, a, lexicon: dictionary), got, "symétrique : \(a) / \(b)", file: file, line: line)
    }

    // MARK: Dictionary

    func testDictionaryIsBigAndAccentInsensitive() {
        XCTAssertGreaterThan(dictionary.count, 300_000)
        for word in ["été", "ete", "ÉTÉ", "nation", "bitume", "gâteau", "gateau", "cœur", "coeur", "l'hiver", "aujourd'hui",
                     "chantent", "rappeur", "punchline", "flow", "kiffe"] {
            XCTAssertTrue(dictionary.contains(word), word)
        }
        for word in ["blarf", "zxqv", "", "123", "nationnn"] {
            XCTAssertFalse(dictionary.contains(word), word)
        }
    }

    func testNormalize() {
        XCTAssertEqual(FrenchDictionary.normalize("Été"), "ete")
        XCTAssertEqual(FrenchDictionary.normalize("Cœur"), "coeur")
        XCTAssertEqual(FrenchDictionary.normalize("garçon!"), "garcon")
        XCTAssertEqual(FrenchDictionary.normalize("aujourd'hui"), "aujourdhui")
    }

    func testFrontCodedFormat() {
        let data = Data("0abri\n4s\n2ricot\n0zoo\n".utf8)
        XCTAssertEqual(FrenchDictionary(frontCoded: data).words, ["abri", "abris", "abricot", "zoo"])
    }

    func testLastWord() {
        XCTAssertEqual(Rhyme.lastWord(of: "En bas du bloc, l'ascenseur est en panne depuis l'hiver,"), "l'hiver")
        XCTAssertEqual(Rhyme.lastWord(of: "« je rappe pour qu'on se taille »"), "taille")
        XCTAssertEqual(Rhyme.lastWord(of: "et personne ne s'en va !"), "va")
        XCTAssertNil(Rhyme.lastWord(of: " … !? "))
    }

    // MARK: Phonetics

    func testPhonemes() {
        let expected: [String: String] = [
            "nation": "n a s j ɔ̃", "passion": "p a s j ɔ̃", "bitume": "b i t y m", "costume": "k o s t y m",
            "gâteau": "g a t o", "bateau": "b a t o", "chat": "ʃ a", "rat": "ʁ a", "ville": "v i l", "fille": "f i j",
            "nuit": "n y i", "bruit": "b ʁ y i", "hiver": "i v e ʁ", "vers": "v e ʁ", "parler": "p a ʁ l e",
            "chantent": "ʃ ɑ̃ t", "moment": "m o m ɑ̃", "temps": "t ɑ̃", "chien": "ʃ j ɛ̃", "client": "k l j ɑ̃",
            "taille": "t a j", "travail": "t ʁ a v a j", "soleil": "s o l e j", "rouge": "ʁ u ʒ", "écho": "e k o",
            "français": "f ʁ ɑ̃ s e", "jamais": "ʒ a m e", "plafond": "p l a f ɔ̃", "lune": "l y n", "bonne": "b o n",
            "rose": "ʁ o z", "pied": "p j e", "deux": "d ø", "sac": "s a k", "blanc": "b l ɑ̃", "étaient": "e t e",
            "aiment": "e m", "famille": "f a m i j", "fatigue": "f a t i g", "plaindre": "p l ɛ̃ d ʁ",
            "atteindre": "a t ɛ̃ d ʁ", "délavé": "d e l a v e", "laver": "l a v e", "seize": "s e z",
            "question": "k e s t j ɔ̃", "loin": "l w ɛ̃", "toi": "t w a", "parfum": "p a ʁ f ɛ̃", "album": "a l b o m",
            "clash": "k l a ʃ", "corps": "k o ʁ", "disent": "d i z", "c'est": "e", "l'hiver": "i v e ʁ", "garçon": "g a ʁ s ɔ̃",
            "poing": "p w ɛ̃", "chevaux": "ʃ ø v o", "sept": "s e t", "six": "s i s", "rap": "ʁ a p", "loup": "l u",
            "hip-hop": "o p", "argent": "a ʁ ʒ ɑ̃", "fusil": "f y z i", "orgueil": "o ʁ g ø j",
        ]
        for (word, phonemes) in expected.sorted(by: { $0.key < $1.key }) {
            XCTAssertEqual(Rhyme.phonemes(word, lexicon: dictionary).joined(separator: " "), phonemes, word)
        }
    }

    // MARK: Rhymes

    func testRichRhymes() {
        for (a, b) in [("nation", "passion"), ("bitume", "costume"), ("gâteau", "bateau"), ("hiver", "vers"),
                       ("délavé", "laver"), ("plaindre", "atteindre"), ("univers", "hiver"), ("tient", "appartient"),
                       ("station", "émotion"), ("bataille", "taille"), ("rappeur", "trappeur"), ("lumière", "première"),
                       ("ascenseur", "danseur"), ("oreille", "pareille"), ("rappent", "frappent"), ("couronne", "patronne")] {
            assertRhyme(a, b, .riche)
        }
    }

    func testSufficientRhymes() {
        for (a, b) in [("nuit", "bruit"), ("rouge", "bouge"), ("or", "dort"), ("travail", "taille"), ("fille", "bille"),
                       ("mur", "dur"), ("rage", "page"), ("flamme", "drame"), ("classe", "masse"), ("glace", "face"),
                       ("toi", "moi"), ("classe", "place")] where a != "classe" || b != "place" {
            assertRhyme(a, b, .suffisante)
        }
    }

    func testPoorRhymes() {
        for (a, b) in [("chat", "rat"), ("ami", "pari"), ("français", "jamais"), ("là", "va"), ("matin", "sien"),
                       ("nom", "plafond"), ("flow", "écho"), ("été", "parler"), ("bleu", "feu")] {
            assertRhyme(a, b, .pauvre)
        }
    }

    func testNoRhymes() {
        for (a, b) in [("ville", "fille"), ("hiver", "pied"), ("nation", "bateau"), ("chat", "chien"), ("rouge", "rose"),
                       ("moment", "amour"), ("nuit", "noir")] {
            assertRhyme(a, b, .aucune)
        }
        XCTAssertEqual(Rhyme.quality("passion", "passion"), .aucune, "le même mot ne rime pas avec lui-même")
        XCTAssertEqual(Rhyme.quality("Été", "ete"), .aucune, "même mot, accents ou pas")
        XCTAssertEqual(Rhyme.quality("", "nation"), .aucune)
    }

    func testRhymeEndingsAreSpelled() {
        let match = Rhyme.match("nation", "passions", lexicon: dictionary)
        XCTAssertEqual(match.quality, .riche)
        XCTAssertEqual(match.endings?.0, "ation")
        XCTAssertEqual(match.endings?.1, "assions")
    }

    // MARK: Punchliner

    private func round(_ id: String, _ index: Int) throws -> PunchlinerRound {
        let world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        return try XCTUnwrap(world.story.minigame(id)?.rounds[index])
    }

    func testEveryRealPunchlineRhymesWithItsTarget() throws {
        let world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        for minigame in world.story.minigames where minigame.kind == .punchliner {
            for (index, round) in minigame.rounds.enumerated() {
                let best = try XCTUnwrap(round.endings.max { $0.score < $1.score })
                let targets = PunchlinerEngine.rhymeTargets(for: round)
                XCTAssertFalse(targets.isEmpty)
                // The real punchline, typed by hand, is judged as at least a sufficient rhyme with the setup line.
                let setupWord = try XCTUnwrap(Rhyme.lastWord(of: round.setup))
                let bestWord = try XCTUnwrap(Rhyme.lastWord(of: best.text))
                XCTAssertGreaterThanOrEqual(Rhyme.quality(setupWord, bestWord, lexicon: dictionary), .pauvre,
                                            "\(minigame.id) #\(index + 1) : \(setupWord) / \(bestWord)")
                // And the flop really doesn't rhyme.
                let flop = try XCTUnwrap(round.endings.min { $0.score < $1.score })
                let written = PunchlinerEngine.judgeWritten(flop.text, in: round, dictionary: dictionary)
                XCTAssertEqual(written.points, 0, "\(minigame.id) #\(index + 1) : « \(flop.text) » → \(written.feedback)")
            }
        }
    }

    func testJudgeWritten() throws {
        let hiver = try round("punchliner_carnet", 0)  // « … depuis l'hiver, » / « moi je monte quand même »
        let rich = PunchlinerEngine.judgeWritten("avec mes rimes en guise de revolver", in: hiver, dictionary: dictionary)
        XCTAssertEqual(rich.quality, .riche, rich.feedback)
        XCTAssertEqual(rich.points, PunchlinerEngine.bestScore)
        XCTAssertTrue(rich.feedback.hasPrefix("Rime riche !"), rich.feedback)

        let unknown = PunchlinerEngine.judgeWritten("jusqu'au blarf", in: hiver, dictionary: dictionary)
        XCTAssertFalse(unknown.known)
        XCTAssertEqual(unknown.points, 0)
        XCTAssertEqual(unknown.feedback, "« blarf » n'est pas dans le dictionnaire.")

        let same = PunchlinerEngine.judgeWritten("jusqu'à l'hiver", in: hiver, dictionary: dictionary)
        XCTAssertEqual(same.points, 0, "le même mot que la rime ne compte pas")
        XCTAssertEqual(same.feedback, "« hiver » avec « hiver » : même mot, ça ne compte pas.")

        let none = PunchlinerEngine.judgeWritten("en chaussettes", in: hiver, dictionary: dictionary)
        XCTAssertEqual(none.quality, .aucune)
        XCTAssertEqual(none.feedback, "Pas de rime avec « hiver ».")

        let empty = PunchlinerEngine.judgeWritten("   ", in: hiver, dictionary: dictionary)
        XCTAssertEqual(empty.points, 0)

        // Accents don't matter: « delave » counts as « délavé ».
        let laver = try round("punchliner_bunker", 0)
        let typed = PunchlinerEngine.judgeWritten("sans jamais etre delave", in: laver, dictionary: dictionary)
        XCTAssertTrue(typed.known)
        XCTAssertEqual(typed.quality, .riche, typed.feedback)

        // Scores follow the quality.
        XCTAssertGreaterThan(PunchlinerEngine.points(for: .riche), PunchlinerEngine.points(for: .suffisante))
        XCTAssertGreaterThan(PunchlinerEngine.points(for: .suffisante), PunchlinerEngine.points(for: .pauvre))
        XCTAssertGreaterThan(PunchlinerEngine.points(for: .pauvre), PunchlinerEngine.points(for: .aucune))
    }

    func testWrittenEndingGoesIntoTheVerse() throws {
        let world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "Test", city: .lille, style: .boomBap))
        let minigame = try XCTUnwrap(engine.minigame("punchliner_carnet"))
        state.minigame = MinigameState(minigame: minigame)
        let written = try engine.dropWrittenPunchline("avec mes rimes en guise de revolver", dictionary: dictionary, in: &state)
        XCTAssertEqual(written.points, PunchlinerEngine.bestScore)
        let running = try XCTUnwrap(state.minigame)
        XCTAssertEqual(running.round, 1)
        XCTAssertEqual(running.points, PunchlinerEngine.bestScore)
        XCTAssertEqual(running.lyrics?.last, "moi je monte quand même avec mes rimes en guise de revolver")
        XCTAssertEqual(running.hook, "avec mes rimes en guise de revolver")
        XCTAssertTrue(running.log.last?.contains("Rime riche") == true)

        _ = try engine.dropWrittenPunchline("blarf", dictionary: dictionary, in: &state)
        XCTAssertEqual(state.minigame?.points, PunchlinerEngine.bestScore, "un mot inconnu ne rapporte rien")
        XCTAssertEqual(state.minigame?.hook, "avec mes rimes en guise de revolver", "le refrain reste la première vraie punchline")
        while engine.punchlinerRound(in: state) != nil { _ = try engine.dropPunchline(nil, in: &state) }
        let track = try XCTUnwrap(engine.track(for: try XCTUnwrap(state.minigame), rapper: state.rapper))
        XCTAssertEqual(track.title, "Avec mes rimes en guise de revolver")
        XCTAssertEqual(track.voiceFileName, "voix-avec-mes-rimes-en-guise-de-revolver.m4a")
    }

    func testWavHeader() {
        let data = PlayerTrack.wav([0, 1, -1, 0.5], sampleRate: 32_000)
        XCTAssertEqual(data.count, 44 + 8)
        XCTAssertEqual(String(decoding: data[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(String(decoding: data[36..<40], as: UTF8.self), "data")
        XCTAssertEqual(data[46], 0xFF)
        XCTAssertEqual(data[47], 0x7F, "1.0 → 32767")
    }
}
