import Foundation

/// The artist level: XP from the Top, the season's challenges and clashes. Each level unlocks something.
enum ArtistLevel {
    enum Unlock: String, CaseIterable {
        case clip, radio, feat, crew, tournee

        /// Level that unlocks it.
        var level: Int {
            switch self {
            case .clip: 2
            case .radio: 3
            case .feat: 4
            case .crew: 5
            case .tournee: 6
            }
        }

        var label: String {
            switch self {
            case .clip: "Clips vidéo pour tes singles (+buzz dans le Top)"
            case .radio: "Passage sur goslo radio : +1 défi par saison, mieux payé"
            case .feat: "Featurings : invite un rival sur ton single"
            case .crew: "Crew : une 4e place pour tes cartes"
            case .tournee: "Tournée : chaque single dans le Top 3 rapporte double"
            }
        }
    }

    /// XP needed to reach each level (level 1 at 0).
    static let thresholds = [0, 60, 150, 270, 420, 600, 810, 1050, 1320, 1620]
    static var maxLevel: Int { thresholds.count }

    static let titles = [
        "Rappeur de cage d'escalier", "Espoir du quartier", "Nom qui circule", "Artiste en vue", "Valeur sûre",
        "Tête d'affiche", "Poids lourd", "Référence", "Monument", "Légende vivante",
    ]

    static func level(xp: Int) -> Int {
        thresholds.lastIndex { xp >= $0 }.map { $0 + 1 } ?? 1
    }

    /// 0…1 toward the next level (1 at the top).
    static func progress(xp: Int) -> Double {
        let level = level(xp: xp)
        guard level < maxLevel else { return 1 }
        let low = thresholds[level - 1], high = thresholds[level]
        return Double(xp - low) / Double(high - low)
    }

    static func title(xp: Int) -> String { titles[level(xp: xp) - 1] }

    static func unlocks(_ unlock: Unlock, in state: GameState) -> Bool {
        level(xp: state.artistXP) >= unlock.level
    }

    /// Adds XP and tells the player when a level is reached.
    static func gain(_ xp: Int, in state: inout GameState, outcome: inout TurnOutcome) {
        let before = level(xp: state.artistXP)
        state.artistXP += xp
        let after = level(xp: state.artistXP)
        guard after > before else { return }
        outcome.notes.append("NIVEAU \(after) : \(titles[after - 1]) !")
        for unlock in Unlock.allCases where unlock.level == after {
            outcome.notes.append("Débloqué : \(unlock.label).")
        }
    }
}

/// Three challenges a season (half a year): short goals that pay artist XP and a little money.
struct Challenge: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case clashes, topRank, single, refrain, respect, meet, terrain
    }

    let kind: Kind
    let target: Int
    /// The value when the season started (counters, refrains…).
    let baseline: Int
    var done = false

    var id: String { kind.rawValue }

    var label: String {
        switch kind {
        case .clashes: "Gagne \(target) clash\(target > 1 ? "s" : "")"
        case .topRank: target == 1 ? "Classe un single n°1 du Top" : "Classe un single dans le Top \(target)"
        case .single: "Sors \(target) single\(target > 1 ? "s" : "")"
        case .refrain: "Écris \(target) nouveau\(target > 1 ? "x" : "") refrain\(target > 1 ? "s" : "")"
        case .respect: "Atteins \(target) de respect"
        case .meet: "Rencontre \(target) nouvelles têtes"
        case .terrain: "Gagne \(target) duels au terrain vague"
        }
    }
}

enum Challenges {
    /// Turns in a season.
    static let seasonTurns = GameState.turnsPerYear / 2
    static let reward = (xp: 40, argent: 4)

    static func season(of turn: Int) -> Int { turn / seasonTurns }

    /// What the challenge counts now.
    static func value(_ kind: Challenge.Kind, in state: GameState) -> Int {
        switch kind {
        case .clashes: state.counters[.clashsGagnes]
        case .topRank: state.seasonBestRank ?? 99
        case .single: state.singles.count
        case .refrain: state.hooks.count
        case .respect: state.stats.credibilite
        case .meet: state.metCast.count
        case .terrain: state.counters[.victoiresTerrain]
        }
    }

    /// Progress toward the target (shown as "1 / 2").
    static func progress(_ challenge: Challenge, in state: GameState) -> Int {
        let now = value(challenge.kind, in: state)
        switch challenge.kind {
        case .topRank: return now <= challenge.target ? 1 : 0
        case .respect: return min(now, challenge.target)
        default: return min(challenge.target, max(0, now - challenge.baseline))
        }
    }

    static func goal(_ challenge: Challenge) -> Int {
        switch challenge.kind {
        case .topRank: 1
        default: challenge.target
        }
    }

    static func isMet(_ challenge: Challenge, in state: GameState) -> Bool {
        progress(challenge, in: state) >= goal(challenge)
    }

    /// The season's challenges: picked from what makes sense now, the same for the same career and season.
    static func draw(for state: GameState) -> [Challenge] {
        let season = season(of: state.turn)
        let level = ArtistLevel.level(xp: state.artistXP)
        var pool: [Challenge] = [
            Challenge(kind: .clashes, target: level >= 5 ? 3 : 2, baseline: value(.clashes, in: state)),
            Challenge(kind: .refrain, target: 1, baseline: value(.refrain, in: state)),
            Challenge(kind: .meet, target: 2, baseline: value(.meet, in: state)),
            Challenge(kind: .terrain, target: level >= 4 ? 4 : 2, baseline: value(.terrain, in: state)),
            Challenge(kind: .respect, target: min(90, max(30, state.stats.credibilite + 8)), baseline: 0),
        ]
        if state.chapter >= ChartRules.fromChapter {
            pool.append(Challenge(kind: .single, target: 1, baseline: value(.single, in: state)))
            pool.append(Challenge(kind: .topRank, target: level >= 6 ? 1 : (level >= 3 ? 3 : 5), baseline: 0))
        }
        let count = 3 + (ArtistLevel.unlocks(.radio, in: state) ? 1 : 0) + (state.flags.contains(HQ.radioFlag) ? 1 : 0)
        let seed = GameEngine.fnv("\(state.id.uuidString)\(season)")
        return pool.enumerated()
            .sorted { GameEngine.fnv("\(seed)\($0.offset)") < GameEngine.fnv("\(seed)\($1.offset)") }
            .prefix(count).map(\.element)
    }
}

extension GameEngine {
    /// New season: new challenges, the season's best rank forgotten.
    func refreshChallenges(in state: inout GameState) {
        let season = Challenges.season(of: state.turn)
        guard state.challengeSeason != season else { return }
        state.challengeSeason = season
        state.seasonBestRank = nil
        state.challenges = Challenges.draw(for: state)
    }

    /// Pays the challenges just met.
    func checkChallenges(_ outcome: inout TurnOutcome, in state: inout GameState) {
        let radio = ArtistLevel.unlocks(.radio, in: state)
        for index in state.challenges.indices where !state.challenges[index].done {
            guard Challenges.isMet(state.challenges[index], in: state) else { continue }
            state.challenges[index].done = true
            outcome.notes.append("Défi réussi : \(state.challenges[index].label) !")
            outcome.add(state.stats.apply([.argent: Challenges.reward.argent + (radio ? 2 : 0)]))
            ArtistLevel.gain(Challenges.reward.xp, in: &state, outcome: &outcome)
        }
    }
}
