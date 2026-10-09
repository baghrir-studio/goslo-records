import Foundation

/// The career leaves marks: rivals quote your lines, friends talk about your tracks,
/// posters go up in the neighbourhood, and the people you met come to the big shows.
extension GameEngine {
    // MARK: Memory

    /// What a rival can throw back at you in a clash (nothing in the terrain vague: they don't know you).
    func callbacks(for clash: ClashState, in state: GameState) -> [String] {
        guard !clash.isWild else { return [] }
        var lines = state.hooks.suffix(3).flatMap { hook in [
            "« \(hook) » ? Même ma petite sœur l'avait vue venir.",
            "T'as écrit « \(hook) » dans une laverie, et ça s'entend.",
            "« \(hook) »… Yanis l'a mis dans son top. Le top des flops.",
        ] }
        if state.flags.contains("sous_contrat") {
            lines.append("Signé dans l'arrière-boutique d'une laverie. Ton contrat sent l'assouplissant.")
        }
        if state.flags.contains("premier_texte") {
            lines.append("Ton premier texte, je l'ai lu. Au crayon. Il s'effaçait tout seul.")
        }
        if state.stats.streams >= 60 {
            lines.append("T'as des streams, d'accord. Moi j'ai des souvenirs de toi à 12 abonnés.")
        }
        lines.append("Retourne à \(state.rapper.city.rawValue), ta mère t'attend avec sa pancarte.")
        return lines
    }

    /// A friend brings up your latest track, now and then (nil if they have nothing to say about it).
    func memoryLine(for castId: String, in state: GameState) -> String? {
        guard let hook = state.hooks.last else { return nil }
        switch castId {
        case "yanis": return "« \(hook) », je l'ai passé dans Le Débrief. Catégorie « prometteur ». Je ne la donne pas souvent."
        case "momo": return "J'ai mis « \(hook) » en boucle dans la laverie. Les clients restent pour le rinçage."
        case "fred": return "« \(hook) »… En 2009, j'aurais mixé ça en or. Là, c'est du platine dans un cœur."
        case "maman": return "J'ai écrit « \(hook) » sur ma pancarte. Tu as vu ? Au premier rang."
        case "lucien": return "On m'a fait écouter « \(hook) » au téléphone. Sur le fixe. C'était bien."
        case "lil_sauge": return "« \(hook) », ouais, j'ai vu passer. 400 vues ? Mignon."
        case "big_nono": return "Les auditeurs redemandent « \(hook) ». Je fais semblant de pas l'avoir."
        case "karim": return "« \(hook) » ? Je l'ai fait écouter à mes contacts. Deux fois, je compte deux fois."
        default: return nil
        }
    }

    // MARK: The neighbourhood

    /// 0…3: how many walls of the neighbourhood carry your poster (pairs), by streams.
    func fame(in state: GameState) -> Int {
        switch state.stats.streams {
        case ..<35: 0
        case ..<55: 1
        case ..<75: 2
        default: 3
        }
    }

    /// How the streets show the artist's level (cosmetic only: nothing here blocks a tile).
    func streetBuzz(in state: GameState) -> StreetBuzz {
        StreetBuzz(level: ArtistLevel.level(xp: state.artistXP), streamPosters: fame(in: state) * 2,
                   home: state.district == StreetBuzz.home)
    }

    /// Beat the Baron, and the laundromat's wall gets your face, painted.
    func hasFresco(in state: GameState) -> Bool {
        state.flags.contains("clash_gagne_le_baron") || state.flags.contains("baron_tombe")
    }

    // MARK: The big shows

    /// The people in the front row: at the Dôme, everyone you met; elsewhere, the ones who like you.
    func concertGuests(_ concertId: String, in state: GameState) -> [CastMember] {
        let dome = concertId == "le_dome"
        let met = world.cast.filter { member in
            !member.wild && state.metCast.contains(member.id) && (dome || state.relation(member.id) >= 60)
        }
        let mother = world.cast.filter { $0.id == "maman" && !state.metCast.contains("maman") }
        return Array((mother + met.sorted { state.relation($0.id) > state.relation($1.id) }).prefix(dome ? 10 : 5))
    }
}

/// The neighbourhood changes as the artist grows (`ArtistLevel`): people stroll on the sidewalks, posters
/// go up from level 3, tags with the artist's name from level 5, fans wait by the door from level 7.
/// More of it at home (Le Bloc). Purely cosmetic: none of it is an obstacle or an NPC.
struct StreetBuzz: Equatable {
    /// The artist's home district.
    static let home = District.bloc
    static let postersFrom = 3
    static let tagsFrom = 5
    static let fansFrom = 7
    static let maxPosters = 8

