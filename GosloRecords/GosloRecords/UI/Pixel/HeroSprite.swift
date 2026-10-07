import UIKit

/// The detailed character (40×56), drawn from the same `CharacterLook` as the map sprite.
/// Used wherever a character is shown large: creation, clashes, cinematics, dialogue portraits, concerts.
/// The map keeps the 16×16 `CharacterSprite`, which matches its tiles.
/// Frames: 0 = standing, 1 and 2 = walk steps. Only front (down) and back (up) views.
@MainActor
enum HeroSprite {
    static let width = 40
    static let height = 56

    static func image(_ look: CharacterLook, facing: Direction, frame: Int = 0) -> UIImage {
        let back = facing == .up
        return PixelCache.image("hero-\(look.hashValue)-\(back)-\(frame)") {
            (back ? backView(look, frame: frame) : front(look, frame: frame)).outlined().makeImage()
        }
    }

    /// Head and shoulders, for dialogue portraits.
    static func bust(_ look: CharacterLook) -> UIImage {
        PixelCache.image("hero-bust-\(look.hashValue)") {
            let full = front(look, frame: 0).outlined()
            let crop = PixelCanvas(width: 34, height: 34)
            crop.stamp(full, at: -3, 0)
            return crop.makeImage()
        }
    }

    private struct Palette {
        let skin, skinShade, skinLight, hair, hairShade, hairLight: PixelColor
        let top, topShade, topLight, bottom, bottomShade, bottomLight: PixelColor
        let shoes, shoesShade, sole, accent, accentShade, accentLight, mouth: PixelColor
        let eye = PixelColor(hex: "#141418")
        let white = PixelColor(hex: "#f2efe8")
        let lens = PixelColor(hex: "#1a1a22")
        let lensShine = PixelColor(hex: "#5a6a80")
        let gear = PixelColor(hex: "#2a2a30")

        init(_ look: CharacterLook) {
            func brightness(_ c: PixelColor) -> Int { Int(c.r) + Int(c.g) + Int(c.b) }
            skin = PixelColor(hex: look.skin)
            skinShade = skin.shaded(0.82)
            skinLight = skin.shaded(1.1)
            hair = PixelColor(hex: look.hair)
            hairShade = hair.shaded(0.7)
            hairLight = brightness(hair) > 120 ? hair.shaded(1.35) : PixelColor(r: 70, g: 70, b: 80)
            top = PixelColor(hex: look.top)
            topShade = top.shaded(0.72)
            topLight = brightness(top) > 90 ? top.shaded(1.18) : PixelColor(r: 58, g: 58, b: 68)
            bottom = PixelColor(hex: look.bottom)
            bottomShade = bottom.shaded(0.7)
            bottomLight = brightness(bottom) > 90 ? bottom.shaded(1.2) : PixelColor(r: 50, g: 50, b: 60)
            shoes = PixelColor(hex: look.shoes)
            shoesShade = shoes.shaded(0.75)
            sole = brightness(shoes) < 600 ? PixelColor(hex: "#f2f2f2") : PixelColor(hex: "#bdbdc4")
            accent = PixelColor(hex: look.accent)
            accentShade = accent.shaded(0.7)
            accentLight = accent.shaded(1.25)
            mouth = skin.shaded(0.6)
        }
    }

    // MARK: Views

    private static func front(_ look: CharacterLook, frame: Int) -> PixelCanvas {
        let c = PixelCanvas(width: width, height: height)
        let p = Palette(look)
        hairBehind(c, look, p)
        body(c, look, p, frame: frame, back: false)
        face(c, look, p)
        headwear(c, look, p)
        return c
    }

