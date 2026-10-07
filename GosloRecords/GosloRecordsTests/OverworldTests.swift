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

    func testParkedTaxiSitsOnTheRoadAndBlocksOnlyInCasablanca() throws {
        let map = try XCTUnwrap(EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)).map)
        for spot in OverworldRules.parkedTaxi {
            XCTAssertTrue(OverworldRules.canStep(to: spot, on: map), "le taxi se gare sur la route, pas sur un mur ou un perso")
            XCTAssertTrue(OverworldRules.blockedByScenery(spot, in: .casablanca))
            XCTAssertFalse(OverworldRules.blockedByScenery(spot, in: .paris))
            XCTAssertNil(map.door(at: spot))
        }
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

    func testCharactersOnlyTalkAgainOnceTheStoryMoves() throws {
        let chat = GameEvent(id: "papote", title: "", text: "", location: .quartier, npc: "ami",
                             choices: [EventChoice(label: "Ok", consequence: "ok")])
        let ami = CastMember(id: "ami", name: "Ami", role: "", idle: ["Un.", "Deux."])
        let engine = GameEngine(events: [chat], cast: [ami])
        var rng = SeededGenerator(seed: 3)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        state.pendingCinematic = nil
        state.actionsLeft = 5

        XCTAssertEqual(try engine.talk(to: "ami", in: &state, using: &rng)?.id, "papote")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertNil(try engine.talk(to: "ami", in: &state, using: &rng), "rien de neuf tant que l'histoire n'avance pas")
        XCTAssertEqual(state.actionsLeft, 4, "la petite discussion ne coûte pas d'action")
        XCTAssertEqual(engine.smallTalk(with: "ami", in: &state).first, "« Un. »")
        XCTAssertEqual(engine.smallTalk(with: "ami", in: &state).first, "« Deux. »", "les répliques se relaient")

        state.objectiveIndex += 1  // The story moves on.
        XCTAssertEqual(try engine.talk(to: "ami", in: &state, using: &rng)?.id, "papote")
    }

    func testAOneTimeSceneStillPlaysAfterAChat() throws {
        let chat = GameEvent(id: "papote", title: "", text: "", location: .quartier, npc: "ami", weight: 1000,
                             choices: [EventChoice(label: "Ok", consequence: "ok")])
        let scene = GameEvent(id: "scene", title: "", text: "", location: .quartier, npc: "ami", weight: 1, unique: true,
                              choices: [EventChoice(label: "Ok", consequence: "ok")])
        let engine = GameEngine(events: [chat, scene], cast: [CastMember(id: "ami", name: "Ami", role: "")])
        var rng = SeededGenerator(seed: 5)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        state.pendingCinematic = nil
        state.actionsLeft = 5

        state.talkedAt["ami"] = engine.progressKey(in: state)  // Already chatted since the story last moved.

        XCTAssertEqual(try engine.talk(to: "ami", in: &state, using: &rng)?.id, "scene", "la scène unique passe quand même")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertNil(try engine.talk(to: "ami", in: &state, using: &rng), "puis plus rien jusqu'à la suite de l'histoire")
    }

    func testEveryoneOnTheMapHasSmallTalk() throws {
        let world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        let npcs = District.allCases.compactMap { world.map(for: $0) }.flatMap(\.npcs)
        for npc in Set(npcs.map(\.id)) {
            let member = try XCTUnwrap(world.cast.first { $0.id == npc }, npc)
            XCTAssertGreaterThanOrEqual(member.idle.count, 3, "\(npc) : au moins trois répliques d'attente")
        }
    }

    func testNewLookOptionsAndOldSaves() throws {
        let old = try JSONDecoder().decode(CharacterLook.self, from: Data(##"{"skin": "#c68642", "hair_style": "puff"}"##.utf8))
        XCTAssertEqual(old.outfit, .hoodie, "une ancienne sauvegarde garde le sweat")
        XCTAssertFalse(old.earrings)
        let rapper = Rapper(name: "T", city: .lyon, style: .trap, hairStyle: .braids, hat: .bandana, outfit: .jersey, earrings: true)
        XCTAssertEqual(rapper.look.hairStyle, .braids)
        XCTAssertEqual(rapper.look.hat, .bandana)
        XCTAssertEqual(rapper.look.outfit, .jersey)
        XCTAssertTrue(rapper.look.earrings)
        let saved = try JSONDecoder().decode(Rapper.self, from: JSONEncoder().encode(rapper))
        XCTAssertEqual(saved.look, rapper.look)
    }

    func testNeverSeenEventsComeFirst() {
        let a = GameEvent(id: "a", title: "", text: "", choices: [])
        let b = GameEvent(id: "b", title: "", text: "", choices: [])
        var state = GameState(rapper: Rapper(name: "T", city: .lyon, style: .trap))
        state.seenEvents = ["a"]
        XCTAssertEqual(GameEngine.freshest([a, b], in: state).map(\.id), ["b"])
        state.seenEvents = ["a", "b"]
        state.recentEvents = ["b"]
        XCTAssertEqual(GameEngine.freshest([a, b], in: state).map(\.id), ["a"])
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
        let castIds = Set(world.cast.map(\.id))
        XCTAssertEqual(Set(world.districts.keys), Set(District.allCases).subtracting([.bloc]), "un plan par quartier")

        for district in District.allCases {
            let realMap = try XCTUnwrap(world.map(for: district), "\(district)")
            let name = district.rawValue
            XCTAssertTrue(realMap.unknownSymbols.isEmpty, "\(name) : symboles inconnus \(realMap.unknownSymbols)")
            XCTAssertEqual(Set(realMap.rows.map(\.count)).count, 1, "\(name) : toutes les lignes doivent avoir la même largeur")
            XCTAssertTrue(OverworldRules.canStep(to: realMap.spawn, on: realMap), "\(name) : le point de départ doit être praticable")

            // Every district has a metro, and you come out of it on your feet.
            let metro = try XCTUnwrap(realMap.metro, "\(name) : pas de métro")
            XCTAssertEqual(realMap.tile(at: metro), .metro, "\(name) : le métro n'est pas sur une bouche de métro")
            XCTAssertTrue(OverworldRules.canStep(to: realMap.arrival, on: realMap), "\(name) : sortie du métro bloquée")
            let reachable = OverworldRules.reachable(from: realMap.arrival, on: realMap)
            XCTAssertTrue(reachable.contains(metro), "\(name) : métro inaccessible")
            XCTAssertTrue(reachable.contains(realMap.spawn), "\(name) : point de départ coupé du métro")

            for door in realMap.doors {
                XCTAssertEqual(realMap.tile(at: door.point), .door, "\(name) : \(door.location) n'est pas sur une porte")
                XCTAssertTrue(reachable.contains(door.point), "\(name) : \(door.location) est inaccessible")
            }
            var seen = Set<TilePoint>()
            for npc in realMap.npcs {
                XCTAssertTrue(castIds.contains(npc.id), "\(name) : personnage inconnu sur la carte : \(npc.id)")
                XCTAssertTrue(realMap.tile(at: npc.point).isWalkable, "\(name) : \(npc.id) est dans un mur")
                XCTAssertTrue(seen.insert(npc.point).inserted, "\(name) : deux personnages sur la même case")
                XCTAssertNotEqual(npc.point, realMap.arrival, "\(name) : \(npc.id) bloque la sortie du métro")
                if npc.sight > 0 {
                    XCTAssertNotNil(world.cast.first { $0.id == npc.id }?.clash, "\(npc.id) guette mais ne peut pas clasher")
                    XCTAssertFalse(OverworldRules.lineOfSight(of: npc, on: realMap).contains(realMap.arrival),
                                   "\(name) : \(npc.id) te tombe dessus à la sortie du métro")
                }
            }
            let benchReachable = (0..<realMap.height).contains { y in
                (0..<realMap.width).contains { x in
                    realMap.tile(at: TilePoint(x: x, y: y)) == .bench
                        && Direction.allCases.contains { reachable.contains(TilePoint(x: x, y: y).moved($0)) }
                }
            }
            XCTAssertTrue(benchReachable, "\(name) : aucun banc accessible pour le quartier")
        }

        let bloc = try XCTUnwrap(world.map)
        XCTAssertTrue(OverworldRules.reachable(from: bloc.spawn, on: bloc).contains { bloc.tile(at: $0).isWildZone },
                      "le terrain vague est inaccessible")
        for location in [Location.studio, .label, .media, .chezToi] {
            XCTAssertNotNil(bloc.door(for: location), "pas de porte pour \(location) au Bloc")
        }
        XCTAssertFalse(world.districts(with: .scene, chapter: 3).isEmpty, "la scène ouvre avec le centre-ville")
        XCTAssertEqual(world.districts(with: .scene, chapter: 6).last, .dome, "le Dôme a sa scène")
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
