import Foundation

/// Beatbox Simon: the beatboxer plays a pattern of sounds, you play it back. One more sound each round;
/// the first slip ends it.
enum BeatSound: String, CaseIterable, Codable {
    case boum, tchak, ts, wiki

    var label: String {
        switch self {
        case .boum: "BOUM"
        case .tchak: "TCHAK"
        case .ts: "TS"
        case .wiki: "WIKI"
        }
    }
}

enum BeatboxEngine {
    /// Sounds in the first pattern.
    static let startLength = 3
    /// Patterns to repeat (3 sounds, then 4… up to 10).
    static let rounds = 8
    static var maxLength: Int { startLength + rounds - 1 }

    /// Sounds to repeat in `round` (0-based).
    static func length(ofRound round: Int) -> Int { startLength + round }

    /// The whole pattern; each round plays a longer start of it. Never three times the same sound in a row.
    static func pattern<R: RandomNumberGenerator>(using rng: inout R) -> [BeatSound] {
        var sounds: [BeatSound] = []
        while sounds.count < maxLength {
            let next = BeatSound.allCases.randomElement(using: &rng)!
            if sounds.count >= 2, sounds.suffix(2).allSatisfy({ $0 == next }) { continue }
            sounds.append(next)
        }
        return sounds
    }

    static func reaction(repeated: Bool, round: Int) -> String {
        guard repeated else { return ["Raté. Le beatboxeur rigole : « Ça arrive aux meilleurs. Pas à moi, mais aux meilleurs. »",
                                      "Tu t'es emmêlé les lèvres. Le cercle applaudit quand même.",
                                      "Le beat s'arrête net. On rejoue demain."][round % 3] }
        return ["Propre.", "Il hoche la tête.", "Le cercle s'agrandit.", "Ça filme.", "Il n'en revient pas.",
                "Le quartier entier tape du pied.", "Il te tend la main : respect.", "Légendaire."][min(round, 7)]
    }
}

extension GameEngine {
    /// Beatbox Simon: the player played the pattern back (or slipped, which ends the game).
    func beatbox(repeated: Bool, in state: inout GameState) throws {
        guard var running = state.minigame, running.kind == .beatbox, !running.isOver else { throw GameEngineError.noMinigame }
        running.log.append(BeatboxEngine.reaction(repeated: repeated, round: running.round))
        if repeated {
            running.points += 1
            running.round += 1
        } else {
            running.round = running.roundCount
        }
        state.minigame = running
    }
}
