import Foundation

/// The four clash moves, each tied to one skill.
enum ClashMove: String, Codable, CaseIterable, CodingKeyRepresentable, Identifiable {
    case punchline
    case flow
    case presence
    case story

    var id: String { rawValue }

    var skill: Skill {
        switch self {
        case .punchline: .plume
        case .flow: .flow
        case .presence: .scene
        case .story: .business
        }
    }

    var label: String {
        switch self {
        case .punchline: "Punchline"
        case .flow: "Flow"
        case .presence: "Présence"
        case .story: "Story Insta"
        }
    }

    var hint: String {
        switch self {
        case .punchline: "Gros dégâts, peut rater"
        case .flow: "Fiable, ne rate jamais"
        case .presence: "Booste ton coup suivant"
        case .story: "Efficace, coûte \(ClashState.storyCredCost) de respect"
        }
    }

    var baseDamage: Int {
        switch self {
        case .punchline: 8
        case .flow: 6
        case .presence: 4
        case .story: 10
        }
    }

    var damagePerLevel: Int {
        switch self {
        case .punchline: 3
        default: 2
        }
    }

    /// Miss chance (%) at a given level.
    func missChance(level: Int) -> Int {
        switch self {
        case .punchline: max(5, 40 - 4 * level)
        case .story: 15
        case .flow, .presence: 0
        }
    }
}

/// Clash triggered by a choice: opponent + outcome on win and on loss.
struct ClashSpec: Codable, Equatable {
    let opponent: String
    let win: ClashResultSpec
    let lose: ClashResultSpec
    /// Boss clash: special intro, stronger opponent, more rounds.
    let boss: Bool
    let rounds: Int
    let levelBonus: Int
    /// How hard the opponent hits (default: `ClashState.opponentDamageFactor`). For bosses already at max stats.
    let opponentPower: Double?

    enum CodingKeys: String, CodingKey {
        case opponent, win, lose, boss, rounds
        case levelBonus = "level_bonus"
        case opponentPower = "opponent_power"
    }

    init(opponent: String, win: ClashResultSpec, lose: ClashResultSpec, boss: Bool = false,
         rounds: Int = ClashState.maxRounds, levelBonus: Int = 0, opponentPower: Double? = nil) {
        self.opponent = opponent
        self.win = win
        self.lose = lose
        self.boss = boss
        self.rounds = rounds
        self.levelBonus = levelBonus
        self.opponentPower = opponentPower
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        opponent = try c.decode(String.self, forKey: .opponent)
        win = try c.decode(ClashResultSpec.self, forKey: .win)
        lose = try c.decode(ClashResultSpec.self, forKey: .lose)
        opponentPower = try c.decodeIfPresent(Double.self, forKey: .opponentPower)
        boss = try c.decodeIfPresent(Bool.self, forKey: .boss) ?? false
        rounds = max(1, try c.decodeIfPresent(Int.self, forKey: .rounds) ?? ClashState.maxRounds)
        levelBonus = try c.decodeIfPresent(Int.self, forKey: .levelBonus) ?? 0
    }
}

struct ClashResultSpec: Codable, Equatable {
    let effects: [StatKind: Int]
    let consequence: String
    /// Story flags set by this result (on top of the automatic `clash_gagne_<id>`).
    let setFlags: [String]

    enum CodingKeys: String, CodingKey {
        case effects, consequence
        case setFlags = "set_flags"
    }

    init(effects: [StatKind: Int] = [:], consequence: String, setFlags: [String] = []) {
        self.effects = effects
        self.consequence = consequence
        self.setFlags = setFlags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effects = try c.decodeIfPresent([StatKind: Int].self, forKey: .effects) ?? [:]
        consequence = try c.decode(String.self, forKey: .consequence)
        setFlags = try c.decodeIfPresent([String].self, forKey: .setFlags) ?? []
    }
}

enum ClashImpact: String, Codable {
    case normal
    case strong
    case weak
    case miss
}

/// Secret technique: unlocked once enough damage has been dealt, usable once per clash.
struct SecretTechnique: Codable, Equatable {
    let name: String
    let line: String
}

