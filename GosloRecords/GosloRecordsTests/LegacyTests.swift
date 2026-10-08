import XCTest
@testable import GosloRecords

/// Achievements and the legacy bonuses they unlock for the next careers.
final class LegacyTests: XCTestCase {
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
    }

    private func record(_ city: City, _ style: Style, _ ending: Ending, gender: Gender = .rappeur) -> CareerRecord {
        var state = engine.newGame(rapper: Rapper(name: "R", city: city, style: style, gender: gender))
        state.ending = ending
        return CareerRecord(state: state)
    }

    func testEveryAchievementIsWritten() {
        for achievement in Achievement.allCases {
            XCTAssertFalse(achievement.title.isEmpty)
            XCTAssertFalse(achievement.detail.isEmpty)
        }
        XCTAssertEqual(Set(Heritage.allCases.map(\.unlockedBy)).count, Heritage.allCases.count, "un héritage par succès")
    }

    func testCareerAchievementsComeFromTheSave() {
        var state = engine.newGame(rapper: Rapper(name: "R", city: .lyon, style: .drill))
        XCTAssertTrue(AchievementRules.earned(in: state).isEmpty)
        state.flags = ["chapitre_1", "clash_gagne_kevlar_jr", AchievementRules.freestyleFlag]
        for district in District.allCases where district != .bloc {
            state.seenUniqueEvents.insert(GameEngine.arrivalEventId(district))
        }
        state.albums = [Album(id: 1, title: "A", tracks: [], cover: .neon, releasedTurn: 0, sales: [80_000, 40_000])]
        let earned = AchievementRules.earned(in: state)
        XCTAssertEqual(earned, [.premierChapitre, .ringDesMots, .rimeur, .touriste, .disqueOr, .disquePlatine])
    }

    func testFinishedCareersUnlockTheRest() {
        XCTAssertTrue(AchievementRules.earned(from: [record(.paris, .trap, .burnOut)]).isEmpty, "un abandon ne compte pas")
        let history = [record(.paris, .trap, .legende), record(.lille, .drill, .carriereHonnete, gender: .rappeuse),
                       record(.lyon, .boomBap, .patronDeLabel), record(.montreal, .melancolique, .rentier)]
        let earned = AchievementRules.earned(from: history)
        XCTAssertEqual(earned, [.carriereComplete, .legende, .patron, .deuxMicros, .tourDeFrance, .tousLesStyles])
        XCTAssertFalse(earned.contains(.toutesLesVilles))
    }

    func testHeritageGivesItsBonus() {
        let plain = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap))
        let rich = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap, heritage: .economies))
        XCTAssertEqual(rich.stats.argent, plain.stats.argent + 12)
        let known = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap, heritage: .repertoire))
        for id in Heritage.contacts { XCTAssertGreaterThan(known.relation(id), plain.relation(id)) }
        let writer = engine.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap, heritage: .carnet))
        XCTAssertEqual(writer.skills.xp(.plume), plain.skills.xp(.plume) + 90)
    }

    func testFlowHeritageStartsClashesHalfCharged() throws {
        let rival = CastMember(id: "rival", name: "Rival", role: "",
                               clash: ClashProfile(stats: [.punchline: 3, .flow: 3, .presence: 3, .story: 3]))
        let event = GameEvent(id: "defi", title: "", text: "", location: .studio, choices: [
            EventChoice(label: "Clash", clash: ClashSpec(opponent: "rival", win: ClashResultSpec(consequence: "w"),
                                                         lose: ClashResultSpec(consequence: "l")), consequence: "go"),
            EventChoice(label: "Non", consequence: "non"),
        ])
        let small = GameEngine(events: [event], cast: [rival])
        var rng = SeededGenerator(seed: 4)
        var state = small.newGame(rapper: Rapper(name: "R", city: .paris, style: .trap, heritage: .flow))
        _ = try small.visit(.studio, in: &state, using: &rng)
        _ = try small.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(state.clash?.playerMeter, ClashState.secretThreshold / 2)
    }

    func testProfileSurvivesAndOldRappersHaveNoHeritage() throws {
        var profile = TrophyCase()
        profile.achievements[.rimeur] = Date(timeIntervalSince1970: 0)
        let saved = try JSONDecoder().decode(TrophyCase.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(saved, profile)
        XCTAssertEqual(saved.heritages, [.flow])
        let future = try JSONDecoder().decode(TrophyCase.self, from: Data(#"{"achievements": {"rimeur": 0, "inconnu": 0}}"#.utf8))
        XCTAssertEqual(future.unlocked, [.rimeur], "un succès inconnu n'efface pas les autres")
        let old = try JSONDecoder().decode(Rapper.self, from: Data(#"{"name":"A","city":"Lyon","style":"Trap"}"#.utf8))
        XCTAssertNil(old.heritage)
    }
}
