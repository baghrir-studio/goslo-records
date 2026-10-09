import Foundation

/// Decorations the player buys in the shop and puts on the map's free spots (`MapPlot`), for the whole career.
/// Each one shows on the map, and gives a small bonus every turn while it stands.
enum Decor: String, Codable, CaseIterable, Identifiable {
    case fresque, sono, bancDore = "banc_dore", palmier, borneArcade = "borne_arcade", foodTruck = "food_truck",
         statueMicro = "statue_micro", neonGoslo = "neon_goslo"
    // Buildings: expensive, they take room (2 tiles wide) and pay every turn.
    case panneauGeant = "panneau_geant", studioPerso = "studio_perso", scenePleinAir = "scene_plein_air",
         boutiqueMerch = "boutique_merch"

    /// The big ones: they block the way (placed only where every door and character stays reachable).
    var isBuilding: Bool { [.panneauGeant, .studioPerso, .scenePleinAir, .boutiqueMerch].contains(self) }

    /// Tiles taken (width, height), from the anchor tile to the right and up.
    var footprint: (width: Int, height: Int) {
        switch self {
        case .foodTruck, .panneauGeant: (2, 1)
        case .studioPerso, .scenePleinAir, .boutiqueMerch: (2, 2)
        default: (1, 1)
        }
    }

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fresque: "Fresque à ton nom"
        case .sono: "Sono de quartier"
        case .bancDore: "Banc doré"
        case .palmier: "Palmier en pot"
        case .borneArcade: "Borne d'arcade"
        case .foodTruck: "Food truck"
        case .statueMicro: "Statue du micro d'or"
        case .neonGoslo: "Néon goslo radio"
        case .panneauGeant: "Panneau géant à ta gloire"
        case .studioPerso: "Ton studio perso"
        case .scenePleinAir: "Scène en plein air"
        case .boutiqueMerch: "Boutique de merch"
        }
    }

    var pitch: String {
        switch self {
        case .fresque: "Ton visage sur un mur. Le quartier te respecte un peu plus."
        case .sono: "Ton son tourne en boucle dans la rue."
        case .bancDore: "Le banc des légendes. Les anciens s'y assoient pour parler de toi."
        case .palmier: "Un bout de vacances au pied des tours. Ça calme."
        case .borneArcade: "Les petits du quartier y jouent toute la journée."
        case .foodTruck: "Ton food truck : sandwichs, frites et un petit billet."
        case .statueMicro: "Un micro en or massif sur un socle. Personne n'ose y toucher."
        case .neonGoslo: "Le néon de goslo radio, offert par l'animateur."
        case .panneauGeant: "Quatre mètres sur trois, ta tête en grand. Tout le quartier te voit en passant."
        case .studioPerso: "Ton propre studio au pied des tours. Plus besoin de louer le Bunker."
        case .scenePleinAir: "Une vraie scène dehors : les concerts gratuits font monter ton respect."
        case .boutiqueMerch: "T-shirts, casquettes, posters à ton nom. Ça vend tout seul."
        }
    }

    var price: Int {
        switch self {
        case .palmier: 8
        case .bancDore, .borneArcade: 12
        case .sono, .neonGoslo: 16
        case .fresque, .foodTruck: 20
        case .statueMicro: 30
        case .panneauGeant: 40
        case .studioPerso: 55
        case .scenePleinAir: 65
        case .boutiqueMerch: 75
        }
    }

    /// Artist level needed to buy it.
    var minLevel: Int {
        switch self {
        case .palmier, .bancDore: 1
        case .sono, .borneArcade: 2
        case .fresque, .foodTruck: 3
        case .neonGoslo, .panneauGeant: 4
        case .statueMicro, .studioPerso: 6
        case .scenePleinAir: 7
        case .boutiqueMerch: 8
        }
    }

    /// What it gives each turn while it stands on the map.
    var perTurn: [StatKind: Int] {
        switch self {
        case .fresque: [.credibilite: 1]
        case .sono: [.streams: 1]
        case .bancDore: [.credibilite: 1]
        case .palmier: [.mental: 1]
        case .borneArcade: [.mental: 1]
        case .foodTruck: [.argent: 2]
        case .statueMicro: [.credibilite: 1, .streams: 1]
        case .neonGoslo: [.streams: 1]
        case .panneauGeant: [.streams: 2]
        case .studioPerso: [.streams: 1, .argent: 2]
        case .scenePleinAir: [.credibilite: 2, .streams: 1]
        case .boutiqueMerch: [.argent: 4]
        }
    }
}

