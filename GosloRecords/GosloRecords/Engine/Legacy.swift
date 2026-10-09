import Foundation

/// Achievements ("Succès"): earned during a career or across careers, kept forever on the device.
enum Achievement: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case premierChapitre, ringDesMots, premiereScene, rimeur, frappeParfaite, touriste
    case disqueOr, disquePlatine, disqueDiamant, tombeurDuBaron
    case carriereComplete, legende, patron, deuxMicros, tourDeFrance, toutesLesVilles, tousLesStyles
    case maison, auditeur, roucoulade, archeologue, maieutique

    /// Hidden until found: the list shows "???".
    var isSecret: Bool { [.maison, .auditeur, .roucoulade, .archeologue].contains(self) }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .premierChapitre: "En bas du bloc"
        case .ringDesMots: "La 32e"
        case .premiereScene: "Première scène"
        case .rimeur: "Rimeur fou"
        case .frappeParfaite: "Pile sur le temps"
        case .touriste: "Ligne goslo"
        case .disqueOr: "Disque d'or"
        case .disquePlatine: "Disque de platine"
        case .disqueDiamant: "Disque de diamant"
        case .tombeurDuBaron: "Le trône"
        case .carriereComplete: "Jusqu'au bout"
        case .legende: "Légende"
        case .patron: "Patron du game"
        case .deuxMicros: "Deux micros"
        case .tourDeFrance: "Tournée"
        case .toutesLesVilles: "Partout chez toi"
        case .tousLesStyles: "Tous les styles"
        case .maison: "Tu connais la maison"
        case .auditeur: "Fidèle auditeur"
        case .roucoulade: "Roucoulade"
        case .archeologue: "Archéologue du Bunker"
        case .maieutique: "Maïeutique"
        }
    }

    var detail: String {
        switch self {
        case .premierChapitre: "Finir le chapitre 1."
        case .ringDesMots: "Battre Kevlar Jr. sur le Ring des Mots."
        case .premiereScene: "Réussir ton premier concert."
        case .rimeur: "Enchaîner 8 rimes en un freestyle."
        case .frappeParfaite: "Charger une technique secrète presque parfaitement."
        case .touriste: "Visiter les quatre quartiers."
        case .disqueOr: "Sortir un album certifié or."
        case .disquePlatine: "Sortir un album certifié platine."
        case .disqueDiamant: "Sortir un album certifié diamant."
        case .tombeurDuBaron: "Faire tomber le Baron."
        case .carriereComplete: "Aller au bout d'une carrière, sans abandonner en route."
        case .legende: "Finir une carrière en légende."
        case .patron: "Finir une carrière à la tête de ton label."
        case .deuxMicros: "Finir une carrière en rappeur et une en rappeuse."
        case .tourDeFrance: "Finir des carrières dans 4 villes différentes."
        case .toutesLesVilles: "Finir une carrière dans chacune des 8 villes."
        case .tousLesStyles: "Finir une carrière dans chacun des 4 styles."
        case .maison: "Porter le nom de la maison."
        case .auditeur: "Trouver le jingle caché de goslo radio."
        case .roucoulade: "Battre le pigeon de Lille. Oui, un pigeon."
        case .archeologue: "Trouver ce que Fred cache derrière le Bunker."
        case .maieutique: "Faire analyser 3 de tes punchlines par le Philosophe de goslo radio."
        }
    }

    var symbol: String {
        switch self {
        case .premierChapitre: "building.2.fill"
        case .ringDesMots: "figure.boxing"
        case .premiereScene: "music.mic"
        case .rimeur: "text.bubble.fill"
        case .frappeParfaite: "metronome.fill"
        case .touriste: "tram.fill"
        case .disqueOr, .disquePlatine, .disqueDiamant: "opticaldisc.fill"
        case .tombeurDuBaron: "crown.fill"
        case .carriereComplete: "flag.checkered"
        case .legende: "star.fill"
        case .patron: "briefcase.fill"
        case .deuxMicros: "person.2.fill"
        case .tourDeFrance: "map.fill"
        case .toutesLesVilles: "globe.europe.africa.fill"
        case .tousLesStyles: "square.grid.2x2.fill"
        case .maison: "house.fill"
        case .auditeur: "radio.fill"
        case .roucoulade: "bird.fill"
        case .archeologue: "shippingbox.fill"
        case .maieutique: "book.closed.fill"
        }
    }

    /// The legacy bonus this achievement unlocks for the next careers, if any.
    var heritage: Heritage? { Heritage.allCases.first { $0.unlockedBy == self } }
}

/// What a new career inherits from the previous ones: pick one at creation, once it's unlocked.
enum Heritage: String, Codable, CaseIterable, Identifiable {
    case carnet, repertoire, respect, economies, fanbase, flow

    var id: String { rawValue }

    var name: String {
        switch self {
        case .carnet: "Le vieux carnet"
        case .repertoire: "Le répertoire"
        case .respect: "Le respect du Bloc"
        case .economies: "Les économies"
        case .fanbase: "La fanbase"
        case .flow: "Le flow d'avant"
        }
    }

    var detail: String {
        switch self {
        case .carnet: "Tes anciens textes : ta plume part avec de l'avance."
        case .repertoire: "Fred, Yanis, Momo et Lucien te connaissent déjà."
        case .respect: "Le quartier se souvient : +8 de respect au départ."
        case .economies: "Ce que t'as mis de côté : +12 d'argent au départ."
        case .fanbase: "Tes anciens fans te suivent : +10 de streams au départ."
        case .flow: "Ta jauge de technique secrète démarre à moitié pleine à chaque clash."
        }
    }

