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

    var isWalkable: Bool {
        switch self {
        case .asphalt, .sidewalk, .grass, .crosswalk, .door: true
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

    var point: TilePoint { TilePoint(x: x, y: y) }

    enum CodingKeys: String, CodingKey {
        case id, x, y, facing, sight
        case fromChapter = "from_chapter"
        case hiddenIf = "hidden_if"
    }

    init(id: String, x: Int, y: Int, facing: Direction = .down, sight: Int = 0, fromChapter: Int = 1,
         hiddenIf: String? = nil) {
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
    }
}

/// The neighbourhood (map.json).
struct WorldMap: Codable, Equatable {
    let rows: [String]
    let spawn: TilePoint
    let doors: [MapDoor]
    let npcs: [MapNPC]

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

    /// The map as it is in a given chapter (characters not there yet are removed).
    func forChapter(_ chapter: Int, flags: Set<String> = []) -> WorldMap {
        WorldMap(rows: rows, spawn: spawn, doors: doors, npcs: npcs.filter { npc in
            npc.fromChapter <= chapter && !(npc.hiddenIf.map(flags.contains) ?? false)
        })
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
