import SwiftUI
import UIKit

/// Pixel art for the victory chests (one per rarity, closed and open) and the league badges (cached).
@MainActor
enum ChestArt {
    private static func c(_ hex: String) -> PixelColor { PixelColor(hex: hex) }

    /// Wood, metal bands, highlight.
    private static func palette(_ rarity: ChestRarity) -> (wood: PixelColor, band: PixelColor, shine: PixelColor) {
        switch rarity {
        case .bronze: (c("#8a5a32"), c("#c47a3d"), c("#e8a46a"))
        case .argent: (c("#4f5866"), c("#c9ced8"), c("#ffffff"))
        case .or: (c("#9a6a1c"), c("#f2c14e"), c("#fff1a8"))
        case .legendaire: (c("#4a2378"), c("#c86bff"), c("#5ef2ff"))
        }
    }

    static func chest(_ rarity: ChestRarity, open: Bool = false) -> UIImage {
        PixelCache.image("chest_\(rarity.rawValue)_\(open)") { draw(rarity, open: open).outlined().makeImage() }
    }

    /// 20×18: the lid on top (rows 2–7), the body below (rows 8–16). Open: the lid flips back, the inside glows.
    private static func draw(_ rarity: ChestRarity, open: Bool) -> PixelCanvas {
        let p = PixelCanvas(width: 20, height: 18)
        let (wood, band, shine) = palette(rarity)
        let dark = wood.shaded(0.65)
        // Body.
        p.fill(2, 9, 17, 16, wood)
        p.fill(2, 15, 17, 16, dark)
        p.fill(2, 9, 3, 16, band)
        p.fill(16, 9, 17, 16, band)
        p.fill(2, 12, 17, 12, band.shaded(0.85))
        if open {
            // Lid thrown back: a thin slab above, the glow pouring out.
            p.fill(3, 1, 16, 3, dark)
            p.fill(3, 1, 16, 1, band)
            p.fill(4, 4, 15, 8, c("#fff6c8"))
            p.fill(6, 5, 13, 7, shine)
            p.fill(4, 8, 15, 8, c("#ffd84d"))
            // Sparkles.
            p.dot(2, 3, shine); p.dot(17, 2, shine); p.dot(9, 0, shine)
        } else {
            // Rounded lid.
            p.fill(3, 3, 16, 8, wood)
            p.fill(4, 2, 15, 2, wood)
            p.fill(4, 3, 15, 3, wood.shaded(1.25))
            p.fill(2, 7, 17, 8, band)
            p.fill(3, 3, 4, 8, band)
            p.fill(15, 3, 16, 8, band)
            // Lock.
            p.fill(8, 7, 11, 11, band)
            p.fill(9, 8, 10, 10, c("#16161a"))
            p.dot(9, 7, shine)
        }
        if rarity == .legendaire {
            // Gems on the corners.
            p.dot(3, 13, shine); p.dot(16, 13, shine)
            if !open { p.dot(5, 4, shine); p.dot(14, 4, shine) }
        }
        return p
    }

    static func badge(_ league: League) -> UIImage {
        PixelCache.image("league_\(league.rawValue)") { drawBadge(league).outlined().makeImage() }
    }

    /// 14×16 shield with a mic, in the league's colour (a crown on top from Légende).
    private static func drawBadge(_ league: League) -> PixelCanvas {
        let p = PixelCanvas(width: 14, height: 16)
        let color = c(league.color)
        let light = color.shaded(1.3), dark = color.shaded(0.6)
        p.fill(1, 3, 12, 10, color)
        p.fill(2, 11, 11, 12, color)
        p.fill(4, 13, 9, 14, color)
        p.fill(6, 15, 7, 15, color)
        p.fill(1, 3, 12, 3, light)
        p.fill(11, 4, 12, 10, dark)
        // Mic.
        p.fill(6, 5, 7, 8, c("#16161a"))
        p.fill(5, 9, 8, 9, c("#16161a"))
        p.fill(6, 10, 7, 11, c("#16161a"))
        if league >= .legende {
            p.dot(3, 1, light); p.dot(7, 0, light); p.dot(10, 1, light)
            p.fill(3, 2, 10, 2, light)
        }
        return p
    }
}

/// The league badge with the trophy count ("🏆 412").
struct LeagueBadge: View {
    let league: League
    let trophies: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            PixelImage(ChestArt.badge(league), width: size)
            Text("\(trophies)")
                .font(.mono(size * 0.62, weight: .heavy))
                .foregroundStyle(league.tint)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ligue \(league.name), \(trophies) trophées")
    }
}

extension League {
    /// The league's colour, for text and frames.
    var tint: Color {
        let p = PixelColor(hex: color)
        return Color(red: Double(p.r) / 255, green: Double(p.g) / 255, blue: Double(p.b) / 255)
    }
}

extension ChestRarity {
    var tint: Color {
        switch self {
        case .bronze: Color(red: 0.77, green: 0.48, blue: 0.24)
        case .argent: Color(red: 0.79, green: 0.81, blue: 0.85)
        case .or: Color(red: 0.95, green: 0.76, blue: 0.31)
        case .legendaire: Color(red: 0.78, green: 0.42, blue: 1)
        }
    }
}
