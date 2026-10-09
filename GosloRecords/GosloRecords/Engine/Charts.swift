import Foundation

/// A single released by the player: it enters the Top goslo radio and climbs or falls each turn.
struct Single: Codable, Equatable, Identifiable {
    let id: Int
    let title: String
    /// Where it comes from (an `AlbumTrack` id: a refrain, a moment of the career).
    let sourceId: String
    /// 1…10: the material and the takes in the studio.
    let quality: Int
    let releasedTurn: Int
    let clip: Bool
    /// The rival who did the featuring, if any.
    let feat: String?
    /// Rank in the Top each turn since the release (nil: out of the Top).
    var ranks: [Int?] = []

    var bestRank: Int? { ranks.compactMap { $0 }.min() }
}

/// One line of the Top goslo radio.
struct ChartEntry: Equatable, Identifiable {
    let id: String
    let title: String
    let artist: String
    /// The player's single.
    let singleId: Int?
    let score: Double

    var isPlayer: Bool { singleId != nil }
}

/// The Top goslo radio: the player's singles against the rivals' tracks, every turn.
enum ChartRules {
    static let size = 10
    static let fromChapter = 2
    static let studioPrice = 6
    static let clipPrice = 10
    /// Turns a single stays in the race.
    static let lifespan = 8
    /// Each turn, a single loses this share of its buzz.
    static let decay = 0.82
    /// Perfect takes possible in a studio session.
    static let takes = 4

    /// Quality of a recorded single: the material, the takes (2 perfect ones keep it as is), the featuring.
    static func quality(material: Int, perfectTakes: Int, feat: Bool) -> Int {
        min(10, max(1, material - 2 + min(max(perfectTakes, 0), takes) + (feat ? 1 : 0)))
    }

    /// Made-up stars of the scene, so the Top is never empty.
    static let regulars: [(artist: String, title: String, score: Double)] = [
        ("Les Jumeaux du 93", "Double Peine", 62),
        ("Mama Kossa", "Soleil de Minuit", 58),
        ("DJ Fantôme", "Plus Personne", 55),
        ("Tonton Flex", "Gros Moteur", 52),
        ("Sœur Lumière", "Prière de Rue", 49),
        ("Kid Néon", "Pixel", 46),
        ("La Brigade", "Contrôle", 44),
        ("Pépite", "Or Blanc", 41),
        ("Zéro Filtre", "Story Privée", 38),
        ("Le Vieux Nas'", "Mixtape 2003", 35),
    ]

    static let titleWords = (
        first: ["Nuit", "Béton", "Couronne", "Fumée", "Miroir", "Silence", "Lumière", "Bitume", "Tempête", "Trône", "Mirage", "Cicatrice"],
        second: ["Blanche", "Froide", "Sans Fin", "d'Or", "du Quartier", "Brisé", "Fatale", "Royale", "Électrique", "Perdue", "de Verre", "Interdite"]
    )
}

extension GameEngine {
    // MARK: Studio

    /// What can become a single: the album material that hasn't been released as a single yet.
    func singleCandidates(in state: GameState) -> [AlbumTrack] {
        let released = Set(state.singles.map(\.sourceId))
        return albumCandidates(in: state).filter { !released.contains($0.id) && $0.id != "interlude" }
    }

    /// Why a studio session isn't possible now (nil: it is).
    func studioRefusal(in state: GameState) -> String? {
        if state.chapter < ChartRules.fromChapter { return "Le studio t'ouvre ses portes après le premier chapitre." }
        if !canVisit(state) { return "Pas maintenant." }
        if state.singles.last?.releasedTurn == state.turn { return "Un single par période : laisse vivre le dernier." }
        if state.stats.argent <= ChartRules.studioPrice { return "Pas assez d'argent pour louer le studio." }
        if singleCandidates(in: state).isEmpty { return "Rien de neuf à enregistrer : écris d'abord un refrain." }
        return nil
    }

    /// The rivals you can invite on a single: met, still on good terms.
    func featCandidates(in state: GameState) -> [CastMember] {
        world.cast.filter { member in
            member.clash != nil && !member.wild && member.cities == nil && state.metCast.contains(member.id)
                && state.relation(member.id) >= 40
        }
    }

