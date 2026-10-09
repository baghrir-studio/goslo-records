import SwiftUI

/// Punchliner: a small pixel crowd under the verse that takes the line. Hands up, jumping, lighters and phones
/// for a punchline or a rich rhyme; heads nodding for a decent line; arms crossed (« bof ») for the rest.
struct PunchlineCrowd: View {
    let mood: PunchlineCrowdMood

    private static let people = 9
    /// Screen points per sprite pixel.
    private static let pixel: CGFloat = 3

    @State private var shown = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: mood == .meh)) { context in
            scene(at: context.date.timeIntervalSince(shown))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .background(
            LinearGradient(colors: [Color.clear, Color(red: 0.25, green: 0.05, blue: 0.2).opacity(mood == .hype ? 0.55 : 0.25)],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipped()
        .onAppear { shown = Date() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        switch mood {
        case .hype: "Le public lève les bras : ouais !"
        case .nod: "Le public hoche la tête."
        case .meh: "Le public croise les bras : bof."
        }
    }

    private func scene(at t: Double) -> some View {
        let width = CGFloat(CrowdSprite.width) * Self.pixel
        let height = CGFloat(CrowdSprite.height) * Self.pixel
        return ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<Self.people, id: \.self) { index in
                    member(index, at: t)
                        .frame(width: width, height: height)
                }
            }
            .padding(.bottom, -6)
            shout(at: t)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private func member(_ index: Int, at t: Double) -> some View {
        let width = CGFloat(CrowdSprite.width) * Self.pixel
        switch mood {
        case .hype:
            let jump = abs(sin(t * 7 + Double(index) * 0.9)) * 10
            ZStack(alignment: .top) {
                PixelImage(CrowdSprite.image(.cheer, palette: index), width: width)
                // Every other fan holds up a lighter or a phone, flickering.
                if index % 2 == 0 {
                    let lighter = index % 4 == 0
                    let on = sin(t * 11 + Double(index) * 2.1) > -0.3
                    Rectangle()
                        .fill(lighter ? Color(red: 1, green: 0.7, blue: 0.2) : Color.white)
                        .frame(width: Self.pixel * 2, height: Self.pixel * (lighter ? 2 : 3))
                        .shadow(color: lighter ? Color.orange : Color.white, radius: on ? 6 : 1)
                        .opacity(on ? 1 : 0.45)
                        .offset(x: -width / 2 + Self.pixel * 1.5, y: -Self.pixel * 3)
                }
            }
            .offset(y: -CGFloat(jump))
        case .nod:
            let down = Int(t * 2.4 + Double(index % 3) * 0.33) % 2 == 1
            PixelImage(CrowdSprite.image(down ? .nodDown : .nodUp, palette: index), width: width)
        case .meh:
            PixelImage(CrowdSprite.image(.crossed, palette: index), width: width)
        }
    }

    /// « OUAIS ! » pops up for a moment; « bof » hangs over the crossed arms.
    @ViewBuilder
    private func shout(at t: Double) -> some View {
        switch mood {
        case .hype:
            let pop = min(1, t / 0.18)
            Text("OUAIS !")
                .font(.display(30))
                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                .shadow(color: .black, radius: 0, x: 2, y: 2)
                .scaleEffect(0.6 + 0.4 * pop + 0.04 * sin(t * 14))
                .opacity(t < 1.8 ? 1 : max(0, 1 - (t - 1.8) / 0.4))
                .frame(maxHeight: .infinity, alignment: .top)
        case .meh:
            Text("bof")
                .font(.mono(14, weight: .heavy))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 24)
        case .nod:
            EmptyView()
        }
    }
}

/// A member of the Punchliner crowd (10×19 pixels): a few poses, a few outfits.
@MainActor
enum CrowdSprite {
    enum Pose: Int {
        case cheer, nodUp, nodDown, crossed
    }

    static let width = 10
    static let height = 19

    private static let outfits: [(skin: String, hair: String, top: String, bottom: String)] = [
        ("#e0ac7e", "#1b1b1f", "#c0392b", "#23232a"),
        ("#8d5524", "#141418", "#2f4a9a", "#141418"),
        ("#f1c9a5", "#b5651d", "#e8c547", "#2f4a7a"),
        ("#5a3825", "#0e0e10", "#4fd6e0", "#23232a"),
        ("#c68642", "#3b2416", "#e04fb0", "#141418"),
        ("#ffdbac", "#d8b25a", "#3a8f4a", "#2a2a30"),
        ("#a0672e", "#1b1b1f", "#f0eee8", "#3a3a44"),
    ]

    static func image(_ pose: Pose, palette: Int) -> UIImage {
        let outfit = palette % outfits.count
        return PixelCache.image("punch-crowd-\(pose.rawValue)-\(outfit)") {
            canvas(pose, outfit: outfits[outfit]).outlined().makeImage()
        }
    }

    private static func canvas(_ pose: Pose, outfit: (skin: String, hair: String, top: String, bottom: String)) -> PixelCanvas {
        let c = PixelCanvas(width: width, height: height)
        let skin = PixelColor(hex: outfit.skin), hair = PixelColor(hex: outfit.hair)
        let top = PixelColor(hex: outfit.top), bottom = PixelColor(hex: outfit.bottom)
        // Legs and torso.
        c.fill(3, 14, 4, 18, bottom)
        c.fill(5, 14, 6, 18, bottom)
        c.fill(2, 8, 7, 13, top)
        c.fill(2, 13, 7, 13, top.shaded(0.8))
        // Head (one pixel lower when nodding down), hair on top.
        let head = pose == .nodDown ? 4 : 3
        c.fill(4, 7, 5, 7, skin)
        c.fill(3, head, 6, head + 3, skin)
        c.fill(3, head, 6, head, hair)
        c.dot(3, head + 1, hair)
        c.dot(6, head + 1, hair)
        c.dot(4, head + 2, PixelColor(hex: "#141418"))
        c.dot(5, head + 2, PixelColor(hex: "#141418"))
        switch pose {
        case .cheer:
            // Arms straight up, hands open.
            c.fill(1, 2, 1, 8, top)
            c.fill(8, 2, 8, 8, top)
            c.fill(1, 0, 1, 1, skin)
            c.fill(8, 0, 8, 1, skin)
            c.dot(4, head + 3, PixelColor(hex: "#7a1f1f"))
        case .nodUp, .nodDown:
            c.fill(1, 8, 1, 12, top)
            c.fill(8, 8, 8, 12, top)
            c.dot(1, 13, skin)
            c.dot(8, 13, skin)
        case .crossed:
            // Shoulders, then the arms folded across the chest.
            c.fill(1, 8, 1, 10, top)
            c.fill(8, 8, 8, 10, top)
            c.fill(2, 10, 7, 11, top.shaded(0.7))
            c.dot(2, 11, skin)
            c.dot(7, 10, skin)
        }
        return c
    }
}
