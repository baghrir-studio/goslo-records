import UIKit

/// Night-time city palette.
enum NightPalette {
    static let asphalt = PixelColor(hex: "#2a2a30")
    static let asphaltLight = PixelColor(hex: "#33333a")
    static let asphaltDark = PixelColor(hex: "#232328")
    static let lane = PixelColor(hex: "#c9b458")
    static let crossing = PixelColor(hex: "#cfcfd4")
    static let sidewalk = PixelColor(hex: "#4a4a53")
    static let sidewalkLine = PixelColor(hex: "#3f3f47")
    static let curb = PixelColor(hex: "#5e5e68")
    static let grass = PixelColor(hex: "#1d3622")
    static let grassBlade = PixelColor(hex: "#2e5634")
    static let grassTip = PixelColor(hex: "#4f8a4f")
    static let brick = PixelColor(hex: "#5b3a32")
    static let brickDark = PixelColor(hex: "#4a2e28")
    static let windowLit = PixelColor(hex: "#f2c14e")
    static let windowDark = PixelColor(hex: "#1a1a22")
    static let windowFrame = PixelColor(hex: "#2a2a30")
    static let roof = PixelColor(hex: "#2d2d36")
    static let roofEdge = PixelColor(hex: "#3d3d49")
    static let roofShadow = PixelColor(hex: "#1f1f26")
    static let door = PixelColor(hex: "#141418")
    static let doorFrame = PixelColor(hex: "#8a8a96")
    static let leaf = PixelColor(hex: "#1e4d2b")
    static let leafLight = PixelColor(hex: "#2f6b3a")
    static let trunk = PixelColor(hex: "#4a3020")
    static let ground = PixelColor(hex: "#1a261d")
    static let metal = PixelColor(hex: "#6b6b75")
    static let wood = PixelColor(hex: "#6b4a2e")
    static let lampLight = PixelColor(hex: "#ffd27a")
    static let water = PixelColor(hex: "#1b3a5c")
    static let ripple = PixelColor(hex: "#2b5a85")
}

extension Location {
    /// Neon color above the door, and interior accent.
    var neon: PixelColor {
        switch self {
        case .studio: PixelColor(hex: "#ff4d2e")
        case .media: PixelColor(hex: "#ffd27a")
        case .scene: PixelColor(hex: "#e04fb0")
        case .label: PixelColor(hex: "#4fd6e0")
        case .chezToi: PixelColor(hex: "#7fe0a0")
        case .quartier, .reseaux: PixelColor(hex: "#ffffff")
        }
    }
}

/// Map tiles (16×16) and rendering of the full map.
@MainActor
enum TileArt {
    static let size = 16

    static func mapImage(_ map: WorldMap, city: City, district: District = .bloc) -> UIImage {
        PixelCache.image("map-\(city.rawValue)-\(district.rawValue)-\(map.rows.hashValue)") {
            let cityTheme = CityTheme.forCity(city)
            let theme = cityTheme.adapted(to: district)
            let canvas = PixelCanvas(width: map.width * size, height: map.height * size)
            for y in 0..<map.height {
                for x in 0..<map.width {
                    canvas.stamp(tile(at: TilePoint(x: x, y: y), on: map, theme: theme, district: district), at: x * size, y * size)
                }
            }
            // The district's architecture and street life (BuildingArt.swift, StreetArt.swift), then each place's façade.
            dressBuildings(canvas, map: map, theme: theme, city: cityTheme, district: district)
            dressStreets(canvas, map: map, theme: theme, district: district)
            if district == .dome { dome(on: canvas, map: map) }
            // The district's own corners (map data "scenery"): city stade, market, belvedere, backstage…
            dressScenery(canvas, map: map, theme: theme, district: district)
            for door in map.doors {
                storefront(door.location, at: door.point, on: canvas, map: map, theme: theme, district: district)
            }
            // The harbour's masts belong to Le Bloc's waterfront, not to the fountain downtown.
            if let landmark = theme.landmark, landmark != .harbour || district == .bloc {
                draw(landmark, on: canvas, map: map, theme: theme)
            }
            return canvas.makeImage()
        }
    }

