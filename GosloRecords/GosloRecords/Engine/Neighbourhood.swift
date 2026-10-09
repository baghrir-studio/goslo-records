import Foundation

/// The mini economy of the map: where you put your buildings matters (synergies between neighbours),
/// and what the neighbourhood wants changes every period (demand). Both are derived from the save
/// (positions and turn), so nothing new is stored.

/// A building earns a bonus when one of its partners stands close by in the same district.
struct Synergy: Equatable {
    let building: Decor
    let partners: [Decor]
    /// Added to what the building gives each period (flat, whatever its level).
    let bonus: [StatKind: Int]
    /// Why, in the game's voice.
    let line: String
}

/// A synergy at work: which partner triggered it.
struct SynergyMatch: Equatable {
    let synergy: Synergy
    let partner: Decor
}

/// What the neighbourhood wants this period: a few businesses pay double.
struct Demand: Equatable {
    let id: String
    let title: String
    /// What it does, short ("le snack et le food truck rapportent double").
    let effect: String
    let boosted: [Decor]

    /// One line for the shop and the period briefing.
    var line: String { "\(title) : \(effect)" }
}

enum Neighbourhood {
    /// Two footprints are neighbours when at most one tile separates them (diagonals count).
    static let reach = 2

    static let synergies: [Synergy] = [
        Synergy(building: .barbier, partners: [.boutiqueMerch], bonus: [.argent: 1],
                line: "Les clients ressortent avec ta casquette."),
        Synergy(building: .barbier, partners: [.snack, .foodTruck], bonus: [.credibilite: 1],
                line: "On refait le monde en attendant son tour."),
        Synergy(building: .snack, partners: [.salleBoxe], bonus: [.argent: 1],
                line: "Les boxeurs sortent de l'entraînement affamés."),
        Synergy(building: .scenePleinAir, partners: [.snack, .foodTruck], bonus: [.argent: 1],
                line: "La buvette des concerts."),
        Synergy(building: .boutiqueMerch, partners: [.scenePleinAir], bonus: [.argent: 1],
                line: "Le public repart avec un t-shirt."),
        Synergy(building: .studioPerso, partners: [.labelInde], bonus: [.streams: 1],
                line: "Le label sort tes sons direct."),
        Synergy(building: .labelInde, partners: [.studioPerso], bonus: [.argent: 1],
                line: "Les artistes du label enregistrent chez toi."),
        Synergy(building: .disquaire, partners: [.studioPerso, .labelInde], bonus: [.argent: 1],
                line: "Tes sons pressés en vinyle, vendus à côté."),
        Synergy(building: .radioPirate, partners: [.disquaire], bonus: [.streams: 1],
                line: "Le disquaire passe ses nouveautés à l'antenne."),
        Synergy(building: .salleBoxe, partners: [.sono], bonus: [.mental: 1],
                line: "Les entraînements en musique."),
        Synergy(building: .fresqueGeante, partners: [.panneauGeant], bonus: [.streams: 1],
                line: "Tout le quartier vient prendre la photo."),
    ]

    /// The synergies a building can have (as the one that earns).
    static func synergies(for decor: Decor) -> [Synergy] { synergies.filter { $0.building == decor } }

    /// Everything that goes well next to it, either way (for the shop's hint).
    static func partners(of decor: Decor) -> [Decor] {
        var result: [Decor] = []
        for synergy in synergies {
            let found = synergy.building == decor ? synergy.partners : (synergy.partners.contains(decor) ? [synergy.building] : [])
            for partner in found where !result.contains(partner) { result.append(partner) }
        }
        return result
    }

    static func areNeighbours(_ a: [TilePoint], _ b: [TilePoint]) -> Bool {
        a.contains { p in b.contains { q in max(abs(p.x - q.x), abs(p.y - q.y)) <= reach } }
    }

    /// The demands, in the order they come round.
    static let demands: [Demand] = [
        Demand(id: "rentree", title: "C'est la rentrée", effect: "le barbier et la boutique de merch rapportent double",
               boosted: [.barbier, .boutiqueMerch]),
        Demand(id: "faim", title: "Le quartier a faim", effect: "le snack et le food truck rapportent double",
               boosted: [.snack, .foodTruck]),
        Demand(id: "fete", title: "Fête de quartier", effect: "la scène et la sono rapportent double",
               boosted: [.scenePleinAir, .sono]),
        Demand(id: "gala", title: "Gala de boxe", effect: "la salle de boxe rapporte double",
               boosted: [.salleBoxe]),
        Demand(id: "bacs", title: "Les bacs sont vides", effect: "le disquaire et la radio pirate rapportent double",
               boosted: [.disquaire, .radioPirate]),
        Demand(id: "signatures", title: "Saison des signatures", effect: "ton label et ton studio rapportent double",
               boosted: [.labelInde, .studioPerso]),
        Demand(id: "affichage", title: "Le quartier se fait beau", effect: "panneau, fresques : tout rapporte double",
               boosted: [.panneauGeant, .fresqueGeante, .fresque]),
    ]

