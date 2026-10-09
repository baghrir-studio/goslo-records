import SwiftUI

extension CrewRarity {
    /// The card's frame.
    var color: Color {
        switch self {
        case .commun: Color(white: 0.7)
        case .rare: Color(red: 0.3, green: 0.6, blue: 1)
        case .epique: Color(red: 0.72, green: 0.4, blue: 1)
        case .legendaire: Color(red: 1, green: 0.85, blue: 0.3)
        }
    }
}

/// « Mon crew »: every card of the collection (owned in colour, the others as silhouettes) and the active crew.
/// Opened from the notebook.
struct CrewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selected: CrewCardSpec?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        if let state = model.state {
            content(state)
        } else {
            Color.clear
        }
    }

    private func content(_ state: GameState) -> some View {
        let cards = Crew.cards(for: state.rapper.city).sorted { $0.rarity > $1.rarity }
        let owned = cards.filter { state.crew.owns($0.id) }.count
        let slots = model.engine.crewSlots(in: state)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("MON CREW").font(.display(40))
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Kicker(text: "\(owned) / \(cards.count) cartes · crew \(state.crew.active.count) / \(slots)")
                HStack(spacing: 8) {
                    ForEach(0..<Crew.maxSlots, id: \.self) { index in
                        slot(index, slots: slots, state: state)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(cards) { spec in
                            Button {
                                selected = spec
                            } label: {
                                CrewCardTile(spec: spec, member: model.engine.castMember(spec.id), crew: state.crew,
                                             met: state.metCast.contains(spec.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Bats un rappeur en clash, termine sa quête ou enregistre un feat avec lui pour gagner sa carte. Chaque doublon est un fragment : \(Crew.fragmentsPerLevel.map { String($0) }.joined(separator: " / ")) fragments pour monter du niveau 1 au \(Crew.maxLevel). Un même rival ne donne qu'un fragment par période.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Theme.text)
        .sheet(item: $selected) { spec in
            CrewCardDetail(spec: spec)
                .environment(model)
                .presentationBackground(Theme.background)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    /// One place of the active crew: the member's bust, an empty place, or the locked 4th one.
    @ViewBuilder
    private func slot(_ index: Int, slots: Int, state: GameState) -> some View {
        let id = state.crew.active.indices.contains(index) ? state.crew.active[index] : nil
        let member = id.flatMap { model.engine.castMember($0) }
        let rarity = id.flatMap { Crew.spec($0)?.rarity }
        ZStack {
            if let member {
                PixelImage(HeroSprite.bust(member.look), width: 44)
            } else if index >= slots {
                VStack(spacing: 2) {
                    Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold))
                    Text("NIV. \(ArtistLevel.Unlock.crew.level)").font(.mono(9, weight: .bold))
                }
                .foregroundStyle(Theme.faint)
            } else {
                Text("+").font(.display(26)).foregroundStyle(Theme.faint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .overlay(Rectangle().stroke(rarity?.color ?? Theme.line, style: StrokeStyle(lineWidth: rarity == nil ? 1 : 2,
                                                                                    dash: rarity == nil ? [4, 3] : [])))
        .onTapGesture { if let id, let spec = Crew.spec(id) { selected = spec } }
    }
}

/// A card of the grid: bust in its rarity frame, level and fragment bar (a silhouette and « ? » when not owned).
struct CrewCardTile: View {
    let spec: CrewCardSpec
    let member: CastMember?
    let crew: CrewState
    /// Met but not earned yet: grey, with the name. Never met: a black silhouette.
    let met: Bool

    var body: some View {
        let owned = crew.owns(spec.id)
        let fragments = crew.fragments[spec.id] ?? 0
        let progress = Crew.progress(fragments: fragments)
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Rectangle().fill(spec.rarity.color.opacity(owned ? 0.16 : 0.04))
                if let member {
                    PixelImage(HeroSprite.bust(member.look), width: 56)
                        .grayscale(owned ? 0 : 1)
                        .colorMultiply(owned || met ? Color.white : Color.black)
                        .opacity(owned ? 1 : 0.45)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if !owned {
                    Text("?").font(.display(30)).foregroundStyle(Theme.text.opacity(0.85))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if crew.isActive(spec.id) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(spec.rarity.color)
                        .padding(4)
                }
            }
            .frame(height: 72)
            .clipped()

            Text(owned || met ? (member?.name ?? spec.id).uppercased() : "???")
                .font(.display(15))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if owned {
                HStack {
                    Text("NIV. \(Crew.level(fragments: fragments))").font(.mono(9, weight: .bold))
                    Spacer(minLength: 0)
                    Text(progress.map { "\($0.have)/\($0.need)" } ?? "MAX").font(.mono(9, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.line)
                        Rectangle().fill(spec.rarity.color)
                            .frame(width: geo.size.width * CGFloat(progress.map { Double($0.have) / Double($0.need) } ?? 1))
                    }
                }
                .frame(height: 3)
            } else {
                Text(spec.rarity.label.uppercased()).font(.mono(9, weight: .bold)).foregroundStyle(Theme.faint)
            }
        }
        .padding(6)
        .overlay(Rectangle().stroke(owned ? spec.rarity.color : Theme.line, lineWidth: owned ? 2 : 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A card's details: the perk now and at the next level, how to earn it, and the crew button.
struct CrewCardDetail: View {
    @Environment(AppModel.self) private var model
    let spec: CrewCardSpec

    var body: some View {
        if let state = model.state {
            content(state)
        } else {
            Color.clear
        }
    }

    private func content(_ state: GameState) -> some View {
        let member = model.engine.castMember(spec.id)
        let owned = state.crew.owns(spec.id)
        let known = owned || state.metCast.contains(spec.id)
        let fragments = state.crew.fragments[spec.id] ?? 0
        let level = Crew.level(fragments: fragments)
        let active = state.crew.isActive(spec.id)
        let refusal = model.engine.crewJoinRefusal(spec.id, in: state)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    if let member {
                        PixelImage(HeroSprite.bust(member.look), width: 96)
                            .grayscale(owned ? 0 : 1)
                            .colorMultiply(known ? Color.white : Color.black)
                            .padding(6)
                            .overlay(Rectangle().stroke(spec.rarity.color, lineWidth: 3))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Kicker(text: spec.rarity.label, color: spec.rarity.color)
                        Text(known ? (member?.name ?? spec.id).uppercased() : "???").font(.display(28))
                        if known, let member {
                            Text(member.role.uppercased()).font(.mono(10, weight: .semibold)).foregroundStyle(Theme.muted)
                        }
                        if owned {
                            Text("NIVEAU \(level)" + (Crew.progress(fragments: fragments).map { " · \($0.have)/\($0.need) fragments" } ?? " · MAX"))
                                .font(.mono(11, weight: .bold))
                                .foregroundStyle(spec.rarity.color)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(spec.perkName.uppercased()).font(.display(20))
                    Text(Crew.perkText(spec, level: level) + ".")
                        .font(.system(size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                    if level < Crew.maxLevel {
                        Text("Niveau \(level + 1) : " + Crew.perkText(spec, level: level + 1).lowercased() + ".")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Effet actif seulement quand la carte est dans ton crew.")
                        .font(.mono(10))
                        .foregroundStyle(Theme.faint)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))

                Kicker(text: "Comment la gagner")
                ForEach(sources(member), id: \.self) { line in
                    Text("• " + line).font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if owned {
                    Button {
                        model.setCrewMember(spec.id, active: !active)
                    } label: {
                        Text(active ? "Retirer du crew" : "Ajouter au crew")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!active && refusal != nil)
                    .opacity(!active && refusal != nil ? 0.5 : 1)
                    .padding(.top, 6)
                    if !active, let refusal {
                        Text(refusal + ". Retire d'abord quelqu'un.")
                            .font(.mono(10, weight: .semibold))
                            .foregroundStyle(Theme.faint)
                    }
                }
            }
            .padding(Theme.gutter)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Theme.text)
    }

    /// The ways to earn (or level up) this card.
    private func sources(_ member: CastMember?) -> [String] {
        var lines: [String] = []
        if let member, member.clash != nil {
            lines.append(member.wild ? "Le battre au terrain vague." : "Le battre en clash.")
            if !member.wild, member.cities == nil { lines.append("Enregistrer un feat avec lui (niveau \(ArtistLevel.Unlock.feat.level)).") }
        }
        let quests = model.engine.world.quests.filter { spec.quests.contains($0.id) }
        for quest in quests { lines.append("Terminer la quête « \(quest.title) ».") }
        if lines.isEmpty { lines.append("Un coffre, un jour peut-être…") }
        return lines
    }
}

/// « Nouvelle carte ! »: the card flips over, shows the character and their perk.
struct CrewCardReveal: View {
    @Environment(AppModel.self) private var model
    let gain: CrewGain
    @State private var flipped = false

    var body: some View {
        let spec = Crew.spec(gain.cardId)
        let member = model.engine.castMember(gain.cardId)
        let color = spec?.rarity.color ?? Theme.accent
        VStack(spacing: 14) {
            Text(gain.isNew ? "NOUVELLE CARTE !" : "CARTE NIVEAU \(gain.level) !")
                .font(.display(30))
                .foregroundStyle(.black)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(color)
                .rotationEffect(.degrees(-3))
            ZStack {
                // Back of the card, then the face once it has turned.
                Rectangle().fill(Theme.surface)
                    .overlay(Text("GOSLO").font(.display(34)).foregroundStyle(color.opacity(0.6)))
                    .opacity(flipped ? 0 : 1)
                VStack(spacing: 8) {
                    if let member {
                        PixelImage(HeroSprite.bust(member.look), width: 120)
                    }
                    Text((member?.name ?? gain.cardId).uppercased()).font(.display(26))
                    if let spec {
                        Kicker(text: spec.rarity.label, color: color)
                        Text(Crew.perkText(spec, level: gain.level))
                            .font(.system(size: 13))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.text.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if gain.joinedCrew {
                        Text("REJOINT TON CREW").font(.mono(10, weight: .bold)).foregroundStyle(color)
                    }
                }
                .padding(14)
                .opacity(flipped ? 1 : 0)
                // The face is drawn mirrored so it reads right once the card has turned.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .frame(width: 220, height: 290)
            .background(Theme.background)
            .overlay(Rectangle().stroke(color, lineWidth: 4))
            .shadow(color: color.opacity(0.6), radius: 18)
            .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            Text("Touche pour fermer").font(.mono(10)).foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.text)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).delay(0.25)) { flipped = true }
        }
    }
}