    private static func tile(at p: TilePoint, on map: WorldMap, theme t: CityTheme, district: District) -> PixelCanvas {
        let kind = map.tile(at: p)
        let above = map.tile(at: p.moved(.up)), below = map.tile(at: p.moved(.down))
        var noise = PixelNoise(p.x, p.y)
        let c = PixelCanvas(width: size, height: size)

        switch kind {
        case .asphalt, .crosswalk:
            asphalt(c, &noise)
            if kind == .crosswalk {
                for x in [1, 2, 3, 4, 9, 10, 11, 12] { c.fill(x, 0, x, 15, NightPalette.crossing) }
            } else if below == .asphalt || below == .crosswalk, above != .asphalt, above != .crosswalk, p.x % 2 == 0 {
                c.fill(2, 15, 13, 15, NightPalette.lane)
            }
            if t.snow, noise.chance(30) { c.fill(noise.next(14), 14, noise.next(14) + 2, 15, PixelColor(hex: "#9aa2ae")) }
        case .sidewalk:
            sidewalk(c, &noise, p, t, curb: below == .asphalt || below == .crosswalk)
        case .grass:
            grass(c, &noise, t)
        case .wall:
            facade(c, p, t)
            if noise.chance(70) { window(c, lit: noise.chance(55), t) }
            if t.outdoorStairs, below != .wall, below != .door, p.x % 3 == 0 { stairs(c) }
        case .door:
            facade(c, p, t)
            c.fill(3, 3, 12, 15, NightPalette.doorFrame)
            c.fill(4, 4, 11, 15, NightPalette.door)
            c.fill(7, 4, 8, 15, NightPalette.door.shaded(1.4))
            c.dot(10, 10, NightPalette.doorFrame)
            let location = map.door(at: p)?.location
            let neon = location?.neon ?? NightPalette.lampLight
            if location == .media {
                // goslo radio sign: a tiny sound wave, the logo shrunk to 3 pixels tall.
                for (x, height) in [(2, 1), (4, 2), (6, 3), (9, 3), (11, 2), (13, 1)] {
                    c.fill(x, 2 - height + 1, x, 2, neon)
                }
                c.fill(7, 1, 8, 1, neon.shaded(0.45))
            } else {
                c.fill(3, 1, 12, 1, neon)
                c.fill(2, 2, 13, 2, neon.shaded(0.45))
            }
        case .metro where t.tram:
            // Tram stop: a glass shelter under a red roof, the round red "T" sign on its pole.
            facade(c, p, t)
            let red = PixelColor(hex: "#d42a1e"), glass = PixelColor(hex: "#7fb8c8")
            c.fill(1, 5, 14, 6, red)
            c.fill(2, 7, 13, 15, glass.shaded(0.55))
            c.fill(2, 7, 2, 15, NightPalette.metal); c.fill(13, 7, 13, 15, NightPalette.metal)
            c.fill(4, 12, 11, 13, NightPalette.wood)
            c.fill(7, 0, 8, 4, NightPalette.metal)
            c.circle(cx: 8, cy: 2, radius: 2, red)
            c.fill(7, 1, 9, 1, PixelColor(hex: "#f0eee8")); c.fill(8, 1, 8, 3, PixelColor(hex: "#f0eee8"))
        case .metro where t.city == .paris:
            // Paris: the old green cast-iron entrance, two amber globes on its posts, an amber "M" on green.
            facade(c, p, t)
            let green = PixelColor(hex: "#2f5a3a"), amber = PixelColor(hex: "#f2a83a")
            c.fill(3, 5, 12, 15, NightPalette.door)
            for (row, inset) in [(9, 0), (11, 1), (13, 2), (15, 3)] {
                c.fill(4 + inset, row, 11 - inset, row, NightPalette.metal.shaded(1.2))
            }
            c.fill(1, 3, 2, 15, green); c.fill(13, 3, 14, 15, green)
            c.fill(1, 4, 14, 5, green)
            c.circle(cx: 2, cy: 1, radius: 1, amber); c.circle(cx: 13, cy: 1, radius: 1, amber)
            c.fill(5, 0, 10, 3, green)
            for (x, y0, y1) in [(6, 1, 3), (7, 1, 1), (8, 1, 1), (9, 1, 3)] { c.fill(x, y0, x, y1, amber) }
        case .metro:
            // Metro entrance: steps going down under a blue frame, the big white M above.
            facade(c, p, t)
            let blue = PixelColor(hex: "#1f5ac8")
            c.fill(2, 3, 13, 15, blue)
            c.fill(4, 6, 11, 15, NightPalette.door)
            for (row, inset) in [(9, 0), (11, 1), (13, 2), (15, 3)] {
                c.fill(4 + inset, row, 11 - inset, row, NightPalette.metal.shaded(1.2))
            }
            c.fill(3, 0, 12, 4, PixelColor(hex: "#f0eee8"))
            for (x, y0, y1) in [(5, 1, 3), (6, 1, 1), (7, 2, 2), (8, 2, 2), (9, 1, 1), (10, 1, 3)] {
                c.fill(x, y0, x, y1, blue)
            }
        case .roof:
            roof(c, &noise, t, above: above, below: below)
            if noise.chance(25) { c.fill(4, 5, 10, 10, NightPalette.metal); c.fill(5, 6, 9, 9, NightPalette.metal.shaded(0.7)) }
            if noise.chance(t.pavement == .zellige ? 35 : 15) {
                // Satellite dish.
                c.circle(cx: 11, cy: 5, radius: 3, NightPalette.metal.shaded(1.3))
                c.circle(cx: 11, cy: 5, radius: 1, NightPalette.metal.shaded(0.8))
                c.fill(11, 8, 11, 11, NightPalette.metal)
                c.fill(9, 11, 13, 11, NightPalette.metal.shaded(0.8))
            }
        case .tree:
            treeTile(c, t)
        case .fence:
            grass(c, &noise, t)
            for x in stride(from: 1, to: 16, by: 4) { c.fill(x, 2, x + 1, 15, NightPalette.metal) }
            c.fill(0, 4, 15, 5, NightPalette.metal.shaded(1.15))
            c.fill(0, 10, 15, 11, NightPalette.metal.shaded(1.15))
        case .bench:
            sidewalk(c, &noise, p, t, curb: false)
            c.fill(1, 4, 14, 6, NightPalette.wood)
            c.fill(1, 8, 14, 10, NightPalette.wood.shaded(1.2))
            c.fill(2, 11, 3, 14, NightPalette.metal)
            c.fill(12, 11, 13, 14, NightPalette.metal)
        case .lamp:
            sidewalk(c, &noise, p, t, curb: false)
            switch district {
            case .centre:
                // A cast-iron lantern on a fluted post.
                let iron = PixelColor(hex: "#1e1e24")
                c.fill(7, 5, 8, 15, iron)
                c.fill(6, 13, 9, 15, iron); c.fill(5, 15, 10, 15, iron)
                c.fill(5, 1, 10, 5, iron)
                c.fill(6, 2, 9, 4, NightPalette.lampLight)
                c.fill(7, 0, 8, 0, iron); c.dot(6, 6, iron); c.dot(9, 6, iron)
            case .hauts:
                // A slim modern post with a cold LED arm.
                c.fill(7, 3, 7, 15, NightPalette.metal.shaded(1.3))
                c.fill(7, 2, 11, 2, NightPalette.metal.shaded(1.3))
                c.fill(9, 3, 11, 3, PixelColor(hex: "#cfe8ff"))
                c.fill(6, 15, 8, 15, NightPalette.metal)
            case .bloc, .dome:
                c.fill(7, 4, 8, 15, NightPalette.metal)
                c.fill(5, 1, 10, 3, NightPalette.metal.shaded(0.8))
                c.fill(6, 3, 9, 4, NightPalette.lampLight)
            }
        case .water:
            c.fill(0, 0, 15, 15, t.water)
            for _ in 0..<3 {
                let x = noise.next(12), y = noise.next(15)
                c.fill(x, y, x + 3, y, t.ripple)
            }
            // Downtown's water is a fountain basin: no quay, no boats.
            if t.landmark == .harbour, district == .bloc {
                // Quay bollards and moorings along the edge.
                if above != .water { c.fill(0, 0, 15, 2, PixelColor(hex: "#8a8070")); c.fill(3, 1, 4, 3, PixelColor(hex: "#3a3630")) }
            }
            if t.boats, district != .centre, p.x % (t.landmark == .harbour ? 2 : 7) == (t.landmark == .harbour ? 1 : 3) {
                // A small boat, hull and mast.
                c.fill(3, 9, 12, 11, PixelColor(hex: "#e8e4dc")); c.fill(4, 12, 11, 12, PixelColor(hex: "#b8b2a8"))
                c.fill(7, 3, 7, 8, NightPalette.wood); c.fill(8, 4, 10, 7, PixelColor(hex: "#d8d4cc"))
            }
            if above != .water { c.fill(0, 0, 15, 1, NightPalette.curb) }
        }
        return c
    }

