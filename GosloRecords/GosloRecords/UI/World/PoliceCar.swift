import SwiftUI

/// Scenery: now and then a police car drives along the main road, lights flashing,
/// a siren far away. Nothing happens, it just passes.
struct PassingPoliceCar: View {
    @Environment(AppModel.self) private var model
    let map: WorldMap
    /// A lane with something parked on it: the car takes the other one.
    var avoidRow: Int? = nil

    /// Seconds between two passes (picked at random), and how long one takes.
    static let interval = 70.0...140.0
    static let crossing = 4.5

    private struct Run: Equatable {
        let row: Int
        let rightward: Bool
        var progress: CGFloat = 0
    }

    @State private var run: Run?
    @State private var lightsOn = false

    /// Rows that are road from one edge to the other (top lane drives left, bottom lane drives right).
    private var lanes: [Int] {
        (0..<map.height).filter { y in
            (1..<(map.width - 1)).allSatisfy {
                let tile = map.tile(at: TilePoint(x: $0, y: y))
                return tile == .asphalt || tile == .crosswalk
            }
        }
    }

    var body: some View {
        let tile = WorldView.tile
        ZStack(alignment: .topLeading) {
            if let run {
                let travel = CGFloat(map.width + 4) * tile
                let x = -2 * tile + travel * (run.rightward ? run.progress : 1 - run.progress)
                PixelImage(PoliceCarArt.image(lightsOn: lightsOn, facingRight: run.rightward), width: tile * 1.7)
                    .position(x: x, y: (CGFloat(run.row) + 0.45) * tile)
            }
        }
        .frame(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await drive() }
    }

    private func drive() async {
        guard let top = lanes.first, let bottom = lanes.last else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: Self.interval)))
            // Only while the player is walking around: never during a card, a clash or a cinematic.
            guard model.phase == .overworld, !model.letterbox else { continue }
            var rightward = Bool.random()
            if (rightward ? bottom : top) == avoidRow { rightward.toggle() }
            run = Run(row: rightward ? bottom : top, rightward: rightward)
            SoundEngine.shared.play(.siren)
            withAnimation(.linear(duration: Self.crossing)) { run?.progress = 1 }
            for _ in 0..<Int(Self.crossing / 0.25) {
                try? await Task.sleep(for: .milliseconds(250))
                lightsOn.toggle()
            }
            run = nil
        }
    }
}

/// The car, side view, 24×14 pixels: white body, blue stripe, light bar.
@MainActor
enum PoliceCarArt {
    static func image(lightsOn: Bool, facingRight: Bool) -> UIImage {
        PixelCache.image("police-\(lightsOn)-\(facingRight)") {
            let canvas = car(lightsOn: lightsOn).outlined()
            return (facingRight ? canvas : canvas.mirrored()).makeImage()
        }
    }

    private static func car(lightsOn: Bool) -> PixelCanvas {
        let c = PixelCanvas(width: 24, height: 14)
        let body = PixelColor(hex: "#e8e8ee"), shade = PixelColor(hex: "#b8b8c4")
        let stripe = PixelColor(hex: "#2f4a9a"), glass = PixelColor(hex: "#1c2a3a")
        let red = PixelColor(hex: "#ff3b30"), blue = PixelColor(hex: "#3b7bff")
        // Body and cabin.
        c.fill(1, 6, 22, 10, body)
        c.fill(1, 10, 22, 10, shade)
        c.fill(6, 3, 16, 6, body)
        c.fill(7, 4, 10, 5, glass)
        c.fill(12, 4, 15, 5, glass)
        c.fill(1, 8, 22, 8, stripe)
        // Light bar: red and blue swap sides.
        c.fill(9, 2, 10, 2, lightsOn ? red : blue)
        c.fill(11, 2, 12, 2, lightsOn ? blue : red)
        // Headlight and rear light.
        c.dot(22, 7, PixelColor(hex: "#ffe27a"))
        c.dot(1, 7, red.shaded(0.7))
        // Wheels.
        for x in [5, 18] {
            c.circle(cx: x, cy: 11, radius: 2, PixelColor(hex: "#141418"))
            c.dot(x, 11, PixelColor(hex: "#8a8a96"))
        }
        return c
    }
}

/// Casablanca scenery: a red petit taxi parked at the curb (`OverworldRules.parkedTaxi`), engine idling.
struct ParkedTaxi: View {
    @State private var idle = false

    var body: some View {
        let tile = WorldView.tile
        let spots = OverworldRules.parkedTaxi
        let x = (CGFloat(spots.map(\.x).reduce(0, +)) / CGFloat(spots.count) + 0.5) * tile
        let y = (CGFloat(spots[0].y) + 0.55) * tile
        PixelImage(TaxiArt.image(facingRight: false), width: tile * 1.6)
            .offset(y: idle ? -0.6 : 0)
            .position(x: x, y: y)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) { idle = true }
            }
    }
}

/// The petit taxi, side view, 24×14 pixels: a small boxy red hatchback, black bumpers,
/// and on the roof a black panel with its number in yellow.
@MainActor
enum TaxiArt {
    static func image(facingRight: Bool) -> UIImage {
        PixelCache.image("taxi3-\(facingRight)") {
            let canvas = car().outlined()
            return (facingRight ? canvas : canvas.mirrored()).makeImage()
        }
    }

    private static func car() -> PixelCanvas {
        let c = PixelCanvas(width: 24, height: 14)
        let red = PixelColor(hex: "#d42a2a"), shade = PixelColor(hex: "#a01c1e"), light = PixelColor(hex: "#ec5a50")
        let glass = PixelColor(hex: "#1c2632"), black = PixelColor(hex: "#16161a"), yellow = PixelColor(hex: "#f2c81e")
        // Lower body, long and flat.
        c.fill(1, 7, 22, 10, red)
        c.fill(1, 7, 22, 7, light)
        c.fill(2, 10, 21, 10, shade)
        // Boxy cabin: straight hatch at the back (left), sloped windscreen at the front (right).
        c.fill(3, 3, 16, 6, red)
        c.fill(17, 4, 17, 6, red)
        c.fill(18, 5, 18, 6, red)
        // Windows: hatch, rear side, door, windscreen.
        c.fill(4, 4, 5, 5, glass)
        c.fill(7, 4, 10, 5, glass)
        c.fill(12, 4, 15, 5, glass)
        c.dot(16, 4, glass); c.fill(16, 5, 17, 5, glass)
        // Door line and handle.
        c.fill(11, 6, 11, 9, shade)
        c.dot(13, 7, shade)
        // Roof panel: black, with the taxi number in yellow.
        c.fill(4, 0, 15, 2, black)
        for x in [6, 9, 12] { c.fill(x, 1, x + 1, 1, yellow) }
        // Black bumpers, lights.
        c.fill(21, 8, 23, 10, black)
        c.fill(0, 8, 1, 10, black)
        c.dot(22, 7, PixelColor(hex: "#fff2b0"))
        c.dot(1, 7, PixelColor(hex: "#ff3b30").shaded(0.8))
        // Wheels.
        for x in [6, 18] {
            c.circle(cx: x, cy: 11, radius: 2, black)
            c.dot(x, 11, PixelColor(hex: "#8a8a96"))
        }
        return c
    }
}
