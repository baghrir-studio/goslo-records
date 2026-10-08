import UIKit

// Each place gets its own façade around its door, so it reads at a glance even without the sign:
// Fred's concrete Bunker, goslo radio's studio window and frequency, the laundromat's machines and lit
// "LAVERIE" sign (goslo records hides in its back room), home's entrance under Mum's window, the Transfo's
// marquee downtown. Only paints over the building's own tiles; the door itself stays a dark doorway.

@MainActor
extension TileArt {
    /// Where a storefront is painted: the door's pixel origin and the building around it.
    struct Front {
        let door: TilePoint
        let map: WorldMap
        let theme: CityTheme

        // 16 = TileArt.size, kept literal so this plain struct needs no actor.
        var x: Int { door.x * 16 }
        var y: Int { door.y * 16 }

        func isBuilding(_ dx: Int, _ dy: Int) -> Bool {
            let kind = map.tile(at: TilePoint(x: door.x + dx, y: door.y + dy))
            return kind == .wall || kind == .roof || kind == .door
        }

        func isWall(_ dx: Int, _ dy: Int) -> Bool {
            map.tile(at: TilePoint(x: door.x + dx, y: door.y + dy)) == .wall
        }
    }

    static func storefront(_ location: Location, at door: TilePoint, on c: PixelCanvas, map: WorldMap, theme t: CityTheme,
                           district: District) {
        let front = Front(door: door, map: map, theme: t)
        switch location {
        case .studio: bunker(front, on: c)
        case .media: radio(front, on: c)
        case .scene: if district == .dome { marquee(front, on: c) } else { transfo(front, on: c) }
        case .label: laundromat(front, on: c)
        case .chezToi: home(front, on: c)
        case .quartier, .reseaux: break
        }
    }

    /// Paints a wall tile next to the door back to plain façade, before a storefront draws on it.
    private static func plainWall(_ f: Front, _ dx: Int, _ dy: Int, on c: PixelCanvas) {
        let p = TilePoint(x: f.door.x + dx, y: f.door.y + dy)
        let tile = PixelCanvas(width: size, height: size)
        facade(tile, p, f.theme)
        c.stamp(tile, at: p.x * size, p.y * size)
    }

    private static let white = PixelColor(hex: "#f0eee8")
    private static let ink = PixelColor(hex: "#101014")

    // MARK: Le Bunker

