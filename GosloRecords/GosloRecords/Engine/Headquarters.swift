import Foundation

/// The HQ, between careers: the laverie of goslo records, built up room by room with the gold records each
/// career brings home. Rooms give the next careers a head start; they never play for you.
enum HQRoom: String, Codable, CaseIterable, Identifiable {
    case studio, repete, coffre, radio, vestiaire, salon

    var id: String { rawValue }

    var name: String {
        switch self {
        case .studio: "Le studio"
        case .repete: "La salle de répète"
        case .coffre: "Le coffre"
        case .radio: "La radio pirate"
        case .vestiaire: "Le vestiaire"
        case .salon: "Le salon VIP"
        }
    }

    var emoji: String {
        switch self {
        case .studio: "🎚️"
        case .repete: "🥁"
        case .coffre: "💰"
        case .radio: "📻"
        case .vestiaire: "👕"
        case .salon: "🛋️"
        }
    }

    var maxLevel: Int { self == .radio ? 1 : 3 }

    /// Gold records to reach `level` (1…maxLevel).
    func cost(toReach level: Int) -> Int { [3, 6, 10][min(max(level, 1), 3) - 1] }

    /// What it gives at `level`, in a few words.
    func perk(at level: Int) -> String {
        switch self {
        case .studio: "Chaque carrière démarre avec \(level * HQ.studioXP) XP d'artiste"
        case .repete: "+\(level * HQ.rehearsalXP) XP dans chaque compétence au départ"
        case .coffre: "+\(level * HQ.safeMoney) d'argent au départ"
        case .radio: "Un défi de plus chaque saison"
        case .vestiaire: "Des fringues offertes au départ (\(level) pièce\(level > 1 ? "s" : ""))"
        case .salon: "+\(level * HQ.loungeRespect) de respect au départ"
        }
    }
}

/// What the device keeps of the HQ (saved with the achievements).
struct Headquarters: Codable, Equatable {
    var discs = 0
    /// Gold records earned over all careers.
    var earned = 0
    var rooms: [String: Int] = [:]
    /// Gold records brought home by the last career (for the ending screen).
    var lastReward: Int?

    func level(_ room: HQRoom) -> Int { rooms[room.rawValue, default: 0] }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        discs = try c.decodeIfPresent(Int.self, forKey: .discs) ?? 0
        earned = try c.decodeIfPresent(Int.self, forKey: .earned) ?? 0
        rooms = try c.decodeIfPresent([String: Int].self, forKey: .rooms) ?? [:]
        lastReward = try c.decodeIfPresent(Int.self, forKey: .lastReward)
    }
}

enum HQ {
    static let studioXP = 40
    static let rehearsalXP = 40
    static let safeMoney = 6
    static let loungeRespect = 5
    static let radioFlag = "qg_radio"
    /// Offered by the wardrobe, one more per level.
    static let wardrobeGifts = ["chaine_or", "lunettes_star", "sneakers_neon"]

    /// Gold records a finished career brings home: always one, more for a career that went far.
    static func reward(for state: GameState) -> Int {
        var discs = 1
        if state.flags.contains("clash_gagne_le_baron") || state.flags.contains("baron_tombe") { discs += 3 }
        discs += ArtistLevel.level(xp: state.artistXP) / 2
        if let best = state.singles.compactMap(\.bestRank).min() { discs += best == 1 ? 2 : (best <= 3 ? 1 : 0) }
        discs += min(3, state.counters[.clashsGagnes] / 3)
        return discs
    }

    /// Why a room can't be upgraded now (nil: it can).
    static func refusal(_ room: HQRoom, in hq: Headquarters) -> String? {
        let next = hq.level(room) + 1
        if next > room.maxLevel { return "Au maximum" }
        if hq.discs < room.cost(toReach: next) { return "Pas assez de disques d'or" }
        return nil
    }

    static func upgrade(_ room: HQRoom, in hq: inout Headquarters) -> Bool {
        guard refusal(room, in: hq) == nil else { return false }
        let next = hq.level(room) + 1
        hq.discs -= room.cost(toReach: next)
        hq.rooms[room.rawValue] = next
        return true
    }

    /// A new career starts with what the HQ gives.
    static func apply(_ hq: Headquarters, to state: inout GameState) {
        state.artistXP += hq.level(.studio) * studioXP
        let rehearsal = hq.level(.repete) * rehearsalXP
        if rehearsal > 0 { state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, rehearsal) })) }
        state.stats.apply([.argent: hq.level(.coffre) * safeMoney, .credibilite: hq.level(.salon) * loungeRespect])
        if hq.level(.radio) > 0 { state.flags.insert(radioFlag) }
        for gift in wardrobeGifts.prefix(hq.level(.vestiaire)) { state.wardrobe.insert(gift) }
    }
}