    /// Le Dôme: a huge silver dome over the arena's roof, ribs, and a ring of lights at its base.
    private static func dome(on c: PixelCanvas, map: WorldMap) {
        // The arena is the building with the stage door (the biggest one if there is none).
        let all = buildings(of: map)
        let arena = all.first { $0.door?.location == .scene } ?? all.max { $0.tiles.count < $1.tiles.count }
        let top = (arena?.tiles ?? []).filter { map.tile(at: $0) == .roof }
        guard let minX = top.map(\.x).min(), let maxX = top.map(\.x).max(), let minY = top.map(\.y).min(),
              let maxY = top.map(\.y).max() else { return }
        let left = minX * size, right = (maxX + 1) * size - 1
        let base = (maxY + 1) * size - 1, height = (maxY - minY + 1) * size + 6
        let cx = Double(left + right) / 2, rx = Double(right - left) / 2, ry = Double(height)
        let light = PixelColor(hex: "#d8dce4"), mid = PixelColor(hex: "#a8aeba"), shadow = PixelColor(hex: "#7a808c")
        for py in (base - height)...base {
            for px in left...right {
                let dx = (Double(px) - cx) / rx, dy = Double(base - py) / ry
                guard dx * dx + dy * dy <= 1 else { continue }
                // Lit from the upper left; ribs follow the curve.
                var color = dx < -0.2 ? light : (dx < 0.45 ? mid : shadow)
                let rib = Int((asin(max(-1, min(1, dx))) * 6).rounded(.down))
                let nextRib = Int((asin(max(-1, min(1, dx + 1 / rx))) * 6).rounded(.down))
                if rib != nextRib { color = color.shaded(0.75) }
                if dx * dx + dy * dy > 0.93 { color = PixelColor(hex: "#5a606c") }
                c.dot(px, py, color)
            }
        }
        // A ring of lights at the base, and a beacon on top.
        for px in stride(from: left + 4, through: right - 4, by: 6) {
            c.dot(px, base - 3, NightPalette.lampLight)
            c.dot(px, base - 2, NightPalette.lampLight.shaded(0.6))
        }
        let peak = base - height
        c.fill(Int(cx) - 1, peak - 6, Int(cx), peak, NightPalette.metal)
        c.fill(Int(cx) - 1, peak - 8, Int(cx), peak - 7, PixelColor(hex: "#ff2a1a"))
    }