struct ClashLogEntry: Codable, Equatable, Identifiable {
    let id: Int
    let byPlayer: Bool
    /// Move played (ignored when `secret` is set).
    let move: ClashMove
    let damage: Int
    let impact: ClashImpact
    let line: String
    /// Secret technique used this round, if any.
    var secret: SecretTechnique? = nil
}

/// State of a clash in progress (saved with the game).
struct ClashState: Codable, Equatable {
    static let startingHype = 100
    static let maxRounds = 4
    static let storyCredCost = 4
    static let weaknessMultiplier = 1.5
    static let resistanceMultiplier = 0.6
    static let boostMultiplier = 1.5
    /// Opponents hit a little softer: the player has to stand a chance against the first rivals.
    static let opponentDamageFactor = 0.85
    /// Damage to deal before you can trigger your secret technique.
    static let secretThreshold = 35

    let spec: ClashSpec
    /// Clash in the terrain vague: no action spent, rewards in XP.
    var isWild = false
    /// Bonus added to a wild opponent's stats.
    var levelBonus = 0
    /// The share of the crowd on each side (the clash's "HP").
    var playerHype = startingHype
    var opponentHype = startingHype
    var round = 1
    var playerBoosted = false
    var opponentBoosted = false
    var log: [ClashLogEntry] = []
    /// Damage dealt by each side (fills the secret technique gauge).
    var playerMeter = 0
    var opponentMeter = 0
    var playerSecretUsed = false
    var opponentSecretUsed = false

    init(spec: ClashSpec, isWild: Bool = false, levelBonus: Int? = nil) {
        self.spec = spec
        self.isWild = isWild
        self.levelBonus = levelBonus ?? spec.levelBonus
    }

    enum CodingKeys: String, CodingKey {
        case spec, isWild, levelBonus, playerHype, opponentHype, round, playerBoosted, opponentBoosted, log
        case playerMeter, opponentMeter, playerSecretUsed, opponentSecretUsed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spec = try c.decode(ClashSpec.self, forKey: .spec)
        isWild = try c.decodeIfPresent(Bool.self, forKey: .isWild) ?? false
        levelBonus = try c.decodeIfPresent(Int.self, forKey: .levelBonus) ?? 0
        playerHype = try c.decode(Int.self, forKey: .playerHype)
        opponentHype = try c.decode(Int.self, forKey: .opponentHype)
        round = try c.decode(Int.self, forKey: .round)
        playerBoosted = try c.decodeIfPresent(Bool.self, forKey: .playerBoosted) ?? false
        opponentBoosted = try c.decodeIfPresent(Bool.self, forKey: .opponentBoosted) ?? false
        log = try c.decodeIfPresent([ClashLogEntry].self, forKey: .log) ?? []
        // Saves from before secret techniques existed.
        playerMeter = try c.decodeIfPresent(Int.self, forKey: .playerMeter) ?? 0
        opponentMeter = try c.decodeIfPresent(Int.self, forKey: .opponentMeter) ?? 0
        playerSecretUsed = try c.decodeIfPresent(Bool.self, forKey: .playerSecretUsed) ?? false
        opponentSecretUsed = try c.decodeIfPresent(Bool.self, forKey: .opponentSecretUsed) ?? false
    }

    var movesUsed: Set<ClashMove> { Set(log.filter { $0.byPlayer && $0.secret == nil }.map(\.move)) }
    var playerSecretReady: Bool { !playerSecretUsed && playerMeter >= ClashState.secretThreshold }
    var opponentSecretReady: Bool { !opponentSecretUsed && opponentMeter >= ClashState.secretThreshold }

    var opponentId: String { spec.opponent }
    var rounds: Int { spec.rounds }
    var isBoss: Bool { spec.boss }
    var damageFactor: Double { spec.opponentPower ?? ClashState.opponentDamageFactor }
    var isOver: Bool { playerHype <= 0 || opponentHype <= 0 || round > rounds }
    /// A tie goes to the opponent: the crowd wanted a clear winner.
    var playerWon: Bool { playerHype > 0 && playerHype > opponentHype }
}

