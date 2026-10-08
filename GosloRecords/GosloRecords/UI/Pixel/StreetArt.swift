import UIKit

// Street life, painted once into the cached map image. Only flat details on the tiles you can walk on
// (manholes, tram rails, puddles, chalk, pigeons, flowers); anything with volume (the playground, the wreck
// on the terrain vague, the fountain) stands on a tile that was already blocked.

@MainActor
extension TileArt {
    static func dressStreets(_ c: PixelCanvas, map: WorldMap, theme t: CityTheme, district: District) {
        guard district != .dome else { return }
        for y in 0..<map.height {
            for x in 0..<map.width {
                let p = TilePoint(x: x, y: y), px = x * size, py = y * size
                var noise = PixelNoise(x, y, salt: 23)
                switch map.tile(at: p) {
                case .asphalt, .crosswalk:
                    if district == .centre {
                        // The tramway's rails, sunk in the road.
                        for ry in [py + 4, py + 11] {
                            c.fill(px, ry, px + 15, ry, NightPalette.metal.shaded(1.25))
                            c.fill(px, ry + 1, px + 15, ry + 1, NightPalette.asphaltDark.shaded(0.7))
                        }
                    } else if map.tile(at: p) == .asphalt, noise.chance(7) {
                        manhole(c, px + 4 + noise.next(6), py + 4 + noise.next(6))
                    }
                case .sidewalk:
                    if t.puddles, noise.chance(12) { puddle(c, px, py, &noise) }
                    if district != .hauts, noise.chance(district == .centre ? 9 : 5), map.door(at: p.moved(.up)) == nil {
                        for _ in 0..<(1 + noise.next(3)) {
                            pigeon(c, px + 2 + noise.next(10), py + 4 + noise.next(9), left: noise.chance(50))
                        }
                    }
                case .grass:
                    if district == .centre, noise.chance(35) {
                        // Flower beds in the square.
                        let petals = ["#e8d040", "#e06a9a", "#f0eee8"].map(PixelColor.init(hex:))
                        for _ in 0..<3 {
                            let fx = px + 1 + noise.next(14), fy = py + 4 + noise.next(11)
                            c.dot(fx, fy, petals[noise.next(petals.count)]); c.dot(fx, fy + 1, t.grassBlade)
                        }
                    } else if district == .bloc, noise.chance(8) {
                        // Litter on the terrain vague: a crushed can.
                        let fx = px + 2 + noise.next(11), fy = py + 6 + noise.next(8)
                        c.fill(fx, fy, fx + 2, fy, PixelColor(hex: noise.chance(50) ? "#c83a2a" : "#b8bcc6"))
                        c.dot(fx + 3, fy, NightPalette.metal)
                    }
                default:
                    break
                }
            }
        }
        switch district {
        case .centre: fountain(c, map: map, theme: t)
        case .bloc: playground(c, map: map, theme: t)
        case .hauts, .dome: break
        }
    }

