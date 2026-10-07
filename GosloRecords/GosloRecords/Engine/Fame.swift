import Foundation

/// The career leaves marks: rivals quote your lines, friends talk about your tracks,
/// posters go up in the neighbourhood, and the people you met come to the big shows.
extension GameEngine {
    // MARK: Memory

    /// What a rival can throw back at you in a clash (nothing in the terrain vague: they don't know you).
    func callbacks(for clash: ClashState, in state: GameState) -> [String] {
        guard !clash.isWild else { return [] }
        var lines = state.hooks.suffix(3).flatMap { hook in [
            "« \(hook) » ? Même ma petite sœur l'avait vue venir.",
            "T'as écrit « \(hook) » dans une laverie, et ça s'entend.",
            "« \(hook) »… Yanis l'a mis dans son top. Le top des flops.",
        ] }
        if state.flags.contains("sous_contrat") {
            lines.append("Signé dans l'arrière-boutique d'une laverie. Ton contrat sent l'assouplissant.")
        }
        if state.flags.contains("premier_texte") {
            lines.append("Ton premier texte, je l'ai lu. Au crayon. Il s'effaçait tout seul.")
        }
        if state.stats.streams >= 60 {
            lines.append("T'as des streams, d'accord. Moi j'ai des souvenirs de toi à 12 abonnés.")
        }
        lines.append("Retourne à \(state.rapper.city.rawValue), ta mère t'attend avec sa pancarte.")
        return lines
    }

    /// A friend brings up your latest track, now and then (nil if they have nothing to say about it).
    func memoryLine(for castId: String, in state: GameState) -> String? {
        guard let hook = state.hooks.last else { return nil }
        switch castId {
        case "yanis": return "« \(hook) », je l'ai passé dans Le Débrief. Catégorie « prometteur ». Je ne la donne pas souvent."
        case "momo": return "J'ai mis « \(hook) » en boucle dans la laverie. Les clients restent pour le rinçage."
        case "fred": return "« \(hook) »… En 2009, j'aurais mixé ça en or. Là, c'est du platine dans un cœur."
        case "maman": return "J'ai écrit « \(hook) » sur ma pancarte. Tu as vu ? Au premier rang."
        case "lucien": return "On m'a fait écouter « \(hook) » au téléphone. Sur le fixe. C'était bien."
        case "lil_sauge": return "« \(hook) », ouais, j'ai vu passer. 400 vues ? Mignon."
        case "big_nono": return "Les auditeurs redemandent « \(hook) ». Je fais semblant de pas l'avoir."
        case "karim": return "« \(hook) » ? Je l'ai fait écouter à mes contacts. Deux fois, je compte deux fois."
        default: return nil
        }
    }

    // MARK: The neighbourhood

    /// 0…3: how many walls of the neighbourhood carry your poster (pairs), by streams.
    func fame(in state: GameState) -> Int {
        switch state.stats.streams {
        case ..<35: 0
        case ..<55: 1
        case ..<75: 2
        default: 3
        }
    }

    /// Beat the Baron, and the laundromat's wall gets your face, painted.
    func hasFresco(in state: GameState) -> Bool {
        state.flags.contains("clash_gagne_le_baron") || state.flags.contains("baron_tombe")
    }

    // MARK: The big shows

    /// The people in the front row: at the Dôme, everyone you met; elsewhere, the ones who like you.
    func concertGuests(_ concertId: String, in state: GameState) -> [CastMember] {
        let dome = concertId == "le_dome"
        let met = world.cast.filter { member in
            !member.wild && state.metCast.contains(member.id) && (dome || state.relation(member.id) >= 60)
        }
        let mother = world.cast.filter { $0.id == "maman" && !state.metCast.contains("maman") }
        return Array((mother + met.sorted { state.relation($0.id) > state.relation($1.id) }).prefix(dome ? 10 : 5))
    }
}
