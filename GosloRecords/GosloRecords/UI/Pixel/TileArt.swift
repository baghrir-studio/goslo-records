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

    static func mapImage(_ map: WorldMap, city: City) -> UIImage {
        PixelCache.image("map-\(city.rawValue)-\(map.rows.hashValue)") {
            let theme = CityTheme.forCity(city)
            let canvas = PixelCanvas(width: map.width * size, height: map.height * size)
            for y in 0..<map.height {
                for x in 0..<map.width {
                    canvas.stamp(tile(at: TilePoint(x: x, y: y), on: map, theme: theme), at: x * size, y * size)
                }
            }
            return canvas.makeImage()
        }
    }

    private static func tile(at p: TilePoint, on map: WorldMap, theme t: CityTheme) -> PixelCanvas {
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
        case .roof:
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
            c.fill(7, 4, 8, 15, NightPalette.metal)
            c.fill(5, 1, 10, 3, NightPalette.metal.shaded(0.8))
            c.fill(6, 3, 9, 4, NightPalette.lampLight)
        case .water:
            c.fill(0, 0, 15, 15, t.water)
            for _ in 0..<3 {
                let x = noise.next(12), y = noise.next(15)
                c.fill(x, y, x + 3, y, t.ripple)
            }
            if t.boats, p.x % 7 == 3 {
                // A small boat, hull and mast.
                c.fill(3, 9, 12, 11, PixelColor(hex: "#e8e4dc")); c.fill(4, 12, 11, 12, PixelColor(hex: "#b8b2a8"))
                c.fill(7, 3, 7, 8, NightPalette.wood); c.fill(8, 4, 10, 7, PixelColor(hex: "#d8d4cc"))
            }
            if above != .water { c.fill(0, 0, 15, 1, NightPalette.curb) }
        }
        return c
    }

    private static func asphalt(_ c: PixelCanvas, _ noise: inout PixelNoise) {
        c.fill(0, 0, 15, 15, NightPalette.asphalt)
        for _ in 0..<10 {
            c.dot(noise.next(16), noise.next(16), noise.chance(50) ? NightPalette.asphaltLight : NightPalette.asphaltDark)
        }
    }

    private static func sidewalk(_ c: PixelCanvas, _ noise: inout PixelNoise, _ p: TilePoint, _ t: CityTheme, curb: Bool) {
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

    private static func grass(_ c: PixelCanvas, _ noise: inout PixelNoise, _ t: CityTheme) {
        c.fill(0, 0, 15, 15, t.grass)
        for _ in 0..<7 {
            let x = noise.next(15), y = 3 + noise.next(12)
            c.fill(x, y - 3, x, y, t.grassBlade)
            c.dot(x, y - 3, t.grassTip)
            if x < 15 { c.fill(x + 1, y - 2, x + 1, y, t.grassBlade) }
        }
    }

    private static func facade(_ c: PixelCanvas, _ p: TilePoint, _ t: CityTheme) {
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

    private static func window(_ c: PixelCanvas, lit: Bool, _ t: CityTheme) {
        c.fill(4, 3, 11, 11, NightPalette.windowFrame)
        c.fill(5, 4, 10, 10, lit ? NightPalette.windowLit : NightPalette.windowDark)
        c.fill(7, 4, 8, 10, NightPalette.windowFrame)
        if lit { c.dot(5, 4, NightPalette.windowLit.shaded(1.15)) }
        if let shutters = t.shutters {
            c.fill(2, 3, 3, 11, shutters); c.fill(12, 3, 13, 11, shutters)
        }
        if t.snow { c.fill(4, 11, 11, 11, PixelColor(hex: "#e8eef6")) }
    }

    /// Montréal's outdoor iron staircase, climbing diagonally across the façade.
    private static func stairs(_ c: PixelCanvas) {
        let iron = PixelColor(hex: "#1a1a1e")
        for step in 0..<5 { c.fill(1 + step * 3, 13 - step * 3, 3 + step * 3, 13 - step * 3, iron) }
        c.fill(0, 14, 15, 14, iron)
    }

    private static func treeTile(_ c: PixelCanvas, _ t: CityTheme) {
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
