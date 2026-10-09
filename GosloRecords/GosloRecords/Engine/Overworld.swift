import Foundation

enum Direction: String, Codable, CaseIterable {
    case up
    case down
    case left
    case right

    var dx: Int {
        switch self {
        case .left: -1
        case .right: 1
        default: 0
        }
    }

    var dy: Int {
        switch self {
        case .up: -1
        case .down: 1
        default: 0
        }
    }

    var opposite: Direction {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }
}

struct TilePoint: Codable, Hashable {
    var x: Int
    var y: Int

    func moved(_ direction: Direction, by steps: Int = 1) -> TilePoint {
        TilePoint(x: x + direction.dx * steps, y: y + direction.dy * steps)
    }
}

/// Map tile types. The character is the symbol used in map.json.
enum TileKind: Character, CaseIterable {
    case asphalt = "."
    case sidewalk = "="
    case grass = "\""
    case crosswalk = "+"
    case wall = "#"
    case roof = "R"
    case door = "D"
    case tree = "T"
    case fence = "F"
    case bench = "B"
    case lamp = "L"
    case water = "W"
    /// Metro entrance: stepping on it opens the metro map.
    case metro = "M"

    var isWalkable: Bool {
        switch self {
        case .asphalt, .sidewalk, .grass, .crosswalk, .door, .metro: true
        default: false
        }
    }

    /// The "terrain vague": wild encounters happen here.
    var isWildZone: Bool { self == .grass }
}

/// Map door: entering it starts a visit to a location.
struct MapDoor: Codable, Equatable {
    let x: Int
    let y: Int
    let location: Location

    var point: TilePoint { TilePoint(x: x, y: y) }
}

/// Character placed on the map. sight > 0 = rival who challenges you on sight.
struct MapNPC: Codable, Equatable, Identifiable {
    let id: String
    let x: Int
    let y: Int
    let facing: Direction
    let sight: Int
    /// The character shows up on the map from this chapter on.
    let fromChapter: Int
    /// The character leaves the map once this flag is set (e.g. exiled to Miami).
    let hiddenIf: String?
    /// Artist level needed before the character shows up (1 = from the start): the cast grows with the career.
    let minLevel: Int

    var point: TilePoint { TilePoint(x: x, y: y) }

    enum CodingKeys: String, CodingKey {
        case id, x, y, facing, sight
        case fromChapter = "from_chapter"
        case hiddenIf = "hidden_if"
        case minLevel = "min_level"
    }

    init(id: String, x: Int, y: Int, facing: Direction = .down, sight: Int = 0, fromChapter: Int = 1,
         hiddenIf: String? = nil, minLevel: Int = 1) {
        self.minLevel = minLevel
        self.id = id
        self.x = x
        self.y = y
        self.facing = facing
        self.sight = sight
        self.fromChapter = fromChapter
        self.hiddenIf = hiddenIf
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        x = try c.decode(Int.self, forKey: .x)
        y = try c.decode(Int.self, forKey: .y)
        facing = try c.decodeIfPresent(Direction.self, forKey: .facing) ?? .down
        sight = try c.decodeIfPresent(Int.self, forKey: .sight) ?? 0
        fromChapter = try c.decodeIfPresent(Int.self, forKey: .fromChapter) ?? 1
        hiddenIf = try c.decodeIfPresent(String.self, forKey: .hiddenIf)
        minLevel = try c.decodeIfPresent(Int.self, forKey: .minLevel) ?? 1
    }
}

/// A free spot on the map where the player can put a decoration bought in the shop (`Decor`).
struct MapPlot: Codable, Equatable, Identifiable {
    let id: String
    let x: Int
    let y: Int

    var point: TilePoint { TilePoint(x: x, y: y) }
}