    private static func backView(_ look: CharacterLook, frame: Int) -> PixelCanvas {
        let c = PixelCanvas(width: width, height: height)
        let p = Palette(look)
        body(c, look, p, frame: frame, back: true)
        let shaved = look.hairStyle == .bald || look.hairStyle == .fade
        let base = shaved ? p.skin : p.hair
        c.fill(13, 6, 26, 20, base); c.fill(12, 8, 27, 18, base)
        c.fill(11, 12, 11, 15, p.skin); c.fill(28, 12, 28, 15, p.skinShade)
        if shaved {
            c.fill(24, 8, 27, 18, p.skinShade); c.fill(15, 8, 17, 9, p.skinLight)
        } else {
            c.fill(14, 18, 25, 20, p.hairShade)
            c.fill(24, 6, 27, 18, p.hairShade)
            c.fill(14, 6, 17, 8, p.hairLight)
        }
        switch look.hat {
        case .none:
            switch look.hairStyle {
            case .puff:
                c.ellipse(19.5, 8, 12.5, 9.5, p.hair); c.ellipse(24, 9, 7, 7, p.hairShade); c.ellipse(18, 7, 8, 6, p.hair)
            case .long:
                c.fill(10, 6, 29, 25, p.hair); c.fill(11, 26, 28, 28, p.hair)
                c.fill(26, 8, 29, 25, p.hairShade); c.fill(26, 26, 28, 28, p.hairShade)
                c.fill(19, 7, 19, 27, p.hairShade); c.fill(13, 7, 16, 9, p.hairLight)
                c.dot(11, 28, .clear); c.dot(28, 28, .clear)
            case .short:
                c.fill(13, 3, 26, 8, p.hair); c.fill(15, 2, 24, 2, p.hair); c.fill(23, 3, 26, 9, p.hairShade)
            case .fade:
                c.fill(13, 2, 26, 7, p.hair); c.fill(14, 1, 25, 1, p.hair); c.fill(12, 8, 27, 9, p.hair)
                for y in [10, 11] {
                    for x in 12..<28 where (x + y) % 2 == 0 { c.dot(x, y, p.hair) }
                }
            case .braids:
                for x in stride(from: 12, to: 28, by: 3) { c.fill(x, 3, x, 18, p.hairShade) }
                for x in stride(from: 12, to: 28, by: 3) {
                    c.fill(x + 1, 19, x + 1, 31, p.hair); c.dot(x + 1, 32, p.accent)
                }
            case .bald:
                break
            }
        case .cap:
            c.fill(12, 2, 27, 9, p.accent); c.fill(13, 1, 26, 1, p.accent); c.fill(24, 2, 27, 9, p.accentShade)
            c.fill(17, 8, 22, 10, base); c.fill(17, 8, 22, 8, p.gear)
        case .beanie:
            c.fill(12, 3, 27, 10, p.accent); c.fill(13, 2, 26, 2, p.accent); c.fill(15, 1, 24, 1, p.accent)
            c.fill(24, 2, 27, 10, p.accentShade); c.fill(11, 8, 28, 11, p.accentShade)
            for x in stride(from: 12, to: 28, by: 2) { c.fill(x, 8, x, 11, p.accentShade.shaded(0.8)) }
        case .bucket:
            c.fill(13, 2, 26, 7, p.accent); c.fill(14, 1, 25, 1, p.accent); c.fill(23, 2, 26, 7, p.accentShade)
            c.fill(10, 8, 29, 8, p.accent); c.fill(9, 9, 30, 10, p.accentShade)
        case .bandana:
            c.fill(12, 3, 27, 9, p.accent); c.fill(14, 2, 25, 2, p.accent); c.fill(24, 3, 27, 9, p.accentShade)
            c.fill(18, 9, 21, 12, p.accent); c.fill(17, 12, 18, 16, p.accentShade); c.fill(21, 12, 22, 15, p.accent)
        case .hood:
            c.fill(10, 3, 29, 25, p.top); c.fill(12, 2, 27, 2, p.top)
            c.fill(25, 4, 29, 25, p.topShade); c.fill(19, 3, 20, 22, p.topShade)
            c.fill(11, 4, 13, 16, p.topLight)
        }
        if look.headphones {
            headphoneBand(c, p)
            c.fill(8, 11, 12, 17, p.accent); c.fill(27, 11, 31, 17, p.accentShade)
        }
        return c
    }

    // MARK: Body (front and back)