/// A decoration the player put on the map, where they chose.
struct PlacedDecor: Codable, Equatable, Identifiable {
    let id: Int
    let decor: Decor
    let district: District
    /// Bottom-left tile of the footprint.
    let x: Int
    let y: Int

    var anchor: TilePoint { TilePoint(x: x, y: y) }

    /// Every tile it covers.
    var tiles: [TilePoint] {
        let size = decor.footprint
        return (0..<size.height).flatMap { dy in (0..<size.width).map { dx in TilePoint(x: x + dx, y: y - dy) } }
    }
}

/// Buying goslo radio itself: the end of the road for a career.
enum RadioDeal {
    static let minLevel = 8
    static let price = 85
    static let flag = "radio_rachetee"
    /// Each turn, the station's income.
    static let perTurn: [StatKind: Int] = [.argent: 3, .credibilite: 1]
    /// Your singles get this much more buzz in the Top.
    static let buzz = 1.12

    static func refusal(in state: GameState) -> String? {
        if state.flags.contains(flag) { return "Elle est déjà à toi" }
        if ArtistLevel.level(xp: state.artistXP) < minLevel { return "Niveau \(minLevel) requis" }
        if state.stats.argent <= price { return "Pas assez d'argent" }
        return nil
    }
}

extension GameEngine {
    // MARK: Free placement

    /// Anchor (bottom-left tile) for a decoration put in front of the player.
    static func placementAnchor(for decor: Decor, front: TilePoint, facing: Direction) -> TilePoint {
        let size = decor.footprint
        switch facing {
        case .left: return TilePoint(x: front.x - size.width + 1, y: front.y)
        case .up: return TilePoint(x: front.x, y: front.y)
        default: return TilePoint(x: front.x, y: front.y + size.height - 1)
        }
    }

    /// Tiles taken on the map by the decorations of a district (all of them, or only the ones that block).
    func decorTiles(in district: District, state: GameState, blockingOnly: Bool = false) -> Set<TilePoint> {
        Set(state.placed.filter { $0.district == district && (!blockingOnly || $0.decor.isBuilding) }.flatMap(\.tiles))
    }

    /// A building standing there blocks the way.
    func isBlockedByDecor(_ point: TilePoint, in state: GameState) -> Bool {
        decorTiles(in: state.district, state: state, blockingOnly: true).contains(point)
    }

    /// Why the decoration can't go there (nil: it can). The player's tile and the way to every door,
    /// character and the metro must stay free.
    func placementRefusal(_ decor: Decor, at anchor: TilePoint, in state: GameState, player: TilePoint) -> String? {
        if ArtistLevel.level(xp: state.artistXP) < decor.minLevel { return "Niveau \(decor.minLevel) requis" }
        if state.stats.argent <= decor.price { return "Pas assez d'argent" }
        guard let map = currentMap(in: state) else { return "Pas de carte" }
        let probe = PlacedDecor(id: 0, decor: decor, district: state.district, x: anchor.x, y: anchor.y)
        let taken = decorTiles(in: state.district, state: state)
        let plotted = Set(map.decorPlots.filter { state.decor[$0.id] != nil }.map(\.point))
        let open: Set<TileKind> = [.sidewalk, .asphalt, .grass, .crosswalk]
        for tile in probe.tiles {
            guard open.contains(map.tile(at: tile)) else { return "Pas de place ici" }
            if map.door(at: tile) != nil || map.metro == tile || map.npc(at: tile) != nil { return "Ça bloquerait le passage" }
            if tile == player || tile == map.spawn || tile == map.arrival { return "Pas de place ici" }
            if taken.contains(tile) || plotted.contains(tile) { return "Il y a déjà quelque chose" }
            if state.rapper.city == .casablanca, OverworldRules.blockedByScenery(tile, in: .casablanca) { return "Pas de place ici" }
        }
        if decor.isBuilding {
            let blocked = decorTiles(in: state.district, state: state, blockingOnly: true).union(probe.tiles)
            if !keepsEverythingReachable(on: map, blocked: blocked, from: player) { return "Ça bloquerait le passage" }
        }
        return nil
    }