    let level: Int
    /// People walking up and down the sidewalks.
    let passersBy: Int
    /// Posters of the artist on the walls (the streams already put some up: the larger count wins).
    let posters: Int
    /// Graffiti tags with the artist's name.
    let tags: Int
    /// Fans waiting near the spawn point (home only).
    let fans: Int

    init(level: Int, streamPosters: Int = 0, home: Bool) {
        self.level = level
        passersBy = home ? min(6, max(0, level - 1)) : min(3, max(0, level - 1) / 2)
        let levelPosters = level >= StreetBuzz.postersFrom ? (home ? 2 : 1) + (level - StreetBuzz.postersFrom) : 0
        posters = min(StreetBuzz.maxPosters, max(streamPosters, levelPosters))
        tags = level >= StreetBuzz.tagsFrom ? min(home ? 6 : 3, (home ? 2 : 1) + (level - StreetBuzz.tagsFrom)) : 0
        fans = home && level >= StreetBuzz.fansFrom ? min(6, 3 + level - StreetBuzz.fansFrom) : 0
    }

    /// The artist's name as a tag: capitals without accents, letters and digits only, 9 at most.
    static func tagText(for name: String) -> String {
        let plain = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .uppercased()
        let kept = plain.filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == " " }
        let text = kept.split(separator: " ").joined(separator: " ")
        let tag = String(text.prefix(9)).trimmingCharacters(in: .whitespaces)
        return tag.isEmpty ? "GOSLO" : tag
    }
}

/// A stretch of sidewalk a passer-by walks up and down.
struct Stroll: Equatable {
    let y: Int
    let from: Int
    let to: Int
}

extension WorldMap {
    /// Front walls where a poster or a tag can go: above the street, away from shop fronts and the metro.
    var fameWalls: [TilePoint] {
        (0..<height).flatMap { y in
            (0..<width).compactMap { x -> TilePoint? in
                let point = TilePoint(x: x, y: y), below = tile(at: point.moved(.down))
                guard tile(at: point) == .wall, below != .wall, below != .door, below != .metro,
                      !doors.contains(where: { $0.y == y && abs($0.x - x) <= 2 }),
                      !(metro.map { $0.y == y && abs($0.x - x) <= 2 } ?? false) else { return nil }
                return point
            }
        }
    }

    /// Walls for the tags: from the other end than the posters, never on a poster's wall, one wall in two
    /// (a tag is about two tiles wide).
    func tagWalls(posters: Int, count: Int) -> [TilePoint] {
        guard count > 0 else { return [] }
        let walls = fameWalls
        let taken = Set(walls.prefix(posters))
        let free = walls.reversed().filter { !taken.contains($0) }
        return Array(stride(from: 0, to: free.count, by: 2).map { free[$0] }.prefix(count))
    }

    /// Sidewalk tiles near the spawn point where fans wait (never in front of a door, nor on someone).
    func fanSpots(count: Int) -> [TilePoint] {
        guard count > 0 else { return [] }
        func distance(_ point: TilePoint) -> Int { abs(point.x - spawn.x) + abs(point.y - spawn.y) }
        let spots = (0..<height).flatMap { y in (0..<width).map { TilePoint(x: $0, y: y) } }.filter { point in
            (2...6).contains(distance(point)) && tile(at: point) == .sidewalk && npc(at: point) == nil
                && door(at: point.moved(.up)) == nil && point != arrival
        }
        let sorted = spots.sorted { a, b in
            distance(a) != distance(b) ? distance(a) < distance(b) : (a.y, a.x) < (b.y, b.x)
        }
        return Array(sorted.prefix(count))
    }

    /// Stretches of sidewalk (4 to 6 tiles, nobody standing on them) for the passers-by, spread over the map.
    func strolls(count: Int) -> [Stroll] {
        guard count > 0 else { return [] }
        var stretches: [Stroll] = []
        for y in 0..<height {
            var start: Int?
            for x in 0...width {
                let point = TilePoint(x: x, y: y)
                if x < width, tile(at: point) == .sidewalk, npc(at: point) == nil {
                    if start == nil { start = x }
                    if let first = start, x - first + 1 == 6 {
                        stretches.append(Stroll(y: y, from: first, to: x))
                        start = nil
                    }
                } else if let first = start {
                    if x - first >= 4 { stretches.append(Stroll(y: y, from: first, to: x - 1)) }
                    start = nil
                }
            }
        }
        guard !stretches.isEmpty else { return [] }
        let picked = min(count, stretches.count)
        return (0..<picked).map { stretches[$0 * stretches.count / picked] }
    }
}