    private static func manhole(_ c: PixelCanvas, _ cx: Int, _ cy: Int) {
        c.circle(cx: cx, cy: cy, radius: 3, PixelColor(hex: "#1e1e22"))
        c.circle(cx: cx, cy: cy, radius: 2, PixelColor(hex: "#3a3a42"))
        for (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)] { c.dot(cx + dx, cy + dy, PixelColor(hex: "#26262c")) }
    }

    private static func puddle(_ c: PixelCanvas, _ px: Int, _ py: Int, _ noise: inout PixelNoise) {
        let w = 4 + noise.next(5), x0 = px + 1 + noise.next(15 - w - 1), y0 = py + 3 + noise.next(9)
        let water = PixelColor(hex: "#34405a")
        c.fill(x0 + 1, y0, x0 + w - 1, y0 + 2, water)
        c.fill(x0, y0 + 1, x0 + w, y0 + 1, water)
        c.fill(x0 + 1, y0, x0 + 2, y0, PixelColor(hex: "#7a8aa8"))
        c.dot(x0 + w - 2, y0 + 2, PixelColor(hex: "#5a6a88"))
    }

    /// Downtown's basin: a stone rim all round, a fountain in the middle, its spray caught in the light.
    /// (The basin is the stretch of water that doesn't reach the sides of the map: the river runs from one to the other.)
    private static func fountain(_ c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        var pools: [[TilePoint]] = [], seen = Set<TilePoint>()
        for y in 0..<map.height {
            for x in 0..<map.width {
                let start = TilePoint(x: x, y: y)
                guard map.tile(at: start) == .water, !seen.contains(start) else { continue }
                var pool: [TilePoint] = [], stack = [start]
                seen.insert(start)
                while let p = stack.popLast() {
                    pool.append(p)
                    for direction in Direction.allCases {
                        let next = p.moved(direction)
                        if map.tile(at: next) == .water, !seen.contains(next) { seen.insert(next); stack.append(next) }
                    }
                }
                pools.append(pool)
            }
        }
        guard let water = pools.first(where: { pool in !pool.contains { $0.x <= 1 || $0.x >= map.width - 2 } }) else { return }
        guard let minX = water.map(\.x).min(), let maxX = water.map(\.x).max(),
              let minY = water.map(\.y).min(), let maxY = water.map(\.y).max() else { return }
        let stone = PixelColor(hex: "#8a8478"), stoneLight = PixelColor(hex: "#aaa498")
        for p in water {
            let px = p.x * size, py = p.y * size
            if map.tile(at: p.moved(.up)) != .water { c.fill(px, py, px + 15, py + 2, stoneLight) }
            if map.tile(at: p.moved(.down)) != .water { c.fill(px, py + 13, px + 15, py + 15, stone) }
            if map.tile(at: p.moved(.left)) != .water { c.fill(px, py, px + 2, py + 15, stone) }
            if map.tile(at: p.moved(.right)) != .water { c.fill(px + 13, py, px + 15, py + 15, stone) }
        }
        let cx = (minX + maxX + 1) * size / 2, cy = (minY + maxY + 1) * size / 2 + 2
        c.circle(cx: cx, cy: cy, radius: 9, stone)
        c.circle(cx: cx, cy: cy, radius: 7, t.ripple)
        c.circle(cx: cx, cy: cy, radius: 3, stoneLight)
        c.fill(cx - 1, cy - 9, cx, cy, PixelColor(hex: "#d8e8f0"))
        c.fill(cx - 3, cy - 10, cx + 2, cy - 9, PixelColor(hex: "#d8e8f0"))
        for (dx, dy) in [(-5, -8), (4, -8), (-6, -4), (5, -4), (-4, -11), (3, -11), (-7, 0), (6, 0)] {
            c.dot(cx + dx, cy + dy, PixelColor(hex: "#a8d0e8"))
        }
        // Pigeons on the rim.
        pigeon(c, minX * size + 6, minY * size, left: false)
        pigeon(c, maxX * size + 4, maxY * size + 13, left: true)
    }

    /// Le Bloc's courtyard and wasteland: the pairs of trees by the benches become a slide and a swing set,
    /// the first pair out on the grass a burnt-out car. Same blocked tiles, new things on them.
    private static func playground(_ c: PixelCanvas, map: WorldMap, theme t: CityTheme) {
        var props: [String] = []
        guard map.height > 2, map.width > 3 else { return }
        for y in 1..<(map.height - 1) {
            for x in 1..<(map.width - 2) {
                let p = TilePoint(x: x, y: y), q = TilePoint(x: x + 1, y: y)
                guard map.tile(at: p) == .tree, map.tile(at: q) == .tree, map.tile(at: p.moved(.left)) != .tree,
                      map.tile(at: q.moved(.right)) != .tree else { continue }
                let ground = map.tile(at: p.moved(.down)), px = x * size, py = y * size
                if ground == .grass, !props.contains("wreck") {
                    props.append("wreck")
                    wreck(c, px, py, t)
                } else if ground == .sidewalk || ground == .bench {
                    if !props.contains("slide") {
                        props.append("slide")
                        slide(c, px, py, t)
                    } else if !props.contains("swings") {
                        props.append("swings")
                        swings(c, px, py, t)
                    }
                }
            }
        }
        // Chalk on the pavement: a hopscotch by the first bench.
        for y in 0..<map.height {
            for x in 2..<max(2, map.width - 1) {
                let p = TilePoint(x: x, y: y)
                guard map.tile(at: p) == .sidewalk, map.tile(at: p.moved(.right)) == .sidewalk,
                      map.tile(at: TilePoint(x: x - 2, y: y)) == .bench else { continue }
                hopscotch(c, x * size, y * size)
                return
            }
        }
    }

    /// Ground under a play structure: packed earth with a low wooden edging.
    private static func playGround(_ c: PixelCanvas, _ px: Int, _ py: Int, _ t: CityTheme) {
        c.fill(px, py, px + 31, py + 15, t.ground)
        c.fill(px + 1, py + 1, px + 30, py + 14, t.snow ? PixelColor(hex: "#dfe6f0") : PixelColor(hex: "#5a4434"))
        c.fill(px, py + 15, px + 31, py + 15, NightPalette.wood)
        c.fill(px, py, px, py + 15, NightPalette.wood); c.fill(px + 31, py, px + 31, py + 15, NightPalette.wood)
    }

    private static func slide(_ c: PixelCanvas, _ px: Int, _ py: Int, _ t: CityTheme) {
        playGround(c, px, py, t)
        let red = PixelColor(hex: "#d8402e"), yellow = PixelColor(hex: "#f2c14e"), steel = NightPalette.metal.shaded(1.3)
        c.fill(px + 3, py + 5, px + 3, py + 14, steel); c.fill(px + 12, py + 5, px + 12, py + 14, steel)
        for ry in stride(from: py + 7, through: py + 13, by: 3) { c.fill(px + 4, ry, px + 11, ry, steel.shaded(0.8)) }
        c.fill(px + 2, py + 1, px + 13, py + 4, red)
        c.fill(px + 2, py + 1, px + 13, py + 1, red.shaded(1.25))
        for i in 0..<16 {
            let sx = px + 13 + i, sy = py + 4 + i * 8 / 16
            c.fill(sx, sy, sx, sy + 2, yellow)
            c.dot(sx, sy + 3, yellow.shaded(0.55))
        }
        if t.snow { c.fill(px + 2, py + 1, px + 13, py + 1, PixelColor(hex: "#f2f5fa")) }
    }

    private static func swings(_ c: PixelCanvas, _ px: Int, _ py: Int, _ t: CityTheme) {
        playGround(c, px, py, t)
        let steel = NightPalette.metal.shaded(1.3)
        c.fill(px + 2, py + 1, px + 29, py + 2, steel)
        for lx in [px + 2, px + 29] { c.fill(lx, py + 1, lx, py + 14, steel); c.dot(lx - 1, py + 14, steel); c.dot(lx + 1, py + 14, steel) }
        for (sx, seat) in [(px + 8, PixelColor(hex: "#d8402e")), (px + 18, PixelColor(hex: "#3f8ad8"))] {
            c.fill(sx, py + 3, sx, py + 10, NightPalette.metal); c.fill(sx + 5, py + 3, sx + 5, py + 10, NightPalette.metal)
            c.fill(sx - 1, py + 11, sx + 6, py + 12, seat)
        }
        if t.snow { c.fill(px + 2, py + 1, px + 29, py + 1, PixelColor(hex: "#f2f5fa")) }
    }

    /// A burnt-out car on bricks, tagged, the weeds growing through.
    private static func wreck(_ c: PixelCanvas, _ px: Int, _ py: Int, _ t: CityTheme) {
        var noise = PixelNoise(px, py, salt: 41)
        for dx in [0, size] {
            let tile = PixelCanvas(width: size, height: size)
            grass(tile, &noise, t)
            c.stamp(tile, at: px + dx, py)
        }
        let body = PixelColor(hex: "#4a4e5a"), rust = PixelColor(hex: "#7a4a2e")
        for bx in [px + 5, px + 23] { c.fill(bx, py + 13, bx + 3, py + 15, NightPalette.brick.shaded(1.4)) }
        c.fill(px + 2, py + 6, px + 29, py + 12, body)
        c.fill(px + 2, py + 6, px + 29, py + 6, body.shaded(1.3))
        c.fill(px + 8, py + 2, px + 22, py + 5, body.shaded(0.85))
        c.fill(px + 9, py + 3, px + 14, py + 5, .outline); c.fill(px + 16, py + 3, px + 21, py + 5, .outline)
        c.dot(px + 11, py + 4, PixelColor(hex: "#5a6a7a"))
        c.fill(px + 4, py + 8, px + 9, py + 10, rust); c.fill(px + 21, py + 7, px + 27, py + 9, rust)
        c.dot(px + 15, py + 11, rust); c.dot(px + 26, py + 11, rust)
        tag(c, &noise, x: px + 12, y: py + 9, width: 8)
        for wx in [px + 3, px + 13, px + 28] { c.fill(wx, py + 11, wx, py + 14, t.grassBlade); c.dot(wx, py + 10, t.grassTip) }
        if t.snow {
            c.fill(px + 8, py + 2, px + 22, py + 2, PixelColor(hex: "#f2f5fa"))
            c.fill(px + 2, py + 6, px + 29, py + 6, PixelColor(hex: "#f2f5fa"))
        }
    }

    private static func hopscotch(_ c: PixelCanvas, _ px: Int, _ py: Int) {
        let chalk = PixelColor(hex: "#b8b8c4")
        for (bx, by) in [(1, 5), (7, 5), (13, 1), (13, 8), (19, 5), (25, 1), (25, 8)] {
            let x0 = px + bx, y0 = py + by
            c.fill(x0, y0, x0 + 5, y0, chalk); c.fill(x0, y0 + 6, x0 + 5, y0 + 6, chalk)
            c.fill(x0, y0, x0, y0 + 6, chalk); c.fill(x0 + 5, y0, x0 + 5, y0 + 6, chalk)
        }
        c.dot(px + 3, py + 8, chalk); c.dot(px + 9, py + 7, chalk); c.dot(px + 10, py + 9, chalk)
    }
}