    // MARK: Landmarks

    /// Drawn once over the finished map, above the rooftops (never over a door or a walkable tile).
    private static func draw(_ landmark: CityTheme.Landmark, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        switch landmark {
        case .harbour:
            // Masts above the boats, a few with a furled sail: the old harbour at night.
            guard let row = map.rows.firstIndex(where: { $0.contains("W") }) else { return }
            let y = row * size
            for x in stride(from: 1 * size + 7, to: (map.width - 1) * size, by: 2 * size)
            where map.tile(at: TilePoint(x: x / size, y: row)) == .water {
                c.fill(x, y - 10, x, y + 8, PixelColor(hex: "#c8c0b0"))
                if (x / size) % 3 == 1 { c.fill(x + 1, y - 8, x + 4, y - 2, PixelColor(hex: "#e8e4dc")) }
                c.dot(x, y - 11, NightPalette.lampLight)
            }
        case .ironTower, .minaret:
            break  // On the horizon (see `skyline`).
        }
    }

    // MARK: Horizon

    /// Height of the sky band above the map, in tiles.
    static let skyRows = 6

    /// The night sky above the neighbourhood: stars, distant rooftops, and the city's landmark on the horizon.
    static func skyline(city: City, width: Int) -> UIImage {
        PixelCache.image("sky-\(city.rawValue)-\(width)") {
            let theme = CityTheme.forCity(city)
            let w = width * size, h = skyRows * size
            let c = PixelCanvas(width: w, height: h)
            var noise = PixelNoise(w, h, salt: city.rawValue.count)
            // Sky, darker at the top.
            for y in 0..<h {
                let t = Double(y) / Double(h)
                c.fill(0, y, w - 1, y, PixelColor(r: UInt8(10 + 16 * t), g: UInt8(12 + 18 * t), b: UInt8(26 + 30 * t)))
            }
            for _ in 0..<(w / 9) {
                c.dot(noise.next(w), noise.next(h * 2 / 3), PixelColor(hex: noise.chance(25) ? "#f2e6b0" : "#8a90a8"))
            }
            c.circle(cx: w / 6, cy: 14, radius: 5, PixelColor(hex: "#e8e2c8"))
            c.circle(cx: w / 6 + 2, cy: 12, radius: 4, PixelColor(r: 14, g: 17, b: 33))
            // The landmark stands behind the distant rooftops.
            switch theme.landmark {
            case .ironTower?: ironTower(c, cx: w * 3 / 4, base: h - 6)
            case .minaret?: minaret(c, cx: w / 3, base: h - 6)
            default: break
            }
            // Distant rooftops, in silhouette, a few windows still lit.
            let far = PixelColor(hex: "#14161f"), near = PixelColor(hex: "#1b1e29")
            var x = 0
            while x < w {
                let bw = 10 + noise.next(22), bh = 8 + noise.next(theme.snow ? 10 : 16)
                c.fill(x, h - bh - 6, x + bw, h - 1, noise.chance(50) ? far : near)
                if theme.snow { c.fill(x, h - bh - 6, x + bw, h - bh - 5, PixelColor(hex: "#c8d0dc")) }
                for _ in 0..<(bw / 6) where noise.chance(40) {
                    c.dot(x + 2 + noise.next(max(1, bw - 3)), h - bh + noise.next(max(1, bh - 2)), NightPalette.windowLit.shaded(0.8))
                }
                x += bw + 1
            }
            return c.makeImage()
        }
    }