    /// Fred's studio: a steel shutter half open on a red room, a stencilled plate, sandbags, a camera.
    private static func bunker(_ f: Front, on c: PixelCanvas) {
        let x = f.x, y = f.y, neon = Location.studio.neon
        // Steel roller shutter, half open on a red-lit room.
        c.fill(x + 4, y + 4, x + 11, y + 15, PixelColor(hex: "#3a1a14"))
        c.fill(x + 4, y + 13, x + 11, y + 15, neon.shaded(0.55))
        c.fill(x + 4, y + 4, x + 11, y + 11, PixelColor(hex: "#6a6d76"))
        for row in stride(from: y + 5, through: y + 11, by: 2) { c.fill(x + 4, row, x + 11, row, PixelColor(hex: "#4a4d56")) }
        c.fill(x + 4, y + 12, x + 11, y + 12, PixelColor(hex: "#2a2a30"))
        // The name stencilled on an olive plate, the red REC light beside it.
        if f.isBuilding(0, -1) {
            let text = "BUNKER", w = PixelFont.width(text)
            let left = x + 8 - w / 2 - 3
            c.fill(left, y - 13, left + w + 5, y - 5, PixelColor(hex: "#3a3e2a"))
            c.fill(left, y - 5, left + w + 5, y - 5, PixelColor(hex: "#26281c"))
            for (bx, by) in [(left + 1, y - 12), (left + w + 4, y - 12), (left + 1, y - 6), (left + w + 4, y - 6)] {
                c.dot(bx, by, PixelColor(hex: "#6a6e58"))
            }
            PixelFont.draw(text, on: c, x: left + 3, y: y - 11, PixelColor(hex: "#d8d4b0"))
            if f.isBuilding(2, -1) {
                let rx = left + w + 8, red = PixelColor(hex: "#ff2a1a")
                c.fill(rx, y - 13, rx + 16, y - 6, ink)
                c.fill(rx + 2, y - 11, rx + 3, y - 9, red)
                PixelFont.draw("REC", on: c, x: rx + 5, y: y - 12, red)
            }
        }
        // A security camera on the corner.
        if f.isWall(-2, -1) {
            let cx = x - 2 * size
            c.fill(cx + 4, y - 12, cx + 10, y - 9, PixelColor(hex: "#c8c8d0"))
            c.fill(cx + 11, y - 11, cx + 12, y - 7, NightPalette.metal)
            c.dot(cx + 4, y - 11, PixelColor(hex: "#ff2a1a"))
        }
        // Sandbags along the wall: it's a bunker, after all.
        for dx in [1, 2] where f.isBuilding(dx, 0) {
            for (bx, by) in [(0, 11), (5, 11), (10, 11), (2, 8), (7, 8)] {
                c.fill(x + dx * size + bx, y + by, x + dx * size + bx + 4, y + by + 3, PixelColor(hex: "#8a7a58"))
                c.fill(x + dx * size + bx, y + by + 3, x + dx * size + bx + 4, y + by + 3, PixelColor(hex: "#5e5238"))
            }
        }
        // A spray-painted tag on the other side.
        if f.isBuilding(-1, 0) {
            let tag = [(2, 6), (3, 5), (4, 6), (5, 7), (6, 6), (7, 5), (8, 6), (9, 7), (10, 6), (11, 5), (12, 6)]
            for (tx, ty) in tag {
                c.fill(x - size + tx, y + ty, x - size + tx, y + ty + 3, PixelColor(hex: "#e04fb0"))
                c.dot(x - size + tx, y + ty + 4, PixelColor(hex: "#4fd6e0"))
            }
        }
        // A big air vent on the roof.
        if f.isBuilding(0, -2) {
            c.fill(x + 3, y - 30, x + 12, y - 21, PixelColor(hex: "#55565e"))
            c.circle(cx: x + 7, cy: y - 26, radius: 3, PixelColor(hex: "#2a2b30"))
            c.fill(x + 7, y - 29, x + 8, y - 23, PixelColor(hex: "#7a7b84"))
            c.fill(x + 4, y - 26, x + 11, y - 26, PixelColor(hex: "#7a7b84"))
        }
    }

    // MARK: goslo radio