    /// Every door, the metro and every character can still be reached from `start` with these tiles blocked.
    func keepsEverythingReachable(on map: WorldMap, blocked: Set<TilePoint>, from start: TilePoint) -> Bool {
        var seen: Set<TilePoint> = [start]
        var queue = [start]
        while let point = queue.popLast() {
            for direction in [Direction.up, .down, .left, .right] {
                let next = point.moved(direction)
                guard !seen.contains(next), !blocked.contains(next) else { continue }
                // Doors and the metro are walkable; characters are reached from a neighbouring tile.
                guard map.tile(at: next).isWalkable, map.npc(at: next) == nil else { continue }
                seen.insert(next)
                queue.append(next)
            }
        }
        let doors = map.doors.map(\.point) + (map.metro.map { [$0] } ?? [])
        guard doors.allSatisfy(seen.contains) else { return false }
        return map.npcs.allSatisfy { npc in
            [Direction.up, .down, .left, .right].contains { seen.contains(npc.point.moved($0)) }
        }
    }

    /// Buys a decoration and puts it where the player chose.
    @discardableResult
    func place(_ decor: Decor, at anchor: TilePoint, in state: inout GameState, player: TilePoint) throws -> [StatKind: Int] {
        guard !state.isOver, placementRefusal(decor, at: anchor, in: state, player: player) == nil else {
            throw GameEngineError.cannotBuy
        }
        let id = (state.placed.map(\.id).max() ?? 0) + 1
        state.placed.append(PlacedDecor(id: id, decor: decor, district: state.district, x: anchor.x, y: anchor.y))
        return state.stats.apply([.argent: -decor.price])
    }

    /// Takes a decoration back (no refund: the crew keeps it in the laverie's cellar).
    func removeDecor(_ id: Int, in state: inout GameState) {
        state.placed.removeAll { $0.id == id }
    }

    /// Buys goslo radio.
    func buyRadio(in state: inout GameState) throws -> [StatKind: Int] {
        guard RadioDeal.refusal(in: state) == nil else { throw GameEngineError.cannotBuy }
        state.flags.insert(RadioDeal.flag)
        return state.stats.apply([.argent: -RadioDeal.price])
    }

    // MARK: Fixed spots (older saves)

    /// Every free spot of every district, by id.
    func decorPlots(in state: GameState) -> [(district: District, plot: MapPlot)] {
        District.allCases.flatMap { district in
            (world.map(for: district)?.decorPlots ?? []).map { (district, $0) }
        }
    }

    /// Why this decoration can't go on this spot now (nil: it can).
    func decorRefusal(_ decor: Decor, plot: String, in state: GameState) -> String? {
        if ArtistLevel.level(xp: state.artistXP) < decor.minLevel { return "Niveau \(decor.minLevel) requis" }
        guard decorPlots(in: state).contains(where: { $0.plot.id == plot }) else { return "Emplacement inconnu" }
        if state.decor[plot] != nil { return "Emplacement déjà pris" }
        if state.stats.argent <= decor.price { return "Pas assez d'argent" }
        return nil
    }

    /// Buys a decoration and puts it on a spot.
    @discardableResult
    func placeDecor(_ decor: Decor, plot: String, in state: inout GameState) throws -> [StatKind: Int] {
        guard !state.isOver, decorRefusal(decor, plot: plot, in: state) == nil else { throw GameEngineError.cannotBuy }
        state.decor[plot] = decor
        return state.stats.apply([.argent: -decor.price])
    }

    /// End of a turn: what the decorations bring.
    func decorIncome(in state: inout GameState) -> [StatKind: Int] {
        var total: [StatKind: Int] = [:]
        for decor in Array(state.decor.values) + state.placed.map(\.decor) {
            for (kind, value) in decor.perTurn { total[kind, default: 0] += value }
        }
        if state.flags.contains(RadioDeal.flag) {
            for (kind, value) in RadioDeal.perTurn { total[kind, default: 0] += value }
        }
        return total.isEmpty ? [:] : state.stats.apply(total)
    }
}
