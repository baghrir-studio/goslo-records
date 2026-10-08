import Foundation

/// A track you can put on an album: a refrain you wrote, or a moment of your career turned into a song.
struct AlbumTrack: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    /// 1…10: how good it is (your refrains are the best material).
    let quality: Int
}

enum AlbumCover: String, Codable, CaseIterable, Identifiable {
    case portrait, neon, street, gold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portrait: "Portrait"
        case .neon: "Néon"
        case .street: "Béton"
        case .gold: "Or massif"
        }
    }
}

struct Album: Codable, Equatable, Identifiable {
    let id: Int
    let title: String
    let tracks: [AlbumTrack]
    let cover: AlbumCover
    let releasedTurn: Int
    /// Copies sold each semester since the release (the first one is the release semester).
    var sales: [Int]

    var totalSales: Int { sales.reduce(0, +) }
    var quality: Double { tracks.isEmpty ? 0 : Double(tracks.map(\.quality).reduce(0, +)) / Double(tracks.count) }
    var isSelling: Bool { sales.count < AlbumRules.salesSemesters }

    var certification: String? {
        switch totalSales {
        case AlbumRules.diamond...: "Diamant"
        case AlbumRules.platinum...: "Platine"
        case AlbumRules.gold...: "Or"
        default: nil
        }
    }
}

/// Album rules: what you can record, how it sells.
enum AlbumRules {
    static let fromChapter = 3
    static let minTracks = 4
    static let maxTracks = 8
    static let maxTitleLength = 28
    /// Semesters between two albums.
    static let cooldown = 4
    /// Semesters an album keeps selling.
    static let salesSemesters = 5
    static let decay = 0.55
    static let gold = 50_000
    static let platinum = 100_000
    static let diamond = 500_000

    /// Moments of the career that become songs (story flag → title, quality).
    static let milestones: [(flag: String, title: String, quality: Int)] = [
        ("premier_texte", "Premier Texte", 4),
        ("micro_ouvert_fait", "Micro Ouvert", 5),
        ("clash_gagne_kevlar_jr", "La 32e", 7),
        ("signe_goslo", "Laverie Records", 6),
        ("mixtape_ch2", "Mixtape du Bloc", 6),
        ("clip_fait", "Tourné au Téléphone", 5),
        ("clash_gagne_lingot", "Aller Simple pour Miami", 7),
        ("debat_gagne", "Droit de Réponse", 5),
        ("dj_recrute", "Une Seule Platine", 6),
        ("concert_reussi", "Première Scène", 8),
        ("kolosse_ko", "K.O. en Direct", 7),
        ("contrat_signe", "Clause 12", 6),
        ("single_ecrit", "Le Single", 8),
        ("scalpel_battu", "Autopsie", 8),
        ("baron_tombe", "Le Trône", 9),
        ("dome_reussi", "Vingt Mille", 10),
    ]

    /// Copies sold the first semester; the next ones decay.
    static func firstSemester(quality: Double, stats: Stats, fame: Int) -> Int {
        let reach = 2_000 + stats.streams * 600 + stats.credibilite * 250 + fame * 6_000
        return Int((Double(reach) * (0.4 + quality / 10)).rounded())
    }
}

extension GameEngine {
    /// What you could put on an album now: your refrains, then the moments you lived, then two you always have.
    func albumCandidates(in state: GameState) -> [AlbumTrack] {
        let pen = state.skills.level(.plume) / 3
        let refrains = state.hooks.enumerated().map { index, hook in
            AlbumTrack(id: "refrain_\(index)", title: AlbumRules.title(fromHook: hook), quality: min(10, 8 + pen))
        }
        let lived = AlbumRules.milestones.filter { state.flags.contains($0.flag) }.map {
            AlbumTrack(id: $0.flag, title: $0.title, quality: min(10, $0.quality + pen))
        }
        let always = [
            AlbumTrack(id: "ville", title: "\(state.rapper.city.rawValue) la Nuit", quality: min(10, 5 + pen)),
            AlbumTrack(id: "interlude", title: "Interlude (Message de Maman)", quality: 3),
        ]
        return refrains + lived + always
    }

    func canRecordAlbum(in state: GameState) -> Bool {
        guard state.chapter >= AlbumRules.fromChapter, !state.isOver else { return false }
        guard let last = state.albums.last else { return true }
        return state.turn - last.releasedTurn >= AlbumRules.cooldown
    }

    /// Releases an album: first semester's sales, a burst of streams, and respect if it's good.
    @discardableResult
    func releaseAlbum(title: String, trackIds: [String], cover: AlbumCover, in state: inout GameState) throws -> Album {
        guard canRecordAlbum(in: state) else { throw GameEngineError.albumNotReady }
        let candidates = albumCandidates(in: state)
        let tracks = trackIds.compactMap { id in candidates.first { $0.id == id } }
        guard (AlbumRules.minTracks...AlbumRules.maxTracks).contains(tracks.count), Set(trackIds).count == trackIds.count else {
            throw GameEngineError.albumNotReady
        }
        let name = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(AlbumRules.maxTitleLength))
        var album = Album(id: state.albums.count + 1, title: name.isEmpty ? "Sans Titre" : name, tracks: tracks,
                          cover: cover, releasedTurn: state.turn, sales: [])
        album.sales = [AlbumRules.firstSemester(quality: album.quality, stats: state.stats, fame: fame(in: state))]
        let respect = album.quality >= 7 ? 4 : (album.quality < 5 ? -2 : 1)
        _ = state.applyStats([.streams: Int(album.quality.rounded()), .credibilite: respect])
        state.counters.increment(.projets)
        state.albums.append(album)
        return album
    }

    /// End of a semester: albums still in shops sell again (less each time) and bring in a little money.
    func sellAlbums(in state: inout GameState) -> [StatKind: Int] {
        var earned = 0
        for index in state.albums.indices where state.albums[index].isSelling {
            let last = state.albums[index].sales.last ?? 0
            let next = Int((Double(last) * AlbumRules.decay).rounded())
            state.albums[index].sales.append(next)
            earned += next
        }
        guard earned > 0 else { return [:] }
        return state.stats.apply([.argent: max(1, earned / 15_000)])
    }
}

extension AlbumRules {
    /// A refrain becomes a title: its first words, capitalized, without the punctuation.
    static func title(fromHook hook: String) -> String {
        let words = hook.split(separator: " ").prefix(4).map(String.init)
        var title = words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        if title.count > maxTitleLength { title = String(title.prefix(maxTitleLength)) }
        return title.prefix(1).uppercased() + title.dropFirst()
    }
}