    /// A lattice iron tower, about 80 px tall: dark iron, three platforms. No light show.
    private static func ironTower(_ c: PixelCanvas, cx: Int, base: Int) {
        let top = 4
        let iron = PixelColor(hex: "#262634"), edge = PixelColor(hex: "#6e6e86"), sky = PixelColor(hex: "#1a1e36")
        func half(_ y: Int) -> Int {
            let progress = Double(y - top) / Double(base - top)
            return Int(1.5 + pow(progress, 2.3) * 26)
        }
        for y in top...base {
            let h = half(y)
            c.fill(cx - h, y, cx + h, y, iron)
            c.dot(cx - h, y, edge); c.dot(cx + h, y, edge)
            if h > 4, y % 4 == 2 { for x in stride(from: cx - h + 2, to: cx + h - 1, by: 3) { c.dot(x, y, sky) } }
        }
        for y in (base - 14)...base {
            let h = half(y), opening = max(0, h - 8) * (y - base + 15) / 15
            if opening > 0 { c.fill(cx - opening, y, cx + opening, y, sky) }
        }
        for y in [top + 24, top + 46] { let h = half(y) + 3; c.fill(cx - h, y, cx + h, y + 1, edge) }
        c.fill(cx, 0, cx, top, edge)
    }

    /// A generic Moroccan-style minaret, about 80 px tall: square shaft, tile bands, a lantern and a small dome.
    private static func minaret(_ c: PixelCanvas, cx: Int, base: Int) {
        let top = 6
        let wall = PixelColor(hex: "#cfc6b4"), shade = PixelColor(hex: "#a39a88"), green = PixelColor(hex: "#1f7a6a")
        c.fill(cx - 9, top + 18, cx + 9, base, wall)
        c.fill(cx + 6, top + 18, cx + 9, base, shade)
        for y in stride(from: top + 26, to: base - 6, by: 12) {
            for x in [cx - 6, cx - 1, cx + 4] { c.fill(x, y, x + 2, y + 6, green) }
        }
        c.fill(cx - 10, top + 15, cx + 10, top + 17, green)
        c.fill(cx - 5, top + 6, cx + 5, top + 14, wall); c.fill(cx + 3, top + 6, cx + 5, top + 14, shade)
        c.fill(cx - 3, top + 8, cx + 1, top + 12, NightPalette.lampLight)
        c.fill(cx - 6, top + 4, cx + 6, top + 5, green)
        c.circle(cx: cx, cy: top + 2, radius: 2, green)
        c.fill(cx, 0, cx, top, PixelColor(hex: "#c8b070"))
    }

    /// The bare roof: the city's covering, a lit top edge, a shadow along the bottom, snow.
    static func roof(_ c: PixelCanvas, _ noise: inout PixelNoise, _ t: CityTheme, above: TileKind, below: TileKind) {
        c.fill(0, 0, 15, 15, t.roof)
        if t.facade == .plaster && !t.snow {
            // Tiles: a row of scallops every 4 pixels.
            for y in stride(from: 3, to: 16, by: 4) {
                for x in stride(from: (y / 4) % 2 * 2, to: 16, by: 4) { c.fill(x, y, x + 2, y, t.roofShadow) }
            }
        }
        if above != .roof { c.fill(0, 0, 15, 1, t.snow ? PixelColor(hex: "#e8eef6") : t.roofEdge) }
        if below != .roof { c.fill(0, 14, 15, 15, t.roofShadow) }
        if t.snow {
            for _ in 0..<5 { let x = noise.next(13); c.fill(x, noise.next(13), x + 2, noise.next(13) / 6 + 2, PixelColor(hex: "#dfe6f0")) }
        }
    }

    static func asphalt(_ c: PixelCanvas, _ noise: inout PixelNoise) {
        c.fill(0, 0, 15, 15, NightPalette.asphalt)
        for _ in 0..<10 {
            c.dot(noise.next(16), noise.next(16), noise.chance(50) ? NightPalette.asphaltLight : NightPalette.asphaltDark)
        }
    }

