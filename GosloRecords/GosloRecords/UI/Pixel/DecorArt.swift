import UIKit

/// The decorations the player puts on the map's free spots (`Decor`), in pixel art at the map's scale
/// (16 pixels = one tile). Each sprite stands on its tile: its bottom edge is the tile's bottom edge.
/// Most fit in one tile and grow upward; the food truck runs over the tile to the right.
@MainActor
enum DecorArt {
    static func image(_ decor: Decor) -> UIImage {
        PixelCache.image("decor-\(decor.rawValue)") { canvas(decor).makeImage() }
    }

    /// The light it gives off at night (a glow drawn around it on the map), if any.
    static func glow(_ decor: Decor) -> PixelColor? {
        switch decor {
        case .neonGoslo: Location.media.neon
        case .borneArcade: PixelColor(hex: "#4fd6e0")
        case .statueMicro: PixelColor(hex: "#f2c14e")
        case .sono: PixelColor(hex: "#e04fb0")
        case .studioPerso: PixelColor(hex: "#ff4d2e")
        case .scenePleinAir: PixelColor(hex: "#e04fb0")
        case .boutiqueMerch, .panneauGeant: PixelColor(hex: "#f2c14e")
        case .fresque, .bancDore, .palmier, .foodTruck: nil
        }
    }

    private static func canvas(_ decor: Decor) -> PixelCanvas {
        switch decor {
        case .fresque: fresque()
        case .sono: sono().outlined()
        case .bancDore: goldenBench().outlined()
        case .palmier: palm().outlined()
        case .borneArcade: arcade().outlined()
        case .foodTruck: foodTruck().outlined()
        case .statueMicro: statue().outlined()
        case .neonGoslo: neon().outlined()
        case .panneauGeant: billboard().outlined()
        case .studioPerso: studio().outlined()
        case .scenePleinAir: stage().outlined()
        case .boutiqueMerch: merch().outlined()
        }
    }

    private static let gold = PixelColor(hex: "#f2c14e")
    private static let goldDark = PixelColor(hex: "#b8862a")
    private static let goldLight = PixelColor(hex: "#ffe8a0")

