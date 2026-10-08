import Foundation

/// A character's outfit (colors in #RRGGBB hex). The sprites are drawn from it.
struct CharacterLook: Codable, Hashable {
    enum HairStyle: String, Codable, CaseIterable { case short, long, bald, puff, braids, fade, bun }
    enum Hat: String, Codable, CaseIterable { case none, cap, beanie, hood, bucket, bandana }
    enum Outfit: String, Codable, CaseIterable { case hoodie, jacket, jersey, puffer }
    /// Body shape, picked at creation (the sprites widen or narrow everything below the head).
    enum Build: String, Codable, CaseIterable { case slim, regular, strong, heavy }

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
    var build: Build = .regular
    var earrings = false
    /// Feminine features on the sprites: lashes, lips, slimmer shoulders.
    var feminine = false

    enum CodingKeys: String, CodingKey {
        case skin, hair, top, bottom, shoes, accent, hat, glasses, headphones, chain, beard, outfit, earrings, feminine, build
        case hairStyle = "hair_style"
    }

    init(skin: String = "#c68642", hair: String = "#1b1b1f", top: String = "#2b2b33", bottom: String = "#23232a",
         shoes: String = "#e8e8e8", accent: String = "#ff4d2e", hairStyle: HairStyle = .short, hat: Hat = .none,
         glasses: Bool = false, headphones: Bool = false, chain: Bool = false, beard: Bool = false,
         outfit: Outfit = .hoodie, earrings: Bool = false, feminine: Bool = false, build: Build = .regular) {
        self.feminine = feminine
        self.build = build
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
        feminine = try c.decodeIfPresent(Bool.self, forKey: .feminine) ?? false
        build = try c.decodeIfPresent(Build.self, forKey: .build) ?? .regular
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
    /// Outfit colors picked at creation: grey and denim, all black, midnight blue, burgundy, khaki, white.
    static let outfitColors: [(top: String, bottom: String, accent: String)] = [
        ("#6b6b75", "#2f4a7a", "#ff4d2e"),
        ("#16161a", "#16161a", "#e8c547"),
        ("#24304f", "#141418", "#8fa3c7"),
        ("#7a1f24", "#1a1a1f", "#f2f2f2"),
        ("#3f5a34", "#2a2a30", "#f2c14e"),
        ("#e8e4dc", "#3a3a44", "#e04fb0"),
    ]

    /// The player's look: the colors and options picked at creation (old saves start from their style's outfit).
    var look: CharacterLook {
        var look: CharacterLook
        if lookFromStyle {
            look = style.outfit
        } else {
            let colors = Rapper.outfitColors[min(max(outfitColor ?? 0, 0), Rapper.outfitColors.count - 1)]
            look = CharacterLook(top: colors.top, bottom: colors.bottom, shoes: "#f2f2f2", accent: colors.accent)
        }
        if gender == .rappeuse {
            look.feminine = true
            look.beard = false
            if look.hairStyle == .short { look.hairStyle = .bun }
        }
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
        if let build { look.build = build }
        look = dressed(look)
        if isHouseMember {
            // "Tu connais la maison": all gold.
            look.top = "#e8c547"; look.accent = "#f2f2f2"; look.bottom = "#16161a"; look.chain = true
        }
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