    var unlockedBy: Achievement {
        switch self {
        case .carnet: .carriereComplete
        case .repertoire: .ringDesMots
        case .respect: .tombeurDuBaron
        case .economies: .disqueOr
        case .fanbase: .disquePlatine
        case .flow: .rimeur
        }
    }

    static let contacts = ["fred", "yanis", "momo", "lucien"]
}

/// Achievements unlocked on this device, with the date of each.
struct TrophyCase: Codable, Equatable {
    var achievements: [Achievement: Date] = [:]
    /// The daily clash: attempts and streak.
    var daily = DailyRecord()
    /// Arcade records, per game.
    var arcadeBest: [String: Int] = [:]
    /// The HQ built between careers.
    var hq = Headquarters()
    /// Punchliner's personal records.
    var punchliner = PunchlinerRecord()

    var unlocked: Set<Achievement> { Set(achievements.keys) }
    var heritages: [Heritage] { Heritage.allCases.filter { unlocked.contains($0.unlockedBy) } }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Unknown achievement ids (from a newer version) are dropped instead of losing the whole profile.
        let raw = try c.decodeIfPresent([String: Date].self, forKey: .achievements) ?? [:]
        achievements = Dictionary(uniqueKeysWithValues: raw.compactMap { key, date in Achievement(rawValue: key).map { ($0, date) } })
        daily = try c.decodeIfPresent(DailyRecord.self, forKey: .daily) ?? DailyRecord()
        arcadeBest = try c.decodeIfPresent([String: Int].self, forKey: .arcadeBest) ?? [:]
        hq = try c.decodeIfPresent(Headquarters.self, forKey: .hq) ?? Headquarters()
        punchliner = try c.decodeIfPresent(PunchlinerRecord.self, forKey: .punchliner) ?? PunchlinerRecord()
    }
}

/// Which achievements a career, or the list of finished careers, has earned.
enum AchievementRules {
    static let perfectCharge = 0.85
    static let freestyleFlag = "freestyle_parfait"
    static let chargeFlag = "charge_parfaite"

    static func earned(in state: GameState) -> Set<Achievement> {
        let flags = state.flags
        let best = state.albums.map(\.totalSales).max() ?? 0
        let rules: [(Achievement, Bool)] = [
            (.premierChapitre, flags.contains("chapitre_1")),
            (.ringDesMots, flags.contains("clash_gagne_kevlar_jr")),
            (.premiereScene, flags.contains("concert_reussi")),
            (.rimeur, flags.contains(freestyleFlag)),
            (.frappeParfaite, flags.contains(chargeFlag)),
            (.touriste, District.allCases.filter { $0 != .bloc }
                .allSatisfy { state.seenUniqueEvents.contains(GameEngine.arrivalEventId($0)) }),
            (.disqueOr, best >= AlbumRules.gold),
            (.disquePlatine, best >= AlbumRules.platinum),
            (.disqueDiamant, best >= AlbumRules.diamond),
            (.tombeurDuBaron, flags.contains("baron_tombe") || flags.contains("clash_gagne_le_baron")),
            (.maison, state.rapper.isHouseMember),
            (.auditeur, flags.contains(Secrets.jingleFlag)),
            (.roucoulade, flags.contains(Secrets.pigeonFlag)),
            (.archeologue, flags.contains(Secrets.archiveFlag)),
            (.maieutique, state.hooks.indices.filter { flags.contains(Philosopher.readFlag($0)) }.count >= 3),
        ]
        return Set(rules.filter { $0.1 }.map { $0.0 })
    }

    static func earned(from history: [CareerRecord]) -> Set<Achievement> {
        let complete = history.filter { !$0.ending.isPremature }
        let rules: [(Achievement, Bool)] = [
            (.carriereComplete, !complete.isEmpty),
            (.legende, history.contains { $0.ending == .legende }),
            (.patron, history.contains { $0.ending == .patronDeLabel }),
            (.deuxMicros, Set(complete.map(\.rapper.gender)).count == Gender.allCases.count),
            (.tourDeFrance, Set(complete.map(\.rapper.city)).count >= 4),
            (.toutesLesVilles, Set(complete.map(\.rapper.city)).count == City.allCases.count),
            (.tousLesStyles, Set(complete.map(\.rapper.style)).count == Style.allCases.count),
        ]
        return Set(rules.filter { $0.1 }.map { $0.0 })
    }
}

extension GameEngine {
    /// A new career's starting bonus from its legacy.
    func applyHeritage(_ heritage: Heritage, to state: inout GameState) {
        switch heritage {
        case .carnet: state.skills.gain([.plume: 90])
        case .repertoire:
            for id in Heritage.contacts { state.relations[id] = min(100, state.relation(id) + 15) }
        case .respect: state.stats.apply([.credibilite: 8])
        case .economies: state.stats.apply([.argent: 12])
        case .fanbase: state.stats.apply([.streams: 10])
        case .flow: break  // Applied when a clash starts (`startingMeter`).
        }
    }

    /// The secret technique gauge at the start of a clash (half full with the "flow" legacy).
    func startingMeter(in state: GameState) -> Int {
        state.rapper.heritage == .flow ? ClashState.secretThreshold / 2 : 0
    }
}