    /// The radio: the billboard holding the glowing logo (drawn by WorldView), the mast, ON AIR, the gold
    /// sound wave along the top floor, the host at the mic in the window, the frequency on a panel.
    private static func radio(_ f: Front, on c: PixelCanvas) {
        let x = f.x, y = f.y, gold = Location.media.neon
        // Billboard legs and a catwalk under the logo panel.
        if f.isBuilding(0, -2) {
            let steel = PixelColor(hex: "#6a6a76")
            for lx in [x - 5, x + 20] {
                c.fill(lx, y - 35, lx + 1, y - 18, steel)
                c.fill(lx - 1, y - 18, lx + 2, y - 17, steel.shaded(0.7))
            }
            c.fill(x - 6, y - 25, x + 22, y - 25, steel.shaded(0.8))
            for bx in stride(from: x - 4, through: x + 20, by: 3) { c.dot(bx, y - 24, steel.shaded(0.6)) }
        }
        // A tall lattice mast on the roof, off to the side, a red light on top, waves going out.
        if let side = [2, -2, 1, -1].first(where: { f.isBuilding($0, -2) && f.isBuilding($0, -1) }) {
            let mx = x + side * size
            let top = f.isBuilding(side, -3) ? y - 46 : y - 30
            let mast = PixelColor(hex: "#9a9aa6")
            c.fill(mx + 6, top, mx + 6, y - 17, mast)
            c.fill(mx + 9, top, mx + 9, y - 17, mast)
            for row in stride(from: top + 2, to: y - 17, by: 4) { c.dot(mx + 7, row, mast); c.dot(mx + 8, row + 2, mast) }
            c.fill(mx + 6, top - 1, mx + 9, top - 1, mast)
            c.fill(mx + 7, top - 3, mx + 8, top - 2, PixelColor(hex: "#ff2a1a"))
            for (r, shade) in [(5, 1.0), (8, 0.7), (11, 0.45)] {
                for dy in (-r / 2)...(r / 2) {
                    c.dot(mx + 7 - r, top + 4 + dy, gold.shaded(shade))
                    c.dot(mx + 8 + r, top + 4 + dy, gold.shaded(shade))
                }
            }
        }
        // ON AIR light above the door, and the gold sound wave running along the floor either side.
        if f.isBuilding(0, -1) {
            c.fill(x + 1, y - 10, x + 14, y - 4, ink)
            c.fill(x + 2, y - 9, x + 13, y - 5, PixelColor(hex: "#c81e14"))
            for px in [3, 5, 7, 9, 11, 12] { c.fill(x + px, y - 8, x + px, y - 6, white) }
            let wave = [1, 2, 3, 4, 3, 2, 1, 2, 4, 2, 1, 3]
            for dx in -3...3 where dx != 0 && f.isWall(dx, -1) {
                let px = x + dx * size
                c.fill(px, y - 3, px + 15, y - 1, ink)
                for i in 0..<8 {
                    let h = wave[(abs(dx) * 8 + i) % wave.count]
                    c.fill(px + i * 2, y - 2 - h, px + i * 2, y - 2, gold)
                }
            }
        }
        // The studio window: the host at the mic, headphones on, the console glowing.
        if f.isWall(-1, 0) {
            let px = x - size, shadow = PixelColor(hex: "#14141c"), red = PixelColor(hex: "#e04f4f")
            c.fill(px + 1, y + 2, px + 14, y + 14, PixelColor(hex: "#2a2a30"))
            c.fill(px + 2, y + 3, px + 13, y + 13, PixelColor(hex: "#2a4a7a"))
            c.fill(px + 2, y + 3, px + 13, y + 3, PixelColor(hex: "#4a7ab0"))
            c.circle(cx: px + 6, cy: y + 7, radius: 2, shadow)
            c.fill(px + 3, y + 10, px + 9, y + 13, shadow)
            c.fill(px + 4, y + 4, px + 8, y + 4, red); c.fill(px + 3, y + 5, px + 3, y + 7, red); c.fill(px + 9, y + 5, px + 9, y + 7, red)
            c.fill(px + 11, y + 4, px + 11, y + 8, NightPalette.metal)
            c.fill(px + 10, y + 8, px + 12, y + 10, PixelColor(hex: "#3a3a44"))
            c.fill(px + 2, y + 12, px + 13, y + 13, gold.shaded(0.75))
            for bx in [3, 6, 9, 12] { c.dot(px + bx, y + 12, PixelColor(hex: "#7fe0a0")) }
        }
        // The frequency on a glowing panel.
        if f.isWall(1, 0) {
            let px = x + size
            plainWall(f, 1, 0, on: c)
            c.fill(px + 1, y + 2, px + 14, y + 14, ink)
            c.fill(px + 1, y + 2, px + 14, y + 2, gold.shaded(0.6))
            PixelFont.draw("98.7", on: c, x: px + 2, y: y + 4, gold)
            PixelFont.draw("FM", on: c, x: px + 5, y: y + 9, gold.shaded(0.75))
        }
        // A satellite dish on the upper floor.
        if f.isWall(-2, -1) {
            let px = x - 2 * size
            c.circle(cx: px + 8, cy: y - 11, radius: 3, PixelColor(hex: "#c8c8d0"))
            c.circle(cx: px + 8, cy: y - 11, radius: 1, PixelColor(hex: "#9a9aa6"))
            c.fill(px + 8, y - 8, px + 8, y - 4, NightPalette.metal)
        }
    }