    private static func body(_ c: PixelCanvas, _ look: CharacterLook, _ p: Palette, frame: Int, back: Bool) {
        let leftUp = frame == 1, rightUp = frame == 2
        // Legs: a walk step lifts one foot.
        let ly = leftUp ? -2 : 0, ry = rightUp ? -2 : 0
        c.fill(12, 37, 27, 40, p.bottom)
        c.fill(12, 41, 18, 49 + ly, p.bottom)
        c.fill(21, 41, 27, 49 + ry, p.bottom)
        c.fill(17, 41, 18, 49 + ly, p.bottomShade)
        c.fill(26, 41, 27, 49 + ry, p.bottomShade)
        c.fill(12, 41, 12, 48 + ly, p.bottomLight)
        c.fill(13, 45 + ly, 16, 45 + ly, p.bottomShade)
        c.fill(22, 45 + ry, 25, 45 + ry, p.bottomShade)
        if back {
            c.fill(13, 38, 17, 41, p.bottomShade); c.fill(14, 39, 16, 40, p.bottom)
            c.fill(22, 38, 26, 41, p.bottomShade); c.fill(23, 39, 25, 40, p.bottom)
        } else {
            c.fill(19, 38, 20, 41, p.bottomShade)
        }
        // Sneakers.
        for (x0, up) in [(11, ly), (21, ry)] {
            c.fill(x0, 50 + up, x0 + 7, 52 + up, p.shoes)
            c.fill(x0, 53 + up, x0 + 7, 53 + up, p.sole)
            c.fill(x0 + 1, 50 + up, x0 + 4, 50 + up, p.shoesShade)
            c.dot(x0 + (x0 == 11 ? 5 : 2), 51 + up, p.accent)
        }
        // Torso: lit from the left.
        c.fill(11, 23, 28, 36, p.top)
        c.fill(10, 24, 29, 26, p.top)
        c.fill(26, 25, 28, 36, p.topShade)
        c.fill(11, 24, 12, 33, p.topLight)
        c.fill(12, 36, 27, 36, p.topShade)
        // Arms swing with the walk.
        let la = rightUp ? 1 : 0, ra = leftUp ? 1 : 0
        c.fill(6, 25, 10, 35 + la, p.top)
        c.fill(29, 25, 33, 35 + ra, p.topShade)
        c.fill(6, 25, 6, 34 + la, p.topLight)
        c.fill(6, 35 + la, 10, 35 + la, p.topShade)
        c.fill(29, 35 + ra, 33, 35 + ra, p.topShade.shaded(0.85))
        c.fill(10, 27, 10, 34, p.topShade)
        c.fill(29, 27, 29, 34, p.topShade.shaded(0.85))
        c.fill(7, 36 + la, 10, 38 + la, p.skin)
        c.fill(29, 36 + ra, 32, 38 + ra, p.skinShade)
        switch look.outfit {
        case .jersey:
            // Sleeveless: bare arms, trim around the armholes.
            c.fill(6, 27, 10, 35 + la, p.skin); c.fill(29, 27, 33, 35 + ra, p.skinShade)
            c.fill(7, 25, 10, 26, p.top); c.fill(29, 25, 32, 26, p.topShade)
            c.fill(10, 25, 10, 33, p.accent); c.fill(29, 25, 29, 33, p.accentShade)
        case .puffer:
            // Puffy and quilted.
            c.fill(9, 23, 30, 26, p.top); c.fill(27, 24, 30, 26, p.topShade)
            for y in [28, 31, 34] {
                c.fill(11, y, 28, y, p.topShade); c.fill(6, y, 10, y, p.topShade); c.fill(29, y, 33, y, p.topShade.shaded(0.85))
            }
        case .hoodie, .jacket:
            break
        }
        // Neck.
        c.fill(17, 20, 22, 23, p.skinShade)
        guard !back else {
            c.fill(14, 23, 25, 23, p.topShade)
            switch look.outfit {
            case .jersey: number(c, p)
            case .puffer: c.fill(15, 21, 24, 23, p.top)
            case .hoodie, .jacket: break
            }
            return
        }
        c.fill(16, 23, 23, 24, p.topShade)
        c.fill(17, 23, 22, 23, p.skinShade)
        if look.hat == .hood {
            c.fill(17, 25, 17, 30, p.white); c.dot(17, 31, p.accent)
            c.fill(22, 25, 22, 30, p.white); c.dot(22, 31, p.accent)
        }
        switch look.outfit {
        case .hoodie:
            // Kangaroo pocket.
            c.fill(14, 31, 25, 31, p.topShade)
            c.fill(14, 31, 14, 35, p.topShade); c.fill(25, 31, 25, 35, p.topShade)
        case .jacket:
            // Open over a white tee: lapels, pockets.
            c.fill(18, 24, 21, 36, p.white.shaded(0.95))
            c.fill(17, 24, 17, 36, p.topShade); c.fill(22, 24, 22, 36, p.topShade)
            c.fill(15, 23, 17, 27, p.topLight); c.fill(22, 23, 24, 27, p.topShade)
            c.fill(12, 31, 15, 31, p.topShade); c.fill(24, 31, 27, 31, p.topShade)
        case .jersey:
            c.fill(16, 23, 23, 24, p.accent)
            number(c, p)
            c.fill(12, 36, 27, 36, p.accent)
        case .puffer:
            // High collar and zip.
            c.fill(15, 21, 24, 24, p.top); c.fill(22, 21, 24, 24, p.topShade)
            c.fill(19, 25, 20, 36, p.topShade)
            c.dot(19, 26, p.accent)
        }
        if look.chain {
            for (x, y) in [(15, 24), (16, 26), (17, 27), (18, 28), (21, 28), (22, 27), (23, 26), (24, 24)] {
                c.dot(x, y, p.accent)
            }
            c.fill(19, 28, 20, 28, p.accent)
            c.fill(18, 29, 21, 31, p.accent); c.dot(18, 29, p.accentLight); c.fill(21, 30, 21, 31, p.accentShade)
        }
    }

