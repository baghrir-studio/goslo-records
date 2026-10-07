import Foundation

/// A character's outfit (colors in #RRGGBB hex). The sprites are drawn from it.
struct CharacterLook: Codable, Hashable {
    enum HairStyle: String, Codable, CaseIterable { case short, long, bald, puff, braids, fade }
    enum Hat: String, Codable, CaseIterable { case none, cap, beanie, hood, bucket, bandana }
    enum Outfit: String, Codable, CaseIterable { case hoodie, jacket, jersey, puffer }

    var skin = "#c68642"
    var hair = "#1b1b1f"
    var top = "#2b2b33"
    var bottom = "#23232a"
    var shoes = "#e8e8e8"
    var accent = "#ff4d2e"
    var hairStyle: HairStyle = .short
    var hat: Hat = .none
    var glasses = false
    var headphones = false
    var chain = false
    var beard = false
    var outfit: Outfit = .hoodie
    var earrings = false

    enum CodingKeys: String, CodingKey {
        case skin, hair, top, bottom, shoes, accent, hat, glasses, headphones, chain, beard, outfit, earrings
        case hairStyle = "hair_style"
    }

    init(skin: String = "#c68642", hair: String = "#1b1b1f", top: String = "#2b2b33", bottom: String = "#23232a",
         shoes: String = "#e8e8e8", accent: String = "#ff4d2e", hairStyle: HairStyle = .short, hat: Hat = .none,
         glasses: Bool = false, headphones: Bool = false, chain: Bool = false, beard: Bool = false,
         outfit: Outfit = .hoodie, earrings: Bool = false) {
        self.outfit = outfit
        self.earrings = earrings
        self.skin = skin
        self.hair = hair
        self.top = top
        self.bottom = bottom
        self.shoes = shoes
        self.accent = accent
        self.hairStyle = hairStyle
        self.hat = hat
        self.glasses = glasses
        self.headphones = headphones
        self.chain = chain
        self.beard = beard
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = CharacterLook()
        skin = try c.decodeIfPresent(String.self, forKey: .skin) ?? base.skin
        hair = try c.decodeIfPresent(String.self, forKey: .hair) ?? base.hair
        top = try c.decodeIfPresent(String.self, forKey: .top) ?? base.top
        bottom = try c.decodeIfPresent(String.self, forKey: .bottom) ?? base.bottom
        shoes = try c.decodeIfPresent(String.self, forKey: .shoes) ?? base.shoes
        accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? base.accent
        hairStyle = try c.decodeIfPresent(HairStyle.self, forKey: .hairStyle) ?? base.hairStyle
        hat = try c.decodeIfPresent(Hat.self, forKey: .hat) ?? base.hat
        glasses = try c.decodeIfPresent(Bool.self, forKey: .glasses) ?? false
        headphones = try c.decodeIfPresent(Bool.self, forKey: .headphones) ?? false
        chain = try c.decodeIfPresent(Bool.self, forKey: .chain) ?? false
        beard = try c.decodeIfPresent(Bool.self, forKey: .beard) ?? false
        outfit = try c.decodeIfPresent(Outfit.self, forKey: .outfit) ?? .hoodie
        earrings = try c.decodeIfPresent(Bool.self, forKey: .earrings) ?? false
    }

    /// The colors, to check they're valid hex.
    var colors: [String] { [skin, hair, top, bottom, shoes, accent] }

    static func isValidHex(_ value: String) -> Bool {
        value.count == 7 && value.first == "#" && UInt32(value.dropFirst(), radix: 16) != nil
    }
}

extension Rapper {
    static let skinTones = ["#f1c9a5", "#e0ac7e", "#c68642", "#8d5524", "#5a3825"]
    /// Black, brown, auburn, blond, grey.
    static let hairColors = ["#1b1b1f", "#5a3a22", "#9a4a24", "#d9bf73", "#9a9aa6"]

    /// The player's outfit: set by the style, then the skin tone and whatever was picked at creation.
    var look: CharacterLook {
        var look = style.outfit
        look.skin = Rapper.skinTones[min(max(skinTone, 0), Rapper.skinTones.count - 1)]
        if let hairColor { look.hair = Rapper.hairColors[min(max(hairColor, 0), Rapper.hairColors.count - 1)] }
        if let hairStyle { look.hairStyle = hairStyle }
        if let hat { look.hat = hat }
        if let glasses { look.glasses = glasses }
        if let beard { look.beard = beard }
        if let chain { look.chain = chain }
        if let headphones { look.headphones = headphones }
        if let outfit { look.outfit = outfit }
        if let earrings { look.earrings = earrings }
        return look
    }
}

extension Style {
    var outfit: CharacterLook {
        switch self {
        case .boomBap:
            CharacterLook(top: "#6b6b75", bottom: "#2f4a7a", shoes: "#c8a165", accent: "#ff4d2e", hat: .cap)
        case .trap:
            CharacterLook(top: "#16161a", bottom: "#16161a", shoes: "#f2f2f2", accent: "#e8c547",
                          hairStyle: .short, glasses: true, chain: true)
        case .melancolique:
            CharacterLook(top: "#24304f", bottom: "#141418", shoes: "#3a3a44", accent: "#8fa3c7", hat: .hood)
        case .drill:
            CharacterLook(top: "#101012", bottom: "#101012", shoes: "#f2f2f2", accent: "#ff4d2e", hat: .beanie)
        }
    }
}
