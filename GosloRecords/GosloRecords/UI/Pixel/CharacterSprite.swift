import UIKit

/// Generates a character's 16×16 sprite from their look.
/// Frames: 0 = standing, 1 and 2 = walk steps.
@MainActor
enum CharacterSprite {
    static func image(_ look: CharacterLook, facing: Direction, frame: Int = 0) -> UIImage {
        PixelCache.image("char-\(look.hashValue)-\(facing.rawValue)-\(frame)") {
            canvas(look, facing: facing, frame: frame).makeImage()
        }
    }

    static func canvas(_ look: CharacterLook, facing: Direction, frame: Int) -> PixelCanvas {
        let shape = { (c: PixelCanvas) in c.reshaped(fromRow: 8, by: look.build.mapDelta) }
        switch facing {
        case .down: return shape(front(look, frame: frame)).outlined()
        case .up: return shape(back(look, frame: frame)).outlined()
        case .right: return shape(side(look, frame: frame)).outlined()
        case .left: return shape(side(look, frame: frame)).outlined().mirrored()
        }
    }

    private static let djellabaGreen = PixelColor(hex: Wardrobe.djellabaGreen)

    private struct Palette {
        let skin, hair, hairShade, top, topShade, bottom, bottomShade, shoes, accent, accentShade: PixelColor
        let eye = PixelColor(hex: "#141418")
        let lens = PixelColor(hex: "#1a1a22")
        let gear = PixelColor(hex: "#2a2a30")

        init(_ look: CharacterLook) {
            skin = PixelColor(hex: look.skin)
            hair = PixelColor(hex: look.hair)
            hairShade = hair.shaded(0.7)
            top = PixelColor(hex: look.top)
            topShade = top.shaded(0.75)
            bottom = PixelColor(hex: look.bottom)
            bottomShade = bottom.shaded(0.75)
            shoes = PixelColor(hex: look.shoes)
            accent = PixelColor(hex: look.accent)
            accentShade = accent.shaded(0.7)
        }
    }

    // MARK: Front (facing down)

