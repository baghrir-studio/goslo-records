import XCTest
@testable import GosloRecords

/// Overworld rules on a small hand-written map, and validation of the real map.json.
final class OverworldTests: XCTestCase {
    //   0123456
    // 0 TTTTTTT
    // 1 T=.D""T
    // 2 T=#=""T
    // 3 T=B==.T
    // 4 TTTTTTT
    private let map = WorldMap(
        rows: ["TTTTTTT", "T=.D\"\"T", "T=#=\"\"T", "T=B==.T", "TTTTTTT"],
        spawn: TilePoint(x: 1, y: 1),
        doors: [MapDoor(x: 3, y: 1, location: .studio)],
        npcs: [MapNPC(id: "rival", x: 5, y: 3, facing: .left, sight: 3)]
    )

    func testWalkability() {
        XCTAssertTrue(OverworldRules.canStep(to: TilePoint(x: 2, y: 1), on: map))   // asphalt
        XCTAssertTrue(OverworldRules.canStep(to: TilePoint(x: 3, y: 1), on: map))   // door
        XCTAssertFalse(OverworldRules.canStep(to: TilePoint(x: 2, y: 2), on: map))  // wall
        XCTAssertFalse(OverworldRules.canStep(to: TilePoint(x: 2, y: 3), on: map))  // bench
        XCTAssertFalse(OverworldRules.canStep(to: TilePoint(x: 5, y: 3), on: map))  // character
        XCTAssertFalse(OverworldRules.canStep(to: TilePoint(x: -1, y: 0), on: map)) // off the map
    }

    func testInteractionInFront() {
        XCTAssertEqual(OverworldRules.interaction(from: TilePoint(x: 1, y: 2), facing: .down, on: map), .nothing)
        XCTAssertEqual(OverworldRules.interaction(from: TilePoint(x: 2, y: 2), facing: .down, on: map), .bench)
        XCTAssertEqual(OverworldRules.interaction(from: TilePoint(x: 4, y: 3), facing: .right, on: map),
                       .npc(map.npcs[0]))
    }

    func testLineOfSightStopsAtObstacles() {
        let sight = OverworldRules.lineOfSight(of: map.npcs[0], on: map)
        // Looks left: (4,3), (3,3), then the bench at (2,3) blocks.
        XCTAssertEqual(sight, [TilePoint(x: 4, y: 3), TilePoint(x: 3, y: 3)])
    }

    func testSpotterRespectsChallengeRule() {
        let player = TilePoint(x: 3, y: 3)
        XCTAssertEqual(OverworldRules.spotter(of: player, on: map, canChallenge: { _ in true })?.id, "rival")
        XCTAssertNil(OverworldRules.spotter(of: player, on: map, canChallenge: { _ in false }))
        XCTAssertNil(OverworldRules.spotter(of: TilePoint(x: 1, y: 3), on: map, canChallenge: { _ in true }))
    }

    func testApproachStopsNextToPlayer() {
        XCTAssertEqual(OverworldRules.approach(of: map.npcs[0], to: TilePoint(x: 3, y: 3)), [TilePoint(x: 4, y: 3)])
    }

    func testWildRollOnlyOnGrassAfterCooldown() {
        var rng = SeededGenerator(seed: 4)
        let attempts = 2_000
        var hits = 0
        for _ in 0..<attempts where OverworldRules.rollWild(on: .grass, stepsSinceLast: 10, using: &rng) { hits += 1 }
        XCTAssertEqual(Double(hits) / Double(attempts), Double(OverworldRules.wildChancePercent) / 100, accuracy: 0.03)
        for _ in 0..<200 {
            XCTAssertFalse(OverworldRules.rollWild(on: .sidewalk, stepsSinceLast: 10, using: &rng))
            XCTAssertFalse(OverworldRules.rollWild(on: .grass, stepsSinceLast: 0, using: &rng))
        }
    }

    func testReachable() {
        let reachable = OverworldRules.reachable(from: map.spawn, on: map)
        XCTAssertTrue(reachable.contains(TilePoint(x: 3, y: 1)))
        XCTAssertFalse(reachable.contains(TilePoint(x: 2, y: 2)))
    }

    // MARK: Engine: characters and wild clashes

    private let rival = CastMember(id: "rival", name: "Rival", role: "",
                                   clash: ClashProfile(stats: [.punchline: 1, .flow: 1, .presence: 1, .story: 1]))
    private let wildOne = CastMember(id: "sauvage", name: "Sauvage", role: "",
                                     clash: ClashProfile(stats: [.punchline: 1, .flow: 1, .presence: 1, .story: 1]), wild: true)

    private func challengeEvent() -> GameEvent {
        GameEvent(id: "defi", title: "Défi", text: "", location: .quartier, npc: "rival", choices: [
            EventChoice(label: "Clash", clash: ClashSpec(opponent: "rival",
                                                         win: ClashResultSpec(consequence: "w"),
                                                         lose: ClashResultSpec(consequence: "l")),
                        consequence: "go"),
            EventChoice(label: "Non", consequence: "non"),
        ])
    }

