import XCTest
@testable import GosloRecords

/// The neighbours who join the cast along the career (kiosk, rooftop beatmaker, retired DJ, graffiti artist…):
/// each one stands somewhere you can reach, talks enough, has a tier and their own small quest.
final class NeighboursTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])

    static let neighbours = ["mounir_kiosque", "petit_sami", "mamie_yvette", "ptit_sauge", "papy_groove",
                             "rachid_halles", "zoe_bombe", "ines_gazette", "jojo_taxi", "sylvie_vigile"]

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func placements() -> [(District, WorldMap, MapNPC)] {
        District.allCases.flatMap { district -> [(District, WorldMap, MapNPC)] in
            guard let map = world.map(for: district) else { return [] }
            return map.npcs.map { (district, map, $0) }
        }
    }

    func testEveryNeighbourIsCastOnceAndOnTheMapOnce() throws {
        let ids = world.cast.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "ids en double")
        for id in Self.neighbours {
            let member = try XCTUnwrap(world.cast.first { $0.id == id }, id)
            XCTAssertFalse(member.role.isEmpty, id)
            XCTAssertFalse(member.bio.isEmpty, id)
            XCTAssertGreaterThanOrEqual(member.idle.count, 6, "\(id) : au moins six répliques")
            XCTAssertEqual(Set(member.idle).count, member.idle.count, "\(id) : répliques en double")
            XCTAssertFalse(member.moments.isEmpty, "\(id) : au moins une réplique liée à l'histoire")
            XCTAssertFalse(member.wild, id)
            XCTAssertEqual(placements().filter { $0.2.id == id }.count, 1, "\(id) doit être placé une fois")
        }
        // Each looks like nobody else.
        let looks = Self.neighbours.compactMap { id in world.cast.first { $0.id == id }?.look }
        XCTAssertEqual(Set(looks).count, looks.count, "deux voisins habillés pareil")
    }

    func testNeighboursStandOnWalkableReachableTiles() throws {
        for (district, map, npc) in placements() where Self.neighbours.contains(npc.id) {
            XCTAssertTrue(map.tile(at: npc.point).isWalkable, "\(npc.id) est dans un mur")
            XCTAssertNil(map.door(at: npc.point), "\(npc.id) bloque une porte")
            XCTAssertFalse(map.decorPlots.contains { $0.point == npc.point }, "\(npc.id) est sur un emplacement")
            XCTAssertGreaterThanOrEqual(npc.fromChapter, district.fromChapter, "\(npc.id) arrive avant son quartier")
            // Everyone on the map at once (worst case): every door, character and the metro stays reachable.
            let full = map.forChapter(10)
            XCTAssertTrue(engine.keepsEverythingReachable(on: full, blocked: [], from: full.arrival),
                          "\(district) : quelqu'un n'est plus joignable")
            let reachable = OverworldRules.reachable(from: full.arrival, on: full)
            XCTAssertTrue(Direction.allCases.contains { reachable.contains(npc.point.moved($0)) }, "\(npc.id) injoignable")
        }
    }

    func testTheCastGrowsWithTheCareer() throws {
        let tiers = placements().filter { Self.neighbours.contains($0.2.id) }
        XCTAssertTrue(tiers.allSatisfy { (1...ArtistLevel.maxLevel).contains($0.2.minLevel) }, "niveau d'artiste invalide")
        XCTAssertTrue(tiers.allSatisfy { (1...6).contains($0.2.fromChapter) }, "chapitre invalide")
        XCTAssertGreaterThanOrEqual(Set(tiers.map(\.2.fromChapter)).count, 4, "les voisins arrivent par vagues")
        XCTAssertTrue(tiers.contains { $0.2.minLevel > 1 }, "certains attendent que tu sois connu")

        // Zoé only shows up once the player is a name that circulates.
        let centre = try XCTUnwrap(world.map(for: .centre))
        XCTAssertFalse(centre.forChapter(3, level: 2).npcs.contains { $0.id == "zoe_bombe" })
        XCTAssertTrue(centre.forChapter(3, level: 3).npcs.contains { $0.id == "zoe_bombe" })
        var state = engine.newGame(rapper: Rapper(name: "T", city: .marseille, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 4
        try engine.travel(to: .hauts, in: &state)
        XCTAssertFalse(engine.currentMap(in: state)?.npcs.contains { $0.id == "jojo_taxi" } ?? true, "Jojo attend le niveau 4")
        state.artistXP = ArtistLevel.thresholds[3]
        XCTAssertTrue(engine.currentMap(in: state)?.npcs.contains { $0.id == "jojo_taxi" } ?? false)
    }

    func testEachNeighbourHasScenesAndAPersonalQuest() throws {
        let questFlags = Set(world.quests.flatMap { quest in
            quest.conditions.requiredFlags + quest.steps.flatMap(\.conditions.requiredFlags)
        })
        for id in Self.neighbours {
            let scenes = world.events.filter { $0.npc == id }
            XCTAssertFalse(scenes.isEmpty, "\(id) n'a aucune scène")
            let sets = Set(scenes.flatMap { $0.choices.flatMap(\.setFlags) })
                .union(scenes.flatMap { $0.choices.compactMap(\.clash).map { "clash_gagne_\($0.opponent)" } })
            XCTAssertFalse(sets.isDisjoint(with: questFlags), "\(id) ne fait avancer aucune quête")
            for scene in scenes {
                // Small rewards only: no single choice gives more than 5 points of stats or 25 XP.
                for choice in scene.choices {
                    XCTAssertLessThanOrEqual(choice.effects.values.filter { $0 > 0 }.reduce(0, +), 5, "\(scene.id) : trop généreux")
                    XCTAssertLessThanOrEqual(choice.xp.values.reduce(0, +), 25, "\(scene.id) : trop d'XP")
                }
                // Repeatable scenes can't hand out stats or XP again and again.
                if !scene.unique {
                    XCTAssertFalse(scene.conditions.excludedFlags.isEmpty, "\(scene.id) se répète sans fin")
                    XCTAssertTrue(scene.choices.allSatisfy { $0.xp.isEmpty && $0.effects.values.allSatisfy { $0 <= 0 } },
                                  "\(scene.id) : une scène répétable ne paie qu'au clash")
                }
            }
        }
        let personal = ["journal_yvette", "prod_sami", "bal_yvette", "freres_sauge", "face_b_papy", "jingle_rachid",
                        "fresque_zoe", "exclu_gazette", "dedicace_jojo", "gamin_dome"]
        for id in personal {
            let quest = try XCTUnwrap(world.quests.first { $0.id == id }, id)
            XCTAssertLessThanOrEqual(quest.reward.effects.values.reduce(0, +), 10, "\(quest.id) : récompense trop grosse")
        }
    }

    func testComeBackAtLevelX() throws {
        let quest = try XCTUnwrap(world.quests.first { $0.id == "dedicace_jojo" })
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .trap))
        state.pendingCinematic = nil
        state.flags.insert("jojo_dedicace_promise")
        XCTAssertTrue(engine.isQuestActive(quest, in: state))
        var outcome = TurnOutcome(consequence: "")
        engine.applyQuestProgress(&outcome, in: &state)
        XCTAssertFalse(state.completedQuests.contains(quest.id), "pas avant le niveau 5")
        state.artistXP = ArtistLevel.thresholds[4]
        engine.applyQuestProgress(&outcome, in: &state)
        XCTAssertTrue(state.completedQuests.contains(quest.id))
        // Paid once.
        let paid = state.stats
        engine.applyQuestProgress(&outcome, in: &state)
        XCTAssertEqual(state.stats, paid)

        let old = try JSONDecoder().decode(EventConditions.self, from: Data("{}".utf8))
        XCTAssertNil(old.minArtistLevel)
        let npc = try JSONDecoder().decode(MapNPC.self, from: Data(#"{"id": "x", "x": 1, "y": 1}"#.utf8))
        XCTAssertEqual(npc.minLevel, 1)
    }
}
