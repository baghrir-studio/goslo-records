import Foundation

/// Local persistence as JSON files in the Documents directory:
/// `current_run.json` (autosave) and `history.json` (finished careers).
final class GameStore {
    private let directory: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var currentRunURL: URL { directory.appendingPathComponent("current_run.json") }
    private var historyURL: URL { directory.appendingPathComponent("history.json") }

    init(directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadCurrentRun() -> GameState? {
        read(GameState.self, from: currentRunURL)
    }

    func saveCurrentRun(_ state: GameState) {
        write(state, to: currentRunURL)
    }

    func clearCurrentRun() {
        try? FileManager.default.removeItem(at: currentRunURL)
    }

    /// Most recent first.
    func loadHistory() -> [CareerRecord] {
        read([CareerRecord].self, from: historyURL) ?? []
    }

    func saveHistory(_ records: [CareerRecord]) {
        write(records, to: historyURL)
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
