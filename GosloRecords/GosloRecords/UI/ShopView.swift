import SwiftUI

private let shopGold = Color(red: 1, green: 0.85, blue: 0.3)

/// The shop: clothes you see on your character, gear for clashes, services, and decorations for the map.
/// Everything is shown, not just listed: the character wearing the piece, the object in pixel art.
struct ShopView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable, Identifiable {
        case fringues = "Fringues", matos = "Matos", services = "Services", deco = "Déco"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .fringues
    @State private var message: String?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Boutique").font(.display(44))
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 18)

            if let state = model.state {
                HStack(spacing: 12) {
                    PixelImage(HeroSprite.bust(state.rapper.look), width: 54)
                        .background(Color.white.opacity(0.06))
                        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ARGENT \(state.stats.argent)")
                            .font(.display(26))
                            .foregroundStyle(shopGold)
                        Text("NIV. \(ArtistLevel.level(xp: state.artistXP)) · à 0, c'est le retour au taf")
                            .font(.mono(10, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, Theme.gutter)

                HStack(spacing: 6) {
                    ForEach(Tab.allCases) { item in
                        Button { tab = item } label: {
                            Text(item.rawValue.uppercased())
                                .font(.mono(11, weight: .bold))
                                .foregroundStyle(tab == item ? Theme.background : Theme.text)
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(tab == item ? Theme.accent : Color.clear)
                                .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 12)

                if let message {
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(shopGold)
                        .padding(.horizontal, Theme.gutter)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if tab == .deco {
                            Text("Choisis, puis pose-la où tu veux sur la carte. Les bâtiments rapportent à chaque période.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                        }
                        LazyVGrid(columns: columns, spacing: 10) {
                            switch tab {
                            case .fringues: ForEach(Wardrobe.items) { wearableCard($0, in: state) }
                            case .matos: ForEach(Shop.gear) { offerCard($0, in: state) }
                            case .services: ForEach(Shop.services) { offerCard($0, in: state) }
                            case .deco:
                                radioCard(in: state)
                                ForEach(Decor.allCases) { decorCard($0, in: state) }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func say(_ text: String) {
        withAnimation { message = text }
    }

    // MARK: Cards

    private func wearableCard(_ item: Wearable, in state: GameState) -> some View {
        let owned = state.wardrobe.contains(item.id)
        let worn = state.rapper.wearing?.contains(item.id) == true
        var preview = state.rapper
        preview.wearing = ((preview.wearing ?? []).filter { Wardrobe.item($0)?.slot != item.slot }) + [item.id]
        let refusal = Wardrobe.refusal(item, in: state)
        return card(image: HeroSprite.image(preview.look, facing: .down, frame: 0), imageWidth: 60,
                    title: item.name, pitch: item.pitch,
                    price: owned ? (worn ? "PORTÉ" : "À TOI") : "\(item.price)",
                    locked: owned ? nil : refusal, highlighted: worn) {
            if owned {
                model.wear(item)
                say(worn ? "Tu retires « \(item.name) »." : "Tu enfiles « \(item.name) ».")
            } else {
                say(model.buy(item) ?? "« \(item.name) » : c'est sur toi.")
            }
        }
    }

    private func offerCard(_ offer: ShopOffer, in state: GameState) -> some View {
        let refusal = Shop.refusal(offer, in: state)
        return card(image: ShopIcons.gear(offer.id), imageWidth: 56, title: offer.name, pitch: offer.pitch,
                    price: refusal == "Déjà à toi" ? "À TOI" : "\(offer.price)", locked: refusal, highlighted: false) {
            say(model.buy(offer) ?? "« \(offer.name) » : c'est fait.")
        }
    }

    private func decorCard(_ decor: Decor, in state: GameState) -> some View {
        let placed = state.decor.values.filter { $0 == decor }.count + state.placed.filter { $0.decor == decor }.count
        let levelLock = ArtistLevel.level(xp: state.artistXP) < decor.minLevel ? "Niveau \(decor.minLevel) requis" : nil
        let moneyLock = state.stats.argent <= decor.price ? "Pas assez d'argent" : nil
        return card(image: ShopIcons.decor(decor), imageWidth: decor.isBuilding ? 64 : 56, title: decor.name,
                    pitch: placed > 0 ? "\(decor.pitch) · \(placed) posé\(placed > 1 ? "s" : "")" : decor.pitch,
                    price: "\(decor.price)", locked: levelLock ?? moneyLock, highlighted: placed > 0) {
            model.beginPlacing(decor)
            dismiss()
        }
    }

    /// The big one: buy goslo radio itself. Your sounds get more airplay and it pays every period.
    private func radioCard(in state: GameState) -> some View {
        let refusal = RadioDeal.refusal(in: state)
        let owned = state.flags.contains(RadioDeal.flag)
        return card(image: ShopIcons.gear("radio_goslo"), imageWidth: 64, title: "Racheter goslo radio",
                    pitch: "La radio devient la tienne : tes sons tournent plus, elle rapporte chaque période.",
                    price: owned ? "À TOI" : "\(RadioDeal.price)", locked: owned ? nil : refusal, highlighted: owned) {
            guard !owned else { return say("goslo radio, c'est chez toi maintenant.") }
            say(model.buyRadio() ?? "goslo radio est à toi. DJ Noize bosse pour toi maintenant.")
        }
    }

    private func card(image: UIImage, imageWidth: CGFloat, title: String, pitch: String, price: String,
                      locked: String?, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Rectangle().fill(Color.white.opacity(0.05))
                    PixelImage(image, width: imageWidth)
                        .opacity(locked == nil ? 1 : 0.45)
                }
                .frame(height: 86)
                Text(title.uppercased())
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(locked == nil ? Theme.text : Theme.faint)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(pitch)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(locked.map { "🔒 \($0)" } ?? price)
                    .font(locked == nil ? .display(22) : .mono(10, weight: .bold))
                    .foregroundStyle(locked == nil ? shopGold : Theme.accent.opacity(0.8))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 210)
            .overlay(Rectangle().stroke(highlighted ? shopGold : Theme.line, lineWidth: highlighted ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(locked != nil && locked != "Déjà à toi")
    }
}