// MARK: Lettering

/// A tiny pixel font for the signs painted on the map: capitals, digits and a dot, 5 pixels tall.
enum PixelFont {
    private static let glyphs: [Character: [String]] = [
        "A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
        "C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
        "E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
        "G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
        "I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
        "K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
        "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"], "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
        "O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
        "Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
        "S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
        "U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
        "W": ["#...#", "#...#", "#.#.#", "##.##", "#...#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
        "Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
        "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#", "##", ".#", ".#", ".#"],
        "2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
        "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
        "6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
        "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
        ".": [".", ".", ".", ".", "#"], " ": ["..", "..", "..", "..", ".."],
    ]

    private static func glyph(_ character: Character) -> [String] { glyphs[character] ?? glyphs[" "]! }

    /// Width of `text` in pixels, one pixel between letters.
    static func width(_ text: String) -> Int {
        let letters = text.uppercased().map { glyph($0)[0].count }
        return letters.reduce(0, +) + max(0, letters.count - 1)
    }

    static func draw(_ text: String, on c: PixelCanvas, x: Int, y: Int, _ color: PixelColor) {
        var cursor = x
        for character in text.uppercased() {
            let rows = glyph(character)
            for (dy, row) in rows.enumerated() {
                for (dx, cell) in row.enumerated() where cell == "#" { c.dot(cursor + dx, y + dy, color) }
            }
            cursor += rows[0].count + 1
        }
    }
}
