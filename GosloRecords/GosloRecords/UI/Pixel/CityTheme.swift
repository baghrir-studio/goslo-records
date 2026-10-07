import Foundation

/// How the neighbourhood looks in each city: same streets, different skin
/// (façades, roofs, pavement, trees, water). The layout never changes, so the story stays the same.
struct CityTheme {
    enum Facade { case bricks, plaster, stone }
    enum Pavement { case slabs, cobbles, zellige }
    enum Tree { case round, plane, palm, pine }
    /// A city landmark seen over the rooftops, or the harbour on the water's edge.
    enum Landmark { case ironTower, minaret, harbour }

    var facade: Facade = .bricks
    var wall = NightPalette.brick
    var wallLine = NightPalette.brickDark
    var roof = NightPalette.roof
    var roofEdge = NightPalette.roofEdge
    var roofShadow = NightPalette.roofShadow
    var pavement: Pavement = .slabs
    var sidewalk = NightPalette.sidewalk
    var sidewalkLine = NightPalette.sidewalkLine
    var accent = NightPalette.sidewalk
    var grass = NightPalette.grass
    var grassBlade = NightPalette.grassBlade
    var grassTip = NightPalette.grassTip
    var ground = NightPalette.ground
    var tree: Tree = .round
    var leaf = NightPalette.leaf
    var leafLight = NightPalette.leafLight
    var water = NightPalette.water
    var ripple = NightPalette.ripple
    /// Snow on roofs, grass and trees.
    var snow = false
    /// Outdoor iron staircases on façades.
    var outdoorStairs = false
    /// Shutters next to windows.
    var shutters: PixelColor?
    /// Small boats on the water.
    var boats = false
    var landmark: Landmark?

