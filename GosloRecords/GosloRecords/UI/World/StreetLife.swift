import SwiftUI

/// The streets as the artist grows (see `StreetBuzz`): people strolling on the sidewalks, tags with the
/// artist's name on the walls, fans waiting by the door. Drawn under the characters, never in the way:
/// none of them is an NPC or an obstacle, the player walks right through.
struct StreetLife: View {
    let map: WorldMap
    let buzz: StreetBuzz
    let name: String
    /// The people (passers-by, fans) step aside during cinematics; the tags stay.
    var people = true

    var body: some View {
        let tile = WorldView.tile
        let tag = StreetBuzz.tagText(for: name)
        let walls = map.tagWalls(posters: buzz.posters, count: buzz.tags)
        let strolls = people ? map.strolls(count: buzz.passersBy) : []
        let fans = people ? map.fanSpots(count: buzz.fans) : []
        ZStack(alignment: .topLeading) {
            ForEach(Array(walls.enumerated()), id: \.offset) { index, wall in
                let image = StreetTag.image(tag, color: index)
                PixelImage(image, width: image.size.width * 2)
                    .rotationEffect(.degrees(index % 2 == 0 ? -4 : 3))
                    .position(x: (CGFloat(wall.x) + 0.5) * tile, y: (CGFloat(wall.y) + 0.55) * tile)
            }
            if !strolls.isEmpty || !fans.isEmpty {
                TimelineView(.animation(minimumInterval: 1 / 12)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(strolls.enumerated()), id: \.offset) { index, stroll in
                            passer(index, stroll, at: t)
                        }
                        ForEach(Array(fans.enumerated()), id: \.offset) { index, spot in
                            fan(index, at: spot, tag: tag, t: t)
                        }
                    }
                    .frame(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile, alignment: .topLeading)
                }
            }
        }
        .frame(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Up and down a stretch of sidewalk, at a stroll.
    private func passer(_ index: Int, _ stroll: Stroll, at t: Double) -> some View {
        let tile = WorldView.tile
        let length = Double(max(1, stroll.to - stroll.from))
        let period = 2 * length / 1.3
        let phase = (t / period + Double(index) * 0.37).truncatingRemainder(dividingBy: 1)
        let right = phase < 0.5
        let x = Double(stroll.from) + length * (right ? phase * 2 : 2 - phase * 2)
        let look = CharacterLook.streetCrowd[(index + 2) % CharacterLook.streetCrowd.count]
        return SpriteView(look: look, facing: right ? .right : .left, frame: Int(t * 6) % 2 + 1)
            .position(x: (CGFloat(x) + 0.5) * tile, y: (CGFloat(stroll.y) + 0.5) * tile - 8)
    }

    /// A fan waiting by the door, turned toward it, hopping now and then; the first one holds up a sign.
    private func fan(_ index: Int, at spot: TilePoint, tag: String, t: Double) -> some View {
        let tile = WorldView.tile
        let dx = map.spawn.x - spot.x, dy = map.spawn.y - spot.y
        let facing: Direction = abs(dx) >= abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
        let excited = sin(t * 0.9 + Double(index) * 1.7) > 0.55
        let hop = excited ? abs(sin(t * 9 + Double(index))) * 7 : 0
        return ZStack {
            SpriteView(look: CharacterLook.streetCrowd[index % CharacterLook.streetCrowd.count], facing: facing,
                       frame: excited ? 1 : 0)
            if index == 0 {
                Text("♥ \(tag)")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(Theme.accent, lineWidth: 1))
                    .offset(y: -tile * 0.62)
            }
        }
        .offset(y: -CGFloat(hop))
        .position(x: (CGFloat(spot.x) + 0.5) * tile, y: (CGFloat(spot.y) + 0.5) * tile - 8)
    }
}

/// The artist's name sprayed on a wall: pixel capitals, a dark shadow, a few drips.
@MainActor
enum StreetTag {
    private static let paints = ["#ff4d2e", "#4fd6e0", "#e8c547", "#e04fb0", "#7bd88f"].map(PixelColor.init(hex:))

    static func image(_ text: String, color: Int) -> UIImage {
        let paint = paints[color % paints.count]
        return PixelCache.image("street-tag-\(text)-\(color % paints.count)") {
            let c = PixelCanvas(width: PixelFont.width(text) + 4, height: 11)
            PixelFont.draw(text, on: c, x: 2, y: 3, paint.shaded(0.45))
            PixelFont.draw(text, on: c, x: 1, y: 2, paint)
            // Drips under a few letters.
            var noise = PixelNoise(text.count, color, salt: 61)
            for x in stride(from: 2, to: c.width - 2, by: 3) where noise.chance(40) {
                let length = 1 + noise.next(3)
                c.fill(x, 7, x, 7 + length, paint)
            }
            return c.outlined().makeImage()
        }
    }
}

extension CharacterLook {
    /// Everyday people: the fans in the chase, the passers-by and the fans on the map.
    static let streetCrowd: [CharacterLook] = [
        CharacterLook(skin: "#e0ac7e", top: "#c0392b", bottom: "#23232a", hat: .cap),
        CharacterLook(skin: "#8d5524", top: "#2f4a9a", bottom: "#141418", hairStyle: .puff),
        CharacterLook(skin: "#f1c9a5", top: "#e8c547", bottom: "#2f4a7a", hairStyle: .long),
        CharacterLook(skin: "#5a3825", top: "#4fd6e0", bottom: "#23232a", hat: .beanie),
        CharacterLook(skin: "#c68642", top: "#e04fb0", bottom: "#141418", glasses: true),
    ]
}
