import Foundation

enum City: String, Codable, CaseIterable, Identifiable {
    case paris = "Paris"
    case marseille = "Marseille"
    case lyon = "Lyon"
    case toulouse = "Toulouse"
    case lille = "Lille"
    case bruxelles = "Bruxelles"
    case montreal = "Montréal"
    case casablanca = "Casablanca"

    var id: String { rawValue }
}

enum Style: String, Codable, CaseIterable, Identifiable {
    case boomBap = "Boom bap"
    case trap = "Trap"
    case melancolique = "Mélancolique"
    case drill = "Drill"

    var id: String { rawValue }

    static let baseStats = Stats(streams: 20, credibilite: 30, argent: 30, mental: 60)

    /// Modifiers applied to `baseStats` at career start.
    var modifiers: [StatKind: Int] {
        switch self {
        case .boomBap: [.credibilite: 20, .streams: -5, .mental: 5]
        case .trap: [.streams: 12, .argent: 5, .credibilite: -10]
        case .melancolique: [.credibilite: 10, .streams: 5, .mental: -15]
        case .drill: [.credibilite: 12, .streams: 8, .mental: -8, .argent: -5]
        }
    }

    var startingStats: Stats { Style.baseStats.adding(modifiers) }

    /// Starting skill XP (60 XP = one level).
    var startingXP: [Skill: Int] {
        switch self {
        case .boomBap: [.plume: 60, .flow: 30]
        case .trap: [.flow: 60, .business: 30]
        case .melancolique: [.plume: 60, .scene: 30]
        case .drill: [.flow: 30, .scene: 60]
        }
    }

    /// The player's secret technique, depending on the style.
    var secret: SecretTechnique {
        switch self {
        case .boomBap:
            SecretTechnique(name: "Le Sample Interdit",
                            line: "Tu lâches un sample de jazz de 1974 que personne n'a jamais déclaré. Trois avocats s'évanouissent au premier rang.")
        case .trap:
            SecretTechnique(name: "L'Ad-lib Infini",
                            line: "Tu enchaînes 47 « skrrt » sans respirer. Un médecin dans le public commence à prendre des notes.")
        case .melancolique:
            SecretTechnique(name: "La Larme Unique",
                            line: "Une seule larme coule sur ta joue, au ralenti, pile sur le drop. Même la sécurité pleure.")
        case .drill:
            SecretTechnique(name: "La Glissade de 808",
                            line: "Ta 808 glisse si bas que les vitres de la salle tremblent. Un voisin appelle la mairie.")
        }
    }

    var pitch: String {
        switch self {
        case .boomBap: "Samples de jazz, casquette vissée, mépris poli pour tout ce qui est sorti après 2003."
        case .trap: "Autotune, ad-libs, et une relation compliquée avec le mot « bénéfice »."
        case .melancolique: "Piano triste, voix cassée. Tu pleures, ils streament."
        case .drill: "Glissandos de 808, cagoule en été. Les médias ont peur, le public adore."
        }
    }
}

struct Rapper: Codable, Equatable {
    static let maxNameLength = 24

    var name: String
    var city: City
    var style: Style
    /// Index into Rapper.skinTones.
    var skinTone: Int

    init(name: String, city: City, style: Style, skinTone: Int = 2) {
        self.name = name
        self.city = city
        self.style = style
        self.skinTone = skinTone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        city = try c.decode(City.self, forKey: .city)
        style = try c.decode(Style.self, forKey: .style)
        skinTone = try c.decodeIfPresent(Int.self, forKey: .skinTone) ?? 2
    }
}
