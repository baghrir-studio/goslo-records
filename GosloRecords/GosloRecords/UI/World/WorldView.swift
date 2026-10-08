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
                PixelImage(TileArt.mapImage(map, city: state.rapper.city, district: state.district), width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile)

                LampGlows(map: map)
                MapLights(map: map, transit: Transit.of(state.rapper.city))
                FameMarks(map: map, look: state.rapper.look, posters: model.engine.fame(in: state) * 2,
                          fresco: model.engine.hasFresco(in: state))

                ForEach(map.doors, id: \.location) { door in
                    DoorSign(location: door.location, name: door.location.name(in: state.district),
                             hasQuest: markers.contains(door.location), isObjective: objectiveDoor == door.location)
                        .position(x: (CGFloat(door.x) + 0.5) * tile, y: CGFloat(door.y) * tile - 2)
                }
                // goslo radio's pixel logo glowing on the radio's roof.
                ForEach(map.doors.filter { $0.location == .media }, id: \.location) { door in
                    let neon = Color(uiColor: Location.media.neon.uiColor)
                    RadioLogo(pixel: 1.6, color: neon)
                        .shadow(color: neon.opacity(0.8), radius: 6)
                        .padding(5)
                        .background(Color.black.opacity(0.55))
                        .overlay(Rectangle().stroke(neon.opacity(0.6), lineWidth: 1))
                        .position(x: (CGFloat(door.x) + 0.5) * tile, y: (CGFloat(door.y) - 2.6) * tile)
                        .allowsHitTesting(false)
                }
                if let metro = map.metro {
                    MetroSign(transit: Transit.of(state.rapper.city), isObjective: model.objectiveDistrict != nil)
                        .position(x: (CGFloat(metro.x) + 0.5) * tile, y: CGFloat(metro.y) * tile - 2)
                }

                if markers.contains(.quartier) {
                    ForEach(benches, id: \.self) { bench in
                        QuestMarker()
                            .position(x: (CGFloat(bench.x) + 0.5) * tile, y: CGFloat(bench.y) * tile - 4)
                    }
                }

                // The free spots for decorations: a chalk outline while empty, the decoration once bought.
                ForEach(map.decorPlots) { plot in
                    DecorSpot(decor: state.decor[plot.id])
                        .position(decorPosition(plot, decor: state.decor[plot.id]))
                        .zIndex(Double(plot.y) + 0.3)
                }

                if let spot = model.happening {
                    HappeningMarker(kind: spot.kind)
                        .position(spritePosition(spot.point))
                        .zIndex(Double(spot.point.y) + 0.4)
                        .transition(.scale.combined(with: .opacity))
                }

                ForEach(map.npcs.filter { !model.hiddenActors.contains($0.id) }) { npc in
                    npcSprite(npc.id, at: model.npcPositions[npc.id] ?? npc.point,
                              facing: model.npcFacing[npc.id] ?? npc.facing, isObjective: objectiveNPC == npc.id)
                }

                // Rare scenery on the main road (rows 6–7): drawn above the people on the sidewalk behind it.
                PassingPoliceCar(map: map, avoidRow: taxiParked ? OverworldRules.parkedTaxi.first?.y : nil)
                    .zIndex(7.7)
                if taxiParked {
                    ParkedTaxi()
                        .frame(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile, alignment: .topLeading)
                        .zIndex(Double(OverworldRules.parkedTaxi[0].y) + 0.6)
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
            .overlay { WeatherLayer(weather: Weather.of(state.rapper.city)) }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
    }

    /// Casablanca's petit taxi waits on Le Bloc's main road.
    private var taxiParked: Bool { state.rapper.city == .casablanca && state.district == .bloc }

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

    /// A decoration stands on its tile (bottom edges together); a wide one (the food truck) starts at the tile's
    /// left edge and runs over the next tile. An empty spot's outline is centred on the tile.
    private func decorPosition(_ plot: MapPlot, decor: Decor?) -> CGPoint {
        let tile = WorldView.tile
        // The painted piece lies flat on the ground: centred like the empty outline.
        guard let decor, decor != .fresque else {
            return CGPoint(x: (CGFloat(plot.x) + 0.5) * tile, y: (CGFloat(plot.y) + 0.5) * tile)
        }
        let size = DecorSpot.size(of: decor)
        let x = size.width > tile ? CGFloat(plot.x) * tile + size.width / 2 : (CGFloat(plot.x) + 0.5) * tile
        return CGPoint(x: x, y: CGFloat(plot.y + 1) * tile - size.height / 2 - 2)
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

    /// From this size up, front and back views use the detailed sprite (the map, at 48, keeps the 16×16 one).
    static let detailedFrom: CGFloat = 60

    private var detailed: Bool { size >= SpriteView.detailedFrom && (facing == .down || facing == .up) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(.black.opacity(0.35))
                .frame(width: size * 0.6, height: size * 0.16)
                .offset(y: -size * 0.02)
            if detailed {
                PixelImage(HeroSprite.image(look, facing: facing, frame: frame),
                           width: size * CGFloat(HeroSprite.width) / CGFloat(HeroSprite.height), height: size)
            } else {
                PixelImage(CharacterSprite.image(look, facing: facing, frame: frame), width: size)
            }
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
    let name: String
    let hasQuest: Bool
    var isObjective = false

    var body: some View {
        VStack(spacing: 2) {
            if isObjective { ObjectiveMarker() } else if hasQuest { QuestMarker() }
            Text(name.uppercased())
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

/// The career on the walls: posters of the player (more as the streams grow), and a fresco on the
/// laundromat once the Baron has fallen. Only on front walls, away from the shop fronts.
private struct FameMarks: View {
    let map: WorldMap
    let look: CharacterLook
    let posters: Int
    let fresco: Bool

    private var spots: [TilePoint] {
        (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x -> TilePoint? in
                let point = TilePoint(x: x, y: y), below = map.tile(at: point.moved(.down))
                guard map.tile(at: point) == .wall, below != .wall, below != .door, below != .metro,
                      !map.doors.contains(where: { $0.y == y && abs($0.x - x) <= 2 }),
                      !(map.metro.map { $0.y == y && abs($0.x - x) <= 2 } ?? false) else { return nil }
                return point
            }
        }
    }

    var body: some View {
        let tile = WorldView.tile
        ZStack(alignment: .topLeading) {
            ForEach(Array(spots.prefix(posters).enumerated()), id: \.offset) { index, spot in
                PixelImage(HeroSprite.bust(look), width: tile * 0.62)
                    .padding(3)
                    .background(index % 2 == 0 ? Theme.accent : Color(red: 1, green: 0.85, blue: 0.3))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                    .rotationEffect(.degrees(index % 2 == 0 ? -4 : 3))
                    .position(x: (CGFloat(spot.x) + 0.5) * tile, y: (CGFloat(spot.y) + 0.45) * tile)
            }
            if fresco, let door = map.doors.first(where: { $0.location == .label }) {
                ZStack {
                    LinearGradient(colors: [Theme.accent, Color(red: 0.31, green: 0.84, blue: 0.88), Color(red: 1, green: 0.85, blue: 0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .opacity(0.85)
                    HStack(spacing: 4) {
                        PixelImage(HeroSprite.image(look, facing: .down), width: tile * 0.95)
                        Text("GOSLO\nFOREVER")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 0, x: 1, y: 1)
                    }
                }
                .frame(width: tile * 2.6, height: tile * 1.7)
                .clipped()
                .position(x: (CGFloat(door.x) + 2.5) * tile, y: CGFloat(door.y) * tile)
            }
        }
        .frame(width: CGFloat(map.width) * tile, height: CGFloat(map.height) * tile, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The metro entrance's sign (marked when the objective is in another district).
private struct MetroSign: View {
    let transit: Transit
    let isObjective: Bool

    var body: some View {
        VStack(spacing: 2) {
            if isObjective { ObjectiveMarker() }
            Text(transit.sign)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(transit.color)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
        }
        .allowsHitTesting(false)
    }
}

extension Location {
    /// The sign over the door: the same place can wear another name in another district.
    func name(in district: District) -> String {
        switch (self, district) {
        case (.scene, .dome): "Le Dôme"
        case (.scene, .centre): "Le Transfo"
        case (.media, .hauts): "La Tour goslo"
        default: name
        }
    }
}

/// A free spot for a decoration: a dashed chalk square while it's empty, the decoration's sprite once it's bought.
/// You walk over it either way (it never blocks a path).
private struct DecorSpot: View {
    let decor: Decor?

    /// The sprite's size on the map (16 pixels per tile).
    static func size(of decor: Decor) -> CGSize {
        let image = DecorArt.image(decor)
        let scale = WorldView.tile / CGFloat(TileArt.size)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    var body: some View {
        Group {
            if let decor {
                let size = DecorSpot.size(of: decor)
                let glow = DecorArt.glow(decor).map { Color(uiColor: $0.uiColor) } ?? .clear
                PixelImage(DecorArt.image(decor), width: size.width, height: size.height)
                    .shadow(color: glow.opacity(0.75), radius: 6)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.32), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    Text("+")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.32))
                }
                .frame(width: WorldView.tile * 0.74, height: WorldView.tile * 0.74)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A street happening on the map: a bouncing bubble over a little crowd ring. Walk onto it.
private struct HappeningMarker: View {
    let kind: Happening
    @State private var bounce = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.25))
                .frame(width: WorldView.tile * 0.9, height: WorldView.tile * 0.35)
                .offset(y: WorldView.tile * 0.3)
            Text(kind.emoji)
                .font(.system(size: WorldView.tile * 0.55))
                .padding(4)
                .background(Circle().fill(Color.black.opacity(0.7)))
                .overlay(Circle().stroke(Color(red: 1, green: 0.85, blue: 0.3), lineWidth: 2))
                .offset(y: bounce ? -WorldView.tile * 0.35 : -WorldView.tile * 0.15)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { bounce = true }
        }
    }
}
