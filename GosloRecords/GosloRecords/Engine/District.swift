import Foundation

/// The city grows with the career: each district opens at a chapter and is reached by metro.
/// Le Bloc is the original map (map.json); the others live in districts.json.
enum District: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case bloc
    case centre
    case hauts
    case dome

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bloc: "Le Bloc"
        case .centre: "Centre-ville"
        case .hauts: "Les Hauts"
        case .dome: "Le Dôme"
        }
    }

    /// One line on the metro map and on the arrival card.
    var tagline: String {
        switch self {
        case .bloc: "Ton quartier. La laverie, le Bunker, le terrain vague."
        case .centre: "Les salles de concert, les disquaires, les battles de rue."
        case .hauts: "Les tours de verre : radios, maisons de disques, contrats."
        case .dome: "L'arène. Vingt mille places. Le trône est là-haut."
        }
    }

    /// The district opens on this chapter.
    var fromChapter: Int {
        switch self {
        case .bloc: 1
        case .centre: 3
        case .hauts: 4
        case .dome: 6
        }
    }
}

extension World {
    /// The map of a district (nil if it isn't in the data).
    func map(for district: District) -> WorldMap? {
        district == .bloc ? map : districts[district]
    }

    /// Where a character stands from a given chapter on: the first district whose map holds them.
    func district(ofNPC id: String, chapter: Int, flags: Set<String> = []) -> District? {
        District.allCases.first { district in
            district.fromChapter <= chapter
                && map(for: district)?.forChapter(chapter, flags: flags).npcs.contains { $0.id == id } == true
        }
    }

    /// Districts with a door to a place, open by a given chapter.
    func districts(with location: Location, chapter: Int) -> [District] {
        District.allCases.filter { district in
            district.fromChapter <= chapter && map(for: district)?.door(for: location) != nil
        }
    }
}

extension GameEngine {
    /// Districts the metro serves in this chapter (always at least Le Bloc).
    func openDistricts(in state: GameState) -> [District] {
        District.allCases.filter { $0.fromChapter <= state.chapter && world.map(for: $0) != nil }
    }

    /// The current district's map, as it is in this chapter.
    func currentMap(in state: GameState) -> WorldMap? {
        world.map(for: state.district)?.forChapter(state.chapter, flags: state.flags)
    }

    /// Takes the metro: you come out of the destination's station.
    func travel(to district: District, in state: inout GameState) throws {
        guard openDistricts(in: state).contains(district), let map = world.map(for: district) else {
            throw GameEngineError.districtLocked(district)
        }
        state.district = district
        state.position = map.arrival
        state.facing = .down
    }

    /// Where the current objective takes place, when it isn't in the district you're in (nil otherwise).
    func objectiveDistrict(in state: GameState) -> District? {
        guard let trigger = currentObjective(in: state)?.trigger else { return nil }
        if let npc = trigger.npc {
            guard let district = world.district(ofNPC: npc, chapter: state.chapter, flags: state.flags) else { return nil }
            return district == state.district ? nil : district
        }
        if let location = trigger.location {
            let districts = world.districts(with: location, chapter: state.chapter)
            guard !districts.isEmpty, !districts.contains(state.district) else { return nil }
            // The newest district with that door (the Dôme's stage for the finale).
            return districts.last
        }
        return nil
    }
}

extension CinematicStep {
    /// The step places, moves or films someone on the map (it needs Le Bloc's layout).
    var isStaged: Bool { move != nil || place != nil || camera != nil || despawn != nil || face != nil || exclaim != nil }
}

extension GameEngine {
    /// Story scenes are staged on Le Bloc's map: before one that moves people around, the player is brought
    /// home (out of Le Bloc's metro). Returns whether the player moved.
    func stageCinematic(_ cinematic: Cinematic, in state: inout GameState) -> Bool {
        guard state.district != .bloc, cinematic.steps.contains(where: \.isStaged), let bloc = world.map else { return false }
        state.district = .bloc
        state.position = bloc.arrival
        state.facing = .down
        return true
    }
}

extension GameEngine {
    static func arrivalEventId(_ district: District) -> String { "arrivee_\(district.rawValue)" }

    /// First time out of the metro in a district: its welcome scene (story.json), once, without spending an action.
    func arrivalEvent(in state: inout GameState) -> GameEvent? {
        let id = GameEngine.arrivalEventId(state.district)
        guard state.district != .bloc, !state.seenUniqueEvents.contains(id), let event = event(withId: id),
              state.currentEventId == nil, state.clash == nil, state.pendingFollowUp == nil, !state.isOver else { return nil }
        state.seenUniqueEvents.insert(id)
        state.currentEventId = id
        return event
    }
}

/// How you get from one district to another: the metro, or Casablanca's red tramway.
enum Transit: Equatable {
    case metro, tramway

    static func of(_ city: City) -> Transit { city == .casablanca ? .tramway : .metro }

    var name: String { self == .tramway ? "Tramway" : "Métro" }
    /// Sign over the stop.
    var sign: String { self == .tramway ? "Ⓣ TRAM" : "Ⓜ︎ MÉTRO" }
    var badge: String { self == .tramway ? "Ⓣ" : "Ⓜ︎" }
    /// "PRENDS LE MÉTRO" / "PRENDS LE TRAM".
    var takeIt: String { self == .tramway ? "PRENDS LE TRAM" : "PRENDS LE MÉTRO" }

    /// What you hear when the line isn't open yet.
    var closedLines: [String] {
        switch self {
        case .metro:
            ["Les grilles sont baissées. Une affiche : « Ligne fermée pour travaux. »",
             "Quelqu'un a écrit au feutre en dessous : « Réouverture quand t'auras un vrai nom. »"]
        case .tramway:
            ["L'arrêt est vide. Un panneau : « Prolongement de la ligne en travaux. »",
             "Un vieux sur le banc : « Le tram passera quand tu seras connu, {khoya|khti}. Moi j'attends depuis 2012. »"]
        }
    }
}
