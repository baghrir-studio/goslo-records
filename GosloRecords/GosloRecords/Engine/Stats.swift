import Foundation

/// The four career stats. Raw values are the keys used in events.json.
enum StatKind: String, Codable, CaseIterable, CodingKeyRepresentable, Identifiable {
    case streams
    case credibilite
    case argent
    case mental

    var id: String { rawValue }

    var label: String {
        switch self {
        case .streams: "Streams"
        case .credibilite: "Respect"
        case .argent: "Argent"
        case .mental: "Mental"
        }
    }

    var shortLabel: String {
        switch self {
        case .streams: "STREAMS"
        case .credibilite: "RESPECT"
        case .argent: "ARGENT"
        case .mental: "MENTAL"
        }
    }
}

/// Stat block. Every write goes through `clamp`, so values always stay within 0...100.
struct Stats: Codable, Equatable {
    static let range = 0...100

    private(set) var streams: Int
    private(set) var credibilite: Int
    private(set) var argent: Int
    private(set) var mental: Int

    init(streams: Int, credibilite: Int, argent: Int, mental: Int) {
        self.streams = Stats.clamp(streams)
        self.credibilite = Stats.clamp(credibilite)
        self.argent = Stats.clamp(argent)
        self.mental = Stats.clamp(mental)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            streams: try c.decode(Int.self, forKey: .streams),
            credibilite: try c.decode(Int.self, forKey: .credibilite),
            argent: try c.decode(Int.self, forKey: .argent),
            mental: try c.decode(Int.self, forKey: .mental)
        )
    }

    static func clamp(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    subscript(kind: StatKind) -> Int {
        get {
            switch kind {
            case .streams: streams
            case .credibilite: credibilite
            case .argent: argent
            case .mental: mental
            }
        }
        set {
            let value = Stats.clamp(newValue)
            switch kind {
            case .streams: streams = value
            case .credibilite: credibilite = value
            case .argent: argent = value
            case .mental: mental = value
            }
        }
    }

    /// Applies deltas and returns the changes actually applied after clamping
    /// (e.g. +10 at 95 yields +5). Zero changes are omitted.
    @discardableResult
    mutating func apply(_ effects: [StatKind: Int]) -> [StatKind: Int] {
        var applied: [StatKind: Int] = [:]
        for kind in StatKind.allCases {
            guard let delta = effects[kind], delta != 0 else { continue }
            let before = self[kind]
            self[kind] = before + delta
            let change = self[kind] - before
            if change != 0 { applied[kind] = change }
        }
        return applied
    }

    func adding(_ effects: [StatKind: Int]) -> Stats {
        var copy = self
        copy.apply(effects)
        return copy
    }
}

/// Career counters. Raw values are the keys used in events.json.
enum CounterKind: String, Codable, CaseIterable, CodingKeyRepresentable {
    case projets
    case disquesOr = "disques_or"
    case beefs
    case featurings
    case clashsGagnes = "clashs_gagnes"
    /// Wild clashes won in the terrain vague.
    case victoiresTerrain = "victoires_terrain"
}

struct Counters: Codable, Equatable {
    private var values: [CounterKind: Int] = [:]

    subscript(kind: CounterKind) -> Int {
        values[kind, default: 0]
    }

    mutating func increment(_ kind: CounterKind, by amount: Int = 1) {
        values[kind] = max(0, self[kind] + amount)
    }
}

/// RPG skills. Raw values are the keys used in the JSON files.
enum Skill: String, Codable, CaseIterable, CodingKeyRepresentable, Identifiable {
    case plume
    case flow
    case scene
    case business

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plume: "Plume"
        case .flow: "Flow"
        case .scene: "Scène"
        case .business: "Business"
        }
    }
}

/// Skill experience. Level = 1 + xp / xpPerLevel, capped at maxLevel.
struct Skills: Codable, Equatable {
    static let xpPerLevel = 60
    static let maxLevel = 10

    private var xp: [Skill: Int] = [:]

    init(xp: [Skill: Int] = [:]) {
        self.xp = xp.mapValues { max(0, $0) }
    }

    func xp(_ skill: Skill) -> Int {
        xp[skill, default: 0]
    }

    func level(_ skill: Skill) -> Int {
        min(Skills.maxLevel, 1 + xp(skill) / Skills.xpPerLevel)
    }

    /// Progress toward the next level (0...1); 1 at max level.
    func progress(_ skill: Skill) -> Double {
        guard level(skill) < Skills.maxLevel else { return 1 }
        return Double(xp(skill) % Skills.xpPerLevel) / Double(Skills.xpPerLevel)
    }

    /// Adds XP and returns the skills that gained a level.
    @discardableResult
    mutating func gain(_ gains: [Skill: Int]) -> [Skill] {
        var levelUps: [Skill] = []
        for skill in Skill.allCases {
            guard let amount = gains[skill], amount != 0 else { continue }
            let before = level(skill)
            xp[skill] = max(0, xp(skill) + amount)
            if level(skill) > before { levelUps.append(skill) }
        }
        return levelUps
    }
}
