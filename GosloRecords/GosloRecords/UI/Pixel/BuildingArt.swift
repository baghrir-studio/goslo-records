import UIKit

// Buildings with a character. Each district has its own architecture (the cité's balconies and tagged
// shutters in Le Bloc, shops and iron balconies downtown, glass offices and villas in Les Hauts), and each
// place its own façade around its door. Painted once into the cached map image, over the plain tiles:
// which tiles you can walk on never changes.

@MainActor
extension TileArt {
    /// Building tiles (walls, roofs, doors, metro) touching each other.
    struct Building {
        var tiles: Set<TilePoint> = []
        var door: MapDoor?
        var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min

        var width: Int { maxX - minX + 1 }

        /// A wall with no building tile below it: the ground floor, facing the street.
        func isFront(_ p: TilePoint) -> Bool { !tiles.contains(p.moved(.down)) }
    }

    enum BuildingStyle {
        /// Le Bloc's housing: balconies, dishes, tagged shutters, bins and scooters.
        case cite
        /// Fred's studio: raw concrete and slit windows.
        case bunker
        /// goslo radio: dark panels, a band of studio windows.
        case radio
        /// Downtown: cornices, tall windows, iron balconies, shops on the ground floor.
        case townhouse
        /// Les Hauts' offices: glass curtain walls, solar panels, a helipad.
        case glass
        /// Les Hauts' villas: pale stone, bay windows, hedges, a pool on the roof.
        case villa
    }

    static func buildings(of map: WorldMap) -> [Building] {
        let solid: Set<TileKind> = [.wall, .roof, .door, .metro]
        var seen = Set<TilePoint>(), result: [Building] = []
        for y in 0..<map.height {
            for x in 0..<map.width {
                let start = TilePoint(x: x, y: y)
                guard solid.contains(map.tile(at: start)), !seen.contains(start) else { continue }
                var building = Building(), stack = [start]
                seen.insert(start)
                while let p = stack.popLast() {
                    building.tiles.insert(p)
                    building.minX = min(building.minX, p.x); building.maxX = max(building.maxX, p.x)
                    building.minY = min(building.minY, p.y); building.maxY = max(building.maxY, p.y)
                    if let door = map.door(at: p) { building.door = door }
                    for direction in Direction.allCases {
                        let next = p.moved(direction)
                        if solid.contains(map.tile(at: next)), !seen.contains(next) { seen.insert(next); stack.append(next) }
                    }
                }
                result.append(building)
            }
        }
        return result
    }

    private static func style(of building: Building, in district: District) -> BuildingStyle? {
        switch district {
        case .bloc:
            if building.door?.location == .studio { return .bunker }
            if building.door?.location == .media { return .radio }
            return .cite
        case .centre: return .townhouse
        case .hauts: return building.width >= 8 ? .glass : .villa
        case .dome: return nil
        }
    }

    /// Les Hauts' villas wear the city's own stone and roofs, lighter.
    private static func villaTheme(_ city: CityTheme) -> CityTheme {
        var v = city
        v.wall = city.wall.shaded(1.3)
        v.wallLine = city.wallLine.shaded(1.3)
        v.outdoorStairs = false
        return v
    }