    /// The jersey's number: 23, in white.
    private static func number(_ c: PixelCanvas, _ p: Palette) {
        let digits = [["###", "..#", "###", "#..", "###"], ["###", "..#", "###", "..#", "###"]]
        for (index, rows) in digits.enumerated() {
            for (dy, row) in rows.enumerated() {
                for (dx, mark) in row.enumerated() where mark == "#" { c.dot(15 + index * 5 + dx, 27 + dy, p.white) }
            }
        }
    }

    // MARK: Head (front)

    private static func face(_ c: PixelCanvas, _ look: CharacterLook, _ p: Palette) {
        c.fill(13, 6, 26, 20, p.skin)
        c.fill(12, 8, 27, 18, p.skin)
        c.fill(14, 21, 25, 21, p.skinShade)
        c.fill(26, 8, 27, 18, p.skinShade)
        c.fill(13, 19, 26, 20, p.skin); c.fill(24, 19, 26, 20, p.skinShade)
        c.fill(11, 12, 11, 15, p.skin); c.fill(28, 12, 28, 15, p.skinShade)
        features(c, look, p, browLeft: 14, browRight: 25)
        if look.beard {
            c.fill(12, 15, 13, 19, p.hair); c.fill(26, 15, 27, 19, p.hair)
            c.fill(13, 19, 26, 21, p.hair); c.fill(15, 20, 24, 22, p.hair)
            c.fill(17, 17, 22, 17, p.hair)
            c.fill(18, 18, 21, 18, p.mouth)
            c.fill(24, 19, 26, 21, p.hairShade)
        }
        if look.glasses {
            glasses(c, p)
            c.fill(12, 13, 13, 13, p.lens); c.fill(26, 13, 27, 13, p.lens)
        }
    }

    /// Brows, eyes (with a glint), nose and mouth.
    private static func features(_ c: PixelCanvas, _ look: CharacterLook, _ p: Palette, browLeft: Int, browRight: Int) {
        c.fill(browLeft, 11, 17, 11, p.hairShade)
        c.fill(22, 11, browRight, 11, p.hairShade)
        c.fill(15, 13, 17, 14, p.white); c.fill(22, 13, 24, 14, p.white)
        c.fill(16, 13, 17, 14, p.eye); c.fill(22, 13, 23, 14, p.eye)
        c.dot(17, 13, p.white); c.dot(23, 13, p.white)
        c.fill(19, 15, 19, 16, p.skinShade); c.dot(20, 17, p.skinShade)
        c.fill(18, 18, 21, 18, p.mouth)
    }

    private static func glasses(_ c: PixelCanvas, _ p: Palette) {
        c.fill(14, 12, 18, 15, p.lens); c.fill(21, 12, 25, 15, p.lens)
        c.fill(19, 13, 20, 13, p.lens)
        c.dot(15, 13, p.lensShine); c.dot(22, 13, p.lensShine)
    }

