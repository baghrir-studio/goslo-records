import Foundation

/// A finished career, as stored in "Mes carrières" and shown on the share card.
struct CareerRecord: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    let finishedAt: Date
    let rapper: Rapper
    let ending: Ending
    let stats: Stats
    let counters: Counters
    let yearsActive: Int
    let summary: String

    init(state: GameState, finishedAt: Date = Date()) {
        id = state.id
        self.finishedAt = finishedAt
        rapper = state.rapper
        ending = state.ending ?? EndingResolver.finalEnding(for: state)
        stats = state.stats
        counters = state.counters
        yearsActive = state.yearsActive
        summary = SummaryGenerator.summary(for: state)
    }

    static func == (lhs: CareerRecord, rhs: CareerRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The share card's one-liner. First matching rule wins: the most
/// distinctive traits (flags, extreme counters) come before generic stats.
enum SummaryGenerator {
    static func summary(for state: GameState) -> String {
        let s = state.stats, c = state.counters, flags = state.flags
        let rules: [(Bool, String)] = [
            (flags.contains("clash_gagne_le_baron"), "A fait tomber le Baron en quatre mesures. Le trône était en carton, mais quand même."),
            (flags.contains("clash_gagne_scalpel"), "A battu Scalpel à la plume. Plus personne n'ose lui parler de rimes."),
            (c[.clashsGagnes] >= 3, "\(c[.clashsGagnes]) clashs gagnés. Les rappeurs changent de trottoir en {le|la} voyant."),
            (flags.contains("feat_scalpel"), "A tenu la cadence face à Scalpel. Peu de gens peuvent en dire autant."),
            (flags.contains("faux_streams"), "A acheté ses streams au Kazakhstan. Le respect, lui, n'était pas en vente."),
            (c[.disquesOr] >= 3 && c[.beefs] >= 2, "\(c[.disquesOr]) disques d'or et \(c[.beefs]) clashs : chaque certif a son ennemi."),
            (c[.disquesOr] >= 3, "\(c[.disquesOr]) disques d'or accrochés au mur des toilettes. Par humilité."),
            (c[.beefs] >= 3, "\(c[.beefs]) clashs. Aucun vraiment gagné, tous monétisés."),
            (flags.contains("fidele_goslo") && s.credibilite >= 50, "Fidèle à goslo records jusqu'au bout, même quand c'était pas rentable."),
            (flags.contains("signe_major") && s.credibilite < 35, "A signé en major et laissé son âme à l'accueil, contre un badge visiteur."),
            (flags.contains("album_concept"), "A sorti un album sur une machine à laver. Personne n'a compris. Culte."),
            (flags.contains("buzz_tiktok") && s.streams >= 50, "{Connu|Connue} pour 12 secondes de danse. Le reste de la carrière est un bonus."),
            (flags.contains("ghostwriter"), "A écrit les tubes des autres en silence. La plume la plus riche du game."),
            (flags.contains("pause_faite"), "Est {parti|partie} deux ans faire de la poterie. Est {revenu|revenue} avec des punchlines en céramique."),
            (c[.featurings] >= 4, "\(c[.featurings]) featurings. {Présent|Présente} sur tous les projets, sauf les siens."),
            (c[.projets] == 0, "Zéro projet sorti. Une carrière 100 % stories."),
            (s.mental >= 80, "{Le seul rappeur|La seule rappeuse} qui dort huit heures par nuit et boit de la tisane."),
            (s.argent >= 80, "Plus de placements financiers que de punchlines."),
            (s.credibilite >= 80, "{Respecté|Respectée} par tous les rappeurs. {Écouté|Écoutée} par leurs cousins."),
            (s.streams >= 80, "Des milliards de streams, et toujours pas de chorus correct."),
            (s.argent <= 10, "A fini sa carrière avec un découvert et une discographie. Dans cet ordre."),
            (s.mental <= 15, "A tout donné au rap. Le rap n'a rien rendu."),
        ]
        if let match = rules.first(where: { $0.0 }) { return TextTemplate.agree(match.1, state.rapper.gender) }
        return "\(state.yearsActive) ans de carrière, \(c[.projets]) projet\(c[.projets] > 1 ? "s" : ""), zéro regret avoué."
    }
}
