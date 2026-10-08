import Foundation

/// The daily clash: every day, the same opponent and the same crowd for every player, one attempt,
/// and a streak of days won in a row. Played outside the career, at a fixed level: only tactics count.
struct DailyChallenge: Equatable {
    /// The day, "yyyy-MM-dd".
    let day: String
    let opponentId: String
    let district: District

    var crowd: ClashMove { ClashTactics.crowdFavorite(in: district) }

    var spec: ClashSpec {
        ClashSpec(opponent: opponentId,
                  win: ClashResultSpec(consequence: "Le Clash du jour est à toi."),
                  lose: ClashResultSpec(consequence: "Le public a choisi l'autre. Reviens demain."))
    }
}

/// What the device remembers of the daily clash (saved with the achievements).
struct DailyRecord: Codable, Equatable {
    /// Last day an attempt was started (one per day).
    var lastPlayed: String?
    /// Last day won.
    var lastWon: String?
    /// Days won in a row, up to `lastWon`.
    var streak = 0
    var best = 0
    var wins = 0
    /// Result of the last attempt (for the home screen).
    var lastResultWon: Bool?

    func canPlay(on day: String) -> Bool { lastPlayed != day }

    /// The streak still alive today (won today or yesterday), else 0.
    func currentStreak(today: String, yesterday: String) -> Int {
        lastWon == today || lastWon == yesterday ? streak : 0
    }

    mutating func start(on day: String) {
        lastPlayed = day
        lastResultWon = nil
    }

    mutating func finish(on day: String, won: Bool, yesterday: String) {
        lastResultWon = won
        if won {
            streak = lastWon == yesterday ? streak + 1 : 1
            lastWon = day
            wins += 1
            best = max(best, streak)
        } else {
            streak = 0
        }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastPlayed = try c.decodeIfPresent(String.self, forKey: .lastPlayed)
        lastWon = try c.decodeIfPresent(String.self, forKey: .lastWon)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        best = try c.decodeIfPresent(Int.self, forKey: .best) ?? 0
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        lastResultWon = try c.decodeIfPresent(Bool.self, forKey: .lastResultWon)
    }
}

enum DailyClash {
    /// Everyone plays at this level in every skill.
    static let playerLevel = 7
    /// Rivals hard enough to be a challenge, never the final boss nor the street extras.
    static let averageStats: ClosedRange<Double> = 4...7

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func yesterdayKey(_ date: Date, calendar: Calendar = .current) -> String {
        dayKey(calendar.date(byAdding: .day, value: -1, to: date) ?? date, calendar: calendar)
    }

    /// Who can be the opponent of the day (sorted, so every device draws from the same list).
    static func pool(_ cast: [CastMember]) -> [CastMember] {
        cast.filter { member in
            guard !member.wild, member.cities == nil, let profile = member.clash else { return false }
            let average = Double(ClashMove.allCases.map(profile.stat).reduce(0, +)) / Double(ClashMove.allCases.count)
            return averageStats.contains(average)
        }
        .sorted { $0.id < $1.id }
    }

    /// The challenge of `day`: the same on every device.
    static func challenge(for day: String, cast: [CastMember]) -> DailyChallenge? {
        let pool = pool(cast)
        guard !pool.isEmpty else { return nil }
        // FNV-1a: a stable seed from the date (Swift's own hash changes on every launch).
        var seed: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in day.utf8 { seed = (seed ^ UInt64(byte)) &* 0x100_0000_01b3 }
        var rng = SeededGenerator(seed: seed)
        let opponent = pool[Int.random(in: 0..<pool.count, using: &rng)]
        let district = District.allCases[Int.random(in: 0..<District.allCases.count, using: &rng)]
        return DailyChallenge(day: day, opponentId: opponent.id, district: district)
    }

    /// The skills everyone plays with.
    static var skills: Skills {
        Skills(xp: Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, (playerLevel - 1) * Skills.xpPerLevel) }))
    }
}

extension GameEngine {
    func dailyChallenge(on date: Date = Date()) -> DailyChallenge? {
        DailyClash.challenge(for: DailyClash.dayKey(date), cast: world.cast)
    }

    /// A throwaway game for the daily clash: the player's look, the standard level, the clash ready.
    func dailyGame(_ challenge: DailyChallenge, rapper: Rapper) -> GameState {
        var state = newGame(rapper: rapper)
        state.pendingCinematic = nil
        state.skills = DailyClash.skills
        state.district = challenge.district
        var clash = ClashState(spec: challenge.spec)
        clash.crowdFavorite = challenge.crowd
        state.clash = clash
        return state
    }
}
