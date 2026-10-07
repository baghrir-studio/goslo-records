import SwiftUI

/// Full-screen transition, depending on the type.
struct TransitionOverlay: View {
    let transition: WorldTransition

    var body: some View {
        switch transition {
        case .fade:
            Color.black.ignoresSafeArea()
        case .battle:
            BattleWipe()
        case .semester(let title, let subtitle):
            SemesterCard(title: title, subtitle: subtitle)
        case .metro(let district):
            MetroRide(district: district)
        }
    }
}

/// Black and red bars sweeping in from both sides before a clash.
private struct BattleWipe: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let count = 10
            let barHeight = geo.size.height / CGFloat(count)
            ZStack(alignment: .topLeading) {
                ForEach(0..<count, id: \.self) { index in
                    Rectangle()
                        .fill(index % 2 == 0 ? Color.black : Theme.accent)
                        .frame(width: geo.size.width, height: barHeight + 1)
                        .offset(x: (index % 2 == 0 ? -1 : 1) * geo.size.width * (1 - progress),
                                y: CGFloat(index) * barHeight)
                }
                Text("CLASH")
                    .font(.display(72))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 0, x: 4, y: 4)
                    .scaleEffect(progress)
                    .opacity(Double(progress))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeOut(duration: 0.45)) { progress = 1 } }
    }
}

/// Title card at the start of each semester.
private struct SemesterCard: View {
    let title: String
    let subtitle: String
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Text(title)
                    .font(.display(86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(.white)
                    .offset(y: shown ? 0 : 30)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: shown ? 120 : 0, height: 5)
                Text(subtitle)
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .opacity(shown ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) { shown = true } }
    }
}

/// Inside a building: the pixel room, the character you meet, you at the entrance.
struct InteriorView: View {
    let location: Location
    let npc: CharacterLook?
    let player: CharacterLook
    var showsBanner = true
    @State private var bannerIn = false

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / CGFloat(TileArt.interiorSize.width * TileArt.size)
            let tile = CGFloat(TileArt.size) * scale
            // The room sits just below the HUD (stats + year), above the dialogue box.
            let top: CGFloat = 185
            ZStack(alignment: .topLeading) {
                Color.black
                ZStack(alignment: .topLeading) {
                    PixelImage(TileArt.interior(location), width: geo.size.width)
                    if let npc {
                        SpriteView(look: npc, facing: .down, size: tile * 1.3)
                            .position(x: tile * 5, y: tile * 3.6)
                    }
                    SpriteView(look: player, facing: .up, size: tile * 1.3)
                        .position(x: tile * 5, y: tile * 6.2)
                }
                .offset(y: top)
                Text(location.name.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.85))
                    .overlay(Rectangle().stroke(Color(uiColor: location.neon.uiColor), lineWidth: 2))
                    .position(x: geo.size.width / 2, y: top + tile * 0.6)
                    .offset(y: bannerIn ? 0 : -80)
                    .opacity(showsBanner ? 1 : 0)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) { bannerIn = true } }
    }
}

/// A metro ride: the train rushes through the tunnel, then the district's name lands.
private struct MetroRide: View {
    let district: District
    @State private var passing = false
    @State private var named = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06)
                // Tunnel lights streaking past.
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<6, id: \.self) { index in
                            let x = (1 - (t * 2.4 + Double(index) / 6).truncatingRemainder(dividingBy: 1)) * (w + 120) - 60
                            Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.5).opacity(0.5))
                                .frame(width: 60, height: 4)
                                .position(x: x, y: h * 0.3)
                        }
                    }
                }
                // The train: a long carriage with lit windows.
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        ZStack {
                            Rectangle().fill(Color(red: 0.75, green: 0.78, blue: 0.82))
                            HStack(spacing: 10) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Rectangle().fill(Color(red: 1, green: 0.88, blue: 0.55)).frame(width: 34, height: 26)
                                }
                            }
                            Rectangle().fill(Theme.accent).frame(height: 8).offset(y: 30)
                        }
                        .frame(width: 300, height: 90)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                    }
                }
                .position(x: passing ? -500 : w + 500, y: h * 0.5)

                VStack(spacing: 10) {
                    Text("Ⓜ︎ \(district.name.uppercased())")
                        .font(.display(60))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .foregroundStyle(.white)
                        .shadow(color: Theme.accent, radius: 0, x: 4, y: 4)
                    Rectangle().fill(Theme.accent).frame(width: named ? 140 : 0, height: 5)
                    Text(district.tagline)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 24)
                .opacity(named ? 1 : 0)
                .scaleEffect(named ? 1 : 1.3)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1)) { passing = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(1.0)) { named = true }
        }
    }
}