    static func sidewalk(_ c: PixelCanvas, _ noise: inout PixelNoise, _ p: TilePoint, _ t: CityTheme, curb: Bool) {
        c.fill(0, 0, 15, 15, t.sidewalk)
        switch t.pavement {
        case .slabs:
            c.fill(0, 7, 15, 7, t.sidewalkLine)
            c.fill(7, 0, 7, 15, t.sidewalkLine)
        case .cobbles:
            for y in stride(from: 3, to: 16, by: 4) {
                c.fill(0, y, 15, y, t.sidewalkLine)
                for x in stride(from: (y / 4) % 2 * 2 + 1, to: 16, by: 4) { c.fill(x, y - 3, x, y - 1, t.sidewalkLine) }
            }
        case .zellige:
            // Little star tiles every other slab.
            c.fill(0, 7, 15, 7, t.sidewalkLine)
            c.fill(7, 0, 7, 15, t.sidewalkLine)
            for (cx, cy) in [(3, 3), (11, 11)] where (p.x + p.y) % 2 == 0 {
                c.fill(cx - 1, cy, cx + 1, cy, t.accent); c.fill(cx, cy - 1, cx, cy + 1, t.accent)
                c.dot(cx, cy, PixelColor(hex: "#e8d8a0"))
            }
        }
        for _ in 0..<4 { c.dot(noise.next(16), noise.next(16), t.sidewalk.shaded(1.12)) }
        if t.snow, noise.chance(40) { c.fill(0, 0, 15, 1, PixelColor(hex: "#cfd6e0")) }
        if curb { c.fill(0, 14, 15, 15, NightPalette.curb) }
    }

    static func grass(_ c: PixelCanvas, _ noise: inout PixelNoise, _ t: CityTheme) {
        c.fill(0, 0, 15, 15, t.grass)
        for _ in 0..<7 {
            let x = noise.next(15), y = 3 + noise.next(12)
            c.fill(x, y - 3, x, y, t.grassBlade)
            c.dot(x, y - 3, t.grassTip)
            if x < 15 { c.fill(x + 1, y - 2, x + 1, y, t.grassBlade) }
        }
    }

    static func facade(_ c: PixelCanvas, _ p: TilePoint, _ t: CityTheme) {
        c.fill(0, 0, 15, 15, t.wall)
        switch t.facade {
        case .bricks:
            for row in stride(from: 3, to: 16, by: 4) {
                c.fill(0, row, 15, row, t.wallLine)
                let offset = (row / 4 + p.x) % 2 == 0 ? 3 : 11
                c.fill(offset, row - 3, offset, row - 1, t.wallLine)
            }
        case .stone:
            // Large cut-stone blocks.
            for row in stride(from: 7, to: 16, by: 8) { c.fill(0, row, 15, row, t.wallLine) }
            c.fill(p.x % 2 == 0 ? 7 : 15, 0, p.x % 2 == 0 ? 7 : 15, 6, t.wallLine)
            c.fill(p.x % 2 == 0 ? 15 : 7, 8, p.x % 2 == 0 ? 15 : 7, 14, t.wallLine)
        case .plaster:
            // Smooth render with a few cracks.
            c.dot(2 + p.x % 5, 13, t.wallLine); c.dot(3 + p.x % 5, 14, t.wallLine)
            c.fill(0, 15, 15, 15, t.wallLine)
        }
    }

    static func window(_ c: PixelCanvas, lit: Bool, _ t: CityTheme) {
        c.fill(4, 3, 11, 11, NightPalette.windowFrame)
        c.fill(5, 4, 10, 10, lit ? NightPalette.windowLit : NightPalette.windowDark)
        c.fill(7, 4, 8, 10, NightPalette.windowFrame)
        if lit { c.dot(5, 4, NightPalette.windowLit.shaded(1.15)) }
        if t.arches {
            // A rounded, horseshoe-like top.
            for (x, y) in [(4, 3), (5, 3), (10, 3), (11, 3), (4, 4), (11, 4)] { c.dot(x, y, t.wall) }
            c.dot(5, 4, NightPalette.windowFrame); c.dot(10, 4, NightPalette.windowFrame)
        }
        if let shutters = t.shutters {
            c.fill(2, 3, 3, 11, shutters); c.fill(12, 3, 13, 11, shutters)
        }
        if t.snow { c.fill(4, 11, 11, 11, PixelColor(hex: "#e8eef6")) }
    }

