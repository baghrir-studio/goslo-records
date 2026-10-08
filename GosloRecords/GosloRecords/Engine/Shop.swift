import Foundation

/// The shop (from the HUD): spend your money on gear that stays (a level more in a clash move) or on a
/// service (once a year each). A purchase never takes your last coin: at 0 money the career ends.
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

    var item: Item {
        if case .gear(let item) = kind { return item }
        return Item(id: id, name: name)
    }
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
            if let last = state.boughtAt[offer.id], state.turn - last < GameState.turnsPerYear {
                return "Une fois par an"
            }
        }
        if state.stats.argent <= offer.price { return "Pas assez d'argent" }
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
        }
        return changes
    }
}