    /// This period's demand: it comes round with the turn (a step of 3 over 7 visits every one, in a mixed order).
    static func demand(turn: Int) -> Demand {
        demands[((turn % demands.count) * 3) % demands.count]
    }
}

/// What a placed decoration really gives this period, and why.
struct BuildingIncome: Equatable {
    /// At its level.
    let base: [StatKind: Int]
    let synergies: [SynergyMatch]
    /// This period's demand doubles it.
    let boosted: Bool

    /// Base (doubled under demand) plus every synergy bonus.
    var total: [StatKind: Int] {
        var result = boosted ? base.mapValues { $0 * 2 } : base
        for match in synergies {
            for (kind, value) in match.synergy.bonus { result[kind, default: 0] += value }
        }
        return result
    }

    /// The most money it keeps waiting: three periods of its usual income (synergies count, demand doesn't).
    var storageCap: Int {
        ((base[.argent] ?? 0) + synergies.reduce(0) { $0 + ($1.synergy.bonus[.argent] ?? 0) }) * 3
    }
}

extension GameEngine {
    /// Synergies a decoration standing on `tiles` would get from what's around it.
    func synergyMatches(for decor: Decor, tiles: [TilePoint], district: District, among placed: [PlacedDecor]) -> [SynergyMatch] {
        let around = placed.filter { $0.district == district && Neighbourhood.areNeighbours(tiles, $0.tiles) }
        return Neighbourhood.synergies(for: decor).compactMap { synergy in
            around.first { synergy.partners.contains($0.decor) }.map { SynergyMatch(synergy: synergy, partner: $0.decor) }
        }
    }

    /// What a placed decoration gives this period.
    func income(of item: PlacedDecor, in state: GameState) -> BuildingIncome {
        let others = state.placed.filter { $0.id != item.id }
        return BuildingIncome(base: item.perTurn,
                              synergies: synergyMatches(for: item.decor, tiles: item.tiles, district: item.district, among: others),
                              boosted: Neighbourhood.demand(turn: state.turn).boosted.contains(item.decor))
    }

    /// Construction mode: the synergies putting it there would start, both ways (what it gets, what it gives).
    /// One short line per synergy, e.g. "+1 argent : synergie avec la boutique de merch".
    func placementSynergies(_ decor: Decor, at anchor: TilePoint, in state: GameState, moving: Int? = nil) -> [String] {
        let probe = PlacedDecor(id: -1, decor: decor, district: state.district, x: anchor.x, y: anchor.y)
        let others = state.placed.filter { $0.id != moving }
        var lines = synergyMatches(for: decor, tiles: probe.tiles, district: state.district, among: others).map {
            "\(GameEngine.bonusText($0.synergy.bonus)) : synergie avec \($0.partner.shortName)"
        }
        // Neighbours that would get a bonus from it (counted once each, and only if they don't have it already).
        for neighbour in others where neighbour.district == state.district && Neighbourhood.areNeighbours(probe.tiles, neighbour.tiles) {
            let without = synergyMatches(for: neighbour.decor, tiles: neighbour.tiles, district: neighbour.district,
                                         among: others.filter { $0.id != neighbour.id })
            let with = synergyMatches(for: neighbour.decor, tiles: neighbour.tiles, district: neighbour.district,
                                      among: others.filter { $0.id != neighbour.id } + [probe])
            for match in with where !without.contains(where: { $0.synergy == match.synergy }) {
                let line = "\(GameEngine.bonusText(match.synergy.bonus)) pour \(neighbour.decor.shortName)"
                if !lines.contains(line) { lines.append(line) }
            }
        }
        return lines
    }

    /// "+1 argent · +1 respect".
    static func bonusText(_ bonus: [StatKind: Int]) -> String {
        bonus.sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.value >= 0 ? "+" : "")\($0.value) \($0.key.label.lowercased())" }
            .joined(separator: " · ")
    }
}
