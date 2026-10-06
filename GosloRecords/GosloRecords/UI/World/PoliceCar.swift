import SwiftUI

/// Scenery: now and then a police car drives along the main road, lights flashing,
/// a siren far away. Nothing happens, it just passes.
struct PassingPoliceCar: View {
    @Environment(AppModel.self) private var model
    let map: WorldMap

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
            let rightward = Bool.random()
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
