import Foundation

/// Decorations the player buys in the shop and puts on the map's free spots (`MapPlot`), for the whole career.
/// Each one shows on the map, and gives a small bonus every turn while it stands.
enum Decor: String, Codable, CaseIterable, Identifiable {
    case fresque, sono, bancDore = "banc_dore", palmier, borneArcade = "borne_arcade", foodTruck = "food_truck",
         statueMicro = "statue_micro", neonGoslo = "neon_goslo"

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
        }
    }

    var price: Int {
        switch self {
        case .palmier: 8
        case .bancDore, .borneArcade: 12
        case .sono, .neonGoslo: 16
        case .fresque, .foodTruck: 20
        case .statueMicro: 30
        }
    }

    /// Artist level needed to buy it.
    var minLevel: Int {
        switch self {
        case .palmier, .bancDore: 1
        case .sono, .borneArcade: 2
        case .fresque, .foodTruck: 3
        case .neonGoslo: 4
        case .statueMicro: 6
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
        }
    }
}

extension GameEngine {
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
        for decor in state.decor.values {
            for (kind, value) in decor.perTurn { total[kind, default: 0] += value }
        }
        return total.isEmpty ? [:] : state.stats.apply(total)
    }
}
