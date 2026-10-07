import Foundation

enum Ending: String, Codable, CaseIterable {
    // Premature endings (a stat hits 0)
    case burnOut = "burn_out"
    case retourAuTaf = "retour_au_taf"
    case vendu
    case oublie
    // Survival endings (all 20 semesters played)
    /// Epilogue: you took over the label and your first signings took off.
    case patronDeLabel = "patron_de_label"
    case heritier
    case legende
    case starCommerciale = "star_commerciale"
    case culteMaisFauche = "culte_mais_fauche"
    case rentier
    case sageDuGame = "sage_du_game"
    case carriereHonnete = "carriere_honnete"

    var title: String {
        switch self {
        case .burnOut: "Burn-out"
        case .retourAuTaf: "Retour au taf"
        case .vendu: "{Vendu|Vendue}"
        case .oublie: "{Oublié|Oubliée}"
        case .patronDeLabel: "{Patron|Patronne} de label"
        case .heritier: "{Héritier|Héritière} du trône"
        case .legende: "Légende"
        case .starCommerciale: "Star commerciale"
        case .culteMaisFauche: "Culte mais {fauché|fauchée}"
        case .rentier: "{Rentier|Rentière} du rap"
        case .sageDuGame: "Sage du game"
        case .carriereHonnete: "Carrière honnête"
        }
    }

    var description: String {
        switch self {
        case .burnOut:
            "Le corps a dit stop avant le label. Tu passes tes journées à regarder un mur. Le mur, au moins, ne te demande pas de single."
        case .retourAuTaf:
            "Compte à zéro. Tu as repris un CDI en logistique. Tes collègues t'appellent « {le rappeur|la rappeuse} » avec un ton que tu n'aimes pas."
        case .vendu:
            "Plus personne dans le milieu ne te respecte. Tu fais des jingles pour une enseigne de bricolage. Ils sont très efficaces."
        case .oublie:
            "Zéro écoute. L'algorithme t'a rayé de la carte. Même ta mère a arrêté de partager tes sons."
        case .patronDeLabel:
            "Le trône, tu l'as laissé refroidir. Tu as repris la laverie, signé la relève, et ce sont leurs noms que le quartier scande maintenant. Toi, tu souris au fond de la salle. Tu as trouvé mieux qu'un trône : un banc de touche."
        case .heritier:
            "Tu as battu le Baron sur son propre terrain. Le trône est à toi. Il est inconfortable, et tout le monde veut s'asseoir dessus."
        case .legende:
            "Les gamins citent tes punchlines sans savoir qu'elles viennent de toi. Le statut ultime : être un classique de son vivant."
        case .starCommerciale:
            "Disques, pubs, plateaux télé. Les puristes te méprisent depuis leurs 300 abonnés. Toi, tu méprises depuis ta piscine."
        case .culteMaisFauche:
            "{Respecté|Respectée} par tous les rappeurs, {écouté|écoutée} par 4 000 personnes très investies. Ton loyer, lui, ne cite pas tes punchlines."
        case .rentier:
            "Tu as compris avant les autres que le rap est un business. Tu parles plus de « ROI » que de rimes. Ça te va bien."
        case .sageDuGame:
            "Dix ans de rap et toujours la tête sur les épaules. Tu dors bien, tu manges des légumes. Le rap français ne comprend pas."
        case .carriereHonnete:
            "Ni légende, ni accident. Une vraie carrière, des vrais fans, des fins de mois parfois sportives. C'est déjà énorme."
        }
    }

    var isPremature: Bool {
        switch self {
        case .burnOut, .retourAuTaf, .vendu, .oublie: true
        default: false
        }
    }
}

enum EndingResolver {
    /// Order matters when several stats hit 0 at once.
    static let prematureOrder: [(StatKind, Ending)] = [
        (.mental, .burnOut),
        (.argent, .retourAuTaf),
        (.credibilite, .vendu),
        (.streams, .oublie),
    ]

    static func prematureEnding(for stats: Stats) -> Ending? {
        prematureOrder.first { stats[$0.0] == 0 }?.1
    }

    /// Ending after surviving all 20 semesters. First matching rule wins.
    static func finalEnding(for state: GameState) -> Ending {
        let stats = state.stats
        let streams = stats.streams, cred = stats.credibilite
        if state.flags.contains("releve_signee") { return .patronDeLabel }
        if state.flags.contains("clash_gagne_le_baron") && streams >= 50 { return .heritier }
        if streams >= 75 && cred >= 75 { return .legende }
        if streams >= 65 && cred < 50 { return .starCommerciale }
        if cred >= 65 && stats.argent < 40 { return .culteMaisFauche }
        if stats.argent >= 65 { return .rentier }
        if stats.mental >= 70 { return .sageDuGame }
        return .carriereHonnete
    }
}