    /// Records and releases a single (1 action): pays the studio (and the clip), enters the Top next turn.
    func releaseSingle(sourceId: String, perfectTakes: Int, clip: Bool, feat: String?, in state: inout GameState) throws -> TurnOutcome {
        guard studioRefusal(in: state) == nil, let material = singleCandidates(in: state).first(where: { $0.id == sourceId }) else {
            throw GameEngineError.cannotRecord
        }
        // The director booked in the shop (`ShopPerk.clipReal`) shoots the clip for free, and it shows.
        let director = hasPerk(.clipReal, in: state)
        let withClip = director || (clip && ArtistLevel.unlocks(.clip, in: state))
        let withFeat = feat.flatMap { id in ArtistLevel.unlocks(.feat, in: state) ? featCandidates(in: state).first { $0.id == id }?.id : nil }
        let price = ChartRules.studioPrice + (withClip && !director ? ChartRules.clipPrice : 0)
        guard state.stats.argent > price else { throw GameEngineError.cannotRecord }

        state.actionsLeft -= 1
        var quality = ChartRules.quality(material: material.quality, perfectTakes: perfectTakes, feat: withFeat != nil)
        if director {
            usePerk(.clipReal, in: &state)
            quality = min(10, quality + 1)
        }
        let single = Single(id: state.singles.count + 1, title: material.title, sourceId: material.id, quality: quality,
                            releasedTurn: state.turn, clip: withClip, feat: withFeat)
        state.singles.append(single)
        var outcome = TurnOutcome(consequence: quality >= 8 ? "« \(single.title) » est dans la boîte. Fred enlève son casque : « Ça, c'est un tube. »"
                                  : quality >= 5 ? "« \(single.title) » est sorti. Le quartier le partage, on verra où il entre dans le Top."
                                  : "« \(single.title) » est sorti… Fred n'a rien dit. Ce n'est jamais bon signe.")
        outcome.add(state.stats.apply([.argent: -price]))
        if director { outcome.notes.append("Ton réal a tourné le clip : drone, figurants, étalonnage. Le single a de la gueule.") }
        if let withFeat {
            state.counters.increment(.featurings)
            let applied = state.changeRelation(withFeat, by: 5)
            if applied != 0 { outcome.relationChanges[withFeat, default: 0] += applied }
        }
        outcome.add(levelUps: state.skills.gain([.flow: 10, .plume: 5]))
        return finishAction(outcome, in: &state)
    }

    // MARK: The Top

    /// This turn's Top goslo radio, best first.
    func chart(in state: GameState) -> [ChartEntry] {
        var entries = ChartRules.regulars.enumerated().map { index, regular in
            ChartEntry(id: "regular_\(index)", title: regular.title, artist: regular.artist, singleId: nil,
                       score: regular.score * GameEngine.wobble("\(regular.artist)\(state.turn)"))
        }
        // The rivals you know release too, as the story goes on.
        for member in world.cast where state.metCast.contains(member.id) {
            guard let profile = member.clash, !member.wild, member.cities == nil else { continue }
            let era = state.turn / 4
            let seed = GameEngine.fnv("\(member.id)\(era)")
            let title = ChartRules.titleWords.first[Int(seed % 12)] + " " + ChartRules.titleWords.second[Int((seed / 12) % 12)]
            let strength = Double(ClashMove.allCases.map(profile.stat).reduce(0, +)) / 4
            entries.append(ChartEntry(id: member.id, title: title, artist: member.name, singleId: nil,
                                      score: (strength * 8 + 12) * GameEngine.wobble("\(member.id)\(state.turn)")))
        }
        for single in state.singles where state.turn - single.releasedTurn < ChartRules.lifespan {
            entries.append(ChartEntry(id: "single_\(single.id)", title: single.title, artist: state.rapper.name,
                                      singleId: single.id, score: singleScore(single, in: state)))
        }
        return Array(entries.sorted { $0.score > $1.score }.prefix(ChartRules.size))
    }

    /// A single's buzz: the song, your fame, your respect, the clip and the featuring, fading with time.
    func singleScore(_ single: Single, in state: GameState) -> Double {
        let age = max(0, state.turn - single.releasedTurn)
        let base = Double(single.quality) * 6.5 + Double(state.stats.streams) * 0.45 + Double(state.stats.credibilite) * 0.2
            + Double(fame(in: state)) * 4 + (single.clip ? 9 : 0) + (single.feat != nil ? 6 : 0)
        // The first turn is the launch: the buzz builds up.
        let curve = age == 0 ? 0.9 : pow(ChartRules.decay, Double(age - 1))
        let owner = state.flags.contains(RadioDeal.flag) ? RadioDeal.buzz : 1
        return base * curve * owner
    }

    /// End of a turn: your singles in the Top bring streams, money and artist XP; their rank is kept.
    func payChart(_ outcome: inout TurnOutcome, in state: inout GameState) {
        let top = chart(in: state)
        for index in state.singles.indices where state.turn - state.singles[index].releasedTurn < ChartRules.lifespan {
            let single = state.singles[index]
            let rank = top.firstIndex { $0.singleId == single.id }.map { $0 + 1 }
            let previous = single.ranks.last ?? nil
            state.singles[index].ranks.append(rank)
            guard let rank else { continue }
            state.seasonBestRank = min(state.seasonBestRank ?? rank, rank)
            let points = ChartRules.size + 1 - rank
            let tour = rank <= 3 && ArtistLevel.unlocks(.tournee, in: state) ? 2 : 1
            outcome.add(state.stats.apply([.streams: max(1, points / 3), .argent: max(1, points / 4) * tour]))
            ArtistLevel.gain(rank == 1 ? 30 : 8, in: &state, outcome: &outcome)
            let move = previous.map { $0 > rank ? " ▲\($0 - rank)" : ($0 < rank ? " ▼\(rank - $0)" : " =") } ?? " (entrée)"
            outcome.notes.append("Top goslo radio : « \(single.title) » n°\(rank)\(move).")
            // Climbed: the one just below is someone you passed.
            if previous.map({ $0 > rank }) == true, top.indices.contains(rank), !top[rank].isPlayer {
                outcome.notes.append("Tu passes devant \(top[rank].artist).")
            }
        }
    }

    // MARK: Helpers

    /// A stable hash (Swift's own changes on every launch).
    static func fnv(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return hash
    }

    /// 0.85…1.15, the same for the same text.
    static func wobble(_ text: String) -> Double {
        0.85 + Double(fnv(text) % 1000) / 1000 * 0.3
    }
}
