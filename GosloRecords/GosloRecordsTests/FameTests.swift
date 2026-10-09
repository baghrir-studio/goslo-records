import XCTest
@testable import GosloRecords

/// The career leaves marks: quotes, posters, guests at the big shows.
final class FameTests: XCTestCase {
    private var world = World(events: [])
    private var engine: GameEngine { GameEngine(world: world) }

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    private func newGame() -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .lille, style: .boomBap))
        state.pendingCinematic = nil
        return state
    }

    func testRivalsQuoteYourLinesButStrangersDont() {
        var state = newGame()
        state.hooks = ["essoré, mais jamais délavé"]
        let rival = ClashState(spec: ClashSpec(opponent: "scalpel", win: ClashResultSpec(consequence: ""),
                                               lose: ClashResultSpec(consequence: "")), isWild: false)
        XCTAssertTrue(engine.callbacks(for: rival, in: state).contains { $0.contains("jamais délavé") })
        let stranger = ClashState(spec: rival.spec, isWild: true)
        XCTAssertTrue(engine.callbacks(for: stranger, in: state).isEmpty)
    }

    func testFriendsTalkAboutYourLatestTrack() {
        var state = newGame()
        XCTAssertNil(engine.memoryLine(for: "yanis", in: state))
        state.hooks = ["un", "deux"]
        XCTAssertTrue(engine.memoryLine(for: "yanis", in: state)?.contains("« deux »") == true)
    }

    func testPostersFollowTheStreams() {
        var state = newGame()
        state.stats = Stats(streams: 10, credibilite: 30, argent: 30, mental: 60)
        XCTAssertEqual(engine.fame(in: state), 0)
        state.stats = Stats(streams: 80, credibilite: 30, argent: 30, mental: 60)
        XCTAssertEqual(engine.fame(in: state), 3)
        XCTAssertFalse(engine.hasFresco(in: state))
        state.flags.insert("clash_gagne_le_baron")
        XCTAssertTrue(engine.hasFresco(in: state))
    }

    // MARK: The neighbourhood grows with the artist level

    func testStreetBuzzGrowsWithTheLevel() {
        let rookie = StreetBuzz(level: 1, home: true)
        XCTAssertEqual([rookie.passersBy, rookie.posters, rookie.tags, rookie.fans], [0, 0, 0, 0])
        XCTAssertEqual(StreetBuzz(level: 2, home: true).posters, 0, "pas d'affiche avant le niveau 3")
        XCTAssertGreaterThan(StreetBuzz(level: 3, home: true).posters, 0)
        XCTAssertEqual(StreetBuzz(level: 4, home: true).tags, 0)
        XCTAssertGreaterThan(StreetBuzz(level: 5, home: true).tags, 0, "les tags à partir du niveau 5")
        XCTAssertEqual(StreetBuzz(level: 6, home: true).fans, 0)
        XCTAssertGreaterThan(StreetBuzz(level: 7, home: true).fans, 0, "les fans à partir du niveau 7")
        for level in 1..<ArtistLevel.maxLevel {
            let now = StreetBuzz(level: level, home: true), next = StreetBuzz(level: level + 1, home: true)
            XCTAssertGreaterThanOrEqual(next.passersBy, now.passersBy)
            XCTAssertGreaterThanOrEqual(next.posters, now.posters)
            XCTAssertGreaterThanOrEqual(next.tags, now.tags)
            XCTAssertGreaterThanOrEqual(next.fans, now.fans)
            let away = StreetBuzz(level: level, home: false)
            XCTAssertLessThanOrEqual(away.passersBy, now.passersBy, "plus de monde chez toi")
            XCTAssertEqual(away.fans, 0, "les fans t'attendent au quartier")
        }
        XCTAssertLessThanOrEqual(StreetBuzz(level: 10, streamPosters: 99, home: true).posters, StreetBuzz.maxPosters)
        XCTAssertEqual(StreetBuzz(level: 1, streamPosters: 6, home: true).posters, 6, "les streams collent déjà des affiches")
    }

    func testStreetBuzzUsesTheArtistLevelAndDistrict() {
        var state = newGame()
        state.artistXP = ArtistLevel.thresholds[6]
        XCTAssertEqual(engine.streetBuzz(in: state).level, 7)
        XCTAssertGreaterThan(engine.streetBuzz(in: state).fans, 0)
        state.district = .centre
        XCTAssertEqual(engine.streetBuzz(in: state).fans, 0)
    }

    func testTagText() {
        XCTAssertEqual(StreetBuzz.tagText(for: "Zoé l'Éclair"), "ZOE LECLA")
        XCTAssertEqual(StreetBuzz.tagText(for: "mc  42"), "MC 42")
        XCTAssertEqual(StreetBuzz.tagText(for: "★★"), "GOSLO")
    }

    func testAmbientSpotsNeverSitOnAnObstacleOrSomeone() throws {
        for district in District.allCases {
            let map = try XCTUnwrap(world.map(for: district))
            let walls = map.fameWalls
            XCTAssertFalse(walls.isEmpty, "\(district) : des murs pour les affiches")
            let tags = map.tagWalls(posters: StreetBuzz.maxPosters, count: 6)
            XCTAssertTrue(Set(tags).isDisjoint(with: walls.prefix(StreetBuzz.maxPosters)), "\(district) : tag sur une affiche")
            XCTAssertTrue(tags.allSatisfy { map.tile(at: $0) == .wall })
            for stroll in map.strolls(count: 6) {
                XCTAssertGreaterThanOrEqual(stroll.to - stroll.from, 3)
                for x in stroll.from...stroll.to {
                    let point = TilePoint(x: x, y: stroll.y)
                    XCTAssertEqual(map.tile(at: point), .sidewalk, "\(district) : passant hors du trottoir")
                    XCTAssertNil(map.npc(at: point))
                }
            }
        }
        let bloc = try XCTUnwrap(world.map(for: .bloc))
        XCTAssertEqual(bloc.strolls(count: 6).count, 6)
        let fans = bloc.fanSpots(count: 6)
        XCTAssertEqual(fans.count, 6, "assez de place près du point de départ")
        for spot in fans {
            XCTAssertTrue(map(bloc, walkableAt: spot))
            XCTAssertNotEqual(spot, bloc.spawn)
            XCTAssertNotEqual(spot, bloc.arrival)
            XCTAssertNil(bloc.door(at: spot.moved(.up)), "pas devant une porte")
            XCTAssertLessThanOrEqual(abs(spot.x - bloc.spawn.x) + abs(spot.y - bloc.spawn.y), 6)
        }
    }

    private func map(_ map: WorldMap, walkableAt point: TilePoint) -> Bool {
        map.tile(at: point).isWalkable && map.npc(at: point) == nil
    }

    func testEveryoneYouMetComesToTheDome() {
        var state = newGame()
        state.metCast = ["momo", "fred", "scalpel", "kolosse"]
        let guests = engine.concertGuests("le_dome", in: state).map(\.id)
        XCTAssertTrue(Set(["momo", "fred", "scalpel", "kolosse"]).isSubset(of: Set(guests)))
        XCTAssertTrue(guests.contains("maman"), "ta mère est toujours là")
        XCTAssertLessThanOrEqual(guests.count, 10)
    }
}