    // MARK: La laverie

    /// The laundromat: washing machines and dryers behind bright glass, the lit "LAVERIE" sign, a striped
    /// awning, soap bubbles, steam from the dryer vent on the roof. No sign of goslo records out front.
    private static func laundromat(_ f: Front, on c: PixelCanvas) {
        let x = f.x, y = f.y, neon = Location.label.neon
        let frame = PixelColor(hex: "#2a2a30"), inside = PixelColor(hex: "#cfe4ea")
        // Washing machines: white fronts, round portholes full of blue water.
        for dx in [-2, -1] where f.isWall(dx, 0) {
            let px = x + dx * size
            c.fill(px, y + 1, px + 15, y + 15, frame)
            c.fill(px + 1, y + 2, px + 14, y + 14, inside)
            c.fill(px + 1, y + 2, px + 14, y + 2, white)
            for mx in [px + 2, px + 9] {
                c.fill(mx, y + 5, mx + 5, y + 14, white)
                c.fill(mx, y + 5, mx + 5, y + 6, PixelColor(hex: "#b8bcc6"))
                c.dot(mx + 4, y + 5, neon)
                porthole(c, mx, y + 8, water: PixelColor(hex: "#2f6fa0"))
            }
        }
        // Dryers on the other side, warm and tumbling.
        if f.isWall(1, 0) {
            let px = x + size
            c.fill(px, y + 1, px + 15, y + 15, frame)
            c.fill(px + 1, y + 2, px + 14, y + 14, inside)
            c.fill(px + 1, y + 2, px + 14, y + 2, white)
            for (mx, my) in [(px + 2, y + 3), (px + 9, y + 3), (px + 2, y + 9), (px + 9, y + 9)] {
                c.fill(mx, my, mx + 5, my + 5, PixelColor(hex: "#d8d8dc"))
                porthole(c, mx, my, water: PixelColor(hex: "#f2a050"))
                c.dot(mx + 3, my + 3, PixelColor(hex: (mx + my) % 2 == 0 ? "#e04f4f" : "#4f8ae0"))
            }
        }
        // A folding table and a plastic chair, bubbles drifting out.
        if f.isWall(2, 0) {
            let px = x + 2 * size
            plainWall(f, 2, 0, on: c)
            c.fill(px + 1, y + 2, px + 14, y + 13, frame)
            c.fill(px + 2, y + 3, px + 13, y + 12, inside)
            c.fill(px + 3, y + 8, px + 12, y + 8, PixelColor(hex: "#8a6a4a"))
            c.fill(px + 4, y + 9, px + 4, y + 12, PixelColor(hex: "#6b4a2e")); c.fill(px + 11, y + 9, px + 11, y + 12, PixelColor(hex: "#6b4a2e"))
            c.fill(px + 5, y + 6, px + 8, y + 7, PixelColor(hex: "#f2c14e"))
            for (bx, by, r) in [(3, 13, 1), (7, 14, 2), (12, 13, 1)] {
                c.circle(cx: px + bx, cy: y + by, radius: r, white.shaded(0.85))
                c.dot(px + bx, y + by, inside)
            }
        }
        // The lit sign, white box with teal letters, over the window and the door.
        if f.isBuilding(0, -1) {
            let text = "LAVERIE", w = PixelFont.width(text)
            let right = x + 15, left = right - w - 5
            c.fill(left, y - 15, right, y - 7, white)
            c.fill(left, y - 15, right, y - 15, neon)
            c.fill(left, y - 7, right, y - 7, neon.shaded(0.6))
            PixelFont.draw(text, on: c, x: left + 3, y: y - 13, PixelColor(hex: "#1f6a8a"))
            // A little T-shirt next to it.
            if f.isWall(-3, -1) || f.isWall(-2, -1) {
                let tx = left - 9
                c.fill(tx + 1, y - 13, tx + 5, y - 8, neon)
                c.fill(tx, y - 13, tx + 6, y - 11, neon)
                c.fill(tx + 2, y - 13, tx + 4, y - 13, frame)
            }
        }
        // A striped awning over the window and the door.
        if f.isBuilding(0, -1) {
            let left = f.isBuilding(-2, -1) ? x - 32 : x, right = x + 15
            for px in left...right {
                let stripe = (px / 3) % 2 == 0 ? neon : white
                c.fill(px, y - 5, px, y - 1, stripe)
                if px % 3 == 1 { c.dot(px, y, stripe) }
            }
        }
        // The dryer vent on the roof, steaming.
        if f.isBuilding(-1, -2) {
            let px = x - size
            c.fill(px + 6, y - 26, px + 9, y - 20, NightPalette.metal)
            c.fill(px + 5, y - 27, px + 10, y - 26, NightPalette.metal.shaded(1.3))
            c.circle(cx: px + 8, cy: y - 30, radius: 2, white.shaded(0.7))
            c.circle(cx: px + 11, cy: y - 33, radius: 3, white.shaded(0.55))
            c.circle(cx: px + 6, cy: y - 36, radius: 2, white.shaded(0.4))
        }
    }

