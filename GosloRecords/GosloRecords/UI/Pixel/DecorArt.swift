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
        case .boutiqueMerch, .panneauGeant, .labelInde, .snack: PixelColor(hex: "#f2c14e")
        case .barbier, .salleBoxe: PixelColor(hex: "#ff4d2e")
        case .disquaire: PixelColor(hex: "#4fd6e0")
        case .radioPirate: PixelColor(hex: "#e04fb0")
        case .fresqueGeante: nil
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
        case .snack: snack().outlined()
        case .barbier: barber().outlined()
        case .salleBoxe: boxingGym().outlined()
        case .disquaire: recordShop().outlined()
        case .radioPirate: pirateRadio().outlined()
        case .labelInde: labelHouse().outlined()
        case .fresqueGeante: mural().outlined()
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

    // MARK: Neighbourhood businesses

    /// Momo's kebab shop (two tiles wide, one deep): green tiles, striped awning, the spit turning in the lit window.
    private static func snack() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 30)
        let wall = PixelColor(hex: "#2f6b4f"), cream = PixelColor(hex: "#f0eee8"), awning = PixelColor(hex: "#e04f4f")
        let meat = PixelColor(hex: "#9a5a2a")
        c.fill(1, 6, 30, 29, wall)
        for y in stride(from: 13, through: 28, by: 3) { c.fill(1, y, 2, y, wall.shaded(0.8)); c.fill(20, y, 21, y, wall.shaded(0.8)) }
        c.fill(0, 5, 31, 6, PixelColor(hex: "#1c1c24"))
        // The sign on the roof.
        let text = "KEBAB", w = PixelFont.width(text)
        c.fill((32 - w) / 2 - 2, 0, (32 + w) / 2 + 1, 5, PixelColor(hex: "#14141a"))
        PixelFont.draw(text, on: c, x: (32 - w) / 2, y: 0, gold)
        // Awning.
        for x in 1...30 { c.fill(x, 7, x, 9, (x / 3) % 2 == 0 ? awning : cream) }
        c.fill(1, 10, 30, 10, awning.shaded(0.7))
        // The window: the spit, the menu, the counter.
        c.fill(3, 12, 19, 24, NightPalette.windowLit.shaded(0.9))
        c.fill(8, 12, 9, 13, NightPalette.metal); c.fill(8, 22, 9, 23, NightPalette.metal)
        c.fill(7, 14, 10, 21, meat); c.fill(6, 15, 11, 19, meat)
        for y in stride(from: 15, through: 20, by: 2) { c.fill(7, y, 10, y, meat.shaded(0.75)) }
        c.dot(6, 15, meat.shaded(1.3)); c.dot(7, 14, meat.shaded(1.3))
        c.fill(13, 13, 18, 18, PixelColor(hex: "#1c1c24"))
        for y in [14, 16] { c.fill(14, y, 17, y, gold) }
        c.fill(2, 23, 20, 24, NightPalette.metal.shaded(1.3))
        c.fill(4, 22, 5, 22, PixelColor(hex: "#f0d060")); c.fill(15, 22, 17, 22, awning)
        // Door.
        c.fill(23, 13, 29, 29, NightPalette.door)
        c.fill(24, 14, 28, 20, NightPalette.windowLit.shaded(0.6))
        c.dot(24, 23, gold)
        return c
    }

    /// The barber's: a blue shopfront, the spinning striped pole, a chair facing the mirror in the window.
    private static func barber() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 46)
        let wall = PixelColor(hex: "#2a4a6a"), red = PixelColor(hex: "#e04f4f"), cream = PixelColor(hex: "#f0eee8")
        c.fill(1, 10, 30, 45, wall)
        for y in stride(from: 21, through: 44, by: 4) { c.fill(1, y, 30, y, wall.shaded(0.85)) }
        c.fill(0, 8, 31, 10, PixelColor(hex: "#1c1c24"))
        // Sign.
        let text = "BARBER", w = PixelFont.width(text)
        c.fill(2, 12, 29, 18, PixelColor(hex: "#14141a"))
        PixelFont.draw(text, on: c, x: (32 - w) / 2, y: 13, cream)
        // Window: the mirror, the red chair.
        c.fill(3, 22, 16, 35, NightPalette.windowLit.shaded(0.85))
        c.fill(4, 23, 10, 28, PixelColor(hex: "#9fd4e8")); c.fill(4, 23, 10, 23, PixelColor(hex: "#d8f0f8"))
        c.fill(9, 30, 14, 32, red); c.fill(13, 26, 14, 32, red); c.fill(13, 26, 14, 26, red.shaded(1.3))
        c.fill(11, 33, 12, 35, NightPalette.metal)
        c.fill(2, 36, 17, 36, NightPalette.metal.shaded(1.2))
        // Door.
        c.fill(18, 30, 24, 45, NightPalette.door)
        c.fill(19, 31, 23, 37, NightPalette.windowLit.shaded(0.6))
        c.dot(23, 40, gold)
        // The pole: red, white and blue stripes, a glass ball on top.
        c.fill(25, 20, 29, 21, NightPalette.metal); c.fill(25, 37, 29, 38, NightPalette.metal)
        for y in 22...36 {
            for x in 26...28 {
                let k = (x + y) % 6
                c.dot(x, y, k < 2 ? red : (k < 4 ? cream : PixelColor(hex: "#3b5bdb")))
            }
        }
        c.circle(cx: 27, cy: 18, radius: 1, PixelColor(hex: "#ffe8a0"))
        return c
    }

    /// The boxing gym (three tiles wide): a brick hall, BOXE in red, a glove painted on the wall,
    /// punching bags hanging behind the big window.
    private static func boxingGym() -> PixelCanvas {
        let c = PixelCanvas(width: 48, height: 46)
        let brick = PixelColor(hex: "#5b3a32"), red = PixelColor(hex: "#ff4d2e")
        c.fill(1, 12, 46, 45, brick)
        for y in stride(from: 14, through: 44, by: 3) {
            c.fill(1, y, 46, y, brick.shaded(0.8))
            for x in stride(from: (y / 3) % 2 == 0 ? 4 : 1, through: 46, by: 6) { c.dot(x, y + 1, brick.shaded(0.8)) }
        }
        c.fill(0, 10, 47, 12, PixelColor(hex: "#2a2a30"))
        c.fill(6, 6, 13, 9, NightPalette.metal); c.fill(7, 7, 12, 8, NightPalette.metal.shaded(0.7))
        // Sign.
        let text = "BOXE", w = PixelFont.width(text)
        c.fill(4, 14, 28, 20, PixelColor(hex: "#14141a"))
        PixelFont.draw(text, on: c, x: 4 + (25 - w) / 2, y: 15, red)
        // The glove on the wall.
        c.circle(cx: 38, cy: 19, radius: 5, red)
        c.circle(cx: 33, cy: 20, radius: 2, red.shaded(0.8))
        c.fill(34, 24, 42, 28, red); c.fill(34, 26, 42, 26, PixelColor(hex: "#f0eee8"))
        c.dot(36, 16, PixelColor(hex: "#ff9a8a")); c.dot(37, 15, PixelColor(hex: "#ff9a8a"))
        // Big window: three bags on chains, the blue ring mat.
        c.fill(3, 24, 30, 37, NightPalette.windowLit.shaded(0.7))
        for x in [8, 16, 24] {
            c.fill(x, 24, x, 26, NightPalette.metal)
            c.fill(x - 1, 27, x + 1, 33, PixelColor(hex: "#8a2a2a"))
            c.fill(x - 1, 27, x - 1, 33, PixelColor(hex: "#b84a3a"))
            c.fill(x - 1, 27, x + 1, 27, PixelColor(hex: "#14141a"))
        }
        c.fill(3, 35, 30, 37, PixelColor(hex: "#2a4a8a"))
        c.fill(3, 35, 30, 35, PixelColor(hex: "#f0eee8"))
        // Door.
        c.fill(35, 31, 42, 45, NightPalette.door)
        c.fill(36, 32, 41, 36, NightPalette.windowLit.shaded(0.55))
        c.dot(41, 39, gold)
        return c
    }

    /// The record shop: a purple front, DISQUES in cyan, a huge vinyl in the window above the crates.
    private static func recordShop() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 46)
        let wall = PixelColor(hex: "#3a2a4a"), cyan = PixelColor(hex: "#4fd6e0"), vinyl = PixelColor(hex: "#14141a")
        c.fill(1, 10, 30, 45, wall)
        c.fill(0, 8, 31, 10, PixelColor(hex: "#1c1c24"))
        // Sign.
        let text = "DISQUES", w = PixelFont.width(text)
        c.fill(1, 12, 30, 18, PixelColor(hex: "#14141a"))
        PixelFont.draw(text, on: c, x: (32 - w) / 2, y: 13, cyan)
        // Window: the vinyl and its grooves, the crates and their sleeves.
        c.fill(3, 21, 19, 37, NightPalette.windowLit.shaded(0.8))
        c.circle(cx: 11, cy: 27, radius: 5, vinyl)
        c.circle(cx: 11, cy: 27, radius: 3, PixelColor(hex: "#24242c"))
        c.circle(cx: 11, cy: 27, radius: 2, vinyl)
        c.circle(cx: 11, cy: 27, radius: 1, PixelColor(hex: "#e04f4f"))
        c.dot(8, 24, NightPalette.metal)
        let sleeves = ["#e04fb0", "#f2c14e", "#4fd6e0", "#7fe0a0", "#ff6a3a", "#f0eee8", "#3b5bdb", "#e04f4f"]
        for (i, x) in stride(from: 4, through: 18, by: 2).enumerated() { c.fill(x, 33, x, 35, PixelColor(hex: sleeves[i % sleeves.count])) }
        c.fill(3, 35, 19, 37, PixelColor(hex: "#8a5a34"))
        // Door, a little vinyl sticker on it.
        c.fill(22, 27, 28, 45, NightPalette.door)
        c.fill(23, 28, 27, 35, NightPalette.windowLit.shaded(0.6))
        c.circle(cx: 25, cy: 39, radius: 1, cyan)
        return c
    }

    /// The pirate radio (two tiles wide, one deep): a tin shack, a lattice mast with a red light,
    /// the waves going out, FM on the wall.
    private static func pirateRadio() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 42)
        let tin = PixelColor(hex: "#5a5a4a"), pink = PixelColor(hex: "#ff5ab4")
        // The mast: wider at the bottom, crossbars, the red light on top.
        for y in 3...25 {
            let half = (y - 3) / 9
            c.dot(22 - half, y, NightPalette.metal); c.dot(22 + half, y, NightPalette.metal)
            if y % 4 == 0 { c.fill(22 - half, y, 22 + half, y, NightPalette.metal) }
        }
        c.fill(22, 1, 22, 2, NightPalette.metal)
        c.dot(22, 0, PixelColor(hex: "#ff4d2e"))
        // Waves.
        for (x, y) in [(18, 1), (17, 2), (17, 3), (18, 4), (26, 1), (27, 2), (27, 3), (26, 4),
                       (14, 0), (13, 1), (13, 2), (13, 3), (13, 4), (14, 5), (30, 0), (31, 1), (31, 2), (31, 3), (31, 4), (30, 5)] {
            c.dot(x, y, pink)
        }
        // The shack, corrugated.
        c.fill(1, 26, 30, 41, tin)
        for x in stride(from: 2, through: 30, by: 3) { c.fill(x, 27, x, 41, tin.shaded(0.8)) }
        c.fill(0, 24, 31, 26, NightPalette.metal.shaded(0.8))
        // Window with the console.
        c.fill(3, 29, 10, 35, NightPalette.windowLit.shaded(0.8))
        for (x, color) in [(4, "#ff4d2e"), (6, "#7fe0a0"), (8, "#4fd6e0")] { c.fill(x, 33, x, 34, PixelColor(hex: color)) }
        // The FM sign.
        let text = "FM", w = PixelFont.width(text)
        c.fill(12, 28, 13 + w, 34, PixelColor(hex: "#14141a"))
        PixelFont.draw(text, on: c, x: 13, y: 29, pink)
        // Door.
        c.fill(24, 30, 29, 41, NightPalette.door)
        c.dot(25, 36, gold)
        return c
    }

    /// Your own label (three tiles wide): a glass-and-steel block, lit offices upstairs, LABEL in gold
    /// with a golden record, a water tank and a dish on the roof.
    private static func labelHouse() -> PixelCanvas {
        let c = PixelCanvas(width: 48, height: 50)
        let body = PixelColor(hex: "#26263a"), glass = PixelColor(hex: "#3a6a8a")
        // Roof: water tank and satellite dish.
        c.fill(6, 1, 13, 5, NightPalette.metal); c.fill(6, 1, 13, 1, NightPalette.metal.shaded(1.3))
        c.fill(7, 6, 7, 7, NightPalette.metal); c.fill(12, 6, 12, 7, NightPalette.metal)
        c.circle(cx: 38, cy: 4, radius: 2, NightPalette.metal.shaded(1.2)); c.fill(38, 6, 38, 7, NightPalette.metal)
        c.fill(0, 8, 47, 10, PixelColor(hex: "#1c1c24"))
        c.fill(1, 10, 46, 49, body)
        // Offices upstairs.
        for (i, x) in stride(from: 4, through: 40, by: 7).enumerated() {
            c.fill(x, 12, x + 4, 19, i % 2 == 0 ? NightPalette.windowLit.shaded(0.85) : NightPalette.windowDark)
            c.fill(x, 16, x + 4, 16, NightPalette.windowFrame)
        }
        c.fill(1, 22, 46, 23, NightPalette.metal.shaded(0.8))
        // Sign and the gold record.
        let text = "LABEL", w = PixelFont.width(text)
        c.fill(4, 25, 32, 31, PixelColor(hex: "#14141a"))
        PixelFont.draw(text, on: c, x: 4 + (29 - w) / 2, y: 26, gold)
        c.circle(cx: 40, cy: 28, radius: 4, gold)
        c.circle(cx: 40, cy: 28, radius: 2, goldDark)
        c.dot(40, 28, PixelColor(hex: "#14141a")); c.dot(38, 26, goldLight)
        // Glass front with a reflection.
        c.fill(3, 34, 30, 48, glass)
        for x in stride(from: 9, through: 27, by: 7) { c.fill(x, 34, x, 48, NightPalette.metal) }
        for i in 0..<6 { c.dot(5 + i, 36 + i, glass.shaded(1.5)); c.dot(19 + i, 36 + i, glass.shaded(1.4)) }
        // Double door and its red carpet.
        c.fill(34, 35, 44, 49, NightPalette.door)
        c.fill(35, 36, 38, 47, NightPalette.windowLit.shaded(0.6)); c.fill(40, 36, 43, 47, NightPalette.windowLit.shaded(0.6))
        c.fill(33, 49, 45, 49, PixelColor(hex: "#c43a3a"))
        return c
    }

    /// The monumental fresco (three tiles wide): a whole wall painted at sunset, your silhouette with a cap,
    /// a crown and the golden mic, the city's towers behind, spray cans at the foot.
    private static func mural() -> PixelCanvas {
        let c = PixelCanvas(width: 48, height: 40)
        let shadow = PixelColor(hex: "#1a1030"), brick = PixelColor(hex: "#6b4a3a")
        c.fill(0, 0, 47, 2, PixelColor(hex: "#5e5e68"))
        c.fill(0, 2, 47, 39, brick)
        // The sky, in bands.
        for y in 4...33 {
            let hex = y < 11 ? "#3b2a6a" : (y < 18 ? "#7a3a8a" : (y < 25 ? "#e04fb0" : "#ff8a3a"))
            c.fill(2, y, 45, y, PixelColor(hex: hex))
        }
        c.circle(cx: 35, cy: 24, radius: 6, gold)
        for (x, y) in [(6, 6), (12, 9), (40, 5), (44, 10), (30, 7)] { c.dot(x, y, goldLight) }
        // Towers behind.
        c.fill(3, 22, 8, 33, shadow); c.fill(9, 26, 12, 33, shadow); c.fill(38, 20, 43, 33, shadow); c.fill(33, 27, 37, 33, shadow)
        for (x, y) in [(5, 24), (5, 28), (40, 23), (40, 27), (42, 30)] { c.dot(x, y, NightPalette.windowLit) }
        // The silhouette: cap, head, shoulders, the mic.
        c.circle(cx: 22, cy: 17, radius: 5, shadow)
        c.fill(16, 11, 27, 13, shadow); c.fill(27, 13, 30, 13, shadow)
        c.fill(14, 23, 30, 33, shadow); c.fill(16, 22, 28, 22, shadow)
        c.circle(cx: 31, cy: 20, radius: 2, gold); c.fill(30, 22, 31, 27, goldDark)
        // The crown above.
        c.fill(17, 7, 26, 9, gold)
        for x in [17, 21, 22, 26] { c.dot(x, 6, gold) }
        c.dot(21, 5, gold); c.dot(22, 5, gold); c.dot(19, 8, PixelColor(hex: "#e04f4f")); c.dot(24, 8, PixelColor(hex: "#4fd6e0"))
        // Brick base, the tag along it, and the spray cans.
        for y in stride(from: 35, through: 38, by: 2) { c.fill(0, y, 47, y, brick.shaded(0.8)) }
        PixelFont.draw("GOSLO", on: c, x: 14, y: 35, PixelColor(hex: "#f0eee8"))
        for (x, hex) in [(4, "#e04f4f"), (7, "#4fd6e0"), (41, "#f2c14e")] {
            c.fill(x, 35, x + 1, 39, PixelColor(hex: hex)); c.fill(x, 34, x + 1, 34, NightPalette.metal)
        }
        return c
    }
}
