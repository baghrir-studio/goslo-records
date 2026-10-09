import Foundation

/// Decorations the player buys in the shop and puts on the map's free spots (`MapPlot`), for the whole career.
/// Each one shows on the map, and gives a small bonus every turn while it stands.
enum Decor: String, Codable, CaseIterable, Identifiable {
    case fresque, sono, bancDore = "banc_dore", palmier, borneArcade = "borne_arcade", foodTruck = "food_truck",
         statueMicro = "statue_micro", neonGoslo = "neon_goslo"
    // Buildings: expensive, they take room (2 tiles wide) and pay every turn.
    case panneauGeant = "panneau_geant", studioPerso = "studio_perso", scenePleinAir = "scene_plein_air",
         boutiqueMerch = "boutique_merch"
    // Neighbourhood businesses, one to aim for at almost every artist level (see `Neighbourhood` for how they
    // help each other and what the period asks for).
    case snack, barbier, salleBoxe = "salle_boxe", disquaire, radioPirate = "radio_pirate",
         labelInde = "label_inde", fresqueGeante = "fresque_geante"

    /// The big ones: they block the way (placed only where every door and character stays reachable).
    var isBuilding: Bool {
        switch self {
        case .fresque, .sono, .bancDore, .palmier, .borneArcade, .foodTruck, .statueMicro, .neonGoslo: false
        case .panneauGeant, .studioPerso, .scenePleinAir, .boutiqueMerch, .snack, .barbier, .salleBoxe, .disquaire,
             .radioPirate, .labelInde, .fresqueGeante: true
        }
    }

    /// Tiles taken (width, height), from the anchor tile to the right and up.
    var footprint: (width: Int, height: Int) {
        switch self {
        case .foodTruck, .panneauGeant, .snack, .radioPirate: (2, 1)
        case .studioPerso, .scenePleinAir, .boutiqueMerch, .barbier, .disquaire: (2, 2)
        case .salleBoxe, .labelInde: (3, 2)
        case .fresqueGeante: (3, 1)
        case .fresque, .sono, .bancDore, .palmier, .borneArcade, .statueMicro, .neonGoslo: (1, 1)
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
        case .snack: "Snack Chez Momo"
        case .barbier: "Barbier du quartier"
        case .salleBoxe: "Salle de boxe"
        case .disquaire: "Disquaire"
        case .radioPirate: "Radio pirate"
        case .labelInde: "Ton label indépendant"
        case .fresqueGeante: "Fresque monumentale"
        }
    }

    /// Short name, for synergy and demand lines ("synergie avec le snack").
    var shortName: String {
        switch self {
        case .fresque: "la fresque"
        case .sono: "la sono"
        case .bancDore: "le banc doré"
        case .palmier: "le palmier"
        case .borneArcade: "la borne d'arcade"
        case .foodTruck: "le food truck"
        case .statueMicro: "la statue"
        case .neonGoslo: "le néon"
        case .panneauGeant: "le panneau géant"
        case .studioPerso: "ton studio"
        case .scenePleinAir: "la scène"
        case .boutiqueMerch: "la boutique de merch"
        case .snack: "le snack"
        case .barbier: "le barbier"
        case .salleBoxe: "la salle de boxe"
        case .disquaire: "le disquaire"
        case .radioPirate: "la radio pirate"
        case .labelInde: "ton label"
        case .fresqueGeante: "la fresque monumentale"
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
        case .snack: "Kebab, frites, sauce blanche. Momo tient la broche, toi tu touches ta part."
        case .barbier: "Le dégradé du quartier. On y parle de toi entre deux coups de tondeuse."
        case .salleBoxe: "Un ring, des sacs, de la sueur. Les petits s'y défoulent, toi tu tiens le coup."
        case .disquaire: "Des bacs de vinyles et tes disques en vitrine. Les puristes passent te voir."
        case .radioPirate: "Une antenne sur le toit et un micro ouvert. Ton son tourne sans demander la permission."
        case .labelInde: "Ta propre structure : tu signes les petits du quartier et tu touches sur tout."
        case .fresqueGeante: "Trois étages de peinture à ta gloire. On vient de loin pour la prendre en photo."
        }
    }

    var price: Int {
        switch self {
        case .palmier: 8
        case .bancDore, .borneArcade: 12
        case .sono, .neonGoslo: 16
        case .fresque, .foodTruck: 20
        case .snack: 30
        case .statueMicro: 30
        case .panneauGeant: 40
        case .barbier: 42
        case .salleBoxe: 50
        case .studioPerso: 55
        case .disquaire: 58
        case .radioPirate: 62
        case .scenePleinAir: 65
        case .boutiqueMerch: 75
        case .labelInde: 80
        case .fresqueGeante: 85
        }
    }

