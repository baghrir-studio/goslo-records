import SwiftUI

// Night atmosphere on the map: each city's weather, neon halos over the doors, light on the water,
// and a soft vignette. Drawn with Canvas (one pass per frame), never in the way of a tap.

/// Fractional part, for cheap repeatable "random" positions.
private func fract(_ x: Double) -> Double { x - floor(x) }
/// A stable pseudo-random value in 0..<1 for particle `index` and `salt`.
private func jitter(_ index: Int, _ salt: Double) -> Double { fract(sin(Double(index) * 12.9898 + salt * 78.233) * 43_758.5453) }

/// What falls (or floats) over each city at night.
enum Weather {
    case rain(intensity: Double)
    case snow
    /// Warm specks drifting up through the lamplight.
    case motes

    static func of(_ city: City) -> Weather {
        switch city {
        case .lille: .rain(intensity: 0.8)
        case .bruxelles: .rain(intensity: 0.55)
        case .montreal: .snow
        default: .motes
        }
    }
}

/// Screen-space layer over the map: weather, then a vignette that darkens the edges.
struct WeatherLayer: View {
    let weather: Weather

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    switch weather {
                    case .rain(let intensity): Self.rain(context, size, t, intensity)
                    case .snow: Self.snow(context, size, t)
                    case .motes: Self.motes(context, size, t)
                    }
                }
            }
            RadialGradient(colors: [.clear, .clear, Color.black.opacity(0.5)], center: .center,
                           startRadius: 40, endRadius: 520)
        }
        .allowsHitTesting(false)
    }

    private static func rain(_ context: GraphicsContext, _ size: CGSize, _ t: Double, _ intensity: Double) {
        let count = Int(140 * intensity)
        var streaks = Path()
        for index in 0..<count {
            let speed = 1.1 + jitter(index, 1) * 0.7
            let y = fract(jitter(index, 2) + t * speed) * (size.height + 60) - 30
            let x = fract(jitter(index, 3) + y / size.height * 0.08) * (size.width + 40) - 20
            let length = 10 + jitter(index, 4) * 10
            streaks.move(to: CGPoint(x: x, y: y))
            streaks.addLine(to: CGPoint(x: x - length * 0.18, y: y + length))
        }
        context.stroke(streaks, with: .color(Color(red: 0.75, green: 0.82, blue: 0.95).opacity(0.32)), lineWidth: 1)
        // Splashes on the ground: tiny rings that pop and fade.
        for index in 0..<Int(30 * intensity) {
            let phase = fract(jitter(index, 5) + t * 1.6)
            let x = jitter(index, 6) * size.width, y = jitter(index, 7) * size.height
            let r = 1 + phase * 5
            context.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.4, width: r * 2, height: r * 0.8)),
                           with: .color(.white.opacity(0.25 * (1 - phase))), lineWidth: 1)
        }
    }

    private static func snow(_ context: GraphicsContext, _ size: CGSize, _ t: Double) {
        for index in 0..<110 {
            let speed = 0.08 + jitter(index, 1) * 0.1
            let y = fract(jitter(index, 2) + t * speed) * (size.height + 20) - 10
            let sway = sin(t * (0.8 + jitter(index, 3)) + Double(index)) * 14
            let x = fract(jitter(index, 4)) * size.width + sway
            let r = 1 + jitter(index, 5) * 2.2
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(0.55 + jitter(index, 6) * 0.35)))
        }
    }

    private static func motes(_ context: GraphicsContext, _ size: CGSize, _ t: Double) {
        for index in 0..<40 {
            let speed = 0.015 + jitter(index, 1) * 0.03
            let y = (1 - fract(jitter(index, 2) + t * speed)) * size.height
            let x = jitter(index, 3) * size.width + sin(t * 0.7 + Double(index)) * 10
            let twinkle = 0.5 + 0.5 * sin(t * (1.5 + jitter(index, 4) * 2) + Double(index))
            let r = 0.8 + jitter(index, 5) * 1.4
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(Color(red: 1, green: 0.85, blue: 0.5).opacity(0.15 + 0.35 * twinkle)))
        }
    }
}

/// Map-space layer: each door's neon throws a colored halo on the pavement, the metro glows blue,
/// and light ripples run across the water.
struct MapLights: View {
    let map: WorldMap

    var body: some View {
        let tile = WorldView.tile
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                var glow = context
                glow.blendMode = .screen
                for (index, door) in map.doors.enumerated() {
                    let pulse = 0.75 + 0.25 * sin(t * 2.2 + Double(index) * 1.7)
                    let color = Color(uiColor: door.location.neon.uiColor)
                    halo(glow, at: CGPoint(x: (CGFloat(door.x) + 0.5) * tile, y: (CGFloat(door.y) + 0.9) * tile),
                         radius: tile * 1.5, color: color.opacity(0.32 * pulse))
                    halo(glow, at: CGPoint(x: (CGFloat(door.x) + 0.5) * tile, y: CGFloat(door.y) * tile + 4),
                         radius: tile * 0.7, color: color.opacity(0.45 * pulse))
                }
                if let metro = map.metro {
                    halo(glow, at: CGPoint(x: (CGFloat(metro.x) + 0.5) * tile, y: (CGFloat(metro.y) + 0.8) * tile),
                         radius: tile * 1.4, color: Color(red: 0.25, green: 0.5, blue: 1).opacity(0.35))
                }
                // Moonlight on the water: short bright dashes drifting along each water tile.
                var ripples = Path()
                for y in 0..<map.height {
                    for x in 0..<map.width where map.tile(at: TilePoint(x: x, y: y)) == .water {
                        for k in 0..<2 {
                            let seed = x * 31 + y * 17 + k * 7
                            let phase = fract(jitter(seed, 1) + t * (0.12 + jitter(seed, 2) * 0.1))
                            let px = (CGFloat(x) + CGFloat(phase)) * tile
                            let py = (CGFloat(y) + 0.25 + CGFloat(jitter(seed, 3)) * 0.6) * tile
                            ripples.move(to: CGPoint(x: px, y: py))
                            ripples.addLine(to: CGPoint(x: px + tile * 0.22, y: py))
                        }
                    }
                }
                glow.stroke(ripples, with: .color(Color(red: 0.75, green: 0.85, blue: 1).opacity(0.45)), lineWidth: 2)
            }
        }
        .frame(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile)
        .allowsHitTesting(false)
    }

    private func halo(_ context: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect),
                     with: .radialGradient(Gradient(colors: [color, .clear]), center: center, startRadius: 0, endRadius: radius))
    }
}