    /// A piece painted on the pavement: a sunburst ring, a microphone in the middle, splashes of colour.
    private static func fresque() -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 16)
        let colors = ["#e04fb0", "#f2c14e", "#4fd6e0", "#7fe0a0", "#ff6a3a"].map(PixelColor.init(hex:))
        for y in 0..<16 {
            for x in 0..<16 {
                let dx = Double(x) - 7.5, dy = Double(y) - 7.5, d = (dx * dx + dy * dy).squareRoot()
                guard d <= 7.6 else { continue }
                let ray = Int((atan2(dy, dx) + .pi) / (2 * .pi) * 10) % colors.count
                c.dot(x, y, (d > 5.5 ? colors[ray] : colors[(ray + 2) % colors.count]).shaded(0.85))
            }
        }
        c.circle(cx: 8, cy: 8, radius: 3, PixelColor(hex: "#1a1030"))
        // The microphone.
        c.fill(7, 5, 8, 7, PixelColor(hex: "#d8d8e0")); c.dot(7, 6, PixelColor(hex: "#8a8a96"))
        c.fill(7, 8, 8, 10, PixelColor(hex: "#f0eee8"))
        // Splashes.
        for (x, y, i) in [(0, 2, 0), (15, 4, 1), (1, 14, 2), (14, 13, 3), (12, 0, 4)] { c.dot(x, y, colors[i]) }
        return c
    }

    /// Two speaker stacks on a flight case, cones and tweeters, a little light on top.
    private static func sono() -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 20)
        let box = PixelColor(hex: "#1c1c22"), cone = PixelColor(hex: "#5a5a66"), pink = PixelColor(hex: "#e04fb0")
        c.fill(1, 17, 14, 19, PixelColor(hex: "#2a2a30"))
        c.fill(1, 17, 14, 17, NightPalette.metal.shaded(1.3))
        for x0 in [1, 8] {
            c.fill(x0, 4, x0 + 6, 16, box)
            c.circle(cx: x0 + 3, cy: 12, radius: 3, cone); c.dot(x0 + 3, 12, box)
            c.fill(x0 + 1, 6, x0 + 5, 7, cone.shaded(1.3))
            c.fill(x0 + 2, 6, x0 + 4, 6, cone.shaded(0.6))
            c.fill(x0, 4, x0 + 6, 4, box.shaded(1.6))
        }
        c.fill(5, 1, 10, 3, box)
        c.fill(6, 2, 9, 2, pink)
        return c
    }

    /// The legends' bench, all gold, a little shine on the backrest.
    private static func goldenBench() -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 16)
        c.fill(1, 3, 14, 6, gold)
        c.fill(1, 3, 14, 3, goldLight)
        c.fill(1, 8, 14, 11, goldDark.shaded(1.15))
        c.fill(1, 8, 14, 8, gold)
        c.fill(2, 12, 3, 15, goldDark); c.fill(12, 12, 13, 15, goldDark)
        c.fill(0, 6, 1, 9, goldDark); c.fill(14, 6, 15, 9, goldDark)
        for (x, y) in [(4, 4), (10, 9)] { c.dot(x, y, PixelColor(hex: "#ffffff")) }
        return c
    }

    /// A palm in a terracotta pot.
    private static func palm() -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 26)
        let leaf = PixelColor(hex: "#2f8a4a"), leafLight = PixelColor(hex: "#5ab86a"), pot = PixelColor(hex: "#b8603a")
        c.fill(4, 19, 11, 25, pot)
        c.fill(3, 18, 12, 19, pot.shaded(1.2))
        c.fill(5, 21, 10, 21, pot.shaded(0.8))
        c.fill(7, 7, 8, 18, PixelColor(hex: "#7a5a34"))
        for y in stride(from: 9, to: 18, by: 3) { c.fill(7, y, 8, y, PixelColor(hex: "#5a4024")) }
        // Fronds falling on both sides.
        for (i, dx) in [-7, -5, -3, 3, 5, 7].enumerated() {
            let steps = abs(dx)
            for s in 0...steps {
                let x = 8 + (dx < 0 ? -s : s), y = 6 - (s < steps / 2 ? s / 2 : 0) + (s > steps / 2 ? (s - steps / 2) : 0)
                c.dot(x, y, i % 2 == 0 ? leaf : leafLight)
                c.dot(x, y + 1, leaf.shaded(0.8))
            }
        }
        c.fill(6, 3, 9, 6, leaf); c.fill(7, 1, 8, 3, leafLight)
        c.circle(cx: 8, cy: 7, radius: 1, PixelColor(hex: "#5a3a1a"))
        return c
    }

    /// An arcade cabinet: lit marquee, glowing screen, joystick and buttons.
    private static func arcade() -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 26)
        let body = PixelColor(hex: "#4a2a7a"), side = PixelColor(hex: "#3a1f62")
        c.fill(2, 2, 13, 25, body)
        c.fill(2, 2, 3, 25, side); c.fill(12, 2, 13, 25, side)
        // Marquee.
        c.fill(2, 1, 13, 5, PixelColor(hex: "#e04fb0"))
        c.fill(4, 2, 11, 4, PixelColor(hex: "#ff9ad8"))
        c.fill(5, 3, 10, 3, PixelColor(hex: "#ffffff"))
        // Screen with a little game on it.
        c.fill(4, 7, 11, 13, PixelColor(hex: "#101828"))
        c.fill(5, 8, 10, 12, PixelColor(hex: "#1f6a8a"))
        c.dot(6, 11, PixelColor(hex: "#f2c14e")); c.dot(9, 9, PixelColor(hex: "#e04f4f")); c.fill(5, 12, 10, 12, PixelColor(hex: "#7fe0a0"))
        // Control panel.
        c.fill(3, 15, 12, 17, PixelColor(hex: "#2a2a34"))
        c.fill(5, 13, 5, 15, NightPalette.metal); c.dot(5, 13, PixelColor(hex: "#e04f4f"))
        c.dot(8, 16, PixelColor(hex: "#f2c14e")); c.dot(10, 16, PixelColor(hex: "#4fd6e0"))
        // Coin slot and the side art stripe.
        c.fill(7, 20, 8, 22, PixelColor(hex: "#f2c14e").shaded(0.7))
        c.fill(12, 8, 13, 20, PixelColor(hex: "#4fd6e0").shaded(0.6))
        return c
    }

    /// A food truck, side view, two tiles long: open hatch lit inside, awning, menu board, wheels.
    private static func foodTruck() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 26)
        let body = PixelColor(hex: "#e8e4dc"), trim = PixelColor(hex: "#2a8a86"), awning = PixelColor(hex: "#e04f4f")
        let o = 4
        c.fill(1, o + 6, 30, o + 18, body)
        c.fill(1, o + 15, 30, o + 16, trim)
        // Cab at the front (right) with its windscreen.
        c.fill(24, o + 7, 29, o + 11, PixelColor(hex: "#1c2433"))
        c.fill(24, o + 7, 25, o + 8, PixelColor(hex: "#5a6a8a"))
        c.dot(30, o + 14, NightPalette.lampLight)
        // The hatch: lit kitchen, someone's shape, the counter.
        c.fill(4, o + 8, 19, o + 13, NightPalette.windowLit.shaded(0.9))
        c.fill(10, o + 9, 12, o + 13, PixelColor(hex: "#5a3a2a")); c.fill(10, o + 8, 12, o + 8, PixelColor(hex: "#f0eee8"))
        c.fill(3, o + 13, 20, o + 14, NightPalette.metal.shaded(1.3))
        for x in 3...20 { c.fill(x, o + 4, x, o + 6, (x / 3) % 2 == 0 ? awning : PixelColor(hex: "#f0eee8")) }
        c.fill(3, o + 7, 20, o + 7, awning.shaded(0.7))
        // The sign on the roof, on two little posts.
        let text = "FOOD", w = PixelFont.width(text)
        c.fill(5, 0, 7 + w, 6, PixelColor(hex: "#14141a"))
        PixelFont.draw(text, on: c, x: 6, y: 1, gold)
        c.fill(7, 7, 7, o + 3, NightPalette.metal); c.fill(5 + w, 7, 5 + w, o + 3, NightPalette.metal)
        // Wheels.
        for wx in [6, 24] {
            c.circle(cx: wx, cy: o + 19, radius: 2, PixelColor(hex: "#14141a"))
            c.dot(wx, o + 19, NightPalette.metal)
        }
        return c
    }

    /// The golden microphone on a stone plinth, a plaque in front.
    private static func statue() -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 30)
        let stone = PixelColor(hex: "#8a8478")
        c.fill(2, 22, 13, 29, stone)
        c.fill(1, 21, 14, 22, stone.shaded(1.25))
        c.fill(2, 29, 13, 29, stone.shaded(0.7))
        c.fill(5, 24, 10, 26, goldDark)
        // Stand and microphone.
        c.fill(7, 11, 8, 20, gold)
        c.fill(4, 19, 11, 20, goldDark)
        c.fill(5, 9, 10, 11, goldDark)
        c.circle(cx: 8, cy: 5, radius: 4, gold)
        for y in stride(from: 3, through: 7, by: 2) { c.fill(5, y, 10, y, goldDark) }
        c.dot(6, 3, goldLight); c.dot(6, 4, goldLight)
        c.fill(4, 8, 11, 8, goldLight)
        return c
    }

    /// The goslo radio neon: the gold sound wave and the name in pink, on a black panel between two posts.
    private static func neon() -> PixelCanvas {
        let c = PixelCanvas(width: 24, height: 24)
        let wave = Location.media.neon, pink = PixelColor(hex: "#ff5ab4")
        c.fill(2, 12, 3, 23, NightPalette.metal); c.fill(20, 12, 21, 23, NightPalette.metal)
        c.fill(0, 0, 23, 15, PixelColor(hex: "#0e0e14"))
        c.fill(0, 0, 23, 0, NightPalette.metal.shaded(1.2))
        for (i, h) in [1, 3, 2, 5, 3, 6, 3, 5, 2, 3, 1].enumerated() {
            let x = 1 + i * 2
            c.fill(x, 7 - h, x, 7, wave)
        }
        let text = "GOSLO"
        PixelFont.draw(text, on: c, x: (24 - PixelFont.width(text)) / 2, y: 9, pink)
        return c
    }

    // MARK: Buildings (two tiles wide, they block the way)

    /// A 4×3 billboard on two posts: the player's name in lights would need the name; a gold mic and stars do.
    private static func billboard() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 36)
        c.fill(5, 20, 6, 35, NightPalette.metal); c.fill(25, 20, 26, 35, NightPalette.metal)
        c.fill(0, 0, 31, 21, PixelColor(hex: "#14141a"))
        c.fill(1, 1, 30, 20, PixelColor(hex: "#2a1a40"))
        // A spotlight beam, the gold mic and stars.
        for y in 2...19 { c.fill(16 - y / 3, y, 16 + y / 3, y, PixelColor(hex: "#3d2a5a")) }
        c.circle(cx: 16, cy: 7, radius: 3, gold)
        c.fill(15, 10, 17, 15, gold); c.fill(13, 16, 19, 17, goldDark)
        for (x, y) in [(4, 4), (27, 6), (6, 15), (25, 16), (22, 3)] { c.dot(x, y, goldLight) }
        PixelFont.draw("STAR", on: c, x: 2, y: 2, PixelColor(hex: "#ff5ab4"))
        // Lamps on top.
        for x in [4, 15, 26] { c.fill(x, 0, x + 2, 0, NightPalette.lampLight) }
        return c
    }

    /// The player's own studio: a small brick block, the red REC light, a lit window with the console.
    private static func studio() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 46)
        let brick = PixelColor(hex: "#6b3a30")
        c.fill(1, 12, 30, 45, brick)
        for y in stride(from: 14, through: 44, by: 3) { c.fill(1, y, 30, y, brick.shaded(0.8)) }
        // Flat roof, an AC unit.
        c.fill(0, 10, 31, 12, PixelColor(hex: "#2a2a30"))
        c.fill(20, 5, 27, 9, NightPalette.metal); c.fill(21, 6, 26, 8, NightPalette.metal.shaded(0.7))
        // The sign and the REC light.
        c.fill(4, 15, 27, 21, PixelColor(hex: "#14141a"))
        PixelFont.draw("STUDIO", on: c, x: 5, y: 16, PixelColor(hex: "#f0eee8"))
        c.circle(cx: 27, cy: 26, radius: 2, PixelColor(hex: "#ff4d2e"))
        // Window: the console's lights.
        c.fill(4, 25, 20, 33, NightPalette.windowLit.shaded(0.8))
        for x in stride(from: 6, through: 18, by: 3) { c.fill(x, 30, x, 32, PixelColor(hex: x % 2 == 0 ? "#4fd6e0" : "#ff4d2e")) }
        // Heavy door.
        c.fill(22, 33, 29, 45, PixelColor(hex: "#1c1c22")); c.dot(23, 39, gold)
        return c
    }

    /// An open-air stage: a wooden deck, a truss with lights, speakers on each side.
    private static func stage() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 44)
        let wood = PixelColor(hex: "#8a5a34"), truss = NightPalette.metal
        // Truss frame.
        c.fill(1, 6, 2, 43, truss); c.fill(29, 6, 30, 43, truss); c.fill(1, 6, 30, 8, truss)
        for x in stride(from: 4, through: 28, by: 4) { c.fill(x, 9, x + 1, 10, PixelColor(hex: ["#ff5ab4", "#f2c14e", "#4fd6e0"][(x / 4) % 3])) }
        // Back drop.
        c.fill(3, 11, 28, 30, PixelColor(hex: "#1a1030"))
        PixelFont.draw("LIVE", on: c, x: 9, y: 14, PixelColor(hex: "#ff5ab4"))
        c.circle(cx: 16, cy: 25, radius: 3, gold); c.fill(15, 28, 17, 30, gold)
        // The deck.
        c.fill(0, 31, 31, 37, wood)
        c.fill(0, 31, 31, 31, wood.shaded(1.3))
        for x in stride(from: 3, through: 30, by: 6) { c.fill(x, 32, x, 37, wood.shaded(0.75)) }
        c.fill(2, 38, 29, 43, wood.shaded(0.6))
        // Speakers.
        for x in [3, 24] {
            c.fill(x, 21, x + 4, 30, PixelColor(hex: "#14141a"))
            c.circle(cx: x + 2, cy: 27, radius: 1, NightPalette.metal)
        }
        return c
    }

    /// The merch shop: a shopfront with an awning, T-shirts and caps in the window, MERCH in gold.
    private static func merch() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 46)
        let wall = PixelColor(hex: "#2e2e3a"), awning = PixelColor(hex: "#ff4d2e")
        c.fill(1, 10, 30, 45, wall)
        c.fill(0, 8, 31, 10, PixelColor(hex: "#1c1c24"))
        // Sign.
        c.fill(3, 12, 28, 18, PixelColor(hex: "#14141a"))
        PixelFont.draw("MERCH", on: c, x: 6, y: 13, gold)
        // Awning stripes.
        for x in 1...30 { c.fill(x, 20, x, 23, (x / 3) % 2 == 0 ? awning : PixelColor(hex: "#f0eee8")) }
        // Window with T-shirts and a cap.
        c.fill(3, 25, 19, 37, NightPalette.windowLit.shaded(0.85))
        for (x, color) in [(5, "#ff4d2e"), (11, "#14141a")] {
            c.fill(x, 28, x + 4, 33, PixelColor(hex: color)); c.fill(x - 1, 28, x + 5, 29, PixelColor(hex: color))
        }
        c.fill(16, 30, 18, 31, PixelColor(hex: "#4fd6e0")); c.fill(15, 32, 19, 32, PixelColor(hex: "#4fd6e0"))
        // Door.
        c.fill(22, 27, 28, 45, PixelColor(hex: "#141418")); c.fill(23, 28, 27, 35, NightPalette.windowLit.shaded(0.6))
        return c
    }
}