    func testTalkSpendsAnActionOnlyWhenThereIsSomethingToSay() throws {
        let engine = GameEngine(events: [challengeEvent()], cast: [rival, wildOne])
        var rng = SeededGenerator(seed: 2)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))

        XCTAssertNil(try engine.talk(to: "inconnu", in: &state, using: &rng))
        XCTAssertEqual(state.actionsLeft, GameState.actionsPerTurn)

        XCTAssertTrue(engine.canChallenge("rival", in: state))
        let event = try XCTUnwrap(engine.talk(to: "rival", challenge: true, in: &state, using: &rng))
        XCTAssertEqual(event.id, "defi")
        XCTAssertEqual(state.actionsLeft, GameState.actionsPerTurn - 1)
        XCTAssertTrue(state.metCast.contains("rival"))
        XCTAssertTrue(state.challengedThisSemester.contains("rival"))

        _ = try engine.resolve(choiceAt: 1, in: &state)
        XCTAssertFalse(engine.canChallenge("rival", in: state), "pas deux défis du même rival par semestre")
    }

    func testWildClashCostsNoActionAndGrantsXP() throws {
        let engine = GameEngine(events: [], cast: [rival, wildOne])
        var rng = SeededGenerator(seed: 8)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        state.skills.gain([.flow: 600])
        let flowBefore = state.skills.xp(.flow)

        let clash = try XCTUnwrap(engine.startWildClash(in: &state, using: &rng))
        XCTAssertTrue(clash.isWild)
        XCTAssertEqual(clash.opponentId, "sauvage")
        XCTAssertNil(engine.startWildClash(in: &state, using: &rng), "un seul clash à la fois")

        while try !engine.clashMove(.flow, in: &state, using: &rng).isOver {}
        let outcome = try engine.finishClash(in: &state)

        XCTAssertEqual(state.actionsLeft, GameState.actionsPerTurn)
        XCTAssertEqual(state.turn, 0)
        XCTAssertEqual(state.counters[.beefs], 0)
        XCTAssertGreaterThan(state.skills.xp(.flow), flowBefore)
        XCTAssertNotNil(outcome.clash)
        XCTAssertNil(state.clash)
    }

    func testFleeingOnlyWorksInTheWild() throws {
        let engine = GameEngine(events: [challengeEvent()], cast: [rival, wildOne])
        var rng = SeededGenerator(seed: 3)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        _ = try engine.talk(to: "rival", challenge: true, in: &state, using: &rng)
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertNotNil(state.clash)
        XCTAssertFalse(engine.fleeWildClash(in: &state))

        var wildState = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        _ = engine.startWildClash(in: &wildState, using: &rng)
        XCTAssertTrue(engine.fleeWildClash(in: &wildState))
        XCTAssertNil(wildState.clash)
    }

    func testWildOpponentsGetStrongerOverTime() {
        let profile = ClashProfile(stats: [.punchline: 9, .flow: 2, .presence: 2, .story: 2])
        let scaled = profile.scaled(by: 3)
        XCTAssertEqual(scaled.stat(.punchline), 10)
        XCTAssertEqual(scaled.stat(.flow), 5)
        XCTAssertGreaterThan(scaled.level, profile.level)
    }

    // MARK: Real map.json

    func testRealMapIsValid() throws {
        let world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        let realMap = try XCTUnwrap(world.map)
        let castIds = Set(world.cast.map(\.id))

        XCTAssertTrue(realMap.unknownSymbols.isEmpty, "symboles inconnus : \(realMap.unknownSymbols)")
        XCTAssertEqual(Set(realMap.rows.map(\.count)).count, 1, "toutes les lignes doivent avoir la même largeur")
        XCTAssertTrue(OverworldRules.canStep(to: realMap.spawn, on: realMap), "le point de départ doit être praticable")

        let reachable = OverworldRules.reachable(from: realMap.spawn, on: realMap)
        for door in realMap.doors {
            XCTAssertEqual(realMap.tile(at: door.point), .door, "\(door.location) n'est pas sur une porte")
            XCTAssertTrue(reachable.contains(door.point), "\(door.location) est inaccessible")
        }
        for location in [Location.studio, .label, .media, .scene, .chezToi] {
            XCTAssertNotNil(realMap.door(for: location), "pas de porte pour \(location)")
        }
        var seen = Set<TilePoint>()
        for npc in realMap.npcs {
            XCTAssertTrue(castIds.contains(npc.id), "personnage inconnu sur la carte : \(npc.id)")
            XCTAssertTrue(realMap.tile(at: npc.point).isWalkable, "\(npc.id) est dans un mur")
            XCTAssertTrue(seen.insert(npc.point).inserted, "deux personnages sur la même case")
            if npc.sight > 0 {
                XCTAssertNotNil(world.cast.first { $0.id == npc.id }?.clash, "\(npc.id) guette mais ne peut pas clasher")
            }
        }
        let benchReachable = Direction.allCases.contains { direction in
            (0..<realMap.height).contains { y in
                (0..<realMap.width).contains { x in
                    realMap.tile(at: TilePoint(x: x, y: y)) == .bench
                        && reachable.contains(TilePoint(x: x, y: y).moved(direction))
                }
            }
        }
        XCTAssertTrue(benchReachable, "aucun banc accessible pour le quartier")
        XCTAssertTrue(reachable.contains { realMap.tile(at: $0).isWildZone }, "le terrain vague est inaccessible")
    }

    func testCastLooksAreValid() throws {
        let world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        for member in world.cast {
            for color in member.look.colors {
                XCTAssertTrue(CharacterLook.isValidHex(color), "\(member.id) : couleur invalide \(color)")
            }
        }
        XCTAssertFalse(world.cast.filter(\.wild).isEmpty, "aucun adversaire sauvage")
        for wild in world.cast where wild.wild {
            XCTAssertNotNil(wild.clash, "\(wild.id) est sauvage mais n'a pas de profil de clash")
        }
    }
}
