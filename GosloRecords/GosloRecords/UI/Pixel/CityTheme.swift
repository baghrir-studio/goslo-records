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
    /// Casablanca has a red tramway instead of the metro.
    var tram = false
    /// Chimney stacks with clay pots on the pitched roofs.
    var chimneys = true
    /// Dormer windows in the roofs above the downtown façades.
    var dormers = false
    /// Flemish stepped gables over the downtown façades.
    var gables = false
    /// Horseshoe-arched windows and a zellige frieze at the foot of the walls.
    var arches = false
    /// Puddles on the pavement (the rainy cities).
    var puddles = false
    /// Shop awnings, striped with off-white.
    var awnings = [PixelColor(hex: "#9a2a26"), PixelColor(hex: "#2f5a3a")]
    /// The local shop downtown, by its sign (8 letters at most).
    var signature = "TABAC"
    /// The city itself, for the props that change from one city to the next (kiosks, shop signs, rooftops, the shore).
    var city: City = .paris

    static func forCity(_ city: City) -> CityTheme {
        var t = CityTheme()
        t.city = city
        switch city {
        case .paris:
            // Pale stone, zinc roofs.
            t.facade = .stone
            t.wall = PixelColor(hex: "#6e6658"); t.wallLine = PixelColor(hex: "#5a5348")
            t.roof = PixelColor(hex: "#3c4654"); t.roofEdge = PixelColor(hex: "#56637a"); t.roofShadow = PixelColor(hex: "#2a313c")
            t.tree = .plane
            // An iron tower in the distance: the plain structure, no light show.
            t.landmark = .ironTower
            // Zinc roofs with dormers, red and green awnings, the tabac on the corner.
            t.dormers = true
            t.awnings = [PixelColor(hex: "#9a2a26"), PixelColor(hex: "#2f5a3a"), PixelColor(hex: "#24304a")]
            t.signature = "TABAC"
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
            // Sea-blue and sun-yellow awnings, and the soap makers.
            t.awnings = [PixelColor(hex: "#2a6a9a"), PixelColor(hex: "#c8902a"), PixelColor(hex: "#3f8a9a")]
            t.signature = "SAVONS"
        case .lyon:
            // Old-town pinks and oranges, cobbles.
            t.facade = .plaster
            t.wall = PixelColor(hex: "#8a5a4a"); t.wallLine = PixelColor(hex: "#734a3c")
            t.roof = PixelColor(hex: "#6a3222"); t.roofEdge = PixelColor(hex: "#86402c"); t.roofShadow = PixelColor(hex: "#4a2218")
            t.shutters = PixelColor(hex: "#5a6a3a")
            t.pavement = .cobbles
            t.water = PixelColor(hex: "#244a4a"); t.ripple = PixelColor(hex: "#3a6a66")
            t.tree = .plane
            t.awnings = [PixelColor(hex: "#7a2a3a"), PixelColor(hex: "#6a7a3a")]
            t.signature = "BOUCHON"
        case .toulouse:
            // The pink city: pink brick everywhere.
            t.wall = PixelColor(hex: "#8a4a44"); t.wallLine = PixelColor(hex: "#6e3834")
            t.roof = PixelColor(hex: "#7a3626"); t.roofEdge = PixelColor(hex: "#94462e"); t.roofShadow = PixelColor(hex: "#56261a")
            t.shutters = PixelColor(hex: "#4a6a8a")
            t.water = PixelColor(hex: "#2a4a5a"); t.ripple = PixelColor(hex: "#3f6a7a")
            t.awnings = [PixelColor(hex: "#6a4a8a"), PixelColor(hex: "#b85a6a")]
            t.signature = "SAUCISSE"
        case .lille:
            // Dark red Flemish brick, slate roofs, wet cobbles.
            t.wall = PixelColor(hex: "#5a2a26"); t.wallLine = PixelColor(hex: "#44201c")
            t.roof = PixelColor(hex: "#24262c"); t.roofEdge = PixelColor(hex: "#34373f"); t.roofShadow = PixelColor(hex: "#18191d")
            t.pavement = .cobbles
            t.sidewalk = PixelColor(hex: "#3e4048"); t.sidewalkLine = PixelColor(hex: "#33353c")
            // Stepped gables downtown, puddles everywhere.
            t.gables = true
            t.puddles = true
            t.awnings = [PixelColor(hex: "#9a2a24"), PixelColor(hex: "#c8a03a")]
            t.signature = "GAUFRES"
        case .bruxelles:
            // Sandstone and brick, cobbles, a bit of gold.
            t.facade = .stone
            t.wall = PixelColor(hex: "#6a5a44"); t.wallLine = PixelColor(hex: "#564836")
            t.roof = PixelColor(hex: "#2e2c30"); t.roofEdge = PixelColor(hex: "#a08440"); t.roofShadow = PixelColor(hex: "#1e1c20")
            t.pavement = .cobbles
            t.tree = .plane
            t.gables = true
            t.dormers = true
            t.puddles = true
            t.awnings = [PixelColor(hex: "#b8902a"), PixelColor(hex: "#9a2a26"), PixelColor(hex: "#2a2a2e")]
            t.signature = "FRITERIE"
        case .montreal:
            // Red brick, outdoor staircases, snow, frozen river.
            t.wall = PixelColor(hex: "#6a3028"); t.wallLine = PixelColor(hex: "#52241e")
            t.outdoorStairs = true
            t.snow = true
            t.grass = PixelColor(hex: "#b8c0cc"); t.grassBlade = PixelColor(hex: "#d8dee8"); t.grassTip = PixelColor(hex: "#f2f5fa")
            t.ground = PixelColor(hex: "#c8ced8")
            t.tree = .pine; t.leaf = PixelColor(hex: "#1c3a2a"); t.leafLight = PixelColor(hex: "#e8eef6")
            t.water = PixelColor(hex: "#5a7a9a"); t.ripple = PixelColor(hex: "#a8c0d8")
            t.awnings = [PixelColor(hex: "#24488a"), PixelColor(hex: "#9a2a26")]
            t.signature = "POUTINE"
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
            t.tram = true
            // Flat roof terraces, arched windows over zellige, green and terracotta awnings.
            t.chimneys = false
            t.arches = true
            t.awnings = [PixelColor(hex: "#1f7a6a"), PixelColor(hex: "#b85a34")]
            t.signature = "HANOUT"
        }
        return t
    }
}