    /// A machine's round door, 6×5 pixels from (x, y): a grey rim, the drum inside, a glint.
    private static func porthole(_ c: PixelCanvas, _ x: Int, _ y: Int, water: PixelColor) {
        let rim = PixelColor(hex: "#5a6474")
        c.fill(x + 1, y, x + 4, y + 4, rim); c.fill(x, y + 1, x + 5, y + 3, rim)
        c.fill(x + 1, y + 1, x + 4, y + 3, water); c.fill(x + 2, y, x + 3, y + 4, water)
        c.dot(x + 1, y + 1, white)
    }

    // MARK: Chez toi

    /// Home: a block's entrance with its glass sidelight and number plate, the intercom, and right above
    /// the door, Mum's window: warm lamplight, lace curtains, her silhouette, geraniums on the sill.
    private static func home(_ f: Front, on c: PixelCanvas) {
        let x = f.x, y = f.y
        if f.isWall(0, -1) {
            plainWall(f, 0, -1, on: c)
            let wy = y - size, lace = PixelColor(hex: "#f2ece0"), mum = PixelColor(hex: "#4a2a20")
            c.fill(x + 2, wy + 1, x + 13, wy + 12, NightPalette.windowFrame)
            c.fill(x + 3, wy + 2, x + 12, wy + 11, PixelColor(hex: "#ffb060"))
            c.fill(x + 3, wy + 2, x + 12, wy + 3, PixelColor(hex: "#ffd090"))
            c.circle(cx: x + 8, cy: wy + 6, radius: 1, mum)
            c.dot(x + 8, wy + 4, mum)
            c.fill(x + 6, wy + 8, x + 10, wy + 11, mum)
            c.fill(x + 3, wy + 2, x + 4, wy + 11, lace); c.fill(x + 11, wy + 2, x + 12, wy + 11, lace)
            for row in stride(from: wy + 3, to: wy + 11, by: 2) { c.dot(x + 4, row, lace.shaded(0.8)); c.dot(x + 11, row, lace.shaded(0.8)) }
            c.fill(x + 1, wy + 13, x + 14, wy + 14, PixelColor(hex: "#8a4a2e"))
            for fx in stride(from: x + 2, through: x + 13, by: 2) {
                c.dot(fx, wy + 12, PixelColor(hex: "#e0404a"))
                c.dot(fx + 1, wy + 12, NightPalette.leafLight)
            }
            if f.theme.snow { c.fill(x + 1, wy + 13, x + 14, wy + 13, PixelColor(hex: "#e8eef6")) }
        }
        // The neighbours' washing on a line across the floor.
        if f.isWall(-1, -1), f.isWall(-2, -1) {
            let left = f.isWall(-3, -1) ? x - 3 * size + 2 : x - 2 * size + 2, right = x - 2
            c.fill(left, y - 15, right, y - 15, white.shaded(0.6))
            let colors = ["#e04f4f", "#4f8ae0", "#f2c14e", "#f0eee8", "#7fe0a0"].map(PixelColor.init(hex:))
            for (i, px) in stride(from: left + 2, through: right - 5, by: 7).enumerated() {
                c.fill(px, y - 14, px + 4, y - 11, colors[i % colors.count])
                c.fill(px - 1, y - 14, px + 5, y - 14, colors[i % colors.count])
            }
        }
        // The hall: a lit glass sidelight and the blue number plate.
        if f.isWall(-1, 0) {
            let px = x - size
            plainWall(f, -1, 0, on: c)
            c.fill(px + 9, y + 3, px + 15, y + 15, NightPalette.doorFrame)
            c.fill(px + 10, y + 4, px + 14, y + 15, PixelColor(hex: "#d8c890"))
            for row in [y + 7, y + 11] { c.fill(px + 10, row, px + 14, row, NightPalette.doorFrame) }
            c.fill(px, y + 3, px + 8, y + 11, white)
            c.fill(px + 1, y + 4, px + 7, y + 10, PixelColor(hex: "#1f4a9a"))
            PixelFont.draw("12", on: c, x: px + 1, y: y + 5, white)
        }
        // A plant pot by the door, and the intercom.
        c.fill(x + 13, y + 12, x + 15, y + 15, PixelColor(hex: "#8a4a2e"))
        c.fill(x + 12, y + 9, x + 15, y + 11, NightPalette.leafLight)
        c.dot(x + 13, y + 8, NightPalette.leaf)
        if f.isBuilding(1, 0) {
            c.fill(x + size + 1, y + 5, x + size + 4, y + 11, NightPalette.metal)
            for row in [y + 6, y + 8, y + 10] { c.dot(x + size + 2, row, NightPalette.lampLight) }
        }
    }

