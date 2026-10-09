import SwiftUI
import UIKit

/// Pixel icons for the shop: gear, services and decorations (16×16, outlined, cached).
@MainActor
enum ShopIcons {
    private static func c(_ hex: String) -> PixelColor { PixelColor(hex: hex) }

    static func gear(_ id: String) -> UIImage {
        PixelCache.image("shop_\(id)") { draw(id).outlined().makeImage() }
    }

    static func decor(_ decor: Decor) -> UIImage {
        PixelCache.image("shop_decor_\(decor.rawValue)") { drawDecor(decor).outlined().makeImage() }
    }

    private static func draw(_ id: String) -> PixelCanvas {
        let p = PixelCanvas(width: 16, height: 16)
        let metal = c("#b8bcc8"), dark = c("#2a2a33"), gold = c("#f2c14e"), red = c("#ff4d2e")
        switch id {
        case "micro_pro":
            p.circle(cx: 8, cy: 4, radius: 3, metal)
            p.fill(7, 3, 9, 5, c("#8a8f9c"))
            p.fill(7, 8, 9, 14, dark)
            p.fill(6, 13, 10, 14, red)
        case "casque_studio":
            p.fill(3, 3, 12, 4, dark)
            p.fill(2, 4, 3, 9, dark)
            p.fill(12, 4, 13, 9, dark)
            p.fill(1, 8, 4, 13, red)
            p.fill(11, 8, 14, 13, red)
        case "dico_rimes":
            p.fill(3, 2, 12, 14, c("#7a3b2e"))
            p.fill(4, 3, 11, 13, c("#a14d3a"))
            p.fill(12, 3, 13, 14, c("#efe6d2"))
            p.fill(5, 6, 10, 7, gold)
        case "dictaphone":
            p.fill(4, 2, 11, 14, dark)
            p.fill(5, 3, 10, 7, c("#3d3d48"))
            p.circle(cx: 7, cy: 5, radius: 1, metal)
            p.dot(8, 5, metal)
            p.fill(5, 10, 6, 11, red)
            p.fill(8, 10, 10, 11, metal)
        case "psy":
            p.fill(2, 8, 13, 11, c("#6b4fa0"))
            p.fill(2, 5, 4, 11, c("#5a4088"))
            p.fill(3, 12, 3, 14, dark)
            p.fill(12, 12, 12, 14, dark)
            p.fill(10, 6, 13, 8, c("#efe6d2"))
        case "promo":
            p.fill(3, 6, 6, 10, c("#e8e8e8"))
            p.fill(7, 4, 12, 12, red)
            p.fill(13, 3, 14, 13, c("#c43a22"))
            p.fill(4, 11, 5, 14, dark)
        case "concert_quartier":
            p.fill(2, 4, 6, 14, dark)
            p.circle(cx: 4, cy: 7, radius: 1, metal)
            p.circle(cx: 4, cy: 11, radius: 2, metal)
            p.fill(9, 4, 13, 14, dark)
            p.circle(cx: 11, cy: 7, radius: 1, metal)
            p.circle(cx: 11, cy: 11, radius: 2, metal)
            p.dot(7, 2, gold); p.dot(8, 1, gold)
        case "hammam":
            // A brass bowl of water, a black-soap jar and the steam rising.
            p.fill(2, 10, 13, 12, c("#c9a63a"))
            p.fill(3, 13, 12, 14, c("#9a7a2a"))
            p.fill(3, 9, 12, 9, c("#5ab4e0"))
            p.fill(11, 6, 14, 9, c("#3a2a1e")); p.fill(11, 5, 14, 5, c("#6b5a3a"))
            for (x, y) in [(4, 7), (5, 6), (4, 5), (5, 4), (8, 7), (9, 6), (8, 5), (9, 4), (8, 3)] { p.dot(x, y, c("#e8e8f0")) }
        case "coach_vocal":
            // A microphone and the sound waves coming out of it.
            p.circle(cx: 5, cy: 5, radius: 3, metal)
            p.fill(4, 4, 6, 6, c("#8a8f9c"))
            p.fill(4, 8, 6, 14, dark)
            for (x, y) in [(10, 3), (11, 4), (11, 5), (11, 6), (10, 7), (13, 2), (14, 3), (14, 4), (14, 5), (14, 6), (14, 7), (13, 8)] {
                p.dot(x, y, gold)
            }
        case "attache_presse":
            // A folded newspaper with your face on the front page.
            p.fill(2, 2, 13, 14, c("#efe6d2"))
            p.fill(3, 3, 12, 4, dark)
            p.fill(3, 6, 7, 10, c("#c68642")); p.fill(3, 6, 7, 7, dark)
            for y in [6, 8, 10, 12] { p.fill(9, y, 12, y, c("#8a8f9c")) }
            p.fill(3, 12, 7, 12, c("#8a8f9c"))
            p.fill(13, 3, 13, 14, c("#c9bfa8"))
        case "masterclass":
            // A notebook, a quill and the gold star of the teacher.
            p.fill(2, 4, 11, 14, c("#2e4a7a"))
            p.fill(3, 5, 10, 13, c("#efe6d2"))
            for y in [7, 9, 11] { p.fill(4, y, 9, y, c("#8a8f9c")) }
            p.fill(12, 1, 13, 2, c("#f0eee8")); p.fill(11, 3, 12, 6, c("#f0eee8")); p.fill(10, 7, 10, 10, dark)
            p.dot(4, 2, gold); p.fill(3, 3, 5, 3, gold); p.dot(4, 4, gold)
        case "avocat":
            // The scales of justice.
            p.fill(7, 2, 8, 13, gold)
            p.fill(3, 3, 12, 3, gold)
            p.fill(5, 14, 10, 14, gold)
            p.fill(2, 4, 2, 7, metal); p.fill(13, 4, 13, 7, metal)
            p.fill(1, 8, 4, 9, c("#d9a92e")); p.fill(11, 8, 14, 9, c("#d9a92e"))
        case "clip_real":
            // A clapperboard.
            p.fill(2, 6, 13, 14, dark)
            p.fill(2, 3, 13, 5, c("#f0eee8"))
            for x in stride(from: 3, to: 13, by: 3) { p.fill(x, 3, x + 1, 5, dark) }
            p.fill(4, 8, 11, 8, c("#f0eee8")); p.fill(4, 11, 8, 11, c("#8a8f9c"))
            p.dot(11, 11, red)
        case "manager":
            // The diary and the phone that never stops ringing.
            p.fill(1, 3, 9, 14, c("#5a2e2e"))
            p.fill(2, 4, 8, 13, c("#efe6d2"))
            p.fill(2, 6, 8, 6, red)
            for y in [8, 10, 12] { p.fill(3, y, 7, y, c("#8a8f9c")) }
            p.fill(10, 6, 14, 14, dark)
            p.fill(11, 7, 13, 12, c("#5ef2ff"))
            p.dot(12, 13, metal)
            p.dot(13, 3, gold); p.dot(14, 2, gold); p.dot(11, 3, gold)
        case "radio_goslo":
            p.fill(1, 6, 14, 14, dark)
            p.fill(2, 7, 13, 13, red)
            p.circle(cx: 5, cy: 10, radius: 2, dark)
            p.fill(9, 8, 12, 9, gold)
            p.fill(9, 11, 12, 11, c("#efe6d2"))
            p.fill(11, 1, 11, 5, metal)
            p.dot(12, 1, gold)
        default:
            p.circle(cx: 8, cy: 8, radius: 5, gold)
        }
        return p
    }