    /// Montréal's outdoor iron staircase, climbing diagonally across the façade.
    static func stairs(_ c: PixelCanvas) {
        let iron = PixelColor(hex: "#1a1a1e")
        for step in 0..<5 { c.fill(1 + step * 3, 13 - step * 3, 3 + step * 3, 13 - step * 3, iron) }
        c.fill(0, 14, 15, 14, iron)
    }

    static func treeTile(_ c: PixelCanvas, _ t: CityTheme) {
        c.fill(0, 0, 15, 15, t.ground)
        switch t.tree {
        case .round:
            c.fill(7, 11, 8, 15, NightPalette.trunk)
            c.circle(cx: 8, cy: 7, radius: 7, t.leaf)
            c.circle(cx: 6, cy: 5, radius: 3, t.leafLight)
            c.dot(10, 9, t.leafLight)
            c.dot(4, 9, t.leaf.shaded(0.7))
        case .plane:
            // Plane tree: mottled trunk, wide flat crown.
            c.fill(7, 10, 8, 15, PixelColor(hex: "#8a8270")); c.dot(7, 12, PixelColor(hex: "#5a5448"))
            c.circle(cx: 8, cy: 6, radius: 6, t.leaf)
            c.fill(1, 6, 14, 8, t.leaf)
            c.circle(cx: 5, cy: 4, radius: 2, t.leafLight); c.circle(cx: 11, cy: 5, radius: 2, t.leafLight)
        case .palm:
            c.fill(7, 6, 8, 15, PixelColor(hex: "#7a5a34"))
            for y in stride(from: 8, to: 15, by: 3) { c.fill(7, y, 8, y, PixelColor(hex: "#5a4024")) }
            for (dx, dy) in [(-6, 2), (-4, -1), (0, -3), (4, -1), (6, 2)] {
                c.fill(min(8, 8 + dx), 5 + min(0, dy), max(8, 8 + dx), 5 + min(0, dy), t.leaf)
                c.dot(8 + dx, 5 + dy, t.leafLight)
            }
            c.fill(1, 5, 14, 5, t.leaf); c.fill(3, 4, 12, 4, t.leafLight)
            c.circle(cx: 8, cy: 6, radius: 1, PixelColor(hex: "#5a3a1a"))
        case .pine:
            c.fill(7, 12, 8, 15, NightPalette.trunk)
            for (row, half) in [(2, 1), (4, 2), (6, 3), (8, 5), (10, 6)] {
                c.fill(8 - half, row, 7 + half, row + 1, t.leaf)
            }
            c.fill(6, 4, 7, 5, t.leafLight); c.fill(4, 8, 6, 9, t.leafLight)
            if t.snow { c.fill(7, 2, 8, 2, PixelColor(hex: "#f2f5fa")); c.fill(5, 6, 10, 6, PixelColor(hex: "#f2f5fa")) }
        }
    }

    // MARK: Interiors

    static let interiorSize = (width: 10, height: 8)