    /// The hair volume behind the face (long hair, afro).
    private static func hairBehind(_ c: PixelCanvas, _ look: CharacterLook, _ p: Palette) {
        guard [CharacterLook.Hat.none, .bucket, .bandana].contains(look.hat) else { return }
        switch look.hairStyle {
        case .puff:
            guard look.hat == .none else { return }
            c.ellipse(19.5, 8, 12.5, 9.5, p.hair)
        case .long:
            c.fill(10, 6, 29, 25, p.hair); c.fill(11, 26, 28, 27, p.hair)
            c.fill(10, 20, 11, 25, p.hairShade); c.fill(28, 20, 29, 25, p.hairShade)
            c.dot(11, 27, .clear); c.dot(28, 27, .clear)
        case .braids:
            for x in [9, 11, 28, 30] {
                c.fill(x, 8, x, 29, p.hair)
                for y in stride(from: 10, to: 29, by: 3) { c.dot(x, y, p.hairShade) }
                c.dot(x, 30, p.accent)
            }
        case .short, .bald, .fade:
            break
        }
    }

    private static func headwear(_ c: PixelCanvas, _ look: CharacterLook, _ p: Palette) {
        switch look.hat {
        case .cap:
            let side = look.hairStyle == .bald ? p.skin : p.hair
            c.fill(12, 8, 13, 12, side); c.fill(26, 8, 27, 12, side)
            c.fill(12, 2, 27, 7, p.accent)
            c.fill(13, 1, 26, 1, p.accent)
            c.fill(24, 2, 27, 7, p.accentShade)
            c.fill(17, 3, 22, 6, p.white)
            c.fill(18, 4, 21, 5, p.accent)
            c.fill(14, 2, 16, 3, p.accentLight)
            c.fill(11, 8, 28, 8, p.accent)
            c.fill(11, 9, 28, 9, p.accentShade)
            c.fill(13, 10, 26, 10, p.skinShade)
        case .beanie:
            c.fill(12, 3, 27, 10, p.accent)
            c.fill(13, 2, 26, 2, p.accent); c.fill(15, 1, 24, 1, p.accent)
            c.fill(24, 2, 27, 7, p.accentShade)
            c.fill(11, 8, 28, 11, p.accentShade)
            for x in stride(from: 12, to: 28, by: 2) { c.fill(x, 8, x, 11, p.accentShade.shaded(0.8)) }
            c.fill(14, 3, 16, 4, p.accentLight)
            if look.hairStyle == .long {
                c.fill(10, 12, 11, 24, p.hair); c.fill(28, 12, 29, 24, p.hair)
            }
        case .hood:
            c.fill(10, 3, 29, 24, p.top)
            c.fill(12, 2, 27, 2, p.top)
            c.fill(26, 4, 29, 24, p.topShade)
            c.fill(11, 4, 12, 18, p.topLight)
            // The face, framed by the hood.
            c.fill(13, 7, 26, 21, p.topShade)
            c.fill(14, 8, 25, 21, p.skin)
            c.fill(24, 8, 25, 20, p.skinShade)
            features(c, look, p, browLeft: 15, browRight: 24)
            if look.beard {
                c.fill(14, 19, 25, 21, p.hair); c.fill(17, 17, 22, 17, p.hair); c.fill(18, 18, 21, 18, p.mouth)
            }
            if look.glasses { glasses(c, p) }
        case .none, .bucket, .bandana:
            switch look.hairStyle {
            case .short:
                c.fill(13, 3, 26, 8, p.hair); c.fill(12, 5, 27, 9, p.hair)
                c.fill(15, 2, 24, 2, p.hair)
                c.fill(12, 10, 12, 12, p.hair); c.fill(27, 10, 27, 12, p.hair)
                for x in [14, 17, 21, 24] { c.dot(x, 10, p.hair) }
                c.fill(23, 3, 26, 9, p.hairShade)
                c.fill(15, 3, 18, 4, p.hairLight)
            case .long:
                c.fill(13, 3, 26, 8, p.hair); c.fill(12, 5, 27, 10, p.hair)
                c.fill(15, 2, 24, 2, p.hair)
                c.fill(12, 10, 12, 17, p.hair); c.fill(27, 10, 27, 17, p.hair)
                c.fill(19, 4, 19, 8, p.hairShade)
                c.fill(23, 3, 26, 9, p.hairShade)
                c.fill(14, 4, 17, 5, p.hairLight)
            case .puff:
                c.fill(13, 5, 26, 9, p.hair)
                c.ellipse(19.5, 6, 11.5, 6.5, p.hair)
                c.ellipse(24, 7, 6, 5, p.hairShade); c.ellipse(19.5, 6, 9.5, 5, p.hair)
                for (x, y) in [(12, 4), (15, 2), (20, 1), (25, 3), (28, 6), (11, 8)] { c.dot(x, y, p.hairShade) }
                c.fill(14, 2, 17, 3, p.hairLight)
            case .bald:
                c.fill(14, 7, 16, 8, p.skinLight); c.dot(15, 6, p.skinLight)
            case .braids:
                c.fill(13, 3, 26, 8, p.hair); c.fill(12, 5, 27, 9, p.hair); c.fill(15, 2, 24, 2, p.hair)
                for x in [14, 17, 20, 23, 26] { c.fill(x, 3, x, 9, p.hairShade) }  // Cornrow parts.
                c.fill(12, 9, 27, 9, p.hairShade)
            case .fade:
                c.fill(13, 2, 26, 6, p.hair); c.fill(14, 1, 25, 1, p.hair)
                c.fill(23, 2, 26, 6, p.hairShade); c.fill(15, 2, 18, 3, p.hairLight)
                for y in 7..<12 {
                    for x in [12, 13, 26, 27] where (x + y) % 2 == 0 || y < 9 { c.dot(x, y, p.hairShade) }
                }
                c.fill(13, 7, 26, 7, p.hair)
            }
        }
        switch look.hat {
        case .bucket:
            let side = look.hairStyle == .bald || look.hairStyle == .fade ? p.skin : p.hair
            c.fill(12, 8, 13, 12, side); c.fill(26, 8, 27, 12, side)
            c.fill(13, 2, 26, 7, p.accent); c.fill(14, 1, 25, 1, p.accent)
            c.fill(23, 2, 26, 7, p.accentShade); c.fill(15, 2, 17, 3, p.accentLight)
            c.fill(13, 6, 26, 6, p.accentShade)
            c.fill(10, 8, 29, 8, p.accent); c.fill(9, 9, 30, 10, p.accentShade)  // Floppy brim.
            c.fill(13, 11, 26, 11, p.skinShade)
        case .bandana:
            c.fill(12, 3, 27, 9, p.accent); c.fill(14, 2, 25, 2, p.accent); c.fill(24, 3, 27, 9, p.accentShade)
            for (x, y) in [(14, 4), (18, 5), (22, 4), (16, 7), (20, 8), (25, 6), (13, 8)] { c.dot(x, y, p.white) }
            c.fill(28, 6, 30, 9, p.accent); c.fill(30, 10, 31, 13, p.accentShade); c.fill(28, 10, 29, 12, p.accent)  // The knot.
        case .none, .cap, .beanie, .hood:
            break
        }
        if look.earrings {
            c.fill(11, 16, 11, 17, PixelColor(hex: "#e8c547")); c.fill(28, 16, 28, 17, PixelColor(hex: "#c9a63a"))
        }
        if look.headphones {
            headphoneBand(c, p)
            c.fill(8, 11, 12, 17, p.accent); c.fill(27, 11, 31, 17, p.accentShade)
            c.fill(9, 12, 9, 16, p.accentLight); c.fill(12, 12, 12, 16, p.gear); c.fill(27, 12, 27, 16, p.gear)
        }
    }

    private static func headphoneBand(_ c: PixelCanvas, _ p: Palette) {
        c.fill(13, 2, 26, 2, p.gear); c.fill(11, 3, 12, 5, p.gear); c.fill(27, 3, 28, 5, p.gear)
        c.fill(10, 6, 11, 10, p.gear); c.fill(28, 6, 29, 10, p.gear)
    }
}

private extension PixelCanvas {
    /// Filled ellipse centred on (cx, cy), radii in pixels.
    func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ color: PixelColor) {
        for y in (Int(cy - ry) - 1)...(Int(cy + ry) + 1) {
            for x in (Int(cx - rx) - 1)...(Int(cx + rx) + 1) {
                let dx = (Double(x) - cx) / rx, dy = (Double(y) - cy) / ry
                if dx * dx + dy * dy <= 1 { dot(x, y, color) }
            }
        }
    }
}