    private static func drawDecor(_ decor: Decor) -> PixelCanvas {
        let p = PixelCanvas(width: 16, height: 16)
        let gold = c("#f2c14e"), dark = c("#2a2a33"), red = c("#ff4d2e")
        switch decor {
        case .fresque:
            p.fill(1, 2, 14, 13, c("#3b5bdb"))
            p.fill(1, 9, 14, 13, c("#f08c3a"))
            p.circle(cx: 8, cy: 7, radius: 3, c("#c68642"))
            p.fill(5, 3, 11, 4, dark)
        case .sono:
            p.fill(1, 3, 6, 14, dark)
            p.circle(cx: 3, cy: 9, radius: 2, c("#b8bcc8"))
            p.fill(9, 3, 14, 14, dark)
            p.circle(cx: 11, cy: 9, radius: 2, c("#b8bcc8"))
        case .bancDore:
            p.fill(1, 7, 14, 9, gold)
            p.fill(1, 4, 14, 5, c("#d9a92e"))
            p.fill(2, 10, 3, 14, dark)
            p.fill(12, 10, 13, 14, dark)
        case .palmier:
            p.fill(7, 6, 8, 12, c("#8a5a2e"))
            p.fill(2, 3, 13, 5, c("#3fa34d"))
            p.fill(4, 1, 11, 3, c("#4cc35c"))
            p.fill(5, 12, 10, 15, c("#c0603a"))
        case .borneArcade:
            p.fill(3, 1, 12, 15, c("#5a2ea0"))
            p.fill(5, 3, 10, 8, c("#5ef2ff"))
            p.fill(5, 10, 6, 11, red)
            p.fill(9, 10, 10, 11, gold)
        case .foodTruck:
            p.fill(0, 4, 15, 12, c("#efe6d2"))
            p.fill(2, 6, 9, 9, dark)
            p.fill(0, 3, 15, 4, red)
            p.circle(cx: 4, cy: 13, radius: 2, dark)
            p.circle(cx: 12, cy: 13, radius: 2, dark)
        case .statueMicro:
            p.circle(cx: 8, cy: 4, radius: 3, gold)
            p.fill(7, 7, 9, 11, gold)
            p.fill(3, 12, 12, 15, c("#8a8f9c"))
        case .panneauGeant:
            p.fill(0, 1, 15, 10, dark)
            p.fill(1, 2, 14, 9, c("#2a1a40"))
            p.circle(cx: 8, cy: 5, radius: 2, gold)
            p.fill(3, 11, 3, 15, c("#8a8f9c")); p.fill(12, 11, 12, 15, c("#8a8f9c"))
        case .studioPerso:
            p.fill(1, 3, 14, 15, c("#6b3a30"))
            p.fill(0, 2, 15, 3, dark)
            p.fill(3, 6, 9, 10, c("#f2c14e"))
            p.circle(cx: 12, cy: 7, radius: 1, red)
            p.fill(10, 11, 13, 15, dark)
        case .scenePleinAir:
            p.fill(0, 1, 15, 2, c("#8a8f9c"))
            p.fill(0, 1, 1, 15, c("#8a8f9c")); p.fill(14, 1, 15, 15, c("#8a8f9c"))
            p.fill(2, 3, 13, 9, c("#1a1030"))
            p.circle(cx: 8, cy: 6, radius: 2, gold)
            p.fill(0, 10, 15, 13, c("#8a5a34"))
        case .boutiqueMerch:
            p.fill(1, 3, 14, 15, c("#2e2e3a"))
            for x in 1...14 { p.fill(x, 5, x, 6, (x / 2) % 2 == 0 ? red : c("#f0eee8")) }
            p.fill(3, 8, 7, 12, red)
            p.fill(10, 8, 13, 15, dark)
        case .neonGoslo:
            p.fill(1, 4, 14, 11, dark)
            p.fill(3, 6, 12, 6, red)
            p.fill(3, 9, 12, 9, gold)
            p.fill(3, 6, 3, 9, red)
        case .snack:
            p.fill(1, 1, 14, 3, dark)
            p.fill(3, 2, 12, 2, gold)
            p.fill(1, 4, 14, 15, c("#2f6b4f"))
            for x in 1...14 { p.fill(x, 4, x, 5, (x / 2) % 2 == 0 ? red : c("#f0eee8")) }
            p.fill(2, 7, 9, 12, c("#f2c14e"))
            p.fill(4, 8, 7, 11, c("#9a5a2a"))
            p.fill(5, 7, 6, 7, c("#b8bcc8"))
            p.fill(11, 8, 13, 15, dark)
        case .barbier:
            p.fill(0, 2, 11, 3, dark)
            p.fill(1, 4, 11, 15, c("#2a4a6a"))
            p.fill(2, 6, 7, 10, c("#9fd4e8"))
            p.fill(4, 11, 7, 12, red)
            p.fill(8, 11, 10, 15, dark)
            for y in 3...14 { for x in 13...14 { p.dot(x, y, (x + y) % 4 < 2 ? red : c("#f0eee8")) } }
            p.fill(12, 2, 15, 2, c("#b8bcc8")); p.fill(12, 15, 15, 15, c("#b8bcc8"))
        case .salleBoxe:
            p.circle(cx: 9, cy: 6, radius: 5, red)
            p.circle(cx: 4, cy: 7, radius: 2, c("#c43a22"))
            p.fill(5, 10, 13, 14, red)
            p.fill(5, 12, 13, 12, c("#f0eee8"))
            p.dot(7, 3, c("#ff9a8a")); p.dot(8, 2, c("#ff9a8a"))
        case .disquaire:
            p.circle(cx: 8, cy: 8, radius: 7, c("#14141a"))
            p.circle(cx: 8, cy: 8, radius: 5, c("#24242c"))
            p.circle(cx: 8, cy: 8, radius: 4, c("#14141a"))
            p.circle(cx: 8, cy: 8, radius: 2, c("#4fd6e0"))
            p.dot(8, 8, dark)
            p.dot(4, 5, c("#b8bcc8")); p.dot(5, 4, c("#b8bcc8"))
        case .radioPirate:
            p.fill(7, 2, 8, 10, c("#b8bcc8"))
            p.fill(6, 5, 9, 5, c("#b8bcc8")); p.fill(5, 8, 10, 8, c("#b8bcc8"))
            p.dot(7, 1, red); p.dot(8, 1, red)
            for (x, y) in [(4, 1), (3, 2), (3, 3), (4, 4), (11, 1), (12, 2), (12, 3), (11, 4)] { p.dot(x, y, c("#ff5ab4")) }
            p.fill(1, 10, 14, 15, c("#5a5a4a"))
            p.fill(3, 12, 6, 13, gold)
            p.fill(10, 12, 12, 15, dark)
        case .labelInde:
            p.fill(1, 1, 14, 15, c("#26263a"))
            p.fill(3, 2, 5, 3, gold); p.fill(10, 2, 12, 3, gold)
            p.circle(cx: 8, cy: 7, radius: 3, gold)
            p.dot(8, 7, dark)
            p.fill(2, 11, 13, 15, c("#3a6a8a"))
            p.fill(7, 11, 8, 15, dark)
        case .fresqueGeante:
            p.fill(0, 1, 15, 4, c("#3b2a6a"))
            p.fill(0, 5, 15, 8, c("#7a3a8a"))
            p.fill(0, 9, 15, 11, c("#e04fb0"))
            p.fill(0, 12, 15, 14, c("#ff8a3a"))
            p.circle(cx: 7, cy: 8, radius: 3, c("#1a1030"))
            p.fill(3, 11, 11, 14, c("#1a1030"))
            p.fill(4, 3, 10, 4, gold)
            p.circle(cx: 12, cy: 10, radius: 1, gold)
        }
        return p
    }
}
