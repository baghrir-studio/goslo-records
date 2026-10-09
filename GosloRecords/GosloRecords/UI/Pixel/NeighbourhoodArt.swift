import UIKit

// The small things that make a street somebody's street (map data "scenery", see `MapScenery.Kind`): life on the
// rooftops, the shops' neon signs, the kiosk, the bus shelter, planters, a tagged hoarding, scooters, a food truck,
// a café terrace, and the water's edge. Each city dresses them its own way: zinc roofs and kebab neons in Paris,
// OM-blue washing and the calanques' white rock in Marseille, zellige pots, mint tea and palm trees in Casablanca.
// Same rule as the rest of the street art: props only stand on tiles that were already blocked; the walkable
// tiles never change.

@MainActor
extension TileArt {
    static func dressNeighbourhood(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme, district: District) {
        switch s.kind {
        case .rooftops: rooftopsArt(s, on: c, map: map, theme: t)
        case .shopfronts: shopfrontsArt(s, on: c, map: map, theme: t)
        case .kiosk: kioskArt(s, on: c, map: map, theme: t, district: district)
        case .busStop: busStopArt(s, on: c, map: map, theme: t)
        case .planters: plantersArt(s, on: c, map: map, theme: t, district: district)
        case .graffiti: graffitiArt(s, on: c, map: map, theme: t, district: district)
        case .scooters: scootersArt(s, on: c, map: map, theme: t)
        case .stalls: stallsArt(s, on: c, map: map, theme: t, district: district)
        case .cafe: cafeArt(s, on: c, map: map, theme: t)
        case .shore: shoreArt(s, on: c, map: map, theme: t)
        default: break
        }
    }

    // MARK: Helpers

    private static func points(of s: MapScenery) -> [TilePoint] {
        guard s.w > 0, s.h > 0 else { return [] }
        return (s.y..<(s.y + s.h)).flatMap { y in (s.x..<(s.x + s.w)).map { TilePoint(x: $0, y: y) } }
    }

    /// Blocked tiles of the rectangle (the props' footprint).
    private static func propTiles(of s: MapScenery, map: WorldMap) -> [TilePoint] {
        points(of: s).filter { !map.tile(at: $0).isWalkable }
    }

    /// Runs of blocked tiles on each row of the rectangle: (first tile, length).
    private static func propRuns(of s: MapScenery, map: WorldMap) -> [(start: TilePoint, length: Int)] {
        var runs: [(start: TilePoint, length: Int)] = []
        for y in s.y..<(s.y + s.h) {
            var start: Int?
            for x in s.x...(s.x + s.w) {
                let blocked = x < s.x + s.w && !map.tile(at: TilePoint(x: x, y: y)).isWalkable
                if blocked, start == nil { start = x }
                if !blocked, let first = start {
                    runs.append((TilePoint(x: first, y: y), x - first))
                    start = nil
                }
            }
        }
        return runs
    }

    /// Plain pavement under a prop (the tree that held its place on the map is painted over).
    private static func pavement(_ c: PixelCanvas, _ p: TilePoint, _ t: CityTheme) {
        var noise = PixelNoise(p.x, p.y, salt: 101)
        let tile = PixelCanvas(width: size, height: size)
        sidewalk(tile, &noise, p, t, curb: false)
        c.stamp(tile, at: p.x * size, p.y * size)
    }

    private static func text(_ label: String, centeredOn cx: Int, y: Int, on c: PixelCanvas, _ color: PixelColor) {
        PixelFont.draw(label, on: c, x: cx - PixelFont.width(label) / 2, y: y, color)
    }

    private static let ink = PixelColor(hex: "#101014")
    private static let paper = PixelColor(hex: "#f0eee8")
    private static let omBlue = PixelColor(hex: "#3fa8e0")

    // MARK: Rooftops

