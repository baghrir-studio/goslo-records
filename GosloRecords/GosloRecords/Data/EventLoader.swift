import Foundation

/// Reads the game data:
/// - events.json  `{ "version": 1, "events": [ ... ] }`
/// - cast.json    `{ "cast": [ ... ] }`
/// - quests.json  `{ "quests": [ ... ] }`
/// - map.json     the neighbourhood (rows, doors, characters)
/// - story.json   chapters, objectives, cinematics, interviews, goslo radio
/// - punchlines.json  the Punchliner's verses
enum EventLoader {
    struct EventFile: Decodable {
        let version: Int?
        let events: [GameEvent]
    }

    struct CastFile: Decodable {
        let cast: [CastMember]
    }

    struct QuestFile: Decodable {
        let quests: [Quest]
    }

    enum LoadError: Error, CustomStringConvertible {
        case missingFile(String)
        case invalid(String, Error)

        var description: String {
            switch self {
            case .missingFile(let name): "Fichier introuvable : \(name).json"
            case .invalid(let name, let error): "\(name).json invalide : \(error)"
            }
        }
    }

    static func load(from data: Data) throws -> [GameEvent] {
        try decode(EventFile.self, from: data, name: "events").events
    }

    static func loadCast(from data: Data) throws -> [CastMember] {
        try decode(CastFile.self, from: data, name: "cast").cast
    }

    static func loadQuests(from data: Data) throws -> [Quest] {
        try decode(QuestFile.self, from: data, name: "quests").quests
    }

    static func loadBundled(named name: String = "events", bundle: Bundle = .main) throws -> [GameEvent] {
        try load(from: bundledData(name, bundle: bundle))
    }

    static func loadMap(from data: Data) throws -> WorldMap {
        try decode(WorldMap.self, from: data, name: "map")
    }

    /// districts.json: one map per district, keyed by district ("centre", "hauts", "dome").
    static func loadDistricts(from data: Data) throws -> [District: WorldMap] {
        try decode([District: WorldMap].self, from: data, name: "districts")
    }

    static func loadStory(from data: Data) throws -> Story {
        try decode(Story.self, from: data, name: "story")
    }

    /// punchlines.json: the Punchliner's shared pool of verses.
    static func loadVerses(from data: Data) throws -> [PunchlinerVerse] {
        try decode(VerseFile.self, from: data, name: "punchlines").verses
    }

    struct VerseFile: Decodable {
        let verses: [PunchlinerVerse]
    }

    static func loadWorld(bundle: Bundle = .main) throws -> World {
        var story = try loadStory(from: bundledData("story", bundle: bundle))
        story.verses = try loadVerses(from: bundledData("punchlines", bundle: bundle))
        return World(
            events: try load(from: bundledData("events", bundle: bundle)),
            cast: try loadCast(from: bundledData("cast", bundle: bundle)),
            quests: try loadQuests(from: bundledData("quests", bundle: bundle)),
            map: try loadMap(from: bundledData("map", bundle: bundle)),
            districts: try loadDistricts(from: bundledData("districts", bundle: bundle)),
            story: story
        )
    }

    /// french-words.txt: the Punchliner's dictionary (a few hundred ms to read: load it off the main thread).
    static func loadDictionary(bundle: Bundle = .main) throws -> FrenchDictionary {
        guard let url = bundle.url(forResource: "french-words", withExtension: "txt") else {
            throw LoadError.missingFile("french-words")
        }
        return FrenchDictionary(frontCoded: try Data(contentsOf: url))
    }

    private static func bundledData(_ name: String, bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw LoadError.missingFile(name)
        }
        return try Data(contentsOf: url)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, name: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw LoadError.invalid(name, error)
        }
    }
}
