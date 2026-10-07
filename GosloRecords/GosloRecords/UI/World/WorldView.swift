import SwiftUI

/// The neighbourhood seen from above: map, characters, lights, camera that follows the player.
struct WorldView: View {
    @Environment(AppModel.self) private var model
    let map: WorldMap
    let state: GameState

    static let tile: CGFloat = 48

    var body: some View {
        let tile = WorldView.tile
        let markers = model.engine.questMarkers(in: state)
        let objectiveDoor = model.objective?.trigger?.location
        let objectiveNPC = model.objective?.trigger?.npc

        GeometryReader { geo in
            let camera = cameraOffset(viewport: geo.size)
            ZStack(alignment: .topLeading) {
                // The horizon above the neighbourhood (landmarks stand there, never on a building).
                PixelImage(TileArt.skyline(city: state.rapper.city, width: map.width), width: CGFloat(map.width) * tile,
                           height: skyHeight)
                    .offset(y: -skyHeight)
                PixelImage(TileArt.mapImage(map, city: state.rapper.city), width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile)

                LampGlows(map: map)

                ForEach(map.doors, id: \.location) { door in
                    DoorSign(location: door.location, hasQuest: markers.contains(door.location),
                             isObjective: objectiveDoor == door.location)
                        .position(x: (CGFloat(door.x) + 0.5) * tile, y: CGFloat(door.y) * tile - 2)
                }

                if markers.contains(.quartier) {
                    ForEach(benches, id: \.self) { bench in
                        QuestMarker()
                            .position(x: (CGFloat(bench.x) + 0.5) * tile, y: CGFloat(bench.y) * tile - 4)
                    }
                }

                ForEach(map.npcs.filter { !model.hiddenActors.contains($0.id) }) { npc in
                    npcSprite(npc.id, at: model.npcPositions[npc.id] ?? npc.point,
                              facing: model.npcFacing[npc.id] ?? npc.facing, isObjective: objectiveNPC == npc.id)
                }

                // Rare scenery on the main road (rows 6–7): drawn above the people on the sidewalk behind it.
                PassingPoliceCar(map: map)
                    .zIndex(7.7)
                if state.rapper.city == .casablanca {
                    PassingTaxi(map: map)
                        .zIndex(7.7)
                }

                ForEach(model.extraActors.sorted { $0.key < $1.key }, id: \.key) { id, point in
                    npcSprite(id, at: point, facing: model.npcFacing[id] ?? .down, isObjective: false)
                }

                ZStack {
                    SpriteView(look: state.rapper.look, facing: model.facing, frame: model.walkFrame)
                    if model.exclaiming == "player" {
                        ExclamationBubble()
                            .offset(y: -WorldView.tile * 0.85)
                            .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                    }
                }
                .position(spritePosition(model.position))
                .zIndex(Double(model.position.y) + 0.5)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: model.exclaiming)
            }
            .frame(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile, alignment: .topLeading)
            .offset(x: camera.width, y: camera.height)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
    }

    private var benches: [TilePoint] {
        (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x in map.tile(at: TilePoint(x: x, y: y)) == .bench ? TilePoint(x: x, y: y) : nil }
        }
    }

    @ViewBuilder
    private func npcSprite(_ id: String, at point: TilePoint, facing: Direction, isObjective: Bool) -> some View {
        if let member = model.engine.castMember(id) {
            ZStack {
                SpriteView(look: member.look, facing: facing, frame: model.npcWalkFrame[id] ?? 0)
                if model.exclaiming == id {
                    ExclamationBubble()
                        .offset(y: -WorldView.tile * 0.85)
                        .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                } else if isObjective && model.phase == .overworld {
                    ObjectiveMarker()
                        .offset(y: -WorldView.tile * 0.8)
                }
            }
            .position(spritePosition(point))
            .zIndex(Double(point.y))
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: model.exclaiming)
        }
    }

    private func spritePosition(_ point: TilePoint) -> CGPoint {
        CGPoint(x: (CGFloat(point.x) + 0.5) * WorldView.tile, y: (CGFloat(point.y) + 0.5) * WorldView.tile - 8)
    }

    /// The sky band drawn above row 0.
    private var skyHeight: CGFloat { CGFloat(TileArt.skyRows) * WorldView.tile }

    /// Centers the player, without going past the edges of the map (the sky band counts as map at the top).
    private func cameraOffset(viewport: CGSize) -> CGSize {
        let tile = WorldView.tile
        let mapSize = CGSize(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile)
        let focus = model.cameraFocus ?? model.position
        let center = CGPoint(x: (CGFloat(focus.x) + 0.5) * tile, y: (CGFloat(focus.y) + 0.5) * tile)
        func clamp(_ value: CGFloat, view: CGFloat, content: CGFloat) -> CGFloat {
            guard content > view else { return (view - content) / 2 }
            return min(0, max(view - content, value))
        }
        // In a cinematic, the subject sits higher (the caption covers the bottom)
        // and the camera may go a little past the bottom edge of the map.
        let anchor: CGFloat = model.letterbox ? 0.32 : 0.45
        let overscroll: CGFloat = model.letterbox ? viewport.height * 0.35 : 0
        let vertical = clamp(viewport.height * anchor - (center.y + skyHeight), view: viewport.height - overscroll,
                             content: mapSize.height + skyHeight) + skyHeight
        return CGSize(width: clamp(viewport.width / 2 - center.x, view: viewport.width, content: mapSize.width),
                      height: vertical)
    }
}

