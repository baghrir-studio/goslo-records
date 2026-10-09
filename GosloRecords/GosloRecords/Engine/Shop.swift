import Foundation

/// The shop (from the HUD): spend your money on gear that stays (a level more in a clash move) or on a
/// service (once a year each, some behind an artist level). A purchase never takes your last coin: at 0 money
/// the career ends. No service pays money back, and each has its yearly cooldown, so none can be farmed (`Gates`).
struct ShopOffer: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Owned for good: an item with a clash bonus.
        case gear(Item)
        /// Stat changes (tuned like any gain), once a year.
        case service([StatKind: Int])
    }

    let id: String
    let name: String
    let pitch: String
    let price: Int
    let kind: Kind
    /// Artist level needed to buy it.
    var minLevel = 1
    /// What a service does besides its stat changes (a lesson, a favour kept for later…).
    var perk: ShopPerk?

    var item: Item {
        if case .gear(let item) = kind { return item }
        return Item(id: id, name: name)
    }
}

/// A service's effect beyond stat changes. The favours kept for later wait in `GameState.flags` (`flag`)
/// until the engine's hook uses them up: the next clash, the next single, the next event that costs you.
enum ShopPerk: String, CaseIterable {
    /// +1 level to every move in the next clash.
    case coachVocal
    /// The next single gets a free clip and +1 quality.
    case clipReal
    /// The losses of the next event choice are cancelled.
    case avocat
    /// +1 Plume level, right away.
    case masterclass
    /// +1 action this period, right away.
    case manager

    /// Set while the favour waits to be used (nil: it applies at once).
    var flag: String? {
        switch self {
        case .coachVocal, .clipReal, .avocat: "service_\(rawValue)"
        case .masterclass, .manager: nil
        }
    }

    static let masterclassXP: [Skill: Int] = [.plume: Skills.xpPerLevel]
}

enum Shop {
    static let gear: [ShopOffer] = [
        offer("micro_pro", "Micro de scène pro", "Le son claque jusqu'au fond de la salle.", 25, .presence,
              "Un micro sans fil qui ne siffle jamais. Le public t'entend même quand tu chuchotes."),
        offer("casque_studio", "Casque studio", "Tu entends chaque temps, tu poses mieux.", 25, .flow,
              "Fermé, lourd, honnête. Avec lui, tu ne rates plus une mesure."),
        offer("dico_rimes", "Dictionnaire de rimes", "Corné, annoté, redoutable.", 25, .punchline,
              "Édition 1987, couverture arrachée. Il trouve la rime avant toi."),
        offer("dictaphone", "Dictaphone vintage", "Tu enregistres la vie du quartier, tu racontes mieux.", 25, .story,
              "Une cassette, un bouton rouge. Tout ce que tu entends devient une histoire."),
    ]

    static let services: [ShopOffer] = [
        ShopOffer(id: "psy", name: "Séance chez la psy", pitch: "Une heure pour vider ta tête. +Mental.",
                  price: 12, kind: .service([.mental: 12])),
        ShopOffer(id: "promo", name: "Campagne de promo", pitch: "Affiches, pubs, influenceurs. +Streams.",
                  price: 18, kind: .service([.streams: 10])),
        ShopOffer(id: "concert_quartier", name: "Concert gratuit au quartier", pitch: "Sono, scène, barbecue : tu rends au Bloc. +Respect.",
                  price: 15, kind: .service([.credibilite: 8, .mental: 3])),
        ShopOffer(id: "hammam", name: "Hammam et kiné", pitch: "Vapeur, savon noir, gommage, puis le kiné : tu ressors neuf. +Mental.",
                  price: 14, kind: .service([.mental: 10])),
        ShopOffer(id: "coach_vocal", name: "Coach vocal", pitch: "Souffle, diction, placement. +1 niveau à tous tes coups au prochain clash.",
                  price: 28, kind: .service([:]), minLevel: 2, perk: .coachVocal),
        ShopOffer(id: "attache_presse", name: "Attaché de presse", pitch: "Il te décroche la une du webzine du moment. +Respect, +Streams.",
                  price: 32, kind: .service([.credibilite: 10, .streams: 4]), minLevel: 3),
        ShopOffer(id: "masterclass", name: "Masterclass d'écriture", pitch: "Deux jours avec une plume légendaire. +1 niveau de Plume.",
                  price: 35, kind: .service([:]), minLevel: 3, perk: .masterclass),
        ShopOffer(id: "avocat", name: "Avocat", pitch: "Il garde ton numéro. La prochaine galère ne te coûtera rien.",
                  price: 40, kind: .service([:]), minLevel: 3, perk: .avocat),
        ShopOffer(id: "clip_real", name: "Clip par un vrai réal", pitch: "Drone, figurants, étalonnage : ton prochain single sort avec un clip offert, +1 qualité.",
                  price: 45, kind: .service([:]), minLevel: 4, perk: .clipReal),
        ShopOffer(id: "manager", name: "Manager", pitch: "Il gère ton agenda, tu gagnes du temps. +1 action cette période.",
                  price: 75, kind: .service([:]), minLevel: 6, perk: .manager),
    ]

