import XCTest
@testable import GosloRecords

/// The districts' new heights, the free spots for decorations (`MapPlot`) and the painted scenery (`MapScenery`).
final class MapPlotsTests: XCTestCase {
    private var world: World!

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    private func maps() throws -> [(District, WorldMap)] {
        try District.allCases.map { ($0, try XCTUnwrap(world.map(for: $0), "\($0)")) }
    }

    private func tiles(of map: WorldMap) -> [TilePoint] {
        (0..<map.height).flatMap { y in (0..<map.width).map { TilePoint(x: $0, y: y) } }
    }

    func testDistrictsAreTall() throws {
        for (district, map) in try maps() {
            XCTAssertTrue((34...40).contains(map.height), "\(district) : \(map.height) lignes")
            XCTAssertGreaterThan(map.height, map.width, "\(district) : la carte doit être plus haute que large")
        }
    }

    func testPlotsAreFreeWalkableSpots() throws {
        var ids = Set<String>()
        for (district, map) in try maps() {
            let name = district.rawValue
            XCTAssertTrue((4...6).contains(map.decorPlots.count), "\(name) : \(map.decorPlots.count) emplacements")
            var points = Set<TilePoint>()
            for plot in map.decorPlots {
                XCTAssertTrue(ids.insert(plot.id).inserted, "emplacement en double : \(plot.id)")
                XCTAssertTrue(plot.id.hasPrefix(name + "_"), "\(plot.id) doit commencer par \(name)_")
                XCTAssertTrue(points.insert(plot.point).inserted, "\(plot.id) : deux emplacements sur la même case")
                XCTAssertTrue([.sidewalk, .asphalt].contains(map.tile(at: plot.point)),
                              "\(plot.id) doit être sur un trottoir ou du bitume, pas sur \(map.tile(at: plot.point))")
                XCTAssertNil(map.door(at: plot.point), "\(plot.id) est sur une porte")
                XCTAssertNotEqual(plot.point, map.metro, "\(plot.id) est sur le métro")
                XCTAssertNotEqual(plot.point, map.arrival, "\(plot.id) bloque la sortie du métro")
                XCTAssertNotEqual(plot.point, map.spawn, "\(plot.id) est sur le point de départ")
                XCTAssertFalse(map.npcs.contains { $0.point == plot.point }, "\(plot.id) est sous un personnage")
                for city in City.allCases {
                    XCTAssertFalse(district == .bloc && OverworldRules.blockedByScenery(plot.point, in: city),
                                   "\(plot.id) est sous le taxi garé")
                }
                // A door right above would get a truck parked in front of it.
                XCTAssertNil(map.door(at: plot.point.moved(.up)), "\(plot.id) bloque l'entrée d'un lieu")
            }
        }
    }

    /// Every walkable tile can be reached on foot (characters aside), and with the characters standing where they
    /// stand in every chapter, every door, every character, every bench and every free spot stays reachable.
    func testMapsStayConnected() throws {
        let allFlags = Set(try maps().flatMap { $0.1.npcs.compactMap(\.hiddenIf) })
        for (district, full) in try maps() {
            let name = district.rawValue
            let empty = WorldMap(rows: full.rows, spawn: full.spawn, doors: full.doors, npcs: [], metro: full.metro)
            let open = OverworldRules.reachable(from: full.spawn, on: empty)
            for point in tiles(of: full) where full.tile(at: point).isWalkable {
                XCTAssertTrue(open.contains(point), "\(name) : la case \(point) est coupée du reste du quartier")
            }
            for chapter in district.fromChapter...10 {
                for flags in [Set<String>(), allFlags] {
                    let map = full.forChapter(chapter, flags: flags)
                    let reachable = OverworldRules.reachable(from: map.arrival, on: map)
                    func near(_ point: TilePoint) -> Bool {
                        Direction.allCases.contains { reachable.contains(point.moved($0)) }
                    }
                    let context = "\(name), chapitre \(chapter)\(flags.isEmpty ? "" : " (drapeaux)")"
                    XCTAssertTrue(reachable.contains(map.spawn), "\(context) : départ inaccessible")
                    for door in map.doors {
                        XCTAssertTrue(reachable.contains(door.point), "\(context) : \(door.location) inaccessible")
                    }
                    for npc in map.npcs {
                        XCTAssertTrue(near(npc.point), "\(context) : impossible de parler à \(npc.id)")
                    }
                    for plot in map.decorPlots {
                        XCTAssertTrue(reachable.contains(plot.point), "\(context) : \(plot.id) inaccessible")
                    }
                    for point in tiles(of: map) where map.tile(at: point) == .bench {
                        XCTAssertTrue(near(point), "\(context) : banc \(point) inaccessible")
                    }
                }
            }
        }
    }

    func testSceneryFitsTheMap() throws {
        for (district, map) in try maps() {
            for scenery in map.scenery ?? [] {
                XCTAssertGreaterThan(scenery.w, 0)
                XCTAssertGreaterThan(scenery.h, 0)
                XCTAssertTrue(scenery.x >= 0 && scenery.y >= 0 && scenery.x + scenery.w <= map.width
                              && scenery.y + scenery.h <= map.height, "\(district) : \(scenery.kind) déborde de la carte")
                let inside = tiles(of: map).filter(scenery.contains)
                switch scenery.kind {
                case _ where scenery.kind.isProp:
                    XCTAssertFalse(inside.contains { map.tile(at: $0).isWalkable }, "\(district) : \(scenery.kind) sur une case praticable")
                case .stairs:
                    XCTAssertTrue(inside.allSatisfy { map.tile(at: $0).isWalkable }, "\(district) : escalier bloqué")
                default:
                    XCTAssertTrue(inside.contains { map.tile(at: $0).isWalkable }, "\(district) : \(scenery.kind) inaccessible")
                }
                XCTAssertFalse(inside.contains { map.door(at: $0) != nil || $0 == map.metro },
                               "\(district) : \(scenery.kind) recouvre une porte ou le métro")
            }
        }
    }

    func testOldSavesStillDecode() throws {
        // A map without plots or scenery (older data) still loads.
        let json = #"{"rows": ["TTT", "T=T", "TTT"], "spawn": {"x": 1, "y": 1}, "doors": [], "npcs": []}"#
        let map = try JSONDecoder().decode(WorldMap.self, from: Data(json.utf8))
        XCTAssertTrue(map.decorPlots.isEmpty)
        XCTAssertNil(map.scenery)
    }
}
