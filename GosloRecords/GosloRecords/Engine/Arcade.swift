import Foundation

/// The arcade, from the home screen: the mini-games, outside any career, at a standard level.
/// A few are free from the start; the others unlock with achievements (by playing careers).
struct ArcadeGame: Identifiable, Equatable {
    enum Mode: Equatable {
        case minigame(String)
        case concert(String)
        case freestyle
    }

    let id: String
    let title: String
    let pitch: String
    let mode: Mode
    /// nil = free from the start.
    let unlockedBy: Achievement?
    /// What the record counts.
    let unit: String
}

enum Arcade {
    /// Beatbox Simon lives in the arcade (no story.json entry).
    static let beatbox = Minigame(
        id: "arcade_beatbox", kind: .beatbox, title: "Beatbox Simon",
        intro: "Le beatboxeur du square lance un motif. Tu le rejoues, son par son. À chaque tour, un son de plus. Une erreur et c'est fini.",
        passScore: 0.5,
        win: InterviewResult(consequence: "Le cercle t'applaudit."),
        lose: InterviewResult(consequence: "Le beatboxeur te tape l'épaule : « Reviens t'entraîner. »"))

    static let games: [ArcadeGame] = [
        ArcadeGame(id: "beatbox", title: "Beatbox Simon", pitch: "Rejoue le motif du beatboxeur, un son de plus à chaque tour.",
                   mode: .minigame(beatbox.id), unlockedBy: nil, unit: "motifs"),
        ArcadeGame(id: "freestyle", title: "Freestyle", pitch: "Enchaîne les rimes avant la fin du beat.",
                   mode: .freestyle, unlockedBy: nil, unit: "rimes"),
        ArcadeGame(id: "platine", title: "Cale la platine", pitch: "Arrête le pitch de DJ Bobine pile sur 100 %.",
                   mode: .minigame("platine_bobine"), unlockedBy: nil, unit: "%"),
        ArcadeGame(id: "punchliner", title: "Punchliner", pitch: "Trouve la vraie fin de la punchline avant le chrono.",
                   mode: .minigame("punchliner_carnet"), unlockedBy: .premierChapitre, unit: "%"),
        ArcadeGame(id: "fuite", title: "Fuir la foule", pitch: "Traverse la foule jusqu'à la porte sans te faire attraper.",
                   mode: .minigame("fuite_transfo"), unlockedBy: .ringDesMots, unit: "évasions"),
        ArcadeGame(id: "concert", title: "Concert", pitch: "Tape les notes en rythme et fais monter le public.",
                   mode: .concert("premier_concert"), unlockedBy: .premiereScene, unit: "% de hype"),
    ]

    static func game(_ id: String) -> ArcadeGame? { games.first { $0.id == id } }

    static func isUnlocked(_ game: ArcadeGame, in profile: TrophyCase) -> Bool {
        game.unlockedBy.map { profile.unlocked.contains($0) } ?? true
    }

    /// The record kept for a finished mini-game: patterns for Beatbox Simon, escapes for the chase, else the score in %.
    static func score(of running: MinigameState, engine: GameEngine) -> Int {
        switch running.kind {
        case .beatbox: running.points
        case .fuite: running.escaped == true ? 1 : 0
        default: Int((engine.minigameScore(running) * 100).rounded())
        }
    }
}

extension TrophyCase {
    /// Best score per arcade game. Escapes add up instead.
    mutating func record(arcade game: ArcadeGame, score: Int) {
        if game.id == "fuite" {
            arcadeBest[game.id, default: 0] += score
        } else {
            arcadeBest[game.id] = max(arcadeBest[game.id] ?? 0, score)
        }
    }
}

extension GameEngine {
    /// A throwaway game to play an arcade game in (never saved).
    func arcadeGame(_ game: ArcadeGame, rapper: Rapper) -> GameState? {
        var state = newGame(rapper: rapper)
        state.pendingCinematic = nil
        state.skills = DailyClash.skills
        switch game.mode {
        case .minigame(let id):
            guard let minigame = minigame(id) else { return nil }
            state.minigame = MinigameState(minigame: minigame)
        case .concert(let id):
            guard let concert = concert(id) else { return nil }
            state.concert = ConcertState(concert: concert)
        case .freestyle:
            break
        }
        return state
    }
}
