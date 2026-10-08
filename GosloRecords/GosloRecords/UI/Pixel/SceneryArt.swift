import UIKit

// The new corners of each district (map.json / districts.json "scenery"): Le Bloc's city stade, car park and
// rooftop terrace, downtown's covered market, murals and barge, the belvedere over the city in Les Hauts, the
// Dôme's car park and backstage. Painted once into the cached map image, after the streets. Same rule as the
// rest of the street art: walkable tiles only get flat details (lines, planks, steps), anything with volume
// (a car, a stall, a bus, a railing) stands on a tile that was already blocked.

@MainActor
extension TileArt {
    static func dressScenery(_ c: PixelCanvas, map: WorldMap, theme t: CityTheme, district: District) {
        for scenery in map.scenery ?? [] {
            switch scenery.kind {
            case .pitch: pitchArt(scenery, on: c, map: map, theme: t)
            case .parking: parkingArt(scenery, on: c, map: map, theme: t, district: district)
            case .terrace: terraceArt(scenery, on: c, map: map, theme: t)
            case .stairs: stepsArt(scenery, on: c, map: map, theme: t)
            case .market: marketArt(scenery, on: c, map: map, theme: t)
            case .murals: paintMurals(scenery, on: c, map: map)
            case .barge: bargeArt(scenery, on: c)
            case .belvedere: belvedereArt(scenery, on: c, map: map, theme: t)
            case .panorama: panoramaArt(scenery, on: c, map: map, theme: t)
            case .backstage: backstageArt(scenery, on: c, map: map, theme: t)
            case .bridge: bridgeArt(scenery, on: c, map: map, theme: t)
            }
        }
    }

    // MARK: Helpers

    private static func sceneryPoints(_ s: MapScenery) -> [TilePoint] {
        guard s.w > 0, s.h > 0 else { return [] }
        return (s.y..<(s.y + s.h)).flatMap { y in (s.x..<(s.x + s.w)).map { TilePoint(x: $0, y: y) } }
    }

    private static func outlineRect(_ c: PixelCanvas, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: PixelColor) {
        c.fill(x0, y0, x1, y0, color); c.fill(x0, y1, x1, y1, color)
        c.fill(x0, y0, x0, y1, color); c.fill(x1, y0, x1, y1, color)
    }

    private static func ringOutline(_ c: PixelCanvas, cx: Int, cy: Int, radius r: Int, _ color: PixelColor) {
        guard r > 0 else { return }
        for y in (cy - r)...(cy + r) {
            for x in (cx - r)...(cx + r) {
                let d = (x - cx) * (x - cx) + (y - cy) * (y - cy)
                if d <= r * r, d > (r - 1) * (r - 1) { c.dot(x, y, color) }
            }
        }
    }

    /// A wooden bench seen from above (the same as the map's bench tile), on whatever floor is already there.
    private static func benchProps(_ c: PixelCanvas, _ px: Int, _ py: Int, wood: PixelColor = NightPalette.wood) {
        c.fill(px + 1, py + 4, px + 14, py + 6, wood)
        c.fill(px + 1, py + 8, px + 14, py + 10, wood.shaded(1.2))
        c.fill(px + 2, py + 11, px + 3, py + 14, NightPalette.metal)
        c.fill(px + 12, py + 11, px + 13, py + 14, NightPalette.metal)
    }

    /// Runs of blocked tiles on one row of a rectangle: (first x, length).
    private static func blockedRuns(_ s: MapScenery, row y: Int, map: WorldMap) -> [(x: Int, length: Int)] {
        var runs: [(x: Int, length: Int)] = [], start: Int?
        for x in s.x...(s.x + s.w) {
            let blocked = x < s.x + s.w && map.tile(at: TilePoint(x: x, y: y)) == .tree
            if blocked, start == nil { start = x }
            if !blocked, let first = start { runs.append((first, x - first)); start = nil }
        }
        return runs
    }

    // MARK: Le Bloc