/// A piece of scenery painted over a rectangle of the map: the city stade, a car park, a rooftop terrace…
/// Only the look changes: which tiles you can walk on still comes from `rows` (the scenery dresses the
/// walkable tiles of its rectangle as floor, and its blocked tiles as props: cars, stalls, buses, railings).
struct MapScenery: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        /// A fenced football cage (city stade): synthetic pitch on the walkable tiles, the cage on the fence.
        case pitch
        /// A car park: bays painted on the asphalt, a car on each blocked tile (a coach on a run of three).
        case parking
        /// A rooftop terrace: roofing floor, a parapet on the fence, a water tank on a blocked tile.
        case terrace
        /// Concrete steps going up (walkable).
        case stairs
        /// A covered market: tiled floor under an iron frame, a stall on each blocked tile.
        case market
        /// Murals painted over a stretch of front walls.
        case murals
        /// A barge moored on the water.
        case barge
        /// A wooden lookout: planks on the walkable tiles, a railing on the fence.
        case belvedere
        /// The city's lights far below, painted over the blocked edge of the map.
        case panorama
        /// The arena's backstage: hazard lines, tour buses, flight cases, the loading dock and the dressing rooms.
        case backstage
        /// A footbridge over the water (walkable planks, a handrail on each side).
        case bridge
        /// Life on the rooftops: washing lines, satellite dishes, aerials, chimney pots, water tanks.
        case rooftops
        /// A row of ground-floor shops on a front wall: kebab neons, a laundromat, a hairdresser, a phone shop.
        case shopfronts
        /// A newspaper kiosk (a ticket booth at Le Dôme) on a blocked tile.
        case kiosk
        /// A bus shelter over a run of blocked tiles.
        case busStop = "bus_stop"
        /// Big planters on blocked tiles: box hedges, olive trees, potted palms.
        case planters
        /// A tagged hoarding over a fence, or throw-ups over a wall.
        case graffiti
        /// Scooters and bikes parked on blocked tiles.
        case scooters
        /// Open-air stalls on blocked tiles (a food truck on a run of two).
        case stalls
        /// A café terrace: tables and parasols on blocked tiles.
        case cafe
        /// The water's edge: limestone calanques, surf on the rocks, or a stone quay, depending on the city.
        case shore

        /// Props stand only on tiles that were already blocked (they never take a walkable tile).
        var isProp: Bool {
            switch self {
            case .barge, .panorama, .murals, .rooftops, .shopfronts, .kiosk, .busStop, .planters, .graffiti,
                 .scooters, .stalls, .cafe, .shore: true
            default: false
            }
        }
    }

    let kind: Kind
    let x: Int
    let y: Int
    let w: Int
    let h: Int

    func contains(_ point: TilePoint) -> Bool {
        (x..<(x + w)).contains(point.x) && (y..<(y + h)).contains(point.y)
    }
}

/// The neighbourhood (map.json).
struct WorldMap: Codable, Equatable {
    let rows: [String]
    let spawn: TilePoint
    let doors: [MapDoor]
    let npcs: [MapNPC]
    /// Metro entrance (a `TileKind.metro` tile), if the district has one.
    var metro: TilePoint? = nil
    /// Spots for the player's decorations (none in older data).
    var plots: [MapPlot]? = nil

    var decorPlots: [MapPlot] { plots ?? [] }
    /// Painted scenery (the look only, see `MapScenery`).
    var scenery: [MapScenery]? = nil