    static var offers: [ShopOffer] { gear + services }

    static func offer(_ id: String) -> ShopOffer? { offers.first { $0.id == id } }

    private static func offer(_ id: String, _ name: String, _ pitch: String, _ price: Int, _ move: ClashMove,
                              _ description: String) -> ShopOffer {
        ShopOffer(id: id, name: name, pitch: pitch + " +1 \(move.label) en clash.", price: price,
                  kind: .gear(Item(id: id, name: name, description: description, clashBonus: [move: 1])))
    }

    /// Why it can't be bought now (nil: it can).
    static func refusal(_ offer: ShopOffer, in state: GameState) -> String? {
        switch offer.kind {
        case .gear:
            if state.items.contains(offer.id) { return "Déjà à toi" }
        case .service:
            if let flag = offer.perk?.flag, state.flags.contains(flag) { return "Déjà réservé" }
            if let last = state.boughtAt[offer.id], state.turn - last < GameState.turnsPerYear {
                return "Une fois par an"
            }
        }
        if ArtistLevel.level(xp: state.artistXP) < offer.minLevel { return "Niveau \(offer.minLevel) requis" }
        if state.stats.argent <= offer.price { return "Pas assez d'argent" }
        // The manager's extra action needs a period in progress.
        if offer.perk == .manager, state.actionsLeft <= 0 || state.pendingFollowUp != nil { return "Pas maintenant" }
        return nil
    }
}

extension GameEngine {
    /// Buys an offer: pays, then gives the gear or the service. Returns the stat changes.
    @discardableResult
    func buy(_ offer: ShopOffer, in state: inout GameState) throws -> [StatKind: Int] {
        guard !state.isOver, Shop.refusal(offer, in: state) == nil else { throw GameEngineError.cannotBuy }
        var changes = state.stats.apply([.argent: -offer.price])
        switch offer.kind {
        case .gear:
            state.items.insert(offer.id)
        case .service(let effects):
            state.boughtAt[offer.id] = state.turn
            for (kind, delta) in state.applyStats(effects) { changes[kind, default: 0] += delta }
            if let perk = offer.perk { apply(perk, in: &state) }
        }
        return changes
    }

    /// A service's perk: done now, or kept as a flag for its hook.
    private func apply(_ perk: ShopPerk, in state: inout GameState) {
        if let flag = perk.flag {
            state.flags.insert(flag)
            return
        }
        switch perk {
        case .masterclass: state.skills.gain(ShopPerk.masterclassXP)
        case .manager: state.actionsLeft += 1
        case .coachVocal, .clipReal, .avocat: break
        }
    }

    /// Whether a favour kept for later is waiting.
    func hasPerk(_ perk: ShopPerk, in state: GameState) -> Bool {
        perk.flag.map { state.flags.contains($0) } ?? false
    }

    /// Uses up a favour kept for later. Returns whether it was there.
    @discardableResult
    func usePerk(_ perk: ShopPerk, in state: inout GameState) -> Bool {
        guard let flag = perk.flag else { return false }
        return state.flags.remove(flag) != nil
    }
}