extension CityTheme {
    /// Each district's own look, over the city's: cobbled shopping streets downtown, glass towers in
    /// Les Hauts, the arena's silver and purple at Le Dôme. Snow and trees stay the city's.
    func adapted(to district: District) -> CityTheme {
        var t = self
        switch district {
        case .bloc:
            break
        case .centre:
            if t.pavement == .slabs { t.pavement = .cobbles }
            t.sidewalk = t.sidewalk.shaded(1.15)
            t.sidewalkLine = t.sidewalkLine.shaded(1.15)
            t.shutters = t.shutters ?? PixelColor(hex: "#6a3a5a")
        case .hauts:
            // Glass and steel.
            t.facade = .stone
            t.wall = PixelColor(hex: "#34465c"); t.wallLine = PixelColor(hex: "#2a384a")
            t.roof = PixelColor(hex: "#1e2530"); t.roofEdge = PixelColor(hex: "#4a5a70"); t.roofShadow = PixelColor(hex: "#151a22")
            t.shutters = nil
            t.outdoorStairs = false
            t.pavement = .slabs
            t.sidewalk = PixelColor(hex: "#50545e"); t.sidewalkLine = PixelColor(hex: "#454852")
        case .dome:
            t.wall = PixelColor(hex: "#3a2f45"); t.wallLine = PixelColor(hex: "#2e2538")
            t.roof = PixelColor(hex: "#3a3f4a"); t.roofEdge = PixelColor(hex: "#5a606c"); t.roofShadow = PixelColor(hex: "#262a32")
            t.shutters = nil
            t.outdoorStairs = false
            t.pavement = .slabs
            t.sidewalk = PixelColor(hex: "#4a4452"); t.sidewalkLine = PixelColor(hex: "#3e3946")
        }
        return t
    }
}