    static func dressBuildings(_ c: PixelCanvas, map: WorldMap, theme t: CityTheme, city: CityTheme, district: District) {
        let villa = villaTheme(city)
        var shopIndex = 0
        for building in buildings(of: map) {
            guard let style = style(of: building, in: district) else { continue }
            let look = style == .villa ? villa : t
            for p in building.tiles.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
                let kind = map.tile(at: p)
                guard kind == .wall || kind == .roof else { continue }
                var noise = PixelNoise(p.x, p.y, salt: 11)
                let tile = PixelCanvas(width: size, height: size)
                if kind == .roof {
                    roofTile(tile, p, style, &noise, look, above: map.tile(at: p.moved(.up)), below: map.tile(at: p.moved(.down)))
                } else {
                    wallTile(tile, p, style, &noise, look, front: building.isFront(p))
                }
                c.stamp(tile, at: p.x * size, p.y * size)
            }
            switch style {
            case .townhouse: shops(building, on: c, map: map, theme: t, index: &shopIndex)
            case .glass where building.door == nil: helipad(building, on: c, map: map)
            case .villa: pool(building, on: c, map: map, theme: villa)
            case .cite where building.door == nil && building.width >= 6: mural(building, on: c, map: map)
            default: break
            }
        }
    }

    // MARK: Walls

    private static func wallTile(_ c: PixelCanvas, _ p: TilePoint, _ style: BuildingStyle, _ noise: inout PixelNoise,
                                 _ t: CityTheme, front: Bool) {
        switch style {
        case .cite:
            facade(c, p, t)
            c.fill(0, 0, 15, 0, t.wall.shaded(1.2))
            if front {
                citeGroundFloor(c, p, &noise, t)
            } else {
                window(c, lit: noise.chance(55), t)
                balcony(c, &noise, t)
            }
        case .bunker:
            // Raw concrete: formwork joints, tie holes, rain streaks.
            let concrete = PixelColor(hex: "#5c5e62")
            c.fill(0, 0, 15, 15, concrete)
            for y in [3, 7, 11] { c.fill(0, y, 15, y, concrete.shaded(0.85)) }
            for (x, y) in [(3, 1), (11, 5), (5, 9), (13, 13)] { c.dot(x, y, concrete.shaded(0.6)) }
            c.fill(0, 15, 15, 15, concrete.shaded(0.7))
            if front {
                for x in [2 + noise.next(4), 9 + noise.next(5)] { c.fill(x, 12, x, 14, concrete.shaded(0.8)) }
            } else {
                // A slit window, the studio's red light inside.
                c.fill(3, 5, 12, 8, PixelColor(hex: "#141418"))
                if noise.chance(60) { c.fill(4, 6, 11, 7, Location.studio.neon.shaded(0.45)) }
                c.fill(3, 9, 12, 9, concrete.shaded(1.2))
            }
        case .radio:
            // Dark panels with seams, a band of studio windows upstairs.
            let panel = PixelColor(hex: "#262a3c")
            c.fill(0, 0, 15, 15, panel)
            c.fill(0, 0, 15, 0, panel.shaded(1.5))
            for x in [0, 8] { c.fill(x, 1, x, 15, panel.shaded(0.75)) }
            if front {
                // goslo radio's gold sound wave, small, on each panel.
                for (i, h) in [1, 3, 2, 4, 2, 3, 1].enumerated() { c.fill(3 + i * 2, 9 - h, 3 + i * 2, 9, Location.media.neon.shaded(0.7)) }
            } else {
                c.fill(1, 2, 14, 9, PixelColor(hex: "#101420"))
                for x in stride(from: 2, to: 14, by: 4) where noise.chance(65) {
                    c.fill(x, 3, x + 2, 8, noise.chance(50) ? PixelColor(hex: "#3a5a8a") : NightPalette.windowLit.shaded(0.85))
                }
            }
        case .townhouse:
            facade(c, p, t)
            if front {
                // A stone plinth: the shops are painted over it, building by building.
                c.fill(0, 0, 15, 15, t.wall.shaded(0.85))
                c.fill(0, 0, 15, 0, t.wallLine)
                c.fill(0, 15, 15, 15, t.wallLine.shaded(0.8))
            } else {
                tallWindow(c, &noise, t)
            }
        case .glass:
            glassWall(c, p, &noise, t, front: front)
        case .villa:
            facade(c, p, t)
            if front {
                window(c, lit: noise.chance(60), t)
                // A trimmed hedge along the foot of the wall.
                c.fill(0, 12, 15, 15, t.leaf)
                for x in stride(from: 1, to: 16, by: 3) { c.fill(x, 12, x + 1, 12, t.leafLight) }
                if t.snow { c.fill(0, 12, 15, 12, PixelColor(hex: "#e8eef6")) }
            } else {
                // A bay window behind a glass balustrade, a potted shrub.
                let lit = noise.chance(60)
                c.fill(2, 2, 13, 11, NightPalette.windowFrame)
                c.fill(3, 3, 12, 10, lit ? NightPalette.windowLit : NightPalette.windowDark)
                c.fill(7, 3, 8, 10, NightPalette.windowFrame)
                c.fill(1, 10, 14, 10, PixelColor(hex: "#a8d0dc"))
                c.fill(1, 11, 14, 12, PixelColor(hex: "#5a8a9a"))
                c.fill(1, 13, 14, 13, t.wall.shaded(1.15))
                if noise.chance(50) { c.fill(12, 8, 13, 9, PixelColor(hex: "#8a4a2e")); c.circle(cx: 12, cy: 6, radius: 2, t.leafLight) }
            }
        }
    }

    /// Le Bloc's ground floor: windows, a lowered shutter, tags, a bin or a scooter against the wall.
    private static func citeGroundFloor(_ c: PixelCanvas, _ p: TilePoint, _ noise: inout PixelNoise, _ t: CityTheme) {
        switch noise.next(4) {
        case 0:
            // A lowered steel shutter, tagged.
            c.fill(2, 2, 13, 12, PixelColor(hex: "#5e6068"))
            for y in stride(from: 3, through: 11, by: 2) { c.fill(2, y, 13, y, PixelColor(hex: "#4c4e56")) }
            tag(c, &noise, x: 3, y: 6)
        case 1:
            // A barred window.
            window(c, lit: noise.chance(40), t)
            for x in [5, 8, 10] { c.fill(x, 3, x, 11, NightPalette.metal) }
        default:
            window(c, lit: noise.chance(50), t)
        }
        if t.arches { zellige(c, y: 13, t) }
        switch noise.next(6) {
        case 0: bin(c, x: 1)
        case 1: scooter(c, x: 5, &noise)
        case 2: tag(c, &noise, x: 2, y: 12)
        default: break
        }
        if t.snow, noise.chance(60) {
            c.fill(0, 14, 15, 15, PixelColor(hex: "#dfe6f0")); c.fill(2, 13, 6, 13, PixelColor(hex: "#dfe6f0"))
        }
        if t.outdoorStairs, p.x % 3 == 0 { stairs(c) }
    }

    /// A balcony in front of a window: railing, slab, and what people keep out there.
    private static func balcony(_ c: PixelCanvas, _ noise: inout PixelNoise, _ t: CityTheme) {
        let rail = PixelColor(hex: "#45454e")
        c.fill(2, 9, 13, 9, rail.shaded(1.3))
        for x in stride(from: 2, through: 13, by: 2) { c.fill(x, 10, x, 12, rail) }
        c.fill(1, 13, 14, 13, t.wall.shaded(1.25))
        c.fill(1, 14, 14, 14, t.wallLine.shaded(0.8))
        switch noise.next(6) {
        case 0:
            // A satellite dish clamped to the railing.
            c.circle(cx: 11, cy: 6, radius: 2, PixelColor(hex: "#d8d8de"))
            c.dot(11, 6, NightPalette.metal); c.fill(11, 8, 11, 9, NightPalette.metal)
        case 1:
            // Washing on the railing.
            for (x, hex) in [(3, "#e04f4f"), (6, "#4f8ae0"), (9, "#f0eee8")] { c.fill(x, 10, x + 1, 12, PixelColor(hex: hex)) }
        case 2:
            // Pot plants.
            c.fill(3, 7, 5, 8, t.leafLight); c.dot(4, 6, t.leaf); c.fill(3, 8, 5, 8, PixelColor(hex: "#8a4a2e"))
        default:
            break
        }
        if t.snow { c.fill(2, 8, 13, 8, PixelColor(hex: "#e8eef6")) }
    }

    /// Downtown upstairs: a cornice, a tall window with shutters, a wrought-iron balcony.
    private static func tallWindow(_ c: PixelCanvas, _ noise: inout PixelNoise, _ t: CityTheme) {
        let lit = noise.chance(50), iron = PixelColor(hex: "#16161a")
        c.fill(0, 0, 15, 1, t.wall.shaded(1.2)); c.fill(0, 2, 15, 2, t.wallLine)
        c.fill(4, 4, 11, 14, NightPalette.windowFrame)
        c.fill(5, 5, 10, 13, lit ? NightPalette.windowLit : NightPalette.windowDark)
        c.fill(7, 5, 8, 13, NightPalette.windowFrame); c.fill(5, 9, 10, 9, NightPalette.windowFrame)
        if lit { c.dot(5, 5, NightPalette.windowLit.shaded(1.15)) }
        if t.arches {
            for (x, y) in [(4, 4), (5, 4), (10, 4), (11, 4), (4, 5), (11, 5)] { c.dot(x, y, t.wall) }
        }
        if let shutters = t.shutters {
            c.fill(2, 4, 3, 14, shutters); c.fill(12, 4, 13, 14, shutters)
            for y in [6, 9, 12] { c.fill(2, y, 3, y, shutters.shaded(0.75)); c.fill(12, y, 13, y, shutters.shaded(0.75)) }
        }
        c.fill(3, 11, 12, 11, iron)
        for x in stride(from: 3, through: 12, by: 2) { c.dot(x, 12, iron) }
        c.fill(3, 13, 12, 13, iron)
        c.fill(2, 14, 13, 14, t.wall.shaded(1.15))
        if t.snow { c.fill(3, 10, 12, 10, PixelColor(hex: "#e8eef6")) }
    }

    /// A glass curtain wall: mullions, a few offices still lit, a reflection running across.
    private static func glassWall(_ c: PixelCanvas, _ p: TilePoint, _ noise: inout PixelNoise, _ t: CityTheme, front: Bool) {
        c.fill(0, 0, 15, 15, t.wall)
        for x in stride(from: 0, to: 16, by: 4) { c.fill(x, 0, x, 15, t.wallLine) }
        c.fill(0, 0, 15, 0, t.roofEdge)
        if front {
            // The lobby: tall bright glass, planters with clipped shrubs.
            c.fill(1, 2, 14, 15, PixelColor(hex: "#6a8aa0"))
            c.fill(1, 2, 14, 2, PixelColor(hex: "#a8c8d8"))
            for x in [4, 8, 12] { c.fill(x, 2, x, 15, t.wallLine) }
            if p.x % 2 == 0 {
                c.fill(2, 12, 13, 15, PixelColor(hex: "#4a4e58"))
                c.fill(2, 12, 13, 12, PixelColor(hex: "#6a6e78"))
                for x in [4, 10] { c.circle(cx: x, cy: 10, radius: 2, t.snow ? PixelColor(hex: "#dfe6f0") : PixelColor(hex: "#2f6a3a")) }
            }
        } else {
            c.fill(0, 8, 15, 8, t.wallLine.shaded(1.25))
            for x in [1, 5, 9, 13] {
                for y in [1, 9] where noise.chance(30) {
                    c.fill(x, y, x + 2, y + 6, noise.chance(60) ? PixelColor(hex: "#9ec8e8") : NightPalette.windowLit.shaded(0.85))
                }
            }
        }
        if (p.x + p.y) % 3 == 0 {
            for i in 0..<16 where (15 - i) % 4 != 0 { c.dot(15 - i, i, t.wall.shaded(1.4)) }
        }
    }

    // MARK: Roofs

    private static func roofTile(_ c: PixelCanvas, _ p: TilePoint, _ style: BuildingStyle, _ noise: inout PixelNoise,
                                 _ t: CityTheme, above: TileKind, below: TileKind) {
        roof(c, &noise, t, above: above, below: below)
        let metal = NightPalette.metal
        switch style {
        case .cite:
            // Flat roofs: lift rooms, dishes, aerials, pigeons on the parapet.
            switch noise.next(7) {
            case 0:
                c.fill(3, 4, 12, 11, t.roof.shaded(1.3)); c.fill(3, 4, 12, 5, t.roofEdge.shaded(1.2))
                c.fill(3, 12, 12, 12, t.roofShadow)
                for y in [7, 9] { c.fill(5, y, 10, y, t.roof.shaded(0.9)) }
            case 1, 2:
                c.circle(cx: 8, cy: 7, radius: 3, metal.shaded(1.35)); c.circle(cx: 8, cy: 7, radius: 1, metal.shaded(0.8))
                c.fill(8, 10, 8, 12, metal); c.fill(6, 12, 10, 12, metal.shaded(0.8))
            case 3:
                c.fill(7, 2, 7, 12, metal)
                for (y, half) in [(3, 4), (6, 3), (9, 2)] { c.fill(7 - half, y, 7 + half, y, metal.shaded(1.2)) }
            default:
                break
            }
            if above != .roof, noise.chance(35) { pigeon(c, 2 + noise.next(10), 3, left: noise.chance(50)) }
        case .bunker:
            // Ventilation grilles and cables.
            c.fill(2, 3, 7, 7, metal.shaded(0.7))
            for x in [3, 5] { c.fill(x, 4, x, 6, metal.shaded(0.4)) }
            if noise.chance(50) { c.fill(0, 11, 15, 11, PixelColor(hex: "#14141a")); c.fill(9, 9, 9, 11, PixelColor(hex: "#14141a")) }
        case .radio:
            if noise.chance(30) {
                c.circle(cx: 4, cy: 9, radius: 2, metal.shaded(1.35)); c.dot(4, 9, metal.shaded(0.8))
            }
        case .townhouse, .villa:
            if t.gables, style == .townhouse, below == .wall, p.x % 2 == 0 {
                gable(c, t)
            } else if t.dormers, below == .wall {
                dormer(c, &noise, t)
            } else if t.chimneys, above != .roof, noise.chance(55) {
                chimney(c, &noise, t)
            } else if !t.chimneys, noise.chance(35) {
                // Roof terraces: washing on a line, a dish.
                c.fill(1, 6, 14, 6, metal.shaded(1.2))
                for (x, hex) in [(3, "#e8e4d8"), (7, "#1f7a6a"), (11, "#c8603a")] { c.fill(x, 7, x + 2, 10, PixelColor(hex: hex)) }
            } else if noise.chance(25) {
                // A skylight.
                c.fill(5, 6, 10, 10, metal); c.fill(6, 7, 9, 9, PixelColor(hex: "#2a3a5a"))
            }
        case .glass:
            switch noise.next(5) {
            case 0, 1:
                // Solar panels.
                c.fill(2, 3, 13, 12, PixelColor(hex: "#1c2a52"))
                for x in stride(from: 2, through: 13, by: 3) { c.fill(x, 3, x, 12, PixelColor(hex: "#3a5a9a")) }
                c.fill(2, 7, 13, 7, PixelColor(hex: "#3a5a9a"))
            case 2:
                // A roof garden.
                c.fill(1, 2, 14, 13, t.snow ? PixelColor(hex: "#dfe6f0") : PixelColor(hex: "#2a4a2a"))
                c.circle(cx: 5, cy: 6, radius: 3, t.leaf); c.circle(cx: 5, cy: 5, radius: 1, t.leafLight)
                c.circle(cx: 11, cy: 10, radius: 2, t.leaf); c.dot(10, 9, t.leafLight)
            case 3:
                // An air-conditioning unit.
                c.fill(4, 4, 11, 11, metal.shaded(1.1)); c.circle(cx: 7, cy: 7, radius: 2, metal.shaded(0.55))
                c.fill(7, 5, 8, 9, metal.shaded(1.3))
            default:
                break
            }
        }
    }

    /// A Flemish stepped gable rising over the roof.
    private static func gable(_ c: PixelCanvas, _ t: CityTheme) {
        for (y, x) in [(4, 6), (7, 4), (10, 2), (13, 1)] {
            c.fill(x, y, 15 - x, 15, t.wall)
            c.fill(x, y, 15 - x, y, t.wall.shaded(1.25))
        }
        c.fill(7, 8, 8, 11, NightPalette.windowLit.shaded(0.8))
        c.fill(7, 8, 8, 8, NightPalette.windowFrame)
    }

    private static func dormer(_ c: PixelCanvas, _ noise: inout PixelNoise, _ t: CityTheme) {
        let lit = noise.chance(45)
        c.fill(5, 6, 10, 14, t.roofEdge)
        c.fill(6, 8, 9, 13, lit ? NightPalette.windowLit : NightPalette.windowDark)
        c.fill(6, 4, 9, 4, t.roofEdge.shaded(1.2)); c.fill(5, 5, 10, 5, t.roofEdge.shaded(1.2))
        if t.snow { c.fill(5, 4, 10, 4, PixelColor(hex: "#e8eef6")) }
    }

    private static func chimney(_ c: PixelCanvas, _ noise: inout PixelNoise, _ t: CityTheme) {
        let x = 2 + noise.next(7)
        c.fill(x, 3, x + 5, 9, t.wall.shaded(0.85))
        c.fill(x, 3, x + 5, 3, t.wall.shaded(1.15))
        c.fill(x, 10, x + 5, 10, t.roofShadow)
        for px in [x + 1, x + 3] { c.fill(px, 1, px + 1, 3, PixelColor(hex: "#a85a3a")) }
        if t.snow { c.fill(x, 3, x + 5, 3, PixelColor(hex: "#f2f5fa")) }
    }

    // MARK: Whole buildings

    /// Downtown's ground floors, two tiles per shop: a sign or an awning, a lit window, the goods.
    private static func shops(_ building: Building, on c: PixelCanvas, map: WorldMap, theme t: CityTheme, index: inout Int) {
        let doors = map.doors.filter { building.tiles.contains($0.point) }
        for y in building.minY...building.maxY {
            // Runs of plain front wall, leaving room for the storefront around a door.
            var runs: [[Int]] = [], run: [Int] = []
            for x in building.minX...(building.maxX + 1) {
                let p = TilePoint(x: x, y: y)
                let free = building.tiles.contains(p) && map.tile(at: p) == .wall && building.isFront(p)
                    && !doors.contains { $0.y == y && abs($0.x - x) <= 2 }
                if free { run.append(x) } else if !run.isEmpty { runs.append(run); run = [] }
            }
            for run in runs {
                var start = 0
                while start < run.count {
                    let left = run.count - start
                    let width = left == 3 ? 3 : min(2, left)
                    // The city's own shop comes first, once; then the usual high street.
                    let street: [Shop] = [.cafe, .records, .market, .kiosk, .bakery]
                    let kind = width == 1 ? Shop.pharmacy : (index == 0 ? .signature : street[(index - 1) % street.count])
                    shop(kind, on: c, x0: run[start] * size, y0: y * size, width: width * size, theme: t, index: index)
                    if width > 1 { index += 1 }
                    start += width
                }
            }
        }
    }

    enum Shop { case signature, records, kiosk, bakery, cafe, market, pharmacy }

    private static func shop(_ kind: Shop, on c: PixelCanvas, x0: Int, y0: Int, width: Int, theme t: CityTheme, index: Int) {
        let x1 = x0 + width - 1
        let white = PixelColor(hex: "#e8e2d4"), dark = PixelColor(hex: "#14141a")
        let awning = t.awnings[index % max(1, t.awnings.count)]
        var noise = PixelNoise(x0, y0, salt: 31)
        switch kind {
        case .signature, .records, .kiosk, .bakery:
            // A dark sign board with its name, the shop window under it.
            let text = switch kind {
            case .records: "DISQUES"
            case .kiosk: "KIOSQUE"
            case .bakery: "PAIN"
            default: t.signature
            }
            c.fill(x0, y0 + 1, x1, y0 + 7, dark)
            c.fill(x0, y0 + 7, x1, y0 + 7, awning)
            PixelFont.draw(text, on: c, x: x0 + (width - PixelFont.width(text)) / 2, y: y0 + 2, NightPalette.lampLight)
            c.fill(x0 + 1, y0 + 8, x1 - 1, y0 + 15, NightPalette.windowFrame)
            c.fill(x0 + 2, y0 + 9, x1 - 2, y0 + 15, NightPalette.windowLit.shaded(0.7))
            switch kind {
            case .records:
                // Records on display, sleeves and all.
                for (i, vx) in stride(from: x0 + 6, to: x1 - 3, by: 7).enumerated() {
                    c.fill(vx - 3, y0 + 10, vx + 3, y0 + 15, i % 2 == 0 ? awning : PixelColor(hex: "#4f8ae0"))
                    c.circle(cx: vx, cy: y0 + 12, radius: 2, dark); c.dot(vx, y0 + 12, NightPalette.lampLight)
                }
            case .bakery:
                // Baguettes standing in a basket, round loaves on the shelf.
                let crust = PixelColor(hex: "#c8903a")
                for bx in stride(from: x0 + 3, to: x1 - 8, by: 3) { c.fill(bx, y0 + 9, bx + 1, y0 + 15, crust); c.dot(bx, y0 + 9, crust.shaded(1.3)) }
                for lx in stride(from: x1 - 8, to: x1 - 2, by: 3) { c.fill(lx, y0 + 12, lx + 2, y0 + 13, crust.shaded(0.85)) }
                c.fill(x0 + 2, y0 + 14, x1 - 2, y0 + 15, NightPalette.wood)
            case .kiosk:
                // Magazines and papers in rows.
                let covers = ["#e04f4f", "#f0eee8", "#4fd6e0", "#f2c14e", "#7fe0a0"].map(PixelColor.init(hex:))
                for (i, mx) in stride(from: x0 + 3, to: x1 - 3, by: 4).enumerated() {
                    c.fill(mx, y0 + 10, mx + 2, y0 + 13, covers[i % covers.count])
                    c.fill(mx, y0 + 10, mx + 2, y0 + 10, dark)
                }
            default:
                // Shelves of whatever the city is known for.
                c.fill(x0 + 2, y0 + 12, x1 - 2, y0 + 12, NightPalette.wood)
                for gx in stride(from: x0 + 3, to: x1 - 2, by: 3) {
                    c.fill(gx, y0 + 10, gx + 1, y0 + 11, noise.chance(50) ? awning.shaded(1.3) : white)
                    c.fill(gx, y0 + 13, gx + 1, y0 + 14, noise.chance(50) ? PixelColor(hex: "#c8903a") : awning)
                }
            }
            if t.snow { c.fill(x0, y0 + 1, x1, y0 + 1, PixelColor(hex: "#e8eef6")) }
        case .cafe, .market:
            // A striped awning over a warm window.
            c.fill(x0 + 1, y0 + 6, x1 - 1, y0 + 15, NightPalette.windowFrame)
            c.fill(x0 + 2, y0 + 7, x1 - 2, y0 + 15, NightPalette.windowLit.shaded(kind == .cafe ? 0.85 : 0.7))
            for px in x0...x1 {
                let stripe = ((px - x0) / 3) % 2 == 0 ? awning : white
                c.fill(px, y0 + 1, px, y0 + 4, stripe)
                if (px - x0) % 2 == 0 { c.dot(px, y0 + 5, stripe) }
            }
            if t.snow { c.fill(x0, y0 + 1, x1, y0 + 1, PixelColor(hex: "#e8eef6")) }
            if kind == .cafe {
                // The terrace: little round tables and chairs against the window.
                for tx in stride(from: x0 + 4, to: x1 - 4, by: 10) {
                    c.fill(tx - 2, y0 + 11, tx - 1, y0 + 15, NightPalette.wood)
                    c.fill(tx, y0 + 11, tx + 3, y0 + 11, white)
                    c.fill(tx + 1, y0 + 12, tx + 2, y0 + 15, NightPalette.metal)
                    c.fill(tx + 4, y0 + 11, tx + 5, y0 + 15, NightPalette.wood)
                }
            } else {
                // Crates of fruit out front.
                let fruit = ["#e04f4f", "#f2a03a", "#7fc04f", "#f2d04e"].map(PixelColor.init(hex:))
                for (i, cx) in stride(from: x0 + 1, to: x1 - 4, by: 7).enumerated() {
                    c.fill(cx, y0 + 12, cx + 5, y0 + 15, NightPalette.wood)
                    c.fill(cx, y0 + 13, cx + 5, y0 + 13, NightPalette.wood.shaded(0.7))
                    for fx in stride(from: cx, through: cx + 5, by: 2) {
                        c.fill(fx, y0 + 11, fx + 1, y0 + 12, fruit[(i + fx) % fruit.count])
                    }
                }
            }
        case .pharmacy:
            // The green cross, lit, over a white window.
            c.fill(x0 + 1, y0 + 8, x1 - 1, y0 + 15, NightPalette.windowFrame)
            c.fill(x0 + 2, y0 + 9, x1 - 2, y0 + 15, PixelColor(hex: "#cfe4dc"))
            c.fill(x0 + 4, y0 + 1, x0 + 11, y0 + 7, dark)
            let green = PixelColor(hex: "#2ac85a")
            c.fill(x0 + 7, y0 + 2, x0 + 8, y0 + 6, green); c.fill(x0 + 5, y0 + 3, x0 + 10, y0 + 4, green)
        }
    }

    /// A painted helipad on an office roof.
    private static func helipad(_ building: Building, on c: PixelCanvas, map: WorldMap) {
        let tx = (building.minX + building.maxX) / 2
        guard map.tile(at: TilePoint(x: tx, y: building.minY)) == .roof,
              map.tile(at: TilePoint(x: tx + 1, y: building.minY)) == .roof else { return }
        let cx = (tx + 1) * size, cy = building.minY * size + size / 2
        let yellow = PixelColor(hex: "#d8b040"), white = PixelColor(hex: "#e8e8ec")
        c.circle(cx: cx, cy: cy, radius: 7, yellow)
        c.circle(cx: cx, cy: cy, radius: 6, PixelColor(hex: "#2a313c"))
        c.fill(cx - 3, cy - 3, cx - 2, cy + 3, white); c.fill(cx + 2, cy - 3, cx + 3, cy + 3, white)
        c.fill(cx - 1, cy, cx + 1, cy, white)
        for (dx, dy) in [(-8, -6), (8, -6), (-8, 6), (8, 6)] { c.dot(cx + dx, cy + dy, PixelColor(hex: "#ff4a3a")) }
    }

    /// A pool on the villa's roof, with its deck and a sunbed (a snowed-over deck in Montréal).
    private static func pool(_ building: Building, on c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        let tx = max(building.minX, (building.minX + building.maxX) / 2 - 1), ty = building.minY
        guard map.tile(at: TilePoint(x: tx, y: ty)) == .roof, map.tile(at: TilePoint(x: tx + 1, y: ty)) == .roof else { return }
        let px = tx * size, py = ty * size
        c.fill(px + 2, py + 3, px + 29, py + 13, t.snow ? PixelColor(hex: "#dfe6f0") : PixelColor(hex: "#d8d2c4"))
        guard !t.snow else { return }
        c.fill(px + 4, py + 5, px + 21, py + 11, PixelColor(hex: "#1f7ab0"))
        c.fill(px + 4, py + 5, px + 21, py + 5, PixelColor(hex: "#5ab8e0"))
        for (rx, ry) in [(7, 7), (14, 9), (17, 7)] { c.fill(px + rx, py + ry, px + rx + 2, py + ry, PixelColor(hex: "#7ad0f0")) }
        // A sunbed and a striped parasol.
        c.fill(px + 24, py + 6, px + 27, py + 11, PixelColor(hex: "#f0eee8"))
        c.fill(px + 24, py + 6, px + 27, py + 7, PixelColor(hex: "#c8c2b4"))
        c.circle(cx: px + 26, cy: py + 4, radius: 2, PixelColor(hex: "#e04f4f")); c.dot(px + 26, py + 4, PixelColor(hex: "#f0eee8"))
    }

    /// A big painted mural on the cité's upper floor: a sunset over the towers, a microphone, "BLOC".
    private static func mural(_ building: Building, on c: PixelCanvas, map: WorldMap) {
        let y = building.maxY - 1
        let xs = (building.maxX - 2)...building.maxX
        guard xs.allSatisfy({ map.tile(at: TilePoint(x: $0, y: y)) == .wall && building.tiles.contains(TilePoint(x: $0, y: y)) })
        else { return }
        let x0 = xs.lowerBound * size + 1, x1 = (xs.upperBound + 1) * size - 2, y0 = y * size + 1, y1 = y * size + 14
        for (i, hex) in ["#3a1a5a", "#7a2a6a", "#c8487a", "#f08a4a", "#f2c14e"].enumerated() {
            c.fill(x0, y0 + i * 2, x1, i == 4 ? y1 : y0 + i * 2 + 1, PixelColor(hex: hex))
        }
        c.circle(cx: x1 - 12, cy: y0 + 9, radius: 4, PixelColor(hex: "#ffe08a"))
        // The towers in silhouette.
        let skyline = [3, 3, 6, 6, 6, 2, 4, 4, 8, 8, 8, 8, 3, 5, 5, 2]
        for x in x0...x1 { c.fill(x, y1 - skyline[(x - x0) / 3 % skyline.count], x, y1, PixelColor(hex: "#1a1030")) }
        // A microphone.
        c.fill(x0 + 5, y0 + 2, x0 + 8, y0 + 5, PixelColor(hex: "#c8c8d0"))
        c.fill(x0 + 6, y0 + 3, x0 + 7, y0 + 3, PixelColor(hex: "#8a8a96"))
        c.fill(x0 + 6, y0 + 6, x0 + 7, y0 + 11, PixelColor(hex: "#14141a"))
        PixelFont.draw("BLOC", on: c, x: x0 + 13, y: y0 + 3, PixelColor(hex: "#14141a"))
        PixelFont.draw("BLOC", on: c, x: x0 + 12, y: y0 + 2, PixelColor(hex: "#f0eee8"))
    }

    // MARK: Small props

    /// A spray-painted tag: a wavy stroke with a drip.
    static func tag(_ c: PixelCanvas, _ noise: inout PixelNoise, x: Int, y: Int, width: Int = 10) {
        let inks = ["#e04fb0", "#4fd6e0", "#f2c14e", "#7fe0a0", "#f0eee8", "#ff6a3a"].map(PixelColor.init(hex:))
        let ink = inks[noise.next(inks.count)]
        let wave = [0, -1, -2, -1, 0, 1, 0, -1, -2, 0, 1, 0]
        let offset = noise.next(wave.count)
        for dx in 0..<width {
            let dy = wave[(dx + offset) % wave.count]
            c.fill(x + dx, y + dy, x + dx, y + dy + 1, ink)
        }
        c.dot(x + width, y - 2, ink)
        c.fill(x + 2, y + 2, x + 2, y + 3, ink)
    }

    /// A green wheelie bin.
    static func bin(_ c: PixelCanvas, x: Int) {
        let green = PixelColor(hex: "#2f6a3a")
        c.fill(x, 9, x + 5, 9, green.shaded(0.7))
        c.fill(x, 10, x + 5, 14, green)
        c.fill(x + 1, 11, x + 1, 13, green.shaded(1.3))
        c.dot(x + 1, 15, .outline); c.dot(x + 4, 15, .outline)
    }

    /// A scooter parked against the wall.
    static func scooter(_ c: PixelCanvas, x: Int, _ noise: inout PixelNoise) {
        let paints = ["#c8322a", "#e8e4dc", "#2a4a8a", "#1a1a1e"].map(PixelColor.init(hex:))
        let paint = paints[noise.next(paints.count)]
        c.fill(x + 1, 11, x + 8, 12, paint)
        c.fill(x + 3, 10, x + 6, 10, PixelColor(hex: "#1a1a1e"))
        c.fill(x + 8, 8, x + 8, 11, NightPalette.metal)
        c.fill(x + 7, 8, x + 9, 8, NightPalette.metal)
        c.dot(x + 9, 10, NightPalette.lampLight)
        for wx in [x + 1, x + 7] { c.fill(wx, 13, wx + 1, 14, .outline) }
    }

    /// A pigeon, three pixels of grey and a head.
    static func pigeon(_ c: PixelCanvas, _ x: Int, _ y: Int, left: Bool) {
        let body = PixelColor(hex: "#8a8e9c")
        c.fill(x, y, x + 2, y + 1, body)
        c.dot(left ? x - 1 : x + 3, y - 1, PixelColor(hex: "#5a6a7a"))
        c.dot(left ? x : x + 2, y - 1, body)
        c.dot(left ? x + 2 : x, y, body.shaded(0.7))
        c.dot(x + 1, y + 2, PixelColor(hex: "#c87a5a"))
    }

    /// Casablanca's zellige frieze: a white band with green and blue stars.
    static func zellige(_ c: PixelCanvas, y: Int, _ t: CityTheme) {
        let white = PixelColor(hex: "#e8e4d8"), blue = PixelColor(hex: "#2a5a9a")
        c.fill(0, y, 15, y + 2, white)
        for x in stride(from: 0, to: 16, by: 4) {
            c.dot(x + 1, y + 1, t.accent); c.dot(x + 3, y + 1, t.accent)
            c.dot(x + 2, y, blue); c.dot(x + 2, y + 2, blue)
        }
    }
}
