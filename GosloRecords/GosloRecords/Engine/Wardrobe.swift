import Foundation

/// Clothes and accessories bought in the shop: they show on the character, in the street and in clashes.
/// One worn per slot; bought for the whole career.
struct Wearable: Identifiable, Equatable {
    enum Slot: String { case head, eyes, neck, top, shoes }

    let id: String
    let name: String
    let pitch: String
    let price: Int
    let minLevel: Int
    let slot: Slot
    let apply: (inout CharacterLook) -> Void

    static func == (a: Wearable, b: Wearable) -> Bool { a.id == b.id }
}

enum Wardrobe {
    static let items: [Wearable] = [
        Wearable(id: "chaine_or", name: "Chaîne en or", pitch: "Elle brille jusqu'au fond de la salle.", price: 14, minLevel: 1,
                 slot: .neck) { $0.chain = true; $0.accent = "#ffd84d" },
        Wearable(id: "lunettes_star", name: "Lunettes de star", pitch: "Même la nuit. Surtout la nuit.", price: 10, minLevel: 1,
                 slot: .eyes) { $0.glasses = true },
        Wearable(id: "bob_rose", name: "Bob rose", pitch: "Personne n'ose. Toi, si.", price: 10, minLevel: 2,
                 slot: .head) { $0.hat = .bucket; $0.accent = "#e04fb0" },
        Wearable(id: "casque_or", name: "Casque doré", pitch: "Sur les oreilles, autour du cou : partout.", price: 16, minLevel: 2,
                 slot: .head) { $0.headphones = true; $0.hat = .none; $0.accent = "#ffd84d" },
        Wearable(id: "survet_goslo", name: "Survêt goslo radio", pitch: "Rouge et noir, l'uniforme de la maison.", price: 18, minLevel: 3,
                 slot: .top) { $0.outfit = .jersey; $0.top = "#ff4d2e"; $0.bottom = "#16161a" },
        Wearable(id: "veste_cuir", name: "Veste en cuir", pitch: "Elle a fait trois tournées avant toi.", price: 20, minLevel: 3,
                 slot: .top) { $0.outfit = .jacket; $0.top = "#3a2a22"; $0.bottom = "#1d1d24" },
        Wearable(id: "sneakers_neon", name: "Sneakers néon", pitch: "On les voit avant de te voir.", price: 12, minLevel: 2,
                 slot: .shoes) { $0.shoes = "#5ef2ff" },
        Wearable(id: "doudoune_or", name: "Doudoune dorée", pitch: "Le froid n'a aucune chance. Le public non plus.", price: 28, minLevel: 5,
                 slot: .top) { $0.outfit = .puffer; $0.top = "#e8c547"; $0.bottom = "#16161a" },
    ]

    static func item(_ id: String) -> Wearable? { items.first { $0.id == id } }

    /// Why it can't be bought now (nil: it can).
    static func refusal(_ item: Wearable, in state: GameState) -> String? {
        if state.wardrobe.contains(item.id) { return "Déjà à toi" }
        if ArtistLevel.level(xp: state.artistXP) < item.minLevel { return "Niveau \(item.minLevel) requis" }
        if state.stats.argent <= item.price { return "Pas assez d'argent" }
        return nil
    }
}

extension Rapper {
    /// The worn clothes, on top of the look picked at creation.
    func dressed(_ base: CharacterLook) -> CharacterLook {
        var look = base
        for id in wearing ?? [] { Wardrobe.item(id)?.apply(&look) }
        return look
    }
}

extension GameEngine {
    /// Buys a piece and puts it on (it replaces what was worn in the same slot).
    @discardableResult
    func buy(_ item: Wearable, in state: inout GameState) throws -> [StatKind: Int] {
        guard !state.isOver, Wardrobe.refusal(item, in: state) == nil else { throw GameEngineError.cannotBuy }
        state.wardrobe.insert(item.id)
        wear(item, in: &state)
        return state.stats.apply([.argent: -item.price])
    }

    /// Puts on an owned piece, or takes it off if it's already worn.
    func wear(_ item: Wearable, in state: inout GameState) {
        guard state.wardrobe.contains(item.id) else { return }
        var worn = state.rapper.wearing ?? []
        if worn.contains(item.id) {
            worn.removeAll { $0 == item.id }
        } else {
            worn.removeAll { Wardrobe.item($0)?.slot == item.slot }
            worn.append(item.id)
        }
        state.rapper.wearing = worn
    }
}