    /// Washing lines from one tile to the next, aerials, water tanks; zinc seams and chimney pots in Paris, OM-blue
    /// washing and bunting in Marseille, rugs airing and clusters of dishes on Casablanca's flat terraces.
    private static func rooftopsArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let roofs = points(of: s).filter { map.tile(at: $0) == .roof }
        guard !roofs.isEmpty else { return }
        let metal = NightPalette.metal
        for p in roofs {
            let px = p.x * size, py = p.y * size
            var noise = PixelNoise(p.x, p.y, salt: 103)
            if t.city == .paris {
                // Zinc: standing seams every four pixels, lighter on the ridge.
                for x in stride(from: 1, to: 16, by: 4) { c.fill(px + x, py + 2, px + x, py + 13, t.roofEdge.shaded(1.1)) }
            }
            // Only the top row of the roof gets the tall things: they stand against the sky.
            guard map.tile(at: p.moved(.up)) != .roof else { continue }
            switch (t.city, noise.next(5)) {
            case (.paris, 0), (.paris, 1):
                // A row of terracotta chimney pots on a brick stack.
                let x = px + 3 + noise.next(6)
                c.fill(x, py + 1, x + 6, py + 6, PixelColor(hex: "#8a4a34"))
                c.fill(x, py + 1, x + 6, py + 1, PixelColor(hex: "#a85a40"))
                for dx in [1, 4] { c.fill(x + dx, py - 2, x + dx + 1, py + 1, PixelColor(hex: "#c8703a")) }
            case (.casablanca, 0), (.casablanca, 1):
                // A white water tank on a frame.
                c.fill(px + 3, py + 3, px + 12, py + 9, PixelColor(hex: "#d8d4c8"))
                c.fill(px + 3, py + 3, px + 12, py + 4, PixelColor(hex: "#f0eee8"))
                c.fill(px + 4, py + 10, px + 4, py + 12, metal); c.fill(px + 11, py + 10, px + 11, py + 12, metal)
            case (.casablanca, 2):
                // A rug airing over the parapet.
                let red = PixelColor(hex: "#a82a2a"), blue = PixelColor(hex: "#2a4a8a")
                c.fill(px + 2, py + 2, px + 13, py + 11, red)
                c.fill(px + 4, py + 4, px + 11, py + 9, blue)
                c.fill(px + 6, py + 6, px + 9, py + 7, PixelColor(hex: "#e8c860"))
                for x in stride(from: px + 2, through: px + 13, by: 2) { c.dot(x, py + 12, paper) }
            case (_, 2):
                // A TV aerial.
                c.fill(px + 8, py - 3, px + 8, py + 9, metal)
                for (y, half) in [(-2, 4), (1, 3), (4, 2)] { c.fill(px + 8 - half, py + y, px + 8 + half, py + y, metal.shaded(1.25)) }
            case (_, 3):
                // A satellite dish, turned to the south like all the others.
                c.circle(cx: px + 6, cy: py + 6, radius: 3, metal.shaded(1.4))
                c.circle(cx: px + 6, cy: py + 6, radius: 1, metal.shaded(0.8))
                c.fill(px + 6, py + 9, px + 6, py + 11, metal)
            default:
                break
            }
        }
        // A washing line across the whole roof, on its lowest row: shirts, towels, a football shirt.
        let bottom = s.y + s.h - 1
        let row = roofs.filter { $0.y == bottom }.map(\.x).sorted()
        guard let first = row.first, let last = row.last, last > first else { return }
        let x0 = first * size + 3, x1 = (last + 1) * size - 4, y = bottom * size + 4
        c.fill(x0, y - 2, x0, y + 8, metal); c.fill(x1, y - 2, x1, y + 8, metal)
        c.fill(x0, y, x1, y, PixelColor(hex: "#c8c0b0"))
        var noise = PixelNoise(s.x, s.y, salt: 107)
        let laundry: [PixelColor]
        switch t.city {
        case .marseille: laundry = [omBlue, paper, omBlue, PixelColor(hex: "#f2c14e"), paper]
        case .casablanca: laundry = ["#1f7a6a", "#e8e4d8", "#c8603a", "#e8c860", "#2a5a9a"].map(PixelColor.init(hex:))
        default: laundry = ["#e04f4f", "#4f8ae0", "#f0eee8", "#7fc04f", "#e06a9a"].map(PixelColor.init(hex:))
        }
        var x = x0 + 3
        while x < x1 - 4 {
            let color = laundry[noise.next(laundry.count)], wide = noise.chance(40)
            if wide {
                // A T-shirt: shoulders, then the body.
                c.fill(x, y + 1, x + 5, y + 2, color); c.fill(x + 1, y + 3, x + 4, y + 6, color)
                if color == omBlue || color == paper, t.city == .marseille { c.fill(x + 2, y + 3, x + 3, y + 3, color == omBlue ? paper : omBlue) }
                x += 8
            } else {
                // A towel or a sock.
                c.fill(x, y + 1, x + 2, y + 4 + noise.next(3), color)
                x += 5
            }
            c.dot(x - 2, y, PixelColor(hex: "#e8d8a0"))
        }
        if t.city == .marseille {
            // Sky-blue and white bunting along the top of the roof: match night.
            let top = s.y * size + 1
            for (i, bx) in stride(from: s.x * size + 2, to: (s.x + s.w) * size - 3, by: 4).enumerated() {
                let flag = i % 2 == 0 ? omBlue : paper
                c.fill(bx, top, bx + 2, top, flag); c.dot(bx + 1, top + 1, flag)
            }
        }
    }

    // MARK: Shopfronts

    private enum ShopSign {
        case food, laundry, barber, phone, pizza, cafe, hammam
    }

    private static func shopKind(_ name: String) -> ShopSign {
        switch name {
        case "LAVERIE": .laundry
        case "BARBIER": .barber
        case "PHONE", "TELE": .phone
        case "PIZZA": .pizza
        case "CAFE": .cafe
        case "HAMMAM": .hammam
        default: .food
        }
    }

    /// The ground floor's names, city by city.
    private static func shopNames(_ t: CityTheme) -> [String] {
        switch t.city {
        case .paris: ["KEBAB", "LAVERIE", "BARBIER", "TACOS", "PHONE"]
        case .marseille: ["PIZZA", "SNACK", "BARBIER", "PANISSE", "LAVERIE"]
        case .casablanca: ["CAFE", "HAMMAM", "MSEMEN", "TELE", "BARBIER"]
        default: ["KEBAB", "LAVERIE", "SNACK", "BARBIER", "PHONE"]
        }
    }

    /// Ground-floor shops along a front wall, two tiles each: a neon name over a lit window and what's inside.
    private static func shopfrontsArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let names = shopNames(t)
        let neons = ["#ff4d6a", "#4fd6e0", "#f2c14e", "#7fe0a0", "#e04fb0"].map(PixelColor.init(hex:))
        var index = s.x + s.y
        for run in propRuns(of: s, map: map) where map.tile(at: run.start) == .wall {
            var start = 0
            while start < run.length {
                let left = run.length - start
                let width = left == 3 ? 3 : min(2, left)
                let x0 = (run.start.x + start) * size, y0 = run.start.y * size, x1 = x0 + width * size - 1
                let name = width == 1 ? "BAR" : names[index % names.count]
                let neon = neons[index % neons.count]
                shopfront(name, kind: width == 1 ? .food : shopKind(name), on: c, x0: x0, x1: x1, y0: y0, neon: neon, theme: t, salt: index)
                index += 1
                start += width
            }
        }
    }


    private static func shopfront(_ name: String, kind: ShopSign, on c: PixelCanvas, x0: Int, x1: Int, y0: Int,
                                  neon: PixelColor, theme t: CityTheme, salt: Int) {
        var noise = PixelNoise(x0, y0, salt: salt)
        let frame = NightPalette.windowFrame, glass = NightPalette.windowLit.shaded(0.75)
        let cx = (x0 + x1) / 2
        // The sign board, the name in neon, its glow on the board's lower edge.
        c.fill(x0, y0 + 1, x1, y0 + 7, ink)
        c.fill(x0 + 1, y0 + 7, x1 - 1, y0 + 7, neon.shaded(0.45))
        text(name, centeredOn: cx, y: y0 + 2, on: c, neon)
        // Window and door under it.
        c.fill(x0 + 1, y0 + 8, x1 - 1, y0 + 15, frame)
        c.fill(x0 + 2, y0 + 9, x1 - 2, y0 + 15, glass)
        if t.arches { zellige(c, y: y0 + 13, t) }
        switch kind {
        case .food:
            // The counter, and the spit turning in the window (kebab, tacos, snack).
            c.fill(x0 + 2, y0 + 13, x1 - 2, y0 + 15, NightPalette.wood)
            let sx = x1 - 7
            c.fill(sx, y0 + 9, sx + 3, y0 + 12, PixelColor(hex: "#8a4a24"))
            c.fill(sx + 1, y0 + 9, sx + 2, y0 + 9, PixelColor(hex: "#c8703a"))
            c.fill(sx + 1, y0 + 8, sx + 2, y0 + 8, NightPalette.metal)
            for gx in stride(from: x0 + 3, to: sx - 2, by: 3) {
                c.fill(gx, y0 + 11, gx + 1, y0 + 12, noise.chance(50) ? PixelColor(hex: "#e8c860") : PixelColor(hex: "#7fc04f"))
            }
        case .laundry:
            // Two machines with their round doors.
            for mx in [x0 + 7, x1 - 7] where mx - 3 > x0 + 1 {
                c.fill(mx - 4, y0 + 9, mx + 4, y0 + 15, PixelColor(hex: "#e8e8ec"))
                c.circle(cx: mx, cy: y0 + 12, radius: 2, PixelColor(hex: "#4f7fa0"))
                c.dot(mx - 1, y0 + 11, PixelColor(hex: "#9ad0f0"))
            }
        case .barber:
            // The striped pole by the door, a chair in the window.
            c.fill(x0 + 2, y0 + 8, x0 + 3, y0 + 15, paper)
            for y in stride(from: y0 + 8, through: y0 + 15, by: 3) { c.dot(x0 + 2, y, PixelColor(hex: "#d42a1e")); c.dot(x0 + 3, y + 1, PixelColor(hex: "#2a4a9a")) }
            c.fill(cx - 2, y0 + 10, cx + 2, y0 + 13, PixelColor(hex: "#3a1a1a"))
            c.fill(cx - 1, y0 + 14, cx + 1, y0 + 15, NightPalette.metal)
        case .phone:
            // A wall of phone screens.
            for (i, px) in stride(from: x0 + 3, to: x1 - 2, by: 4).enumerated() {
                c.fill(px, y0 + 10, px + 2, y0 + 14, ink)
                c.fill(px, y0 + 11, px + 2, y0 + 13, i % 2 == 0 ? PixelColor(hex: "#4fd6e0") : PixelColor(hex: "#e04fb0"))
            }
        case .pizza:
            // The wood oven glowing at the back.
            c.fill(cx - 5, y0 + 10, cx + 5, y0 + 15, PixelColor(hex: "#8a4a34"))
            c.fill(cx - 3, y0 + 12, cx + 3, y0 + 15, PixelColor(hex: "#ff8a3a"))
            c.fill(cx - 2, y0 + 11, cx + 2, y0 + 11, PixelColor(hex: "#8a4a34"))
            c.dot(cx, y0 + 13, PixelColor(hex: "#ffd27a"))
        case .cafe:
            // Two little tables with mint tea glasses.
            for tx in [x0 + 5, x1 - 6] {
                c.fill(tx - 2, y0 + 12, tx + 2, y0 + 12, paper)
                c.fill(tx, y0 + 13, tx, y0 + 15, NightPalette.metal)
                c.dot(tx - 1, y0 + 11, PixelColor(hex: "#7fe0a0")); c.dot(tx + 1, y0 + 11, PixelColor(hex: "#7fe0a0"))
            }
        case .hammam:
            // A blue arched door under a zellige band.
            c.fill(cx - 3, y0 + 9, cx + 3, y0 + 15, PixelColor(hex: "#1f4a7a"))
            c.dot(cx - 3, y0 + 9, glass); c.dot(cx + 3, y0 + 9, glass)
            c.fill(cx - 2, y0 + 8, cx + 2, y0 + 8, PixelColor(hex: "#1f4a7a"))
            c.dot(cx + 2, y0 + 12, PixelColor(hex: "#e8c860"))
        }
        if t.snow { c.fill(x0, y0 + 1, x1, y0 + 1, PixelColor(hex: "#e8eef6")) }
    }

    // MARK: Kiosk

    /// A newspaper kiosk: Paris's green one with its little dome, Marseille's blue and white, a mint-green stall in
    /// Casablanca. At Le Dôme, the ticket booth.
    private static func kioskArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme, district: District) {
        for p in propTiles(of: s, map: map) {
            pavement(c, p, t)
            let px = p.x * size, py = p.y * size, cx = px + 8
            let body: PixelColor, trim: PixelColor, label: String
            switch (district, t.city) {
            case (.dome, _): body = PixelColor(hex: "#3a2f45"); trim = PixelColor(hex: "#d8b040"); label = "BILLETS"
            case (_, .paris): body = PixelColor(hex: "#24503a"); trim = PixelColor(hex: "#c8a040"); label = "PRESSE"
            case (_, .marseille): body = PixelColor(hex: "#2a6a9a"); trim = paper; label = "PRESSE"
            case (_, .casablanca): body = PixelColor(hex: "#1f7a6a"); trim = PixelColor(hex: "#e8d8a0"); label = "PRESSE"
            default: body = PixelColor(hex: "#2a3a5a"); trim = PixelColor(hex: "#c8c0b0"); label = "PRESSE"
            }
            // Body, a roof that overhangs, and a little dome with its finial (a flat awning in Casablanca).
            c.fill(px + 2, py + 2, px + 13, py + 15, body)
            c.fill(px + 2, py + 15, px + 13, py + 15, body.shaded(0.6))
            c.fill(px + 1, py + 1, px + 14, py + 2, trim)
            if t.city == .casablanca, district != .dome {
                for x in 0..<14 { c.fill(px + 1 + x, py - 3, px + 1 + x, py, (x / 2) % 2 == 0 ? body.shaded(1.3) : trim) }
            } else {
                c.fill(px + 4, py - 1, px + 11, py, body.shaded(1.2))
                c.fill(px + 6, py - 3, px + 9, py - 2, body.shaded(1.3))
                c.fill(px + 7, py - 5, px + 8, py - 4, trim)
            }
            // The sign, wider than the kiosk.
            let w = PixelFont.width(label) + 4
            c.fill(cx - w / 2, py + 3, cx - w / 2 + w - 1, py + 9, ink)
            text(label, centeredOn: cx, y: py + 4, on: c, trim)
            if district == .dome {
                // A round ticket window, lit.
                c.circle(cx: cx, cy: py + 12, radius: 2, NightPalette.windowLit)
                c.fill(cx - 3, py + 14, cx + 3, py + 14, trim)
            } else {
                // Magazines pinned all over the front.
                let covers = ["#e04f4f", "#f0eee8", "#4fd6e0", "#f2c14e", "#7fe0a0", "#e04fb0"].map(PixelColor.init(hex:))
                var noise = PixelNoise(p.x, p.y, salt: 109)
                for (i, mx) in stride(from: px + 3, to: px + 12, by: 3).enumerated() {
                    c.fill(mx, py + 10, mx + 1, py + 13, covers[(i + noise.next(6)) % covers.count])
                }
            }
        }
    }

    // MARK: Bus stop

    /// A glass shelter: its roof, a bench inside, a lit poster at the end (goslo radio's), the stop's sign on a pole.
    private static func busStopArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        for run in propRuns(of: s, map: map) {
            for i in 0..<run.length { pavement(c, TilePoint(x: run.start.x + i, y: run.start.y), t) }
            let x0 = run.start.x * size + 1, x1 = (run.start.x + run.length) * size - 2, y0 = run.start.y * size
            let glass = PixelColor(hex: "#5a7a8a"), steel = NightPalette.metal.shaded(1.3)
            // Glass back panel, posts, the roof.
            c.fill(x0, y0 + 2, x1, y0 + 11, glass.shaded(0.6))
            for x in stride(from: x0 + 3, to: x1, by: 5) { c.dot(x, y0 + 4, glass.shaded(1.1)) }
            c.fill(x0, y0 + 1, x0, y0 + 15, steel); c.fill(x1, y0 + 1, x1, y0 + 15, steel)
            c.fill(x0 - 1, y0, x1 + 1, y0 + 1, PixelColor(hex: "#2a2a30"))
            c.fill(x0 - 1, y0 + 2, x1 + 1, y0 + 2, steel)
            // The bench.
            c.fill(x0 + 2, y0 + 11, x1 - 8, y0 + 12, NightPalette.wood.shaded(1.2))
            c.fill(x0 + 3, y0 + 13, x0 + 3, y0 + 15, NightPalette.metal); c.fill(x1 - 9, y0 + 13, x1 - 9, y0 + 15, NightPalette.metal)
            // A lit poster at the end: goslo radio's gold wave.
            c.fill(x1 - 6, y0 + 4, x1 - 1, y0 + 13, PixelColor(hex: "#f2e6b0"))
            c.fill(x1 - 5, y0 + 5, x1 - 2, y0 + 12, PixelColor(hex: "#1f2a44"))
            for (i, h) in [1, 3, 2].enumerated() { c.fill(x1 - 5 + i, y0 + 9 - h, x1 - 5 + i, y0 + 9, Location.media.neon) }
            // The stop's sign.
            c.fill(x0 + 1, y0 - 4, x0 + 1, y0, steel)
            c.fill(x0 - 2, y0 - 9, x0 + 12, y0 - 4, PixelColor(hex: "#1f5ac8"))
            text("BUS", centeredOn: x0 + 5, y: y0 - 8, on: c, paper)
            if t.snow { c.fill(x0 - 1, y0, x1 + 1, y0, PixelColor(hex: "#e8eef6")) }
        }
    }

    // MARK: Planters

    /// Big pots: box hedges in green crates in Paris, olive trees in terracotta in Marseille, palms in zellige pots
    /// in Casablanca, ornamental grass in concrete up in Les Hauts and at Le Dôme.
    private static func plantersArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme, district: District) {
        for p in propTiles(of: s, map: map) {
            pavement(c, p, t)
            let px = p.x * size, py = p.y * size
            let modern = district == .hauts || district == .dome
            switch (modern, t.city) {
            case (true, _):
                c.fill(px + 2, py + 8, px + 13, py + 15, PixelColor(hex: "#8a8e96"))
                c.fill(px + 2, py + 8, px + 13, py + 8, PixelColor(hex: "#a8acb4"))
                for x in stride(from: px + 3, through: px + 12, by: 2) { c.fill(x, py + 3 + (x % 3), x, py + 7, t.leafLight) }
            case (_, .paris):
                c.fill(px + 2, py + 9, px + 13, py + 15, PixelColor(hex: "#24503a"))
                for x in [px + 2, px + 13] { c.fill(x, py + 9, x, py + 15, PixelColor(hex: "#1a3a2a")) }
                c.circle(cx: px + 8, cy: py + 5, radius: 5, t.leaf)
                c.circle(cx: px + 6, cy: py + 3, radius: 2, t.leafLight)
            case (_, .marseille):
                c.fill(px + 4, py + 10, px + 11, py + 15, PixelColor(hex: "#b85a34"))
                c.fill(px + 3, py + 10, px + 12, py + 10, PixelColor(hex: "#d8703a"))
                c.fill(px + 7, py + 5, px + 8, py + 9, NightPalette.trunk)
                c.circle(cx: px + 8, cy: py + 3, radius: 4, PixelColor(hex: "#6a7a5a"))
                for (dx, dy) in [(-2, 2), (2, 1), (0, -1)] { c.dot(px + 8 + dx, py + 3 + dy, PixelColor(hex: "#9aa88a")) }
                c.dot(px + 10, py + 4, PixelColor(hex: "#2a2a30"))
            case (_, .casablanca):
                c.fill(px + 4, py + 9, px + 11, py + 15, PixelColor(hex: "#e8e4d8"))
                for x in stride(from: px + 4, through: px + 11, by: 2) { c.dot(x, py + 11, t.accent); c.dot(x + 1, py + 13, PixelColor(hex: "#2a5a9a")) }
                c.fill(px + 7, py + 3, px + 8, py + 8, PixelColor(hex: "#7a5a34"))
                for (dx, dy) in [(-5, 1), (-3, -1), (0, -2), (3, -1), (5, 1)] {
                    c.fill(min(8, 8 + dx) + px, py + 3 + min(0, dy), max(8, 8 + dx) + px, py + 3 + min(0, dy), t.leaf)
                    c.dot(px + 8 + dx, py + 3 + dy, t.leafLight)
                }
                c.dot(px + 5, py + 8, PixelColor(hex: "#e06a9a")); c.dot(px + 11, py + 7, PixelColor(hex: "#e06a9a"))
            default:
                c.fill(px + 3, py + 9, px + 12, py + 15, PixelColor(hex: "#7a7e86"))
                c.circle(cx: px + 8, cy: py + 6, radius: 4, t.leaf)
                c.dot(px + 7, py + 4, t.leafLight)
            }
            if t.snow { c.fill(px + 4, py + 2, px + 11, py + 3, PixelColor(hex: "#f2f5fa")) }
        }
    }

    // MARK: Graffiti

    /// Over a fence: a plywood hoarding covered in wild posters and tags. Downtown, along the river: the stone
    /// embankment, tagged from end to end, a big piece in the middle.
    private static func graffitiArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme, district: District) {
        let tiles = propTiles(of: s, map: map)
        guard let minX = tiles.map(\.x).min(), let maxX = tiles.map(\.x).max(),
              let minY = tiles.map(\.y).min(), let maxY = tiles.map(\.y).max() else { return }
        let stone = district == .centre
        let base = stone ? PixelColor(hex: "#6a665c") : PixelColor(hex: "#8a6a44")
        for p in tiles {
            let px = p.x * size, py = p.y * size
            c.fill(px, py, px + 15, py + 15, base)
            if stone {
                // Cut stone blocks.
                for y in [py + 7, py + 15] { c.fill(px, y, px + 15, y, base.shaded(0.8)) }
                c.fill(px + (p.y % 2 == 0 ? 7 : 15), py, px + (p.y % 2 == 0 ? 7 : 15), py + 6, base.shaded(0.8))
                c.fill(px + (p.y % 2 == 0 ? 15 : 7), py + 8, px + (p.y % 2 == 0 ? 15 : 7), py + 14, base.shaded(0.8))
            } else {
                // Plywood panels, a seam every tile, nails.
                c.fill(px, py, px + 15, py + 1, base.shaded(1.2))
                c.fill(px + 15, py, px + 15, py + 15, base.shaded(0.7))
                c.dot(px + 2, py + 3, base.shaded(0.5)); c.dot(px + 2, py + 12, base.shaded(0.5))
            }
        }
        var noise = PixelNoise(s.x, s.y, salt: 113)
        let x0 = minX * size, x1 = (maxX + 1) * size - 1, y0 = minY * size, y1 = (maxY + 1) * size - 1
        if !stone {
            // Wild posters, a bit crooked, some torn.
            for px in stride(from: x0 + 2, to: x1 - 8, by: 11) where noise.chance(70) {
                let paperColor = [paper, PixelColor(hex: "#f2c14e"), PixelColor(hex: "#e04fb0"), PixelColor(hex: "#4fd6e0")][noise.next(4)]
                let top = y0 + 2 + noise.next(3)
                c.fill(px, top, px + 7, top + 9, paperColor)
                c.fill(px + 1, top + 1, px + 6, top + 2, ink)
                for line in stride(from: top + 4, to: top + 9, by: 2) { c.fill(px + 1, line, px + 3 + noise.next(4), line, paperColor.shaded(0.55)) }
                if noise.chance(30) { c.fill(px + 5, top + 6, px + 7, top + 9, base) }
            }
        }
        // A big throw-up in the middle: bubble letters, outlined.
        let word = ["BLOC", "RAP", "ZOE"][noise.next(3)]
        let small = PixelCanvas(width: PixelFont.width(word), height: 5)
        PixelFont.draw(word, on: small, x: 0, y: 0, paper)
        let scale = 2, w = small.width * scale
        let lx = (x0 + x1 - w) / 2, ly = (y0 + y1) / 2 - 5
        let fill = [PixelColor(hex: "#e04fb0"), PixelColor(hex: "#4fd6e0"), PixelColor(hex: "#f2c14e")][noise.next(3)]
        for y in 0..<5 {
            for x in 0..<small.width where !small[x, y].isClear {
                c.fill(lx + x * scale - 1, ly + y * scale - 1, lx + x * scale + scale, ly + y * scale + scale, ink)
            }
        }
        for y in 0..<5 {
            for x in 0..<small.width where !small[x, y].isClear {
                c.fill(lx + x * scale, ly + y * scale, lx + x * scale + scale - 1, ly + y * scale + scale - 1, fill)
            }
        }
        // Tags all along.
        for x in stride(from: x0 + 4, to: x1 - 12, by: 15) where x + 12 < lx || x > lx + w + 2 {
            tag(c, &noise, x: x, y: y1 - 4 - noise.next(5), width: 7 + noise.next(4))
        }
    }

    // MARK: Scooters

    /// Scooters and a bike parked along the kerb, on a rack.
    private static func scootersArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        for p in propTiles(of: s, map: map) {
            pavement(c, p, t)
            var noise = PixelNoise(p.x, p.y, salt: 127)
            let tile = PixelCanvas(width: size, height: size)
            // The rack's bar, then a scooter (or a bike) leaning on it.
            tile.fill(0, 9, 15, 9, NightPalette.metal.shaded(1.3))
            if noise.chance(65) {
                scooter(tile, x: 2 + noise.next(4), &noise)
            } else {
                let frame = [PixelColor(hex: "#c8322a"), PixelColor(hex: "#2a8a5a"), PixelColor(hex: "#e8e4dc")][noise.next(3)]
                for wx in [4, 11] {
                    tile.circle(cx: wx, cy: 12, radius: 2, ink)
                    tile.dot(wx, 12, NightPalette.metal)
                }
                tile.fill(4, 10, 11, 10, frame); tile.fill(7, 9, 8, 11, frame)
                tile.fill(10, 7, 11, 7, ink); tile.fill(5, 8, 6, 8, ink)
            }
            c.stamp(tile, at: p.x * size, p.y * size)
        }
    }

    // MARK: Stalls and food trucks

    /// A food truck over a run of two blocked tiles (its menu changes with the city), a little stall on a single one.
    private static func stallsArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme, district: District) {
        var index = 0
        for run in propRuns(of: s, map: map) {
            for i in 0..<run.length { pavement(c, TilePoint(x: run.start.x + i, y: run.start.y), t) }
            var x = run.start.x
            while x < run.start.x + run.length {
                if x + 1 < run.start.x + run.length {
                    foodTruck(c, x * size, run.start.y * size, theme: t, district: district, index: index + s.x)
                    x += 2
                } else {
                    streetStall(c, x * size, run.start.y * size, theme: t, index: index + s.x)
                    x += 1
                }
                index += 1
            }
        }
    }

    private static func foodTruck(_ c: PixelCanvas, _ px: Int, _ py: Int, theme t: CityTheme, district: District, index: Int) {
        let menus: [String]
        switch t.city {
        case .paris: menus = ["CREPES", "FRITES"]
        case .marseille: menus = ["PANISSE", "PIZZA"]
        case .casablanca: menus = ["MSEMEN", "SFENJ"]
        default: menus = ["FRITES", "TACOS"]
        }
        let menu = menus[(index + (district == .dome ? 1 : 0)) % menus.count]
        let bodies = ["#e8e4dc", "#d8a03a", "#c8322a", "#2a6a9a"].map(PixelColor.init(hex:))
        let body = bodies[index % bodies.count]
        let x0 = px + 1, x1 = px + 2 * size - 2
        // Body, cab, wheels.
        c.fill(x0, py + 2, x1 - 7, py + 13, body)
        c.fill(x0, py + 2, x1 - 7, py + 2, body.shaded(1.2))
        c.fill(x1 - 6, py + 6, x1, py + 13, body.shaded(0.9))
        c.fill(x1 - 5, py + 7, x1 - 1, py + 9, PixelColor(hex: "#1c2433"))
        for wx in [x0 + 4, x1 - 4] { c.fill(wx - 2, py + 13, wx + 2, py + 15, ink); c.dot(wx, py + 14, NightPalette.metal) }
        // The serving hatch, lit, its awning propped open, the menu on top.
        c.fill(x0 + 3, py + 6, x1 - 10, py + 10, NightPalette.windowLit.shaded(0.85))
        c.fill(x0 + 2, py + 5, x1 - 9, py + 5, t.awnings.first ?? PixelColor(hex: "#9a2a26"))
        c.fill(x0 + 3, py + 11, x1 - 10, py + 11, NightPalette.metal.shaded(1.3))
        c.fill(x0 + 1, py - 5, x0 + PixelFont.width(menu) + 4, py + 1, ink)
        PixelFont.draw(menu, on: c, x: x0 + 3, y: py - 4, NightPalette.lampLight)
        // A string of bulbs.
        for bx in stride(from: x0 + 2, through: x1 - 8, by: 4) { c.dot(bx, py + 3 + (bx / 4) % 2, NightPalette.lampLight) }
    }

    private static func streetStall(_ c: PixelCanvas, _ px: Int, _ py: Int, theme t: CityTheme, index: Int) {
        let awning = t.awnings.isEmpty ? PixelColor(hex: "#9a2a26") : t.awnings[index % t.awnings.count]
        for x in 0..<16 { c.fill(px + x, py + 1, px + x, py + 5, (x / 3) % 2 == 0 ? awning : paper) }
        c.fill(px + 1, py + 6, px + 1, py + 15, NightPalette.metal); c.fill(px + 14, py + 6, px + 14, py + 15, NightPalette.metal)
        c.fill(px + 1, py + 10, px + 14, py + 14, NightPalette.wood)
        let goods = t.city == .casablanca ? ["#2a8a3a", "#e8c860", "#c8402a"] : ["#e04f4f", "#f2a03a", "#7fc04f"]
        for (i, gx) in stride(from: px + 2, to: px + 13, by: 3).enumerated() {
            c.fill(gx, py + 9, gx + 1, py + 10, PixelColor(hex: goods[i % goods.count]))
        }
    }

    // MARK: Café terrace

    /// Round tables seen from above: rattan chairs in Paris, sun-yellow parasols in Marseille, green ones and a
    /// silver teapot in Casablanca.
    private static func cafeArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        for p in propTiles(of: s, map: map) {
            pavement(c, p, t)
            let px = p.x * size, py = p.y * size, cx = px + 8, cy = py + 9
            let chair = t.city == .paris ? PixelColor(hex: "#a8844a") : NightPalette.metal.shaded(1.2)
            for (dx, dy) in [(-6, 0), (5, 0)] {
                c.fill(cx + dx, cy + dy - 1, cx + dx + 1, cy + dy + 2, chair)
                if t.city == .paris { c.dot(cx + dx, cy + dy, chair.shaded(0.7)) }
            }
            switch t.city {
            case .marseille, .casablanca:
                // A parasol over the table, in segments.
                let cloth = t.city == .marseille ? PixelColor(hex: "#f2c14e") : PixelColor(hex: "#1f7a6a")
                c.circle(cx: cx, cy: cy - 2, radius: 6, cloth)
                for (dx, dy) in [(-4, -4), (4, -4), (-4, 2), (4, 2)] { c.dot(cx + dx, cy - 2 + dy, cloth.shaded(0.75)) }
                c.fill(cx - 6, cy - 2, cx + 6, cy - 2, cloth.shaded(0.8))
                c.dot(cx, cy - 2, paper)
                if t.city == .casablanca { c.dot(cx - 3, cy + 5, PixelColor(hex: "#7fe0a0")); c.dot(cx + 3, cy + 5, PixelColor(hex: "#7fe0a0")) }
            default:
                // A small marble table, two cups.
                c.circle(cx: cx, cy: cy, radius: 3, PixelColor(hex: "#d8d4cc"))
                c.dot(cx - 1, cy - 1, PixelColor(hex: "#5a3a22")); c.dot(cx + 1, cy + 1, PixelColor(hex: "#5a3a22"))
                c.fill(px + 1, py + 1, px + 14, py + 3, PixelColor(hex: "#9a2a26"))
                for x in stride(from: px + 1, through: px + 14, by: 3) { c.dot(x, py + 3, paper) }
            }
        }
    }

    // MARK: Shore

    /// The water's edge. Marseille: white limestone falling into turquoise water, a pine on top, a little lighthouse.
    /// Casablanca: dark rocks under the Atlantic's surf. Elsewhere: a stone quay going down into the water.
    private static func shoreArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let water = points(of: s).filter { map.tile(at: $0) == .water }
        guard let minX = water.map(\.x).min(), let maxX = water.map(\.x).max(),
              let minY = water.map(\.y).min(), let maxY = water.map(\.y).max() else { return }
        // The rocks cling to whichever side of the map the rectangle touches.
        let leftSide = minX <= 1
        let x0 = minX * size, x1 = (maxX + 1) * size - 1, y0 = minY * size, y1 = (maxY + 1) * size - 1
        let width = x1 - x0 + 1
        var noise = PixelNoise(s.x, s.y, salt: 131)
        switch t.city {
        case .marseille, .casablanca:
            let rock = t.city == .marseille ? PixelColor(hex: "#d8d0bc") : PixelColor(hex: "#3a3a40")
            let shade = t.city == .marseille ? PixelColor(hex: "#a89e88") : PixelColor(hex: "#24242a")
            let shallow = t.city == .marseille ? PixelColor(hex: "#2a9aa8") : PixelColor(hex: "#2a5a8a")
            for y in y0...y1 {
                // The cliff gets wider toward the bottom, with a ragged edge.
                let reach = width * 2 / 5 + (y - y0) * width / (3 * max(1, y1 - y0)) + noise.next(4)
                let edge = leftSide ? x0 + reach : x1 - reach
                let (from, to) = leftSide ? (x0, edge) : (edge, x1)
                c.fill(from, y, to, y, rock)
                c.fill(leftSide ? to - 2 : from, y, leftSide ? to : from + 2, y, shade)
                // Shallow, clear water along the rock, foam where it breaks.
                let (wf, wt) = leftSide ? (to + 1, min(x1, to + 5)) : (max(x0, from - 5), from - 1)
                if wf <= wt { c.fill(wf, y, wt, y, shallow) }
                if noise.chance(t.city == .casablanca ? 45 : 15) { c.dot(leftSide ? to + 1 : from - 1, y, paper) }
            }
            // Strata lines on the limestone, or wet glints on the basalt.
            for y in stride(from: y0 + 5, to: y1, by: 7) {
                let len = width / 3
                c.fill(leftSide ? x0 : x1 - len, y, leftSide ? x0 + len : x1, y, shade)
            }
            if t.city == .marseille {
                // A twisted pine on top of the cliff.
                let px = leftSide ? x0 + 6 : x1 - 10
                c.fill(px + 2, y0 + 3, px + 3, y0 + 9, NightPalette.trunk)
                c.fill(px - 2, y0 + 1, px + 7, y0 + 3, t.leaf); c.fill(px, y0, px + 5, y0, t.leafLight)
            }
            // A little lighthouse on the far rocks.
            let lx = leftSide ? x0 + 4 : x1 - 7
            c.fill(lx, y1 - 22, lx + 3, y1 - 12, paper)
            c.fill(lx, y1 - 18, lx + 3, y1 - 17, PixelColor(hex: "#c8322a"))
            c.fill(lx - 1, y1 - 24, lx + 4, y1 - 23, PixelColor(hex: "#c8322a"))
            c.fill(lx + 1, y1 - 26, lx + 2, y1 - 25, NightPalette.lampLight)
            let beam = leftSide ? 1 : -1
            for i in 1...6 { c.dot(lx + 1 + beam * (3 + i), y1 - 26 + i / 3, NightPalette.lampLight.shaded(0.8)) }
        default:
            // A stone quay: steps going down into the water, mooring rings, a small boat tied up.
            let stone = PixelColor(hex: "#8a8478")
            let stepsX = leftSide ? x0 : x1 - 15
            for (i, y) in stride(from: y0, to: min(y1, y0 + 24), by: 4).enumerated() {
                c.fill(stepsX, y, stepsX + 15, y + 3, stone.shaded(1.0 - Double(i) * 0.08))
                c.fill(stepsX, y, stepsX + 15, y, stone.shaded(1.2))
            }
            let bx = leftSide ? x0 + 18 : x1 - 34
            if bx > x0, bx + 14 < x1 {
                c.fill(bx, y0 + 10, bx + 14, y0 + 14, PixelColor(hex: "#2a4a6a"))
                c.fill(bx + 1, y0 + 9, bx + 13, y0 + 9, PixelColor(hex: "#c8c0b0"))
                c.fill(bx + 4, y0 + 7, bx + 8, y0 + 9, PixelColor(hex: "#e8e4dc"))
            }
            for y in stride(from: y0 + 2, to: y1, by: 12) { c.circle(cx: leftSide ? x0 + 1 : x1 - 1, cy: y, radius: 1, NightPalette.metal) }
            // Two ducks.
            for (dx, dy) in [(8, 30), (14, 34)] where y0 + dy < y1 {
                let dxs = leftSide ? x0 + 20 + dx : x1 - 20 - dx
                c.fill(dxs, y0 + dy, dxs + 2, y0 + dy + 1, PixelColor(hex: "#8a7a5a")); c.dot(dxs + 3, y0 + dy - 1, PixelColor(hex: "#2a6a3a"))
            }
        }
    }
}