    /// Where you come out of the metro (just below the entrance), or the spawn point.
    var arrival: TilePoint { metro?.moved(.down) ?? spawn }

    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }

    /// Out-of-bounds tiles are trees (an impassable edge).
    func tile(at point: TilePoint) -> TileKind {
        guard rows.indices.contains(point.y) else { return .tree }
        let row = Array(rows[point.y])
        guard row.indices.contains(point.x) else { return .tree }
        return TileKind(rawValue: row[point.x]) ?? .tree
    }

    func door(at point: TilePoint) -> MapDoor? {
        doors.first { $0.point == point }
    }

    func door(for location: Location) -> MapDoor? {
        doors.first { $0.location == location }
    }

    func npc(at point: TilePoint) -> MapNPC? {
        npcs.first { $0.point == point }
    }

    /// The map as it is in a given chapter (characters not there yet are removed). `level` is the player's
    /// artist level: characters asking for more stay away (by default everyone who could be there is).
    func forChapter(_ chapter: Int, flags: Set<String> = [], level: Int = Int.max) -> WorldMap {
        WorldMap(rows: rows, spawn: spawn, doors: doors, npcs: npcs.filter { npc in
            npc.fromChapter <= chapter && npc.minLevel <= level && !(npc.hiddenIf.map(flags.contains) ?? false)
        }, metro: metro, plots: plots, scenery: scenery)
    }

    /// Symbols that aren't part of TileKind (used to validate the data).
    var unknownSymbols: Set<Character> {
        Set(rows.joined()).filter { TileKind(rawValue: $0) == nil }
    }
}

/// What the player finds in front of them when they interact.
enum Interaction: Equatable {
    case npc(MapNPC)
    case bench
    case nothing
}

/// Pure movement and detection rules for the overworld.
enum OverworldRules {
    static let wildCooldown = 3
    static let wildChancePercent = 12

    static func canStep(to point: TilePoint, on map: WorldMap) -> Bool {
        map.tile(at: point).isWalkable && map.npc(at: point) == nil
    }

    /// Casablanca: a petit taxi parked at the curb of the main road, waiting for a fare. Nobody walks through it.
    static let parkedTaxi = [TilePoint(x: 15, y: 7), TilePoint(x: 16, y: 7)]

    static func blockedByScenery(_ point: TilePoint, in city: City) -> Bool {
        city == .casablanca && parkedTaxi.contains(point)
    }

    static func interaction(from point: TilePoint, facing: Direction, on map: WorldMap) -> Interaction {
        let front = point.moved(facing)
        if let npc = map.npc(at: front) { return .npc(npc) }
        if map.tile(at: front) == .bench { return .bench }
        return .nothing
    }

    /// Tiles an NPC can see, until the first obstacle.
    static func lineOfSight(of npc: MapNPC, on map: WorldMap) -> [TilePoint] {
        var tiles: [TilePoint] = []
        var cursor = npc.point
        for _ in 0..<npc.sight {
            cursor = cursor.moved(npc.facing)
            guard map.tile(at: cursor).isWalkable, map.npc(at: cursor) == nil else { break }
            tiles.append(cursor)
        }
        return tiles
    }

    /// First rival who sees the player and is allowed to challenge.
    static func spotter(of player: TilePoint, on map: WorldMap, canChallenge: (String) -> Bool) -> MapNPC? {
        map.npcs.first { npc in
            npc.sight > 0 && lineOfSight(of: npc, on: map).contains(player) && canChallenge(npc.id)
        }
    }

    /// Path the rival walks to end up next to the player.
    static func approach(of npc: MapNPC, to player: TilePoint) -> [TilePoint] {
        var tiles: [TilePoint] = []
        var cursor = npc.point.moved(npc.facing)
        while cursor != player && tiles.count < npc.sight {
            tiles.append(cursor)
            cursor = cursor.moved(npc.facing)
        }
        return tiles
    }

    /// Wild encounter after a step on grass.
    static func rollWild<R: RandomNumberGenerator>(on tile: TileKind, stepsSinceLast: Int, using rng: inout R) -> Bool {
        tile.isWildZone && stepsSinceLast >= wildCooldown && Int.random(in: 0..<100, using: &rng) < wildChancePercent
    }

    /// Tiles reachable on foot from a starting point (used to validate the map).
    static func reachable(from start: TilePoint, on map: WorldMap) -> Set<TilePoint> {
        var seen: Set<TilePoint> = [start]
        var queue = [start]
        while let point = queue.popLast() {
            for direction in Direction.allCases {
                let next = point.moved(direction)
                if !seen.contains(next), canStep(to: next, on: map) {
                    seen.insert(next)
                    queue.append(next)
                }
            }
        }
        return seen
    }
}