    private static func front(_ look: CharacterLook, frame: Int) -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 16)
        let p = Palette(look)

        // Legs and shoes (the walk animation lifts one foot).
        c.fill(5, 12, 10, 13, p.bottom)
        let leftUp = frame == 1, rightUp = frame == 2
        c.fill(5, 14, 6, leftUp ? 13 : 14, p.bottom)
        c.fill(9, 14, 10, rightUp ? 13 : 14, p.bottom)
        c.fill(5, leftUp ? 14 : 15, 6, leftUp ? 14 : 15, p.shoes)
        c.fill(9, rightUp ? 14 : 15, 10, rightUp ? 14 : 15, p.shoes)
        c.dot(7, 12, p.bottomShade)
        c.dot(8, 12, p.bottomShade)

        // Torso and arms (arms swing as you walk).
        c.fill(4, 8, 11, 11, p.top)
        c.fill(4, 8, 4, 11, p.topShade)
        c.fill(11, 8, 11, 11, p.topShade)
        let leftArmEnd = rightUp ? 10 : 11, rightArmEnd = leftUp ? 10 : 11
        c.fill(3, 9, 3, leftArmEnd, p.top)
        c.fill(12, 9, 12, rightArmEnd, p.top)
        c.dot(3, leftArmEnd + 1, p.skin)
        c.dot(12, rightArmEnd + 1, p.skin)
        c.fill(7, 8, 8, 8, p.skin)
        switch look.outfit {
        case .hoodie: break
        case .jacket: c.fill(7, 9, 8, 11, PixelColor(hex: "#e8e6e0"))
        case .jersey:
            c.fill(3, 9, 3, leftArmEnd, p.skin)
            c.fill(12, 9, 12, rightArmEnd, p.skin)
            c.dot(7, 10, PixelColor(hex: "#f2efe8"))
        case .puffer: c.fill(4, 10, 11, 10, p.topShade)
        case .djellaba:
            // The robe down to the ankles: the stepping foot peeks out under the hem. The green star on the chest.
            c.fill(4, 12, 11, 14, p.top)
            c.fill(11, 12, 11, 14, p.topShade)
            c.fill(4, 14, 11, 14, p.topShade)
            if leftUp { c.fill(5, 14, 6, 14, p.shoes) }
            if rightUp { c.fill(9, 14, 10, 14, p.shoes) }
            c.fill(7, 9, 8, 10, djellabaGreen)
        }
        if look.chain {
            c.fill(6, 9, 9, 9, p.accent)
            c.fill(7, 10, 8, 10, p.accent)
        }

        // Head.
        c.fill(5, 2, 10, 7, p.skin)
        c.dot(5, 7, .clear)
        c.dot(10, 7, .clear)
        c.dot(6, 5, p.eye)
        c.dot(9, 5, p.eye)
        if look.beard {
            c.fill(5, 6, 5, 6, p.hair)
            c.fill(10, 6, 10, 6, p.hair)
            c.fill(6, 7, 9, 7, p.hair)
        }
        if look.glasses {
            c.fill(5, 5, 10, 5, p.lens)
            c.dot(6, 5, p.lens.shaded(1.8))
        }
        if look.feminine {
            c.dot(5, 4, p.eye)
            c.dot(10, 4, p.eye)
            c.fill(7, 7, 8, 7, PixelColor(hex: "#c0505a"))
        }
        if look.earrings {
            c.dot(4, 6, PixelColor(hex: "#e8c547"))
            c.dot(11, 6, PixelColor(hex: "#e8c547"))
        }
        frontHair(c, look, p)
        return c
    }

    private static func frontHair(_ c: PixelCanvas, _ look: CharacterLook, _ p: Palette) {
        switch look.hat {
        case .cap:
            c.fill(4, 1, 11, 2, p.accent)
            c.fill(3, 3, 12, 3, p.accentShade)
            c.dot(7, 1, p.accent.shaded(1.3))
        case .beanie:
            c.fill(4, 0, 11, 3, p.accent)
            c.fill(4, 3, 11, 3, p.accentShade)
        case .hood:
            c.fill(3, 1, 12, 9, p.top)
            c.fill(4, 1, 11, 1, p.topShade)
            c.fill(5, 3, 10, 7, p.skin)
            c.dot(5, 7, p.topShade)
            c.dot(10, 7, p.topShade)
            c.dot(6, 5, look.glasses ? p.lens : p.eye)
            c.dot(9, 5, look.glasses ? p.lens : p.eye)
            if look.glasses { c.fill(5, 5, 10, 5, p.lens) }
        case .bucket:
            c.fill(5, 1, 10, 2, p.accent)
            c.fill(3, 3, 12, 3, p.accentShade)
        case .bandana:
            c.fill(4, 1, 11, 3, p.accent)
            c.dot(6, 2, p.accent.shaded(1.4))
            c.dot(9, 1, p.accent.shaded(1.4))
            c.fill(12, 3, 12, 4, p.accentShade)
        case .none:
            switch look.hairStyle {
            case .short:
                c.fill(5, 1, 10, 1, p.hair)
                c.fill(4, 2, 11, 2, p.hair)
                c.dot(4, 3, p.hair)
                c.dot(11, 3, p.hair)
            case .long:
                c.fill(5, 1, 10, 1, p.hair)
                c.fill(4, 2, 11, 2, p.hair)
                c.fill(4, 3, 4, 8, p.hair)
                c.fill(11, 3, 11, 8, p.hair)
            case .puff:
                c.fill(4, 0, 11, 2, p.hair)
                c.fill(3, 1, 12, 2, p.hair)
                c.dot(4, 3, p.hair)
                c.dot(11, 3, p.hair)
            case .bald:
                c.dot(7, 2, p.skin.shaded(1.15))
            case .braids:
                c.fill(5, 1, 10, 1, p.hair)
                c.fill(4, 2, 11, 2, p.hair)
                c.fill(4, 3, 4, 9, p.hair)
                c.fill(11, 3, 11, 9, p.hair)
                c.dot(4, 10, p.accent)
                c.dot(11, 10, p.accent)
            case .fade:
                c.fill(5, 1, 10, 2, p.hair)
                c.dot(4, 3, p.hairShade)
                c.dot(11, 3, p.hairShade)
            case .bun:
                c.fill(6, 0, 9, 0, p.hair)
                c.fill(5, 1, 10, 1, p.hair)
                c.fill(4, 2, 11, 2, p.hair)
                c.dot(4, 3, p.hair)
                c.dot(11, 3, p.hair)
            }
        }
        if look.headphones {
            c.fill(4, 1, 11, 1, p.gear)
            c.fill(3, 3, 4, 5, p.accent)
            c.fill(11, 3, 12, 5, p.accent)
        }
    }

    // MARK: Back (facing up)

    private static func back(_ look: CharacterLook, frame: Int) -> PixelCanvas {
        let c = front(look.withoutFace, frame: frame)
        let p = Palette(look)
        // The back of the head hides the face.
        switch look.hat {
        case .hood:
            c.fill(3, 1, 12, 9, p.top)
            c.fill(5, 2, 10, 7, p.topShade)
        case .cap:
            c.fill(5, 3, 10, 7, look.hairStyle == .bald ? p.skin : p.hair)
            c.fill(4, 1, 11, 3, p.accent)
        case .beanie:
            c.fill(5, 4, 10, 7, look.hairStyle == .bald ? p.skin : p.hair)
            c.fill(4, 0, 11, 4, p.accent)
        case .bucket:
            c.fill(5, 3, 10, 7, look.hairStyle == .bald ? p.skin : p.hair)
            c.fill(5, 1, 10, 2, p.accent)
            c.fill(3, 3, 12, 3, p.accentShade)
        case .bandana:
            c.fill(5, 4, 10, 7, look.hairStyle == .bald ? p.skin : p.hair)
            c.fill(4, 1, 11, 3, p.accent)
            c.fill(7, 4, 8, 5, p.accentShade)
        case .none:
            let back = look.hairStyle == .bald ? p.skin : p.hair
            c.fill(5, 2, 10, 7, back)
            if look.hairStyle == .puff { c.fill(3, 0, 12, 4, p.hair) }
            if look.hairStyle == .long { c.fill(4, 2, 11, 9, p.hair) }
            if look.hairStyle == .fade { c.fill(5, 5, 10, 7, p.skin) }
            if look.hairStyle == .bun { c.fill(6, 0, 9, 1, p.hair) }
            if look.hairStyle == .braids {
                c.fill(4, 2, 11, 9, p.hair)
                for x in [5, 7, 9] { c.fill(x, 3, x, 9, p.hairShade) }
            }
        }
        c.fill(7, 8, 8, 8, look.hat == .hood ? p.topShade : p.skin)
        if look.outfit == .djellaba {
            // No star on the back: the pointed hood (qob) hangs there, a green tassel at its tip.
            c.fill(7, 9, 8, 10, p.top)
            if look.hat != .hood {
                c.fill(5, 8, 10, 8, p.topShade); c.fill(6, 9, 9, 9, p.topShade); c.fill(7, 10, 8, 10, p.topShade)
                c.fill(7, 11, 8, 11, djellabaGreen)
            }
        }
        if look.headphones {
            c.fill(4, 1, 11, 1, p.gear)
            c.fill(3, 3, 4, 5, p.accent)
            c.fill(11, 3, 12, 5, p.accent)
        }
        return c
    }

    // MARK: Side (facing right)

    private static func side(_ look: CharacterLook, frame: Int) -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 16)
        let p = Palette(look)

        // Legs: the stride alternates the front and back leg.
        switch frame {
        case 1:
            c.fill(8, 12, 9, 14, p.bottom)
            c.fill(5, 12, 6, 14, p.bottomShade)
            c.fill(9, 15, 10, 15, p.shoes)
            c.fill(4, 15, 5, 15, p.shoes.shaded(0.8))
        case 2:
            c.fill(5, 12, 6, 14, p.bottom)
            c.fill(8, 12, 9, 14, p.bottomShade)
            c.fill(4, 15, 5, 15, p.shoes)
            c.fill(9, 15, 10, 15, p.shoes.shaded(0.8))
        default:
            c.fill(6, 12, 9, 14, p.bottom)
            c.fill(6, 15, 10, 15, p.shoes)
        }

        // Torso and arm.
        c.fill(5, 8, 10, 11, p.top)
        c.fill(5, 8, 5, 11, p.topShade)
        let armOffset = frame == 1 ? 1 : (frame == 2 ? -1 : 0)
        c.fill(7 + armOffset, 9, 8 + armOffset, 11, p.topShade)
        c.dot(8 + armOffset, 12, p.skin)
        if look.outfit == .djellaba {
            // The robe hides the legs and its hem swings with the stride; the hood on the back, the star in front.
            c.fill(5, 12, 10, 14, p.top)
            c.fill(5, 12, 5, 14, p.topShade)
            if frame == 1 { c.dot(11, 14, p.top) } else if frame == 2 { c.dot(4, 14, p.top) }
            c.dot(8 + armOffset, 12, p.skin)
            if look.hat != .hood { c.fill(4, 8, 4, 10, p.topShade); c.dot(4, 11, djellabaGreen) }
            c.dot(10, 9, djellabaGreen)
        }
        if look.chain { c.fill(9, 9, 10, 9, p.accent) }

        // Head in profile.
        c.fill(6, 2, 10, 7, p.skin)
        c.dot(11, 5, p.skin)
        c.dot(9, 5, p.eye)
        c.dot(6, 7, .clear)
        if look.beard { c.fill(8, 7, 10, 7, p.hair); c.dot(10, 6, p.hair) }
        if look.glasses { c.fill(8, 5, 11, 5, p.lens) }

        switch look.hat {
        case .cap:
            c.fill(5, 1, 10, 2, p.accent)
            c.fill(10, 3, 12, 3, p.accentShade)
            c.fill(5, 3, 6, 5, look.hairStyle == .bald ? p.skin : p.hair)
        case .beanie:
            c.fill(5, 0, 10, 3, p.accent)
            c.fill(5, 3, 10, 3, p.accentShade)
        case .bucket:
            c.fill(6, 1, 10, 2, p.accent)
            c.fill(4, 3, 12, 3, p.accentShade)
        case .bandana:
            c.fill(5, 1, 10, 3, p.accent)
            c.fill(4, 3, 4, 4, p.accentShade)
        case .hood:
            c.fill(4, 1, 10, 9, p.top)
            c.fill(7, 3, 10, 7, p.skin)
            c.dot(11, 5, p.skin)
            c.dot(9, 5, look.glasses ? p.lens : p.eye)
            if look.glasses { c.fill(8, 5, 11, 5, p.lens) }
        case .none:
            switch look.hairStyle {
            case .short:
                c.fill(6, 1, 10, 2, p.hair)
                c.fill(5, 2, 6, 5, p.hair)
            case .long:
                c.fill(6, 1, 10, 2, p.hair)
                c.fill(4, 2, 6, 9, p.hair)
            case .puff:
                c.fill(5, 0, 10, 2, p.hair)
                c.fill(4, 1, 6, 5, p.hair)
            case .bald:
                c.dot(7, 2, p.skin.shaded(1.15))
            case .braids:
                c.fill(6, 1, 10, 2, p.hair)
                c.fill(4, 2, 6, 10, p.hair)
                c.dot(5, 11, p.accent)
            case .fade:
                c.fill(6, 1, 10, 2, p.hair)
                c.dot(5, 3, p.hairShade)
            case .bun:
                c.fill(6, 1, 10, 2, p.hair)
                c.fill(5, 0, 7, 1, p.hair)
                c.fill(5, 2, 6, 5, p.hair)
            }
        }
        if look.headphones {
            c.fill(6, 1, 9, 1, p.gear)
            c.fill(6, 4, 7, 6, p.accent)
        }
        return c
    }
}

private extension CharacterLook {
    /// Same look, without the accessories that only show from the front.
    var withoutFace: CharacterLook {
        var copy = self
        copy.glasses = false
        copy.beard = false
        copy.chain = false
        copy.earrings = false
        if copy.outfit == .jacket { copy.outfit = .hoodie }
        return copy
    }
}

extension CharacterLook.Build {
    /// Pixels added (or taken) on each side of the 16×16 map sprite's body.
    var mapDelta: Int {
        switch self {
        case .slim: -1
        case .regular: 0
        case .strong: 1
        case .heavy: 2
        }
    }

    /// Same for the 40×56 detailed sprite.
    var heroDelta: Int {
        switch self {
        case .slim: -2
        case .regular: 0
        case .strong: 2
        case .heavy: 4
        }
    }
}
