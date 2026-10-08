import Foundation

/// Street happenings: something going on a few steps away on the map (a cypher forming, a fan, a beatboxer).
/// Walk onto it to join in. They cost no action; one per turn at most.
enum Happening: String, Codable, CaseIterable {
    case cypher, selfie, beatbox

    var emoji: String {
        switch self {
        case .cypher: "🎤"
        case .selfie: "📸"
        case .beatbox: "🥁"
        }
    }

    /// What the player sees on arrival.
    var intro: String {
        switch self {
        case .cypher: "Un cypher se forme au coin de la rue. Quelqu'un te tend le micro : « Vas-y, montre. »"
        case .selfie: "Une fan te reconnaît et court vers toi, téléphone en l'air."
        case .beatbox: "Un beatboxeur a posé une enceinte sur le trottoir. Il te pointe du doigt : « Toi. Répète ça. »"
        }
    }
}

struct StreetHappening: Equatable {
    let kind: Happening
    let point: TilePoint
}

enum Happenings {
    /// Chance per step, once the turn has none yet.
    static let chancePercent = 6
    static let distance = 3...6

    /// Where a happening could show up: a free walkable tile a few steps from the player, not a door or the metro.
    static func spot<R: RandomNumberGenerator>(near player: TilePoint, on map: WorldMap, city: City,
                                               using rng: inout R) -> TilePoint? {
        var candidates: [TilePoint] = []
        for dy in -distance.upperBound...distance.upperBound {
            for dx in -distance.upperBound...distance.upperBound {
                let point = TilePoint(x: player.x + dx, y: player.y + dy)
                guard distance.contains(abs(dx) + abs(dy)), OverworldRules.canStep(to: point, on: map),
                      !OverworldRules.blockedByScenery(point, in: city), map.door(at: point) == nil, map.metro != point,
                      [.sidewalk, .asphalt, .crosswalk, .grass].contains(map.tile(at: point)) else { continue }
                candidates.append(point)
            }
        }
        return candidates.randomElement(using: &rng)
    }

    /// Which happening: a cypher needs someone to clash with in this city.
    static func pick<R: RandomNumberGenerator>(canClash: Bool, using rng: inout R) -> Happening {
        let pool: [Happening] = canClash ? [.cypher, .cypher, .selfie, .beatbox, .beatbox] : [.selfie, .beatbox]
        return pool.randomElement(using: &rng)!
    }

    static let fans = ["Inès", "Kenza", "Théo", "Moussa", "Léa", "Yacine", "Chloé", "Bilal"]

    static let selfieLines = [
        "« Une photo ? C'est pour ma cousine. Elle te connaît pas, mais elle va. »",
        "« Je t'ai vu dans le Top goslo radio ! Enfin, mon frère t'a vu. Il m'a dit de te dire. »",
        "« Tu peux signer mon bras ? Je me le fais tatouer demain. Non, je rigole. Peut-être. »",
        "« T'es plus petit en vrai. Plus grand, pardon. Bref, une photo. »",
    ]
}

extension GameEngine {
    /// A fan, a photo: a few streams, a little morale. Returns what they say and what changed.
    func takeSelfie<R: RandomNumberGenerator>(in state: inout GameState, using rng: inout R) -> (fan: String, line: String, changes: [StatKind: Int]) {
        let fan = Happenings.fans.randomElement(using: &rng)!
        let line = Happenings.selfieLines.randomElement(using: &rng)!
        let changes = state.applyStats([.streams: 2, .mental: 2])
        var notes = TurnOutcome(consequence: "")
        ArtistLevel.gain(3, in: &state, outcome: &notes)
        return (fan, line, changes)
    }

    /// The beatboxer's challenge: Beatbox Simon, for real (no action spent).
    func startStreetBeatbox(in state: inout GameState) throws -> MinigameState {
        guard canVisit(state) else { throw GameEngineError.cannotVisit }
        let running = MinigameState(minigame: Arcade.beatbox)
        state.minigame = running
        return running
    }
}