    /// Artist level needed to buy it.
    var minLevel: Int {
        switch self {
        case .palmier, .bancDore: 1
        case .sono, .borneArcade, .snack: 2
        case .fresque, .foodTruck, .barbier: 3
        case .neonGoslo, .panneauGeant: 4
        case .salleBoxe: 5
        case .statueMicro, .studioPerso, .disquaire: 6
        case .scenePleinAir, .radioPirate: 7
        case .boutiqueMerch: 8
        case .labelInde: 9
        case .fresqueGeante: 10
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
        case .snack: [.argent: 3]
        case .barbier: [.argent: 2, .credibilite: 1]
        case .salleBoxe: [.mental: 2, .credibilite: 1]
        case .disquaire: [.argent: 3, .streams: 1]
        case .radioPirate: [.streams: 2, .credibilite: 1]
        case .labelInde: [.argent: 5, .streams: 1]
        case .fresqueGeante: [.credibilite: 2, .streams: 2]
        }
    }
}

/// A decoration the player put on the map, where they chose.
struct PlacedDecor: Codable, Equatable, Identifiable {
    let id: Int
    let decor: Decor
    let district: District
    /// Bottom-left tile of the footprint.
    var x: Int
    var y: Int
    /// Buildings go up to `Decor.maxLevel`; each level pays more.
    var level: Int = 1
    /// Money it made, waiting for the player to come and pick it up (capped).
    var stored: Int = 0
    /// Everything spent on it (purchase and upgrades), for the resale price.
    var invested: Int = 0

    var anchor: TilePoint { TilePoint(x: x, y: y) }

    /// Every tile it covers.
    var tiles: [TilePoint] {
        let size = decor.footprint
        return (0..<size.height).flatMap { dy in (0..<size.width).map { dx in TilePoint(x: x + dx, y: y - dy) } }
    }

    /// What it gives each turn at its level.
    var perTurn: [StatKind: Int] { decor.perTurn(level: level) }

    /// The most money it keeps waiting: three periods' worth. Come back or it's lost.
    var storageCap: Int { (perTurn[.argent] ?? 0) * 3 }

    /// What you get back when you sell it: half of what you put in.
    var resale: Int { invested / 2 }

    init(id: Int, decor: Decor, district: District, x: Int, y: Int, level: Int = 1, stored: Int = 0, invested: Int? = nil) {
        self.id = id
        self.decor = decor
        self.district = district
        self.x = x
        self.y = y
        self.level = level
        self.stored = stored
        self.invested = invested ?? decor.price
    }

    private enum CodingKeys: String, CodingKey { case id, decor, district, x, y, level, stored, invested }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        decor = try c.decode(Decor.self, forKey: .decor)
        district = try c.decode(District.self, forKey: .district)
        x = try c.decode(Int.self, forKey: .x)
        y = try c.decode(Int.self, forKey: .y)
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? 1
        stored = try c.decodeIfPresent(Int.self, forKey: .stored) ?? 0
        invested = try c.decodeIfPresent(Int.self, forKey: .invested) ?? decor.price
    }
}

extension Decor {
    static let maxLevel = 3

    /// Income at a level: ×1.5 at level 2, ×2 at level 3 (rounded up).
    func perTurn(level: Int) -> [StatKind: Int] {
        perTurn.mapValues { ($0 * (level + 1) + 1) / 2 }
    }

    /// Price to go from `level` to `level + 1` (nil: can't go higher, or it's not a building).
    func upgradeCost(from level: Int) -> Int? {
        guard isBuilding, level < Decor.maxLevel else { return nil }
        return (price * (level + 1) + 2) / 3
    }