    /// The city stade: a green synthetic pitch in a wire cage, white lines, two little goals.
    private static func pitchArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let turf = t.snow ? PixelColor(hex: "#9aa8b0") : PixelColor(hex: "#2f6b3e")
        let stripe = t.snow ? PixelColor(hex: "#a8b4bc") : PixelColor(hex: "#367a47")
        let line = PixelColor(hex: "#e8e8ec"), mesh = PixelColor(hex: "#7a7e88")
        for p in sceneryPoints(s) {
            let px = p.x * size, py = p.y * size
            if map.tile(at: p).isWalkable {
                c.fill(px, py, px + 15, py + 15, turf)
                for x in stride(from: px, to: px + 16, by: 1) where (x / 8) % 2 == 0 { c.fill(x, py, x, py + 15, stripe) }
            } else if map.tile(at: p) == .fence {
                // The cage: dark turf under a diamond wire mesh, a steel post every tile.
                c.fill(px, py, px + 15, py + 15, turf.shaded(0.7))
                for y in 0..<16 {
                    for x in 0..<16 where (x + y) % 4 == 0 || (x - y + 16) % 4 == 0 { c.dot(px + x, py + y, mesh.shaded(0.8)) }
                }
                c.fill(px + 7, py, px + 8, py + 15, mesh.shaded(1.3))
                c.fill(px, py + 7, px + 15, py + 7, mesh.shaded(1.15))
            }
        }
        // The lines, inside the cage.
        let x0 = (s.x + 1) * size + 2, x1 = (s.x + s.w - 1) * size - 3
        let y0 = (s.y + 1) * size + 2, y1 = (s.y + s.h - 1) * size - 3
        guard x1 - x0 > 24, y1 - y0 > 16 else { return }
        outlineRect(c, x0, y0, x1, y1, line)
        let cx = (x0 + x1) / 2, cy = (y0 + y1) / 2
        c.fill(cx, y0, cx, y1, line)
        ringOutline(c, cx: cx, cy: cy, radius: 7, line)
        c.dot(cx, cy, line)
        let box = min(12, (y1 - y0) / 2 - 2)
        for (edge, inward) in [(x0, 1), (x1, -1)] {
            // Penalty area, spot, and the goal: a white frame with its net hanging behind.
            let far = edge + inward * 10
            outlineRect(c, min(edge, far), cy - box, max(edge, far), cy + box, line)
            c.dot(edge + inward * 7, cy, line)
            let back = edge - inward * 2
            c.fill(min(edge, back), cy - 5, max(edge, back), cy + 5, PixelColor(hex: "#c8ccd4"))
            for y in stride(from: cy - 4, through: cy + 4, by: 2) { c.dot(back, y, mesh) }
            c.fill(edge, cy - 5, edge, cy + 5, line)
        }
        // A ball left near the centre spot.
        c.fill(cx + 4, cy + 3, cx + 5, cy + 4, line); c.dot(cx + 5, cy + 4, PixelColor(hex: "#14141a"))
    }

    /// A car park: bays painted on the asphalt, a parked car on each blocked tile, a coach on a run of three.
    private static func parkingArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme, district: District) {
        let paint = PixelColor(hex: "#b8b8c0")
        for y in s.y..<(s.y + s.h) {
            let runs = blockedRuns(s, row: y, map: map)
            guard !runs.isEmpty else { continue }
            // The row of bays: asphalt under the cars, a line between two bays.
            for x in s.x..<(s.x + s.w) {
                let p = TilePoint(x: x, y: y), px = x * size, py = y * size
                if map.tile(at: p) == .tree {
                    var noise = PixelNoise(x, y, salt: 61)
                    let ground = PixelCanvas(width: size, height: size)
                    asphalt(ground, &noise)
                    c.stamp(ground, at: px, py)
                }
                c.fill(px, py + 1, px, py + 13, paint)
                c.fill(px + 15, py + 1, px + 15, py + 13, paint)
            }
            for run in runs {
                if run.length >= 3 {
                    for start in stride(from: run.x, through: run.x + run.length - 3, by: 3) {
                        coach(c, start * size, y * size, tour: false)
                    }
                    for x in (run.x + run.length / 3 * 3)..<(run.x + run.length) { parkedCar(c, x, y, theme: t) }
                } else {
                    for x in run.x..<(run.x + run.length) { parkedCar(c, x, y, theme: t) }
                }
            }
        }
    }

    /// A car seen from above, nose up: body, windscreen, roof, rear window, lights.
    private static func parkedCar(_ c: PixelCanvas, _ x: Int, _ y: Int, theme t: CityTheme) {
        var noise = PixelNoise(x, y, salt: 67)
        let paints = ["#c8322a", "#e8e4dc", "#2a4a8a", "#1a1a1e", "#8a8e96", "#2f6a3a", "#d8a03a"].map(PixelColor.init(hex:))
        let body = paints[noise.next(paints.count)], glass = PixelColor(hex: "#1c2433")
        let px = x * size, py = y * size
        c.fill(px + 3, py + 1, px + 12, py + 14, body)
        c.fill(px + 4, py, px + 11, py + 15, body)
        c.fill(px + 4, py + 4, px + 11, py + 5, glass)
        c.fill(px + 4, py + 6, px + 11, py + 10, body.shaded(1.15))
        c.fill(px + 4, py + 11, px + 11, py + 12, glass)
        c.dot(px + 5, py + 4, PixelColor(hex: "#5a6a8a"))
        c.dot(px + 4, py, NightPalette.lampLight.shaded(0.8)); c.dot(px + 11, py, NightPalette.lampLight.shaded(0.8))
        c.dot(px + 4, py + 15, PixelColor(hex: "#a8201a")); c.dot(px + 11, py + 15, PixelColor(hex: "#a8201a"))
        c.dot(px + 2, py + 5, body.shaded(0.7)); c.dot(px + 13, py + 5, body.shaded(0.7))
        if t.snow { c.fill(px + 4, py + 6, px + 11, py + 10, PixelColor(hex: "#e8eef6")) }
    }

    /// A coach over three bays, seen from above: a long roof with its air-con units. On tour, it's black and gold.
    private static func coach(_ c: PixelCanvas, _ px: Int, _ py: Int, tour: Bool) {
        let body = tour ? PixelColor(hex: "#1a1a20") : PixelColor(hex: "#e8e4dc")
        let trim = tour ? PixelColor(hex: "#d8b040") : PixelColor(hex: "#2a6ab0")
        let x0 = px + 1, x1 = px + 3 * size - 2
        c.fill(x0, py + 2, x1, py + 13, body)
        c.fill(x0 + 1, py + 1, x1 - 1, py + 14, body)
        c.fill(x0 + 1, py + 3, x1 - 1, py + 3, trim)
        c.fill(x0 + 1, py + 12, x1 - 1, py + 12, trim)
        // Windscreen at the front (right), the roof hatches and air-con.
        c.fill(x1 - 3, py + 3, x1 - 1, py + 12, PixelColor(hex: "#1c2433"))
        c.fill(x1 - 3, py + 4, x1 - 3, py + 6, PixelColor(hex: "#5a6a8a"))
        if tour {
            c.fill(x0 + 3, py + 5, x0 + 10, py + 10, body.shaded(1.8))
            PixelFont.draw("TOUR", on: c, x: x0 + 15, y: py + 6, trim)
            c.fill(x0 + 33, py + 6, x0 + 37, py + 9, body.shaded(1.5))
        } else {
            for ax in [x0 + 6, x0 + 20] { c.fill(ax, py + 5, ax + 7, py + 10, body.shaded(0.85)) }
            c.fill(x0 + 33, py + 6, x0 + 37, py + 9, body.shaded(0.9))
        }
        c.dot(x1, py + 3, NightPalette.lampLight); c.dot(x1, py + 12, NightPalette.lampLight)
    }

    /// The cité's rooftop terrace: roofing gravel, a parapet all round, a water tank, fairy lights on the railing.
    private static func terraceArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let gravel = t.roof.shaded(1.25), grit = t.roof.shaded(1.5), parapet = t.wall.shaded(1.15)
        for p in sceneryPoints(s) {
            let px = p.x * size, py = p.y * size
            var noise = PixelNoise(p.x, p.y, salt: 71)
            let kind = map.tile(at: p)
            switch kind {
            case .sidewalk, .bench, .tree:
                c.fill(px, py, px + 15, py + 15, gravel)
                for _ in 0..<12 { c.dot(px + noise.next(16), py + noise.next(16), noise.chance(50) ? grit : gravel.shaded(0.85)) }
                c.fill(px, py + 7, px + 15, py + 7, gravel.shaded(0.9))
                if t.snow { c.fill(px + noise.next(8), py + 2, px + 8 + noise.next(6), py + 3, PixelColor(hex: "#e8eef6")) }
                // The low wall where the roof stops.
                if !s.contains(p.moved(.down)) || map.tile(at: p.moved(.down)) == .wall {
                    c.fill(px, py + 13, px + 15, py + 15, parapet)
                    c.fill(px, py + 13, px + 15, py + 13, parapet.shaded(1.2))
                }
                if !s.contains(p.moved(.left)) { c.fill(px, py, px + 1, py + 15, parapet) }
                if kind == .bench { benchProps(c, px, py) }
                if kind == .tree {
                    // A water tank on its legs.
                    let steel = NightPalette.metal.shaded(1.25)
                    for (lx, ly) in [(3, 12), (12, 12), (3, 4), (12, 4)] { c.fill(px + lx, py + ly, px + lx, py + ly + 2, NightPalette.metal) }
                    c.circle(cx: px + 8, cy: py + 8, radius: 6, steel)
                    c.circle(cx: px + 8, cy: py + 8, radius: 4, steel.shaded(0.85))
                    c.fill(px + 7, py + 7, px + 9, py + 9, steel.shaded(1.15))
                }
            case .fence:
                // The parapet along the street side, a railing on top, fairy lights.
                c.fill(px, py, px + 15, py + 15, t.wall.shaded(0.9))
                c.fill(px, py + 10, px + 15, py + 15, parapet)
                c.fill(px, py + 10, px + 15, py + 10, parapet.shaded(1.2))
                c.fill(px, py + 3, px + 15, py + 3, NightPalette.metal.shaded(1.3))
                for x in stride(from: 1, to: 16, by: 4) { c.fill(px + x, py + 3, px + x, py + 9, NightPalette.metal) }
                for x in stride(from: 2, to: 16, by: 5) {
                    c.dot(px + x, py + 4 + (x % 3), [NightPalette.lampLight, PixelColor(hex: "#e04fb0"), PixelColor(hex: "#4fd6e0")][x % 3])
                }
            default:
                break
            }
        }
    }

    /// Concrete steps climbing up, a handrail on each side.
    private static func stepsArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let stone = t.sidewalk.shaded(1.2)
        for p in sceneryPoints(s) where map.tile(at: p).isWalkable {
            let px = p.x * size, py = p.y * size
            c.fill(px, py, px + 15, py + 15, stone)
            for y in stride(from: 0, to: 16, by: 4) {
                c.fill(px, py + y, px + 15, py + y, stone.shaded(1.25))
                c.fill(px, py + y + 3, px + 15, py + y + 3, stone.shaded(0.7))
            }
            if p.x == s.x { c.fill(px, py, px + 1, py + 15, NightPalette.metal.shaded(1.2)) }
            if p.x == s.x + s.w - 1 { c.fill(px + 14, py, px + 15, py + 15, NightPalette.metal.shaded(1.2)) }
        }
    }

    // MARK: Centre-ville

    /// The covered market: a tiled floor under an iron and glass canopy, a stall on each blocked tile.
    private static func marketArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let tileA = PixelColor(hex: "#5a5048"), tileB = PixelColor(hex: "#4c443c")
        let iron = PixelColor(hex: "#2a4a3a"), glass = PixelColor(hex: "#6a98a4")
        for p in sceneryPoints(s) {
            let px = p.x * size, py = p.y * size
            switch map.tile(at: p) {
            case .sidewalk:
                for (i, (dx, dy)) in [(0, 0), (8, 0), (0, 8), (8, 8)].enumerated() {
                    c.fill(px + dx, py + dy, px + dx + 7, py + dy + 7, (i == 0 || i == 3) ? tileA : tileB)
                }
            case .tree:
                stall(c, p, s: s, map: map, theme: t)
            default:
                break
            }
        }
        // The canopy's edge along the street, with its name; iron columns at the corners and along the sides.
        let x0 = s.x * size, x1 = (s.x + s.w) * size - 1, y0 = s.y * size, y1 = (s.y + s.h) * size - 1
        c.fill(x0, y0, x1, y0 + 6, iron)
        c.fill(x0, y0 + 7, x1, y0 + 8, glass)
        for x in stride(from: x0 + 3, to: x1, by: 6) { c.dot(x, y0 + 7, glass.shaded(1.4)) }
        let name = "HALLES"
        PixelFont.draw(name, on: c, x: (x0 + x1 - PixelFont.width(name)) / 2, y: y0 + 1, NightPalette.lampLight)
        for x in stride(from: x0, through: x1 - 2, by: 4 * size) {
            for y in [y0 + 9, y1 - 3] { c.fill(x, y, x + 2, y + 2, iron.shaded(1.3)) }
        }
        c.fill(x1 - 2, y0 + 9, x1, y0 + 11, iron.shaded(1.3)); c.fill(x1 - 2, y1 - 3, x1, y1 - 1, iron.shaded(1.3))
        // Bare bulbs hanging over the aisles.
        for y in stride(from: y0 + 2 * size + 6, to: y1, by: 3 * size) {
            for x in stride(from: x0 + 12, to: x1, by: 24) where map.tile(at: TilePoint(x: x / size, y: y / size)).isWalkable {
                c.dot(x, y, NightPalette.lampLight); c.dot(x, y - 1, NightPalette.metal)
            }
        }
    }

    /// A market stall: striped awning on top, the counter and what's for sale.
    private static func stall(_ c: PixelCanvas, _ p: TilePoint, s: MapScenery, map: WorldMap, theme t: CityTheme) {
        let px = p.x * size, py = p.y * size
        var noise = PixelNoise(p.x, p.y, salt: 79)
        let awning = t.awnings.isEmpty ? PixelColor(hex: "#9a2a26") : t.awnings[(p.x + p.y) % t.awnings.count]
        let white = PixelColor(hex: "#e8e2d4")
        c.fill(px, py, px + 15, py + 15, PixelColor(hex: "#4c443c"))
        for x in 0..<16 { c.fill(px + x, py, px + x, py + 5, ((p.x * 16 + x) / 3) % 2 == 0 ? awning : white) }
        c.fill(px, py + 6, px + 15, py + 6, awning.shaded(0.6))
        c.fill(px, py + 7, px + 15, py + 14, NightPalette.wood)
        c.fill(px, py + 15, px + 15, py + 15, NightPalette.wood.shaded(0.6))
        let goods: [[String]] = [
            ["#e04f4f", "#f2a03a", "#7fc04f"],   // fruit
            ["#3f8a3a", "#e8d8a0", "#c86a2a"],   // vegetables
            ["#a8b8c8", "#e8eef6", "#7a8a9a"],   // fish on ice
            ["#e8d040", "#e06a9a", "#f0eee8"],   // flowers
            ["#f2d07a", "#e8c860", "#c89a3a"],   // cheese
            ["#c8402a", "#e8a030", "#8a5a2a"],   // spices
        ]
        let palette = goods[noise.next(goods.count)].map(PixelColor.init(hex:))
        for (i, gx) in stride(from: px + 1, to: px + 15, by: 3).enumerated() {
            c.fill(gx, py + 8, gx + 1, py + 9, palette[i % palette.count])
            c.fill(gx + 1, py + 11, gx + 2, py + 12, palette[(i + 1) % palette.count])
        }
        // A price tag on the first stall of a row.
        if map.tile(at: p.moved(.left)) != .tree { c.fill(px + 1, py + 13, px + 4, py + 14, white) }
    }

    /// Murals across a stretch of front walls: a sunset over a boombox, big bubble letters, a face with headphones.
    private static func paintMurals(_ s: MapScenery, on c: PixelCanvas, map: WorldMap) {
        let x0 = s.x * size, x1 = (s.x + s.w) * size - 1, y0 = s.y * size, y1 = (s.y + s.h) * size - 1
        guard x1 > x0 + 8, y1 > y0 + 8 else { return }
        let panels = max(1, s.w / 3), width = (x1 - x0 + 1) / panels
        for panel in 0..<panels {
            let px0 = x0 + panel * width, px1 = panel == panels - 1 ? x1 : px0 + width - 1
            switch panel % 3 {
            case 0:
                // Sunset, a palm, and a boombox in the middle.
                for (i, hex) in ["#2a1a4a", "#5a2a6a", "#a83a6a", "#e8704a", "#f2b84e"].enumerated() {
                    let band = (y1 - y0 + 1) / 5
                    c.fill(px0, y0 + i * band, px1, i == 4 ? y1 : y0 + (i + 1) * band - 1, PixelColor(hex: hex))
                }
                let bx = (px0 + px1) / 2 - 10, by = y1 - 14
                c.fill(bx, by, bx + 20, by + 10, PixelColor(hex: "#1a1a20"))
                c.fill(bx + 7, by - 3, bx + 13, by - 2, PixelColor(hex: "#8a8a96"))
                for sx in [bx + 5, bx + 15] {
                    c.circle(cx: sx, cy: by + 5, radius: 3, PixelColor(hex: "#5a5a66"))
                    c.dot(sx, by + 5, PixelColor(hex: "#14141a"))
                }
                c.fill(bx + 9, by + 2, bx + 11, by + 3, PixelColor(hex: "#4fd6e0"))
                c.fill(px0 + 4, y0 + 4, px0 + 5, y1, PixelColor(hex: "#1a1030"))
                for (dx, dy) in [(-3, 0), (3, 0), (-2, -1), (2, -1), (0, -2)] { c.fill(px0 + 4 + dx, y0 + 4 + dy, px0 + 5 + dx, y0 + 4 + dy, PixelColor(hex: "#1a1030")) }
            case 1:
                // Bubble letters with drips, on a teal wall.
                c.fill(px0, y0, px1, y1, PixelColor(hex: "#1f6a6a"))
                for x in stride(from: px0 + 2, to: px1, by: 7) { c.fill(x, y0 + 2, x + 1, y0 + 3, PixelColor(hex: "#2a8a86")) }
                let word = "RAP", w = PixelFont.width(word) * 2
                let lx = (px0 + px1 - w) / 2, ly = (y0 + y1) / 2 - 5
                for (dx, dy, hex) in [(1, 1, "#14141a"), (0, 0, "#f2c14e")] {
                    let big = PixelCanvas(width: PixelFont.width(word), height: 5)
                    PixelFont.draw(word, on: big, x: 0, y: 0, PixelColor(hex: hex))
                    for y in 0..<5 {
                        for x in 0..<big.width where !big[x, y].isClear {
                            c.fill(lx + dx + x * 2, ly + dy + y * 2, lx + dx + x * 2 + 1, ly + dy + y * 2 + 1, big[x, y])
                        }
                    }
                }
                for dx in [3, 9, 15] { c.fill(lx + dx, ly + 10, lx + dx, ly + 13, PixelColor(hex: "#f2c14e")) }
                c.fill(px0 + 2, y1 - 3, px0 + 7, y1 - 3, PixelColor(hex: "#e04fb0"))
                c.fill(px1 - 7, y0 + 3, px1 - 3, y0 + 3, PixelColor(hex: "#f0eee8"))
            default:
                // A face in profile with big headphones, on magenta.
                c.fill(px0, y0, px1, y1, PixelColor(hex: "#8a2a6a"))
                for y in stride(from: y0 + 1, to: y1, by: 4) { c.fill(px0, y, px1, y, PixelColor(hex: "#7a2460")) }
                let cx = (px0 + px1) / 2, cy = (y0 + y1) / 2 + 1
                c.circle(cx: cx, cy: cy, radius: 10, PixelColor(hex: "#3a2418"))
                c.fill(cx + 8, cy - 1, cx + 11, cy + 2, PixelColor(hex: "#3a2418"))
                c.fill(cx - 12, cy - 12, cx + 4, cy - 10, PixelColor(hex: "#14141a"))
                c.fill(cx - 12, cy - 10, cx - 10, cy + 2, PixelColor(hex: "#14141a"))
                c.fill(cx - 13, cy - 3, cx - 8, cy + 4, PixelColor(hex: "#4fd6e0"))
                c.dot(cx + 5, cy - 3, PixelColor(hex: "#f0eee8"))
                for (i, nx) in [cx + 14, cx + 18].enumerated() where nx < px1 - 1 {
                    c.fill(nx, cy - 8 + i * 4, nx, cy - 4 + i * 4, PixelColor(hex: "#f2c14e"))
                    c.fill(nx - 2, cy - 4 + i * 4, nx, cy - 3 + i * 4, PixelColor(hex: "#f2c14e"))
                }
            }
            // A thin dark seam between two pieces.
            if panel > 0 { c.fill(px0, y0, px0, y1, PixelColor(hex: "#14141a")) }
        }
        // Tags along the foot of the wall, and the plinth.
        var noise = PixelNoise(s.x, s.y, salt: 83)
        for x in stride(from: x0 + 6, to: x1 - 12, by: 22) { tag(c, &noise, x: x, y: y1 - 3, width: 8) }
        c.fill(x0, y1, x1, y1, PixelColor(hex: "#14141a"))
    }

    /// A barge moored on the river: a long dark hull, a cabin with lit portholes, pots on the deck.
    private static func bargeArt(_ s: MapScenery, on c: PixelCanvas) {
        let x0 = s.x * size + 1, x1 = (s.x + s.w) * size - 2, y0 = s.y * size + 2, y1 = s.y * size + 13
        guard x1 - x0 > 30 else { return }
        let hull = PixelColor(hex: "#24303a"), deck = PixelColor(hex: "#6b4a2e"), cabin = PixelColor(hex: "#c8b89a")
        c.fill(x0 + 2, y0, x1 - 6, y1, hull)
        for i in 0..<6 { c.fill(x1 - 6 + i, y0 + i, x1 - 6 + i, y1 - i, hull) }
        c.fill(x0, y0 + 2, x0 + 1, y1 - 2, hull)
        c.fill(x0 + 3, y0 + 2, x1 - 8, y1 - 2, deck)
        c.fill(x0 + 3, y0 + 2, x1 - 8, y0 + 2, PixelColor(hex: "#c83a2a"))
        // The cabin at the stern, lit.
        c.fill(x0 + 5, y0 + 3, x0 + 26, y1 - 3, cabin)
        c.fill(x0 + 5, y0 + 3, x0 + 26, y0 + 4, cabin.shaded(1.15))
        for wx in stride(from: x0 + 8, to: x0 + 25, by: 5) { c.fill(wx, y0 + 6, wx + 2, y0 + 8, NightPalette.windowLit) }
        c.fill(x0 + 28, y1 - 4, x0 + 29, y1 - 3, PixelColor(hex: "#8a4a2e")); c.circle(cx: x0 + 28, cy: y1 - 6, radius: 2, PixelColor(hex: "#3f8a3a"))
        c.fill(x0 + 34, y1 - 4, x0 + 35, y1 - 3, PixelColor(hex: "#8a4a2e")); c.dot(x0 + 35, y1 - 6, PixelColor(hex: "#e06a9a"))
        // A bike on the deck and a mooring line to the quay.
        c.circle(cx: x0 + 44, cy: y0 + 7, radius: 2, NightPalette.metal.shaded(1.3)); c.circle(cx: x0 + 50, cy: y0 + 7, radius: 2, NightPalette.metal.shaded(1.3))
        c.fill(x0 + 44, y0 + 6, x0 + 50, y0 + 6, PixelColor(hex: "#c83a2a"))
        for i in 0..<8 { c.dot(x0 + 12 + i, y0 - 1 - i / 3, PixelColor(hex: "#c8c0b0")) }
        c.dot(x1 - 2, y0 + 5, NightPalette.lampLight)
    }

    // MARK: Les Hauts

    /// The belvedere: a wooden deck, a railing over the slope, a coin telescope turned to the city.
    private static func belvedereArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let plank = NightPalette.wood.shaded(1.1), slope = PixelColor(hex: "#141826")
        let telescope = s.x + s.w / 2
        for p in sceneryPoints(s) {
            let px = p.x * size, py = p.y * size
            let kind = map.tile(at: p)
            switch kind {
            case .sidewalk, .bench, .lamp:
                c.fill(px, py, px + 15, py + 15, plank)
                for y in stride(from: 3, to: 16, by: 4) { c.fill(px, py + y, px + 15, py + y, plank.shaded(0.75)) }
                for y in stride(from: 1, to: 16, by: 4) { c.dot(px + (p.x % 2 == 0 ? 3 : 11), py + y, plank.shaded(1.3)) }
                if t.snow { c.fill(px, py, px + 15, py + 1, PixelColor(hex: "#e8eef6")) }
                if kind == .bench { benchProps(c, px, py, wood: NightPalette.wood.shaded(0.8)) }
                if kind == .lamp {
                    c.fill(7 + px, py + 3, 7 + px, py + 15, NightPalette.metal.shaded(1.3))
                    c.fill(px + 7, py + 2, px + 11, py + 2, NightPalette.metal.shaded(1.3))
                    c.fill(px + 9, py + 3, px + 11, py + 3, PixelColor(hex: "#cfe8ff"))
                }
            case .fence:
                // The deck's edge and the railing, the dark slope going down behind.
                c.fill(px, py, px + 15, py + 15, slope)
                c.fill(px, py, px + 15, py + 4, plank.shaded(0.85))
                c.fill(px, py + 5, px + 15, py + 5, NightPalette.metal.shaded(1.4))
                c.fill(px, py + 10, px + 15, py + 10, NightPalette.metal)
                for x in stride(from: 1, to: 16, by: 5) { c.fill(px + x, py + 5, px + x, py + 12, NightPalette.metal.shaded(1.2)) }
                var noise = PixelNoise(p.x, p.y, salt: 89)
                for _ in 0..<2 { c.dot(px + noise.next(16), py + 13 + noise.next(3), t.leaf) }
                if p.x == telescope {
                    // A coin telescope on its post, pointing at the city.
                    let steel = PixelColor(hex: "#3a6a8a")
                    c.fill(px + 7, py + 1, px + 8, py + 6, NightPalette.metal)
                    c.fill(px + 4, py - 4, px + 11, py + 0, steel)
                    c.fill(px + 10, py - 3, px + 12, py + 1, steel.shaded(1.3))
                    c.dot(px + 5, py - 3, steel.shaded(1.5))
                }
            default:
                break
            }
        }
    }

    /// The view from the hill: the city's lights far below, a river of headlights, the towers in silhouette.
    private static func panoramaArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let x0 = s.x * size, x1 = (s.x + s.w) * size - 1, y0 = s.y * size, y1 = (s.y + s.h) * size - 1
        guard x1 > x0, y1 > y0 else { return }
        for y in y0...y1 {
            let k = Double(y - y0) / Double(max(1, y1 - y0))
            c.fill(x0, y, x1, y, PixelColor(r: UInt8(16 + 10 * k), g: UInt8(18 + 10 * k), b: UInt8(34 + 14 * k)))
        }
        var noise = PixelNoise(s.x, s.y, salt: 97)
        // Blocks of buildings, lower and lower toward the bottom, windows lit here and there.
        var x = x0
        while x < x1 {
            let w = 6 + noise.next(12), top = y0 + 4 + noise.next(10)
            let shade = noise.chance(50) ? PixelColor(hex: "#1a1e2c") : PixelColor(hex: "#222838")
            c.fill(x, top, min(x1, x + w), y1, shade)
            if t.snow { c.fill(x, top, min(x1, x + w), top, PixelColor(hex: "#8a94a8")) }
            for _ in 0..<(w / 2) where noise.chance(55) {
                c.dot(x + 1 + noise.next(max(1, w - 1)), top + 2 + noise.next(max(1, y1 - top - 2)),
                      noise.chance(80) ? NightPalette.windowLit.shaded(0.85) : PixelColor(hex: "#9ec8e8"))
            }
            x += w + 1 + noise.next(3)
        }
        // A road crossing the city: white headlights one way, red tail lights the other.
        let road = y0 + (y1 - y0) * 2 / 3
        c.fill(x0, road, x1, road + 2, PixelColor(hex: "#14161e"))
        for lx in stride(from: x0 + noise.next(6), to: x1, by: 5 + noise.next(4)) {
            c.dot(lx, road, PixelColor(hex: "#f0eee8")); c.dot(lx + 2, road + 2, PixelColor(hex: "#e0402a"))
        }
        // The radio tower's red light, far away.
        let mast = x0 + (x1 - x0) * 3 / 4
        c.fill(mast, y0 + 1, mast, y0 + 12, PixelColor(hex: "#3a3e4a"))
        c.dot(mast, y0, PixelColor(hex: "#ff2a1a"))
    }

    // MARK: Le Dôme

    /// Behind the arena: hazard stripes by the loading dock, tour buses, flight cases, the dressing rooms' stars.
    private static func backstageArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let yellow = PixelColor(hex: "#e8c040"), black = PixelColor(hex: "#14141a"), gold = PixelColor(hex: "#d8b040")
        for y in s.y..<(s.y + s.h) {
            for run in blockedRuns(s, row: y, map: map) {
                if run.length >= 3 {
                    for start in stride(from: run.x, through: run.x + run.length - 3, by: 3) { coach(c, start * size, y * size, tour: true) }
                } else {
                    for x in run.x..<(run.x + run.length) { flightCases(c, x * size, y * size) }
                }
            }
        }
        for p in sceneryPoints(s) {
            let px = p.x * size, py = p.y * size
            let kind = map.tile(at: p)
            if kind.isWalkable, wallRun(p.moved(.up), map: map) >= 5 {
                // Hazard stripes in front of the dock doors.
                for x in 0..<16 { c.fill(px + x, py, px + x, py + 2, ((px + x) / 3) % 2 == 0 ? yellow : black) }
            }
            if kind == .wall, map.tile(at: p.moved(.down)).isWalkable {
                // A loading door (wide buildings) or a dressing-room door with its gold star (the trailers).
                let run = wallRun(p, map: map)
                if run >= 5 {
                    c.fill(px + 1, py + 3, px + 14, py + 15, PixelColor(hex: "#5e6068"))
                    for row in stride(from: py + 4, through: py + 14, by: 2) { c.fill(px + 1, row, px + 14, row, PixelColor(hex: "#4c4e56")) }
                    c.fill(px + 1, py + 2, px + 14, py + 2, yellow)
                } else if run == 3, map.tile(at: p.moved(.left)) == .wall, map.tile(at: p.moved(.right)) == .wall {
                    c.fill(px + 4, py + 4, px + 11, py + 15, PixelColor(hex: "#2a2430"))
                    c.fill(px + 4, py + 4, px + 11, py + 4, gold)
                    for (dx, dy) in [(7, 0), (8, 0), (6, 1), (7, 1), (8, 1), (9, 1), (7, 2), (8, 2), (6, 3), (9, 3)] {
                        c.dot(px + dx, py + 6 + dy, gold)
                    }
                    c.dot(px + 10, py + 10, gold.shaded(0.7))
                }
            }
            if kind == .fence, map.tile(at: p.moved(.right)).isWalkable, p.y == s.y {
                // The gate's sign, on the fence just left of the way in.
                let text = "BACKSTAGE", w = PixelFont.width(text) + 4
                c.fill(px + 15 - w, py + 3, px + 15, py + 11, black)
                c.fill(px + 15 - w, py + 11, px + 15, py + 11, gold)
                PixelFont.draw(text, on: c, x: px + 17 - w, y: py + 5, gold)
            }
        }
    }

    /// Length of the row of walls a wall tile belongs to (0 if it isn't a wall).
    private static func wallRun(_ p: TilePoint, map: WorldMap) -> Int {
        guard map.tile(at: p) == .wall else { return 0 }
        var length = 1, left = p.moved(.left), right = p.moved(.right)
        while map.tile(at: left) == .wall { length += 1; left = left.moved(.left) }
        while map.tile(at: right) == .wall { length += 1; right = right.moved(.right) }
        return length
    }

    /// Two flight cases stacked on a dolly: black, metal corners, a stencilled band.
    private static func flightCases(_ c: PixelCanvas, _ px: Int, _ py: Int) {
        let shell = PixelColor(hex: "#1c1c22"), corner = NightPalette.metal.shaded(1.4)
        c.fill(px + 2, py + 7, px + 13, py + 14, shell)
        c.fill(px + 4, py + 1, px + 12, py + 6, shell.shaded(1.3))
        for (x, y) in [(2, 7), (13, 7), (2, 14), (13, 14), (4, 1), (12, 1), (4, 6), (12, 6)] { c.dot(px + x, py + y, corner) }
        c.fill(px + 3, py + 10, px + 12, py + 10, PixelColor(hex: "#e8e8ec"))
        c.fill(px + 5, py + 3, px + 11, py + 3, PixelColor(hex: "#d8b040"))
        c.fill(px + 2, py + 15, px + 13, py + 15, NightPalette.metal)
    }

    // MARK: Bridges

    /// A footbridge over the water: planks, a handrail on each side, the water showing under its edges.
    private static func bridgeArt(_ s: MapScenery, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let plank = NightPalette.wood.shaded(1.15)
        for p in sceneryPoints(s) where map.tile(at: p).isWalkable {
            let px = p.x * size, py = p.y * size
            c.fill(px, py, px + 15, py + 15, t.water)
            c.fill(px, py, px + 15, py + 15, plank)
            for x in stride(from: 3, to: 16, by: 4) { c.fill(px + x, py, px + x, py + 15, plank.shaded(0.75)) }
            if t.snow { c.fill(px + 1, py + 2, px + 6, py + 3, PixelColor(hex: "#e8eef6")) }
            if p.x == s.x {
                c.fill(px, py, px + 1, py + 15, NightPalette.metal.shaded(1.3))
                c.dot(px, py + 7, NightPalette.lampLight)
            }
            if p.x == s.x + s.w - 1 {
                c.fill(px + 14, py, px + 15, py + 15, NightPalette.metal.shaded(1.3))
                c.dot(px + 15, py + 7, NightPalette.lampLight)
            }
        }
    }
}
