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

/// Rappeur or rappeuse: the texts agree with it (`TextTemplate`), and the sprite follows.
enum Gender: String, Codable, CaseIterable {
    case rappeur, rappeuse
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
                            line: "Tu lâches un sample de jazz de 1974 que personne n'a jamais déclaré. Trois avocats s'évanouissent au premier rang.", fx: .vinyl)
        case .trap:
            SecretTechnique(name: "L'Ad-lib Infini",
                            line: "Tu enchaînes 47 « skrrt » sans respirer. Un médecin dans le public commence à prendre des notes.", fx: .adlib)
        case .melancolique:
            SecretTechnique(name: "La Larme Unique",
                            line: "Une seule larme coule sur ta joue, au ralenti, pile sur le drop. Même la sécurité pleure.", fx: .tear)
        case .drill:
            SecretTechnique(name: "La Glissade de 808",
                            line: "Ta 808 glisse si bas que les vitres de la salle tremblent. Un voisin appelle la mairie.", fx: .bass)
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
    // Picked at creation; nil keeps the style's look.
    /// Index into Rapper.hairColors.
    var hairColor: Int?
    var hairStyle: CharacterLook.HairStyle?
    var hat: CharacterLook.Hat?
    var glasses: Bool?
    var beard: Bool?
    var chain: Bool?
    var headphones: Bool?
    var outfit: CharacterLook.Outfit?
    var earrings: Bool?
    /// Index into Rapper.outfitColors (nil: the first one).
    var outfitColor: Int?
    /// Saves from before the look had its own page wore their style's outfit; new characters don't:
    /// the style is how you rap, not how you dress.
    var lookFromStyle: Bool
    /// nil in saves from before the choice existed: rappeur.
    var genderChoice: Gender?

    var gender: Gender { genderChoice ?? .rappeur }

    init(name: String, city: City, style: Style, skinTone: Int = 2, hairColor: Int? = nil,
         hairStyle: CharacterLook.HairStyle? = nil, hat: CharacterLook.Hat? = nil, glasses: Bool? = nil,
         beard: Bool? = nil, chain: Bool? = nil, headphones: Bool? = nil,
         outfit: CharacterLook.Outfit? = nil, earrings: Bool? = nil, outfitColor: Int? = nil, gender: Gender = .rappeur) {
        genderChoice = gender
        self.outfitColor = outfitColor
        lookFromStyle = false
        self.outfit = outfit
        self.earrings = earrings
        self.name = name
        self.city = city
        self.style = style
        self.skinTone = skinTone
        self.hairColor = hairColor
        self.hairStyle = hairStyle
        self.hat = hat
        self.glasses = glasses
        self.beard = beard
        self.chain = chain
        self.headphones = headphones
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        city = try c.decode(City.self, forKey: .city)
        style = try c.decode(Style.self, forKey: .style)
        skinTone = try c.decodeIfPresent(Int.self, forKey: .skinTone) ?? 2
        hairColor = try c.decodeIfPresent(Int.self, forKey: .hairColor)
        hairStyle = try c.decodeIfPresent(CharacterLook.HairStyle.self, forKey: .hairStyle)
        hat = try c.decodeIfPresent(CharacterLook.Hat.self, forKey: .hat)
        glasses = try c.decodeIfPresent(Bool.self, forKey: .glasses)
        beard = try c.decodeIfPresent(Bool.self, forKey: .beard)
        chain = try c.decodeIfPresent(Bool.self, forKey: .chain)
        headphones = try c.decodeIfPresent(Bool.self, forKey: .headphones)
        outfit = try c.decodeIfPresent(CharacterLook.Outfit.self, forKey: .outfit)
        earrings = try c.decodeIfPresent(Bool.self, forKey: .earrings)
        genderChoice = try c.decodeIfPresent(Gender.self, forKey: .genderChoice)
        outfitColor = try c.decodeIfPresent(Int.self, forKey: .outfitColor)
        lookFromStyle = try c.decodeIfPresent(Bool.self, forKey: .lookFromStyle) ?? true
    }
}