    // MARK: Concert halls

    /// Le Transfo: an old electrical substation turned club. Dark brick and steel beams, hazard stripes,
    /// a marquee spelling TRANSFO in bulbs and neon, gig posters, a velvet rope, insulators on the roof.
    private static func transfo(_ f: Front, on c: PixelCanvas) {
        let x = f.x, y = f.y, neon = Location.scene.neon
        let brick = PixelColor(hex: "#3a2624"), mortar = PixelColor(hex: "#2a1a18"), beam = PixelColor(hex: "#4a4a52")
        for dx in -2...2 {
            for dy in [-1, 0] where !(dx == 0 && dy == 0) && f.isWall(dx, dy) {
                let px = x + dx * size, py = y + dy * size
                c.fill(px, py, px + 15, py + 15, brick)
                for row in stride(from: 2, to: 16, by: 3) {
                    c.fill(px, py + row, px + 15, py + row, mortar)
                    let offset = (row / 3 + dx) % 2 == 0 ? 4 : 11
                    c.fill(px + offset, py + row - 2, px + offset, py + row - 1, mortar)
                }
                c.fill(px, py, px + 15, py + 1, beam)
                for rx in [2, 7, 12] { c.dot(px + rx, py, beam.shaded(1.4)) }
                if dy == 0 {
                    // Hazard stripes along the foot of the wall.
                    for sx in 0..<16 { c.fill(px + sx, py + 14, px + sx, py + 15, (sx / 2) % 2 == 0 ? PixelColor(hex: "#f2c14e") : ink) }
                }
            }
        }
        // The marquee.
        if f.isBuilding(0, -1) {
            let left = f.isBuilding(-1, -1) ? x - 12 : x, right = f.isBuilding(1, -1) ? x + 27 : x + 15
            c.fill(left, y - 13, right, y - 2, ink)
            c.fill(left, y - 1, right, y - 1, neon)
            for bx in stride(from: left + 1, through: right - 1, by: 3) {
                c.dot(bx, y - 12, NightPalette.lampLight)
                c.dot(bx + 1, y - 3, NightPalette.lampLight.shaded(0.7))
            }
            let text = "TRANSFO"
            PixelFont.draw(text, on: c, x: x + 8 - PixelFont.width(text) / 2, y: y - 10, neon)
        }
        // Gig posters on both sides of the door.
        for (dx, color) in [(-1, neon), (1, PixelColor(hex: "#ffd27a"))] where f.isWall(dx, 0) {
            let px = x + dx * size
            c.fill(px + 3, y + 2, px + 12, y + 12, color)
            c.circle(cx: px + 7, cy: y + 5, radius: 2, ink)
            c.fill(px + 5, y + 7, px + 10, y + 10, ink)
            c.fill(px + 4, y + 11, px + 11, y + 11, white)
        }
        // Velvet rope for the queue.
        if f.isWall(-2, 0) {
            let px = x - 2 * size, brass = PixelColor(hex: "#d8b040")
            for post in [px + 2, px + 13] { c.fill(post, y + 7, post, y + 13, brass); c.fill(post - 1, y + 6, post + 1, y + 6, brass) }
            for (i, rx) in (px + 3...px + 12).enumerated() { c.dot(rx, y + 8 + [0, 1, 1, 2, 2, 2, 2, 1, 1, 0][i % 10], PixelColor(hex: "#b81e2e")) }
        }
        // High voltage: the danger sign.
        if f.isWall(2, 0) {
            let px = x + 2 * size, yellow = PixelColor(hex: "#f2c14e")
            for row in 0..<7 { c.fill(px + 7 - row / 2 - 1, y + 3 + row, px + 8 + row / 2, y + 3 + row, yellow) }
            for (bx, by) in [(8, 4), (7, 5), (7, 6), (8, 6), (8, 7), (7, 8)] { c.dot(px + bx, y + by, ink) }
        }
        // Ceramic insulators and cables on the roof.
        let insulators = [-1, 1].filter { f.isBuilding($0, -2) }
        for dx in insulators {
            let px = x + dx * size + 6
            for i in 0..<4 {
                c.fill(px - 1, y - 30 + i * 3, px + 3, y - 29 + i * 3, PixelColor(hex: "#c8b8a0"))
                c.fill(px, y - 28 + i * 3, px + 2, y - 28 + i * 3, PixelColor(hex: "#6a5a4a"))
            }
        }
        if insulators.count == 2 { c.fill(x - size + 7, y - 31, x + size + 7, y - 31, ink) }
    }