/// A character drawn at the scale of a tile.
struct SpriteView: View {
    let look: CharacterLook
    let facing: Direction
    var frame = 0
    var size: CGFloat = WorldView.tile

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(.black.opacity(0.35))
                .frame(width: size * 0.6, height: size * 0.16)
                .offset(y: -size * 0.02)
            PixelImage(CharacterSprite.image(look, facing: facing, frame: frame), width: size)
        }
        .frame(width: size, height: size)
    }
}

private struct LampGlows: View {
    let map: WorldMap
    @State private var flicker = false

    var body: some View {
        let tile = WorldView.tile
        ForEach(lamps, id: \.self) { lamp in
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.82, blue: 0.48).opacity(0.35), .clear],
                                     center: .center, startRadius: 2, endRadius: tile * 1.6))
                .frame(width: tile * 3.2, height: tile * 3.2)
                .position(x: (CGFloat(lamp.x) + 0.5) * tile, y: (CGFloat(lamp.y) + 0.2) * tile)
                .opacity(flicker ? 0.85 : 1)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { flicker = true }
        }
    }

    private var lamps: [TilePoint] {
        (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x in map.tile(at: TilePoint(x: x, y: y)) == .lamp ? TilePoint(x: x, y: y) : nil }
        }
    }
}

private struct DoorSign: View {
    let location: Location
    let hasQuest: Bool
    var isObjective = false

    var body: some View {
        VStack(spacing: 2) {
            if isObjective { ObjectiveMarker() } else if hasQuest { QuestMarker() }
            Text(location.name.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.85))
                .overlay(Rectangle().stroke(Color(uiColor: location.neon.uiColor), lineWidth: 1))
        }
        .allowsHitTesting(false)
    }
}

/// Bouncing "!" above a place or a character.
struct QuestMarker: View {
    @State private var bounce = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(45))
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2).rotationEffect(.degrees(45)))
            Text("!")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.background)
        }
        .offset(y: bounce ? -4 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { bounce = true }
            }
    }
}

private struct ExclamationBubble: View {
    var body: some View {
        Text("!")
            .font(.system(size: 22, weight: .black, design: .monospaced))
            .foregroundStyle(Theme.accent)
            .frame(width: 26, height: 30)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
    }
}

extension PixelColor {
    var uiColor: UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

/// Character walking in place (menus, character creation).
struct WalkingSprite: View {
    let look: CharacterLook
    var facing: Direction = .down
    var size: CGFloat = 96

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.22)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.22)
            SpriteView(look: look, facing: facing, frame: [1, 0, 2, 0][tick % 4], size: size)
        }
    }
}

/// Gold star bouncing above the main story objective.
struct ObjectiveMarker: View {
    @State private var bounce = false

    var body: some View {
        Text("★")
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
            .shadow(color: .black, radius: 0, x: 2, y: 2)
            .scaleEffect(bounce ? 1.15 : 0.95)
            .offset(y: bounce ? -5 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { bounce = true }
            }
    }
}