/// Pure clash rules.
enum ClashEngine {
    static func damage<R: RandomNumberGenerator>(move: ClashMove, level: Int, boosted: Bool, multiplier: Double,
                                                 using rng: inout R) -> (Int, ClashImpact) {
        let level = min(max(level, 1), 10)
        if Int.random(in: 0..<100, using: &rng) < move.missChance(level: level) {
            return (0, .miss)
        }
        var value = Double(move.baseDamage + move.damagePerLevel * level)
        value *= Double.random(in: 0.8...1.2, using: &rng)
        value *= multiplier
        if boosted { value *= ClashState.boostMultiplier }
        let impact: ClashImpact = multiplier >= ClashState.weaknessMultiplier ? .strong
            : (multiplier <= ClashState.resistanceMultiplier ? .weak : .normal)
        return (max(1, Int(value.rounded())), impact)
    }

    static func multiplier(for move: ClashMove, against profile: ClashProfile) -> Double {
        if move == profile.weakness { return ClashState.weaknessMultiplier }
        if move == profile.resistance { return ClashState.resistanceMultiplier }
        return 1
    }

    /// The opponent favors its strongest moves (weight = stat²).
    static func opponentMove<R: RandomNumberGenerator>(_ profile: ClashProfile, using rng: inout R) -> ClashMove {
        let weights = ClashMove.allCases.map { profile.stat($0) * profile.stat($0) }
        var roll = Int.random(in: 0..<weights.reduce(0, +), using: &rng)
        for (move, weight) in zip(ClashMove.allCases, weights) {
            roll -= weight
            if roll < 0 { return move }
        }
        return .flow
    }

    /// Secret technique damage: never misses, ignores resistances.
    static func secretDamage<R: RandomNumberGenerator>(level: Int, factor: Double = 1, using rng: inout R) -> Int {
        let base = Double(22 + 3 * min(max(level, 1), 10)) * Double.random(in: 0.9...1.1, using: &rng)
        return max(1, Int((base * factor).rounded()))
    }

    /// One round: the player hits (move or secret technique), then the opponent answers if still standing.
    /// The opponent triggers its own technique as soon as its gauge is full.
    static func playRound<R: RandomNumberGenerator>(_ state: inout ClashState, playerMove: ClashMove,
                                                    playerSecret: SecretTechnique? = nil,
                                                    playerLevel: (Skill) -> Int, opponent: ClashProfile,
                                                    opponentName: String, opponentSecret: SecretTechnique? = nil,
                                                    using rng: inout R) {
        guard !state.isOver else { return }

        if let secret = playerSecret, state.playerSecretReady {
            let average = Skill.allCases.map(playerLevel).reduce(0, +) / Skill.allCases.count
            let hit = secretDamage(level: average, using: &rng)
            state.playerSecretUsed = true
            state.playerBoosted = false
            state.opponentHype = max(0, state.opponentHype - hit)
            state.log.append(ClashLogEntry(id: state.log.count, byPlayer: true, move: playerMove, damage: hit,
                                           impact: .strong, line: secret.line, secret: secret))
        } else {
            let (playerDamage, playerImpact) = damage(move: playerMove, level: playerLevel(playerMove.skill),
                                                      boosted: state.playerBoosted,
                                                      multiplier: multiplier(for: playerMove, against: opponent), using: &rng)
            state.playerBoosted = playerMove == .presence && playerImpact != .miss
            state.opponentHype = max(0, state.opponentHype - playerDamage)
            state.playerMeter += playerDamage
            state.log.append(ClashLogEntry(id: state.log.count, byPlayer: true, move: playerMove, damage: playerDamage,
                                           impact: playerImpact, line: ClashLines.player(playerMove, impact: playerImpact, using: &rng)))
        }

        if state.opponentHype > 0 {
            if state.opponentSecretReady {
                let secret = opponentSecret ?? ClashLines.defaultSecret(for: opponentName)
                let hit = secretDamage(level: opponent.level, factor: state.damageFactor, using: &rng)
                state.opponentSecretUsed = true
                state.opponentBoosted = false
                state.playerHype = max(0, state.playerHype - hit)
                state.log.append(ClashLogEntry(id: state.log.count, byPlayer: false, move: .presence, damage: hit,
                                               impact: .strong, line: secret.line, secret: secret))
            } else {
                let move = opponentMove(opponent, using: &rng)
                let (opponentDamage, opponentImpact) = damage(move: move, level: opponent.stat(move),
                                                              boosted: state.opponentBoosted,
                                                              multiplier: state.damageFactor, using: &rng)
                state.opponentBoosted = move == .presence && opponentImpact != .miss
                state.playerHype = max(0, state.playerHype - opponentDamage)
                state.opponentMeter += opponentDamage
                state.log.append(ClashLogEntry(id: state.log.count, byPlayer: false, move: move, damage: opponentDamage,
                                               impact: opponentImpact,
                                               line: ClashLines.opponent(move, impact: opponentImpact, name: opponentName,
                                                                         taunts: opponent.taunts, using: &rng)))
            }
        }
        state.round += 1
    }
}