    /// Le Dôme's entrance: a marquee edged with bulbs over the door, gig posters either side.
    private static func marquee(_ f: Front, on c: PixelCanvas) {
        let x = f.x, y = f.y, neon = Location.scene.neon
        if f.isBuilding(0, -1) {
            let left = f.isBuilding(-1, -1) ? x - 10 : x, right = f.isBuilding(1, -1) ? x + 25 : x + 15
            c.fill(left, y - 8, right, y - 1, ink)
            c.fill(left, y - 1, right, y - 1, neon)
            for bx in stride(from: left + 1, through: right - 1, by: 3) {
                c.dot(bx, y - 7, NightPalette.lampLight)
                c.dot(bx + 1, y - 3, NightPalette.lampLight.shaded(0.7))
            }
            for (i, px) in [x + 2, x + 5, x + 8, x + 11].enumerated() {
                c.fill(px, y - 5, px + 1, y - 4, i % 2 == 0 ? neon : white)
            }
        }
        for (dx, color) in [(-1, neon), (1, PixelColor(hex: "#ffd27a"))] where f.isBuilding(dx, 0) {
            let px = x + dx * size
            c.fill(px + 3, y + 2, px + 12, y + 13, color)
            c.circle(cx: px + 7, cy: y + 6, radius: 2, ink)
            c.fill(px + 5, y + 8, px + 10, y + 11, ink)
            c.fill(px + 4, y + 12, px + 11, y + 12, white)
        }
    }
}
