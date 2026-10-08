import XCTest
@testable import GosloRecords

/// Choices that change what follows: cinematic lines that depend on earlier choices, characters' story lines,
/// scenes that only play on some paths (Momo and the photo, Fred's Bunker in the epilogue).
final class StoryArcsTests: XCTestCase {
    private var world = World(events: [])
    private var engine: GameEngine { GameEngine(world: world) }
    private var rng = SeededGenerator(seed: 1994)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    // MARK: Conditional cinematic lines

    func testCinematicStepsCanDependOnEarlierChoices() throws {
        let json = #"{"narration": "Merci, Lucien.", "when": {"required_flags": ["lucien_promesse"]}}"#
        let step = try JSONDecoder().decode(CinematicStep.self, from: Data(json.utf8))
        XCTAssertEqual(step.fieldCount, 1, "la condition n'est pas une action")
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lille, style: .boomBap))
        XCTAssertFalse(step.plays(in: state))
        state.flags.insert("lucien_promesse")
        XCTAssertTrue(step.plays(in: state))
        XCTAssertTrue(step.plays(in: nil), "sans partie en cours, tout se joue")

        let old = try JSONDecoder().decode(CinematicStep.self, from: Data(#"{"narration": "x", "cities": ["Lille"]}"#.utf8))
        XCTAssertNil(old.when)
        XCTAssertTrue(old.plays(in: state))
        XCTAssertFalse(old.plays(in: engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .boomBap))))
    }

    func testTheThroneRemembersTheBenchPromise() throws {
        let outro = try XCTUnwrap(world.story.cinematic("ch6_outro"))
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .drill))
        func lines() -> [String] { outro.steps.filter { $0.plays(in: state) }.compactMap { $0.narration ?? $0.say?.text } }
        XCTAssertTrue(lines().contains { $0.contains("tabouret vide") })
        XCTAssertFalse(lines().contains { $0.contains("répondeur") })
        state.flags.insert("lucien_promesse")
        XCTAssertTrue(lines().contains { $0.contains("répondeur") }, "la promesse du chapitre 3 se tient au Dôme")
        XCTAssertFalse(lines().contains { $0.contains("tabouret vide") })

        // Fred mixes the Dôme in the open, or anonymously.
        XCTAssertTrue(outro.steps.filter { $0.plays(in: state) }.contains { $0.say?.who == "fred" })
        state.flags.insert("fred_banni")
        XCTAssertFalse(outro.steps.filter { $0.plays(in: state) }.contains { $0.say?.who == "fred" })
        XCTAssertTrue(lines().contains { $0.contains("— F.") })
    }

    // MARK: Characters' story lines

    func testStoryLinesAreSaidOnceNewestFirst() throws {
        let ami = CastMember(id: "ami", name: "Ami", role: "", idle: ["Un.", "Deux.", "Trois."], moments: [
            CastMoment(text: "Bravo pour le concert.", conditions: EventConditions(requiredFlags: ["concert_reussi"])),
            CastMoment(text: "Courage pour le Dôme.", conditions: EventConditions(minChapter: 6)),
        ])
        let engine = GameEngine(events: [], cast: [ami])
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        state.pendingCinematic = nil
        XCTAssertEqual(engine.smallTalk(with: "ami", in: &state).first, "« Un. »", "rien de neuf : les répliques d'attente")
        state.flags.insert("concert_reussi")
        state.chapter = 6
        XCTAssertEqual(engine.smallTalk(with: "ami", in: &state).first, "« Courage pour le Dôme. »", "la plus récente d'abord")
        XCTAssertEqual(engine.smallTalk(with: "ami", in: &state).first, "« Bravo pour le concert. »")
        let after = try XCTUnwrap(engine.smallTalk(with: "ami", in: &state).first)
        XCTAssertTrue(["« Un. »", "« Deux. »", "« Trois. »"].contains(after), "une seule fois chacune : \(after)")
    }

    func testCastStoryLinesAreValid() throws {
        let decoded = try JSONDecoder().decode(CastMember.self, from: Data(#"{"id": "x", "name": "X", "role": "r"}"#.utf8))
        XCTAssertTrue(decoded.moments.isEmpty, "un ancien fichier sans répliques se lit toujours")
        let castIds = Set(world.cast.map(\.id))
        for member in world.cast {
            for moment in member.moments {
                XCTAssertFalse(moment.text.isEmpty, member.id)
                XCTAssertNotEqual(moment.conditions, EventConditions(), "\(member.id) : une réplique d'histoire dépend de l'histoire")
                XCTAssertTrue(moment.conditions.referencedCast.isSubset(of: castIds), member.id)
            }
        }
        XCTAssertFalse(try XCTUnwrap(world.cast.first { $0.id == Philosopher.id }).moments.isEmpty)
    }

    func testMomoTalksAboutLucien() throws {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 6
        state.flags.insert("adieu_lucien")
        XCTAssertTrue(try XCTUnwrap(engine.smallTalk(with: "momo", in: &state).first).contains("Lucien"))
    }

    func testThePhilosopherSharesAThoughtAfterHisReading() throws {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .boomBap))
        state.hooks = ["le bitume est mon costume"]
        state.flags.insert("adieu_lucien")
        let lines = engine.philosopherReading(in: &state)
        XCTAssertTrue(lines[0].contains("le bitume est mon costume"), "la lecture d'abord")
        XCTAssertTrue(lines.last?.contains("banc") == true)
        XCTAssertFalse(engine.philosopherReading(in: &state).contains { $0.contains("On l'habite") }, "une seule fois")
    }

    // MARK: Story scenes

    /// The new scenes make the story longer, not the career: they don't spend one of the semester's actions.
    func testStoryScenesDontSpendAnAction() throws {
        let engine = engine
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 3
        state.flags = ["chapitre_1", "chapitre_2", "signe_goslo", "sous_contrat"]
        state.counters.increment(.projets)
        let chapter = try XCTUnwrap(engine.story.chapter(3))
        state.objectiveIndex = try XCTUnwrap(chapter.objectives.firstIndex { $0.id == "lucien_banc" })
        XCTAssertTrue(chapter.objectives[state.objectiveIndex].free)
        XCTAssertEqual(try engine.talk(to: "lucien", in: &state, using: &rng)?.id, "story_lucien_banc")
        XCTAssertEqual(state.actionsLeft, GameState.actionsPerTurn, "une scène ne coûte pas d'action")
        _ = try engine.resolve(choiceAt: 1, in: &state)
        XCTAssertEqual(state.actionsLeft, GameState.actionsPerTurn)
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "balance")
        XCTAssertEqual(try engine.visit(.scene, in: &state, using: &rng).id, "story_balance")
        XCTAssertEqual(state.actionsLeft, GameState.actionsPerTurn - 1, "une étape de carrière, si")

        let free = engine.story.chapters.flatMap(\.objectives).filter(\.free).map(\.id)
        XCTAssertEqual(Set(free), ["lucien_banc", "fuite", "adieu_lucien", "momo_photo", "nuit_blanche", "bunker"])
        let old = try JSONDecoder().decode(Objective.self, from: Data(#"{"id": "o", "label": "l", "conditions": {}}"#.utf8))
        XCTAssertFalse(old.free)
    }

    // MARK: Scenes that only play on some paths

    /// Went up to the Baron's in chapter 5: a neighbour took a photo, and Momo saw it.
    func testMomoAsksAboutThePhotoOnlyIfYouWentUp() throws {
        let engine = engine
        let chapter = try XCTUnwrap(engine.story.chapter(6))
        let index = try XCTUnwrap(chapter.objectives.firstIndex { $0.id == "momo_photo" })
        var state = engine.newGame(rapper: Rapper(name: "T", city: .bruxelles, style: .trap))
        engine.debugJump(toChapter: 6, in: &state)
        engine.cinematicFinished("ch6_intro", in: &state)
        state.objectiveIndex = index
        XCTAssertTrue(chapter.objectives[index].conditions.isSatisfied(by: state), "sans photo, rien à expliquer")

        state.flags.insert("photo_baron")
        XCTAssertEqual(try engine.visit(.label, in: &state, using: &rng).id, "story_momo_photo")
        _ = try engine.resolve(choiceAt: 1, in: &state)
        XCTAssertTrue(state.flags.contains("momo_blesse"))
        XCTAssertFalse(state.flags.contains("photo_baron"))
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "stylo")
    }

    /// Fred banished in chapter 5: in the epilogue, the Bunker is for sale. Forgiven: the scene doesn't exist.
    func testFredsBunkerOnlyIfYouWalkedOut() throws {
        let engine = engine
        let chapter = try XCTUnwrap(engine.story.chapter(7))
        let index = try XCTUnwrap(chapter.objectives.firstIndex { $0.id == "bunker" })
        var state = engine.newGame(rapper: Rapper(name: "T", city: .toulouse, style: .melancolique))
        engine.debugJump(toChapter: 7, in: &state)
        engine.cinematicFinished("ch7_intro", in: &state)
        state.objectiveIndex = index
        XCTAssertTrue(chapter.objectives[index].conditions.isSatisfied(by: state))

        state.flags.insert("fred_banni")
        XCTAssertFalse(chapter.objectives[index].conditions.isSatisfied(by: state))
        XCTAssertEqual(try engine.visit(.studio, in: &state, using: &rng).id, "story_bunker_vendre")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertTrue(state.flags.contains("fred_retrouve"))
        XCTAssertFalse(state.flags.contains("fred_banni"))
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "lancement")
    }

    /// Who stands in your corner at the Dôme depends on what you did for them.
    func testTheCornerDependsOnWhoYouStoodBy() throws {
        let kitchen = try XCTUnwrap(engine.event(withId: "story_cuisine_maman"))
        var state = engine.newGame(rapper: Rapper(name: "T", city: .montreal, style: .drill))
        XCTAssertTrue(kitchen.choices[0].isAvailable(in: state), "ta mère, toujours")
        XCTAssertFalse(kitchen.choices[1].isAvailable(in: state))
        XCTAssertFalse(kitchen.choices[2].isAvailable(in: state))
        state.changeRelation("lil_sauge", by: 30)
        XCTAssertTrue(kitchen.choices[1].isAvailable(in: state))

        // Forgiving Fred brings him close enough; walking out pushes him away.
        let leak = try XCTUnwrap(engine.event(withId: "story_fuite"))
        var forgiven = engine.newGame(rapper: Rapper(name: "T", city: .montreal, style: .drill))
        forgiven.currentEventId = leak.id
        _ = try engine.resolve(choiceAt: 0, in: &forgiven)
        XCTAssertTrue(kitchen.choices[2].isAvailable(in: forgiven))
        var banished = engine.newGame(rapper: Rapper(name: "T", city: .montreal, style: .drill))
        banished.currentEventId = leak.id
        _ = try engine.resolve(choiceAt: 1, in: &banished)
        XCTAssertFalse(kitchen.choices[2].isAvailable(in: banished))
        XCTAssertTrue(banished.flags.contains("fred_banni"))
    }
}