    /// Artist level needed to upgrade to `level + 1`.
    func upgradeMinLevel(from level: Int) -> Int { min(minLevel + level, ArtistLevel.thresholds.count) }
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
    /// `moving`: a decoration already owned being moved (no price, its old spot counts as free).
    func placementRefusal(_ decor: Decor, at anchor: TilePoint, in original: GameState, player: TilePoint,
                          moving: Int? = nil) -> String? {
        var state = original
        if let moving {
            state.placed.removeAll { $0.id == moving }
        } else {
            if ArtistLevel.level(xp: state.artistXP) < decor.minLevel { return "Niveau \(decor.minLevel) requis" }
            if state.stats.argent <= decor.price { return "Pas assez d'argent" }
        }
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

    /// Picks up the money a decoration made. Returns how much.
    @discardableResult
    func collect(_ id: Int, in state: inout GameState) -> Int {
        guard let index = state.placed.firstIndex(where: { $0.id == id }), state.placed[index].stored > 0 else { return 0 }
        let amount = state.placed[index].stored
        state.placed[index].stored = 0
        return state.stats.apply([.argent: amount])[.argent] ?? 0
    }

    /// Why it can't be upgraded now (nil: it can).
    func upgradeRefusal(_ id: Int, in state: GameState) -> String? {
        guard let item = state.placed.first(where: { $0.id == id }) else { return "Introuvable" }
        guard item.decor.isBuilding else { return "Seuls les bâtiments s'améliorent" }
        guard let cost = item.decor.upgradeCost(from: item.level) else { return "Niveau max" }
        let needed = item.decor.upgradeMinLevel(from: item.level)
        if ArtistLevel.level(xp: state.artistXP) < needed { return "Niveau \(needed) requis" }
        if state.stats.argent <= cost { return "Pas assez d'argent" }
        return nil
    }

    /// Upgrades a building one level.
    @discardableResult
    func upgrade(_ id: Int, in state: inout GameState) throws -> [StatKind: Int] {
        guard !state.isOver, upgradeRefusal(id, in: state) == nil,
              let index = state.placed.firstIndex(where: { $0.id == id }),
              let cost = state.placed[index].decor.upgradeCost(from: state.placed[index].level) else {
            throw GameEngineError.cannotBuy
        }
        state.placed[index].level += 1
        state.placed[index].invested += cost
        return state.stats.apply([.argent: -cost])
    }

    /// Sells a decoration: half of what you put in, plus what it had waiting.
    @discardableResult
    func sell(_ id: Int, in state: inout GameState) -> [StatKind: Int] {
        guard let item = state.placed.first(where: { $0.id == id }) else { return [:] }
        state.placed.removeAll { $0.id == id }
        return state.stats.apply([.argent: item.resale + item.stored])
    }

    /// Why a decoration you already own can't move there (nil: it can). Same rules as a new one, without paying.
    func moveRefusal(_ id: Int, to anchor: TilePoint, in state: GameState, player: TilePoint) -> String? {
        guard let item = state.placed.first(where: { $0.id == id }) else { return "Introuvable" }
        return placementRefusal(item.decor, at: anchor, in: state, player: player, moving: id)
    }

    /// Moves a decoration to another spot of the current district (free).
    func move(_ id: Int, to anchor: TilePoint, in state: inout GameState, player: TilePoint) throws {
        guard moveRefusal(id, to: anchor, in: state, player: player) == nil,
              let index = state.placed.firstIndex(where: { $0.id == id }) else { throw GameEngineError.cannotBuy }
        let old = state.placed[index]
        state.placed[index] = PlacedDecor(id: old.id, decor: old.decor, district: state.district, x: anchor.x, y: anchor.y,
                                          level: old.level, stored: old.stored, invested: old.invested)
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

    /// End of a turn: what the decorations bring, with their synergies and the period's demand (`Neighbourhood`).
    /// Money from placed ones waits on the spot until you pick it up.
    func decorIncome(in state: inout GameState) -> [StatKind: Int] {
        var total: [StatKind: Int] = [:]
        for decor in state.decor.values {
            for (kind, value) in decor.perTurn { total[kind, default: 0] += value }
        }
        // Synergies and the period's demand are worked out on the map as it stands before anything changes.
        let incomes = state.placed.map { income(of: $0, in: state) }
        for index in state.placed.indices {
            let item = state.placed[index], earned = incomes[index]
            let crew = Crew.buildingBonus(item.decor, in: state)
            for (kind, base) in earned.total {
                let value = Crew.boosted(base, by: crew)
                if kind == .argent {
                    // A busy period can push it past the usual cap; it never eats what's already waiting.
                    let cap = max(earned.storageCap, value * 3)
                    state.placed[index].stored = max(item.stored, min(item.stored + value, cap))
                } else {
                    total[kind, default: 0] += value
                }
            }
        }
        if state.flags.contains(RadioDeal.flag) {
            for (kind, value) in RadioDeal.perTurn { total[kind, default: 0] += value }
        }
        return total.isEmpty ? [:] : state.stats.apply(total)
    }
}