/// Clash commentary. Original lines only, no real lyrics.
enum ClashLines {
    static func defaultSecret(for name: String) -> SecretTechnique {
        SecretTechnique(name: "Coup de Grâce",
                        line: "\(name) sort sa botte secrète. Personne n'a compris ce qui s'est passé, mais tout le monde a crié.")
    }

    static func player<R: RandomNumberGenerator>(_ move: ClashMove, impact: ClashImpact, using rng: inout R) -> String {
        if impact == .miss {
            return [
                "Ta punchline arrive deux temps trop tard. Le public te regarde avec pitié.",
                "Tu as rimé « baskets » avec « baskets ». Silence de mort.",
                "Ta story fait 12 vues, dont 3 de ta mère.",
            ].randomElement(using: &rng)!
        }
        let lines: [String]
        switch move {
        case .punchline: lines = [
            "Double sens, triple rime, le public met trois secondes à comprendre puis explose.",
            "Tu sors la punchline écrite à 4h du matin. Elle valait le manque de sommeil.",
            "Une métaphore filée sur trois mesures. Même son DJ a hoché la tête.",
        ]
        case .flow: lines = [
            "Tu changes de flow en plein milieu de la mesure. Propre, chirurgical.",
            "Débit en rafale, pas une syllabe à côté. La salle suit.",
            "Tu poses sur le contretemps. Les puristes notent ça dans leur carnet.",
        ]
        case .presence: lines = [
            "Tu descends dans la fosse. La salle est à toi, et elle s'en souviendra au prochain couplet.",
            "Tu lèves la main, 2 000 personnes la lèvent avec toi.",
            "Un regard caméra de huit secondes. Le live Insta s'emballe.",
        ]
        case .story: lines = [
            "Tu postes une capture de ses vieux tweets. Coup bas, mais efficace.",
            "Story avec un sticker clown. Internet s'enflamme.",
            "Tu révèles ses chiffres de ventes en story. Les commentaires sont en feu.",
        ]
        }
        return lines.randomElement(using: &rng)!
    }

    static func opponent<R: RandomNumberGenerator>(_ move: ClashMove, impact: ClashImpact, name: String,
                                                   taunts: [String], using rng: inout R) -> String {
        if impact == .miss {
            return "\(name) bafouille son couplet. Quelqu'un tousse dans la salle."
        }
        if !taunts.isEmpty, Int.random(in: 0..<100, using: &rng) < 45 {
            return "\(name) : « \(taunts.randomElement(using: &rng)!) »"
        }
        switch move {
        case .punchline: return "\(name) te découpe en une rime. Le public fait « ooooh »."
        case .flow: return "\(name) déroule son flow sans respirer. Impressionnant, agaçant."
        case .presence: return "\(name) fait chanter toute la salle. Le prochain coup va faire mal."
        case .story: return "\(name) poste une photo de toi à 15 ans. Le coup est bas. Il porte."
        }
    }
}