    static func forCity(_ city: City) -> CityTheme {
        var t = CityTheme()
        switch city {
        case .paris:
            // Pale stone, zinc roofs.
            t.facade = .stone
            t.wall = PixelColor(hex: "#6e6658"); t.wallLine = PixelColor(hex: "#5a5348")
            t.roof = PixelColor(hex: "#3c4654"); t.roofEdge = PixelColor(hex: "#56637a"); t.roofShadow = PixelColor(hex: "#2a313c")
            t.tree = .plane
            // An iron tower in the distance: the plain structure, no light show.
            t.landmark = .ironTower
        case .marseille:
            // Ochre plaster, terracotta tiles, the harbour.
            t.facade = .plaster
            t.wall = PixelColor(hex: "#8a6a44"); t.wallLine = PixelColor(hex: "#735735")
            t.roof = PixelColor(hex: "#7a3a24"); t.roofEdge = PixelColor(hex: "#984a2e"); t.roofShadow = PixelColor(hex: "#5a2a1a")
            t.shutters = PixelColor(hex: "#3f6f8a")
            t.sidewalk = PixelColor(hex: "#5a5248"); t.sidewalkLine = PixelColor(hex: "#4c453c")
            t.grass = PixelColor(hex: "#3a3a22"); t.grassBlade = PixelColor(hex: "#56542e"); t.grassTip = PixelColor(hex: "#8a8440")
            t.ground = PixelColor(hex: "#2e2c1c")
            t.tree = .pine; t.leaf = PixelColor(hex: "#1f4a2a"); t.leafLight = PixelColor(hex: "#2f6a36")
            t.water = PixelColor(hex: "#1a4a78"); t.ripple = PixelColor(hex: "#3a7ab0")
            t.boats = true
            // The old harbour: a stone quay, moorings and a forest of masts.
            t.landmark = .harbour
        case .lyon:
            // Old-town pinks and oranges, cobbles.
            t.facade = .plaster
            t.wall = PixelColor(hex: "#8a5a4a"); t.wallLine = PixelColor(hex: "#734a3c")
            t.roof = PixelColor(hex: "#6a3222"); t.roofEdge = PixelColor(hex: "#86402c"); t.roofShadow = PixelColor(hex: "#4a2218")
            t.shutters = PixelColor(hex: "#5a6a3a")
            t.pavement = .cobbles
            t.water = PixelColor(hex: "#244a4a"); t.ripple = PixelColor(hex: "#3a6a66")
            t.tree = .plane
        case .toulouse:
            // The pink city: pink brick everywhere.
            t.wall = PixelColor(hex: "#8a4a44"); t.wallLine = PixelColor(hex: "#6e3834")
            t.roof = PixelColor(hex: "#7a3626"); t.roofEdge = PixelColor(hex: "#94462e"); t.roofShadow = PixelColor(hex: "#56261a")
            t.shutters = PixelColor(hex: "#4a6a8a")
            t.water = PixelColor(hex: "#2a4a5a"); t.ripple = PixelColor(hex: "#3f6a7a")
        case .lille:
            // Dark red Flemish brick, slate roofs, wet cobbles.
            t.wall = PixelColor(hex: "#5a2a26"); t.wallLine = PixelColor(hex: "#44201c")
            t.roof = PixelColor(hex: "#24262c"); t.roofEdge = PixelColor(hex: "#34373f"); t.roofShadow = PixelColor(hex: "#18191d")
            t.pavement = .cobbles
            t.sidewalk = PixelColor(hex: "#3e4048"); t.sidewalkLine = PixelColor(hex: "#33353c")
        case .bruxelles:
            // Sandstone and brick, cobbles, a bit of gold.
            t.facade = .stone
            t.wall = PixelColor(hex: "#6a5a44"); t.wallLine = PixelColor(hex: "#564836")
            t.roof = PixelColor(hex: "#2e2c30"); t.roofEdge = PixelColor(hex: "#a08440"); t.roofShadow = PixelColor(hex: "#1e1c20")
            t.pavement = .cobbles
            t.tree = .plane
        case .montreal:
            // Red brick, outdoor staircases, snow, frozen river.
            t.wall = PixelColor(hex: "#6a3028"); t.wallLine = PixelColor(hex: "#52241e")
            t.outdoorStairs = true
            t.snow = true
            t.grass = PixelColor(hex: "#b8c0cc"); t.grassBlade = PixelColor(hex: "#d8dee8"); t.grassTip = PixelColor(hex: "#f2f5fa")
            t.ground = PixelColor(hex: "#c8ced8")
            t.tree = .pine; t.leaf = PixelColor(hex: "#1c3a2a"); t.leafLight = PixelColor(hex: "#e8eef6")
            t.water = PixelColor(hex: "#5a7a9a"); t.ripple = PixelColor(hex: "#a8c0d8")
        case .casablanca:
            // White walls, zellige pavement, palm trees, the ocean.
            t.facade = .plaster
            t.wall = PixelColor(hex: "#a8a49a"); t.wallLine = PixelColor(hex: "#908c82")
            t.roof = PixelColor(hex: "#8a857a"); t.roofEdge = PixelColor(hex: "#a8a398"); t.roofShadow = PixelColor(hex: "#6a665c")
            t.shutters = PixelColor(hex: "#2a7a6a")
            t.pavement = .zellige
            t.sidewalk = PixelColor(hex: "#5a544a"); t.sidewalkLine = PixelColor(hex: "#4c463c")
            t.accent = PixelColor(hex: "#1f7a6a")
            t.grass = PixelColor(hex: "#4a4026"); t.grassBlade = PixelColor(hex: "#6a5c30"); t.grassTip = PixelColor(hex: "#9a8a40")
            t.ground = PixelColor(hex: "#3a3220")
            t.tree = .palm; t.leaf = PixelColor(hex: "#2a5a2a"); t.leafLight = PixelColor(hex: "#3f7a36")
            t.water = PixelColor(hex: "#1a3f6a"); t.ripple = PixelColor(hex: "#4a80b8")
            t.boats = true
            // A generic Moroccan-style minaret in the distance (not a copy of any real building).
            t.landmark = .minaret
        }
        return t
    }
}
