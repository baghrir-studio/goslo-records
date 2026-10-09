import Foundation

// The Punchliner's shared pool of verses (punchlines.json), and how a game draws from it without repeating itself:
// a verse never comes back within a game, and across games the ones never seen (or seen longest ago) come first.

/// A verse from the shared pool: a `PunchlinerRound` with an id, a theme, a difficulty tier and, for some, a city.
struct PunchlinerVerse: Codable, Equatable, Identifiable {
    let id: String
    /// « quartier », « nuit », « mere », « metro », « ville », « ambition », « doute », « argent », « amitie », « exil »…
    let theme: String
    /// 1 (the weaker endings are easy to spot) … 3 (they are close to the real punchline).
    let tier: Int
    /// Only offered in a career from this city (nil: everywhere).
    let city: City?
    let round: PunchlinerRound

    init(id: String, theme: String = "", tier: Int = 1, city: City? = nil, round: PunchlinerRound) {
        self.id = id
        self.theme = theme
        self.tier = tier
        self.city = city
        self.round = round
    }

    enum CodingKeys: String, CodingKey {
        case id, theme, tier, city, setup, lead, endings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? ""
        tier = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 1
        city = try c.decodeIfPresent(City.self, forKey: .city)
        round = PunchlinerRound(setup: try c.decode(String.self, forKey: .setup),
                                lead: try c.decode(String.self, forKey: .lead),
                                endings: try c.decode([PunchlinerAnswer].self, forKey: .endings))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(theme, forKey: .theme)
        try c.encode(tier, forKey: .tier)
        try c.encodeIfPresent(city, forKey: .city)
        try c.encode(round.setup, forKey: .setup)
        try c.encode(round.lead, forKey: .lead)
        try c.encode(round.endings, forKey: .endings)
    }

    /// Can a game of this tier, in a career from this city, offer it?
    func isOffered(maxTier: Int, city: City) -> Bool {
        tier <= maxTier && (self.city == nil || self.city == city)
    }
}

/// Draws the verses of a Punchliner game.
enum PunchlinerDeck {
    /// The highest tier: the arcade, and mini-games without a tier, offer every verse.
    static let maxTier = 3
    /// How many verse ids are remembered (more than the pool holds, so it can cycle through all of them).
    static let memory = 400

    /// The id of a mini-game's own verse (story.json), to remember it like a pool verse.
    static func authoredId(_ minigameId: String, index: Int) -> String { "\(minigameId)#\(index)" }

    /// The index of a mini-game's own verse in its `rounds`, from its id (nil for a pool verse).
    static func authoredIndex(_ id: String, minigameId: String) -> Int? {
        let prefix = "\(minigameId)#"
        guard id.hasPrefix(prefix) else { return nil }
        return Int(id.dropFirst(prefix.count))
    }

    /// `count` different verse ids. Verses never seen come first: the `preferred` ones in their order (a mini-game's
    /// own verses, so its story plays as written the first time), then the `pool` in random order. Only once every
    /// verse has been seen do the ones seen longest ago come back. `recent` is ordered oldest first.
    static func draw<R: RandomNumberGenerator>(count: Int, preferred: [String], pool: [String], recent: [String],
                                               using rng: inout R) -> [String] {
        var candidates: [String] = []
        for id in preferred + pool where !candidates.contains(id) { candidates.append(id) }
        let seenAt = Dictionary(recent.enumerated().map { ($1, $0) }, uniquingKeysWith: { max($0, $1) })
        let unseenPreferred = candidates.filter { seenAt[$0] == nil && preferred.contains($0) }
        let unseenPool = candidates.filter { seenAt[$0] == nil && !preferred.contains($0) }.shuffled(using: &rng)
        // Seen ones, least recently first (ties, which can't happen with a well-formed list, keep a random order).
        let seen = candidates.filter { seenAt[$0] != nil }.shuffled(using: &rng)
            .sorted { seenAt[$0, default: 0] < seenAt[$1, default: 0] }
        return Array((unseenPreferred + unseenPool + seen).prefix(max(0, count)))
    }

    /// `recent` with `ids` moved to its end (most recent), capped to `memory`.
    static func remember(_ ids: [String], in recent: [String]) -> [String] {
        let fresh = Set(ids)
        let kept = recent.filter { !fresh.contains($0) } + ids
        return Array(kept.suffix(memory))
    }
}

extension GameEngine {
    /// Starts a mini-game. A Punchliner game draws its verses: its own first (while never seen), then the shared pool
    /// (up to the mini-game's tier, and the career's city), never one twice in a game, the unseen ones first.
    func startMinigame(_ minigame: Minigame, in state: inout GameState, maxTier: Int? = nil) -> MinigameState {
        var rng = SystemRandomNumberGenerator()
        return startMinigame(minigame, in: &state, maxTier: maxTier, using: &rng)
    }

    func startMinigame<R: RandomNumberGenerator>(_ minigame: Minigame, in state: inout GameState, maxTier: Int? = nil,
                                                 using rng: inout R) -> MinigameState {
        var running = MinigameState(minigame: minigame)
        if minigame.kind == .punchliner, !minigame.rounds.isEmpty {
            let tier = maxTier ?? minigame.tier ?? PunchlinerDeck.maxTier
            let own = minigame.rounds.indices.map { PunchlinerDeck.authoredId(minigame.id, index: $0) }
            let pool = story.verses.filter { $0.isOffered(maxTier: tier, city: state.rapper.city) }.map(\.id)
            let ids = PunchlinerDeck.draw(count: minigame.rounds.count, preferred: own, pool: pool,
                                          recent: state.seenVerses, using: &rng)
            running.verses = ids
            state.seenVerses = PunchlinerDeck.remember(ids, in: state.seenVerses)
        }
        state.minigame = running
        return running
    }

    /// The verse with this id, for this mini-game (one of its own, or one from the pool).
    func punchlinerVerse(_ id: String, in minigame: Minigame) -> PunchlinerRound? {
        if let index = PunchlinerDeck.authoredIndex(id, minigameId: minigame.id) {
            return minigame.rounds.indices.contains(index) ? minigame.rounds[index] : nil
        }
        return story.verse(id)?.round
    }

    /// The verses of a Punchliner game, in order: the ones it drew, or (games started before the pool) its own.
    func punchlinerRounds(of running: MinigameState) -> [PunchlinerRound] {
        guard let minigame = minigame(running.id) else { return [] }
        guard let ids = running.verses else { return minigame.rounds }
        return ids.enumerated().compactMap { index, id in
            punchlinerVerse(id, in: minigame)
                ?? (minigame.rounds.isEmpty ? nil : minigame.rounds[index % minigame.rounds.count])
        }
    }

    /// The seed of the order the endings of round `index` are shown in: stable per verse.
    func punchlinerSeed(of running: MinigameState, round index: Int) -> UInt64 {
        guard let id = running.verses?[safe: index] else { return PunchlinerEngine.seed(running.id, round: index) }
        if let own = PunchlinerDeck.authoredIndex(id, minigameId: running.id) {
            return PunchlinerEngine.seed(running.id, round: own)
        }
        return PunchlinerEngine.seed(id, round: 0)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
