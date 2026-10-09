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
        }
        return p
    }
}