    /// A room for each location: floor, back wall, props.
    static func interior(_ location: Location) -> UIImage {
        PixelCache.image("interior-\(location.rawValue)") {
            let w = interiorSize.width * size, h = interiorSize.height * size
            let c = PixelCanvas(width: w, height: h)
            var noise = PixelNoise(location.rawValue.count, 7)
            let neon = location.neon

            // Floor.
            for ty in 0..<interiorSize.height {
                for tx in 0..<interiorSize.width {
                    let x0 = tx * size, y0 = ty * size
                    switch location {
                    case .label:
                        let light = (tx + ty) % 2 == 0
                        c.fill(x0, y0, x0 + 15, y0 + 15, PixelColor(hex: light ? "#d8d8dc" : "#b8b8c0"))
                    case .scene:
                        c.fill(x0, y0, x0 + 15, y0 + 15, NightPalette.wood.shaded(0.8))
                        c.fill(x0, y0 + 7, x0 + 15, y0 + 7, NightPalette.wood.shaded(0.6))
                    case .chezToi:
                        c.fill(x0, y0, x0 + 15, y0 + 15, NightPalette.wood)
                        c.fill(x0 + 7, y0, x0 + 7, y0 + 15, NightPalette.wood.shaded(0.75))
                    case .media:
                        c.fill(x0, y0, x0 + 15, y0 + 15, PixelColor(hex: "#1f2a44"))
                        c.dot(x0 + noise.next(16), y0 + noise.next(16), PixelColor(hex: "#26345a"))
                    default:
                        c.fill(x0, y0, x0 + 15, y0 + 15, PixelColor(hex: "#1c1c22"))
                        c.dot(x0 + noise.next(16), y0 + noise.next(16), PixelColor(hex: "#24242c"))
                    }
                }
            }

            // Back wall (2 tiles tall) + neon strip.
            let wall: PixelColor = switch location {
            case .label: PixelColor(hex: "#3e7a8c")
            case .scene: PixelColor(hex: "#5a0f1e")
            case .chezToi: PixelColor(hex: "#3a3346")
            case .media: PixelColor(hex: "#14141c")
            default: PixelColor(hex: "#16161c")
            }
            c.fill(0, 0, w - 1, 2 * size - 1, wall)
            c.fill(0, 2 * size - 2, w - 1, 2 * size - 1, wall.shaded(0.6))
            c.fill(0, 2, w - 1, 2, neon)

            switch location {
            case .studio:
                // Acoustic foam, mixing desk, speakers, mic.
                for x in stride(from: 4, to: w - 4, by: 8) {
                    for y in stride(from: 6, to: 26, by: 8) { c.fill(x, y, x + 5, y + 5, PixelColor(hex: "#22222a")) }
                }
                c.fill(40, 40, 119, 55, PixelColor(hex: "#2a2a30"))
                for x in stride(from: 44, to: 116, by: 6) {
                    c.fill(x, 43, x + 1, 50, NightPalette.metal)
                    c.dot(x, 44 + noise.next(6), neon)
                }
                c.fill(22, 30, 33, 55, PixelColor(hex: "#101014")); c.circle(cx: 27, cy: 44, radius: 4, NightPalette.metal)
                c.fill(126, 30, 137, 55, PixelColor(hex: "#101014")); c.circle(cx: 131, cy: 44, radius: 4, NightPalette.metal)
                c.fill(79, 70, 80, 100, NightPalette.metal); c.fill(76, 64, 83, 70, PixelColor(hex: "#3a3a44"))
            case .label:
                // Laundromat machines.
                for i in 0..<5 {
                    let x = 8 + i * 30
                    c.fill(x, 10, x + 21, 34, PixelColor(hex: "#ececf0"))
                    c.fill(x, 10, x + 21, 13, PixelColor(hex: "#c8c8d0"))
                    c.circle(cx: x + 11, cy: 24, radius: 7, PixelColor(hex: "#9aa3b0"))
                    c.circle(cx: x + 11, cy: 24, radius: 5, PixelColor(hex: "#4f7fa0"))
                    c.dot(x + 18, 11, neon)
                }
                c.fill(30, 60, 129, 70, PixelColor(hex: "#8a6a4a")); c.fill(30, 70, 129, 72, PixelColor(hex: "#6b4a2e"))
            case .media:
                // ON AIR, desk, microphones.
                c.fill(62, 8, 97, 20, PixelColor(hex: "#3a0c0c")); c.fill(64, 10, 95, 18, neon.shaded(0.3))
                c.fill(66, 12, 93, 16, PixelColor(hex: "#ff4d2e"))
                c.fill(30, 48, 129, 60, PixelColor(hex: "#3a3a44"))
                for x in [56, 102] { c.fill(x, 38, x + 1, 48, NightPalette.metal); c.fill(x - 2, 34, x + 3, 38, PixelColor(hex: "#22222a")) }
            case .scene:
                // Curtains, spotlights, stage edge.
                for x in stride(from: 0, to: w, by: 6) { c.fill(x, 0, x + 2, 30, PixelColor(hex: "#8a1a2e")) }
                for x in [20, 80, 140] { c.circle(cx: x, cy: 6, radius: 4, NightPalette.lampLight) }
                c.fill(0, 96, w - 1, 99, NightPalette.wood.shaded(1.3))
                c.fill(70, 60, 71, 90, NightPalette.metal); c.fill(67, 56, 74, 60, PixelColor(hex: "#3a3a44"))
            case .chezToi:
                // Bed, poster, desk.
                c.fill(10, 34, 49, 70, PixelColor(hex: "#e8e8ec")); c.fill(10, 34, 49, 44, PixelColor(hex: "#ff4d2e").shaded(0.7))
                c.fill(64, 6, 85, 26, PixelColor(hex: "#101014")); c.fill(66, 8, 83, 24, neon.shaded(0.5))
                c.fill(110, 40, 149, 52, NightPalette.wood.shaded(0.7)); c.fill(122, 30, 137, 40, PixelColor(hex: "#22222a"))
                c.fill(124, 32, 135, 38, PixelColor(hex: "#3fa0e0"))
            case .quartier, .reseaux:
                break
            }
            return c.makeImage()
        }
    }
}
