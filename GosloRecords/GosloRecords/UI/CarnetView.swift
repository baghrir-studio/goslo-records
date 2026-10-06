import SwiftUI

/// The player's notebook: quests, contacts, skills.
struct CarnetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let state: GameState

    enum Tab: String, CaseIterable {
        case quetes = "Quêtes"
        case contacts = "Contacts"
        case competences = "Skills"
        case objets = "Objets"
    }

    @State private var tab: Tab = .quetes

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CARNET").font(.display(40))
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 24)

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { item in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { tab = item }
                    } label: {
                        VStack(spacing: 6) {
                            Text(item.rawValue.uppercased())
                                .font(.mono(11, weight: .bold))
                                .foregroundStyle(tab == item ? Theme.text : Theme.muted)
                            Rectangle()
                                .fill(tab == item ? Theme.accent : Theme.line)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .quetes: quests
                    case .contacts: contacts
                    case .competences: skills
                    case .objets: items
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Theme.text)
    }

    // MARK: Quêtes

    @ViewBuilder
    private var quests: some View {
        let engine = model.engine
        let active = engine.activeQuests(in: state)
        let done = engine.world.quests.filter { state.completedQuests.contains($0.id) }

        if active.isEmpty && done.isEmpty {
            Text("Aucune quête pour l'instant. Avance dans ta carrière, elles viendront à toi.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted)
        }

        ForEach(active) { quest in
            let current = state.questProgress[quest.id, default: 0]
            VStack(alignment: .leading, spacing: 10) {
                Text(quest.title.uppercased()).font(.display(26))
                if !quest.description.isEmpty {
                    Text(quest.description).font(.system(size: 14)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(quest.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(index < current ? "✓" : (index == current ? "●" : "○"))
                            .font(.mono(12, weight: .bold))
                            .foregroundStyle(index <= current ? Theme.accent : Theme.faint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.label)
                                .font(.system(size: 15, weight: index == current ? .semibold : .regular))
                                .foregroundStyle(index < current ? Theme.muted : (index == current ? Theme.text : Theme.faint))
                                .strikethrough(index < current, color: Theme.muted)
                            if index == current, let location = step.location {
                                Text("→ \(location.name.uppercased())")
                                    .font(.mono(10, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
        }

        if !done.isEmpty {
            Kicker(text: "Terminées").padding(.top, 8)
            ForEach(done) { quest in
                HStack {
                    Text("✓").foregroundStyle(Theme.accent).font(.mono(12, weight: .bold))
                    Text(quest.title).font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    // MARK: Contacts

    @ViewBuilder
    private var contacts: some View {
        let cast = model.engine.world.cast.filter { !$0.wild }
        let met = cast.filter { state.metCast.contains($0.id) }

        if met.isEmpty {
            Text("Tu n'as encore croisé personne. Sors de chez toi.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted)
        }

        ForEach(met) { member in
            let relation = state.relation(member.id)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(member.name.uppercased()).font(.display(24))
                    Spacer()
                    if state.flags.contains("clash_gagne_\(member.id)") {
                        Text("BATTU").font(.mono(9, weight: .bold)).foregroundStyle(Theme.accent)
                    } else if member.clash != nil {
                        Text("⚔").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                }
                Text(member.role.uppercased()).font(.mono(10, weight: .semibold)).foregroundStyle(Theme.muted)
                Text(member.bio).font(.system(size: 14)).foregroundStyle(Theme.text.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Theme.line)
                            Rectangle().fill(relation >= 60 ? Theme.accent : Theme.text.opacity(0.7))
                                .frame(width: geo.size.width * CGFloat(relation) / 100)
                        }
                    }
                    .frame(height: 3)
                    Text(relationLabel(relation))
                        .font(.mono(10, weight: .bold))
                        .foregroundStyle(relation >= 60 ? Theme.accent : Theme.muted)
                        .frame(width: 70, alignment: .trailing)
                }
                if member.id == GameEngine.chroniqueurId {
                    Text(relation >= GameEngine.scoutingRelation
                         ? "Il te briefe avant chaque clash."
                         : "À \(GameEngine.scoutingRelation) de relation, il te briefera avant tes clashs.")
                        .font(.mono(10)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.vertical, 6)
            Rectangle().fill(Theme.line).frame(height: 1)
        }

        if met.count < cast.count {
            Text("\(cast.count - met.count) personnage\(cast.count - met.count > 1 ? "s" : "") encore inconnu\(cast.count - met.count > 1 ? "s" : "").")
                .font(.mono(11)).foregroundStyle(Theme.faint)
        }
    }

    private func relationLabel(_ value: Int) -> String {
        switch value {
        case ..<20: "ENNEMI"
        case ..<40: "FROID"
        case ..<60: "NEUTRE"
        case ..<80: "POTE"
        default: "FAMILLE"
        }
    }

    // MARK: Compétences

    @ViewBuilder
    private var skills: some View {
        ForEach(Skill.allCases) { skill in
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text(skill.label.uppercased()).font(.display(28))
                    Spacer()
                    Text("NIV. \(state.skills.level(skill))")
                        .font(.mono(14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.line)
                        Rectangle().fill(Theme.accent).frame(width: geo.size.width * state.skills.progress(skill))
                    }
                }
                .frame(height: 3)
                Text(skillHelp(skill)).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }

    private func skillHelp(_ skill: Skill) -> String {
        let move = ClashMove.allCases.first { $0.skill == skill }!
        let places = Location.allCases.filter { $0.visitXP[skill] != nil }.map(\.name).joined(separator: ", ")
        return "En clash : \(move.label). S'entraîne : \(places)."
    }

    // MARK: Objets

    @ViewBuilder
    private var items: some View {
        let owned = model.engine.ownedItems(in: state)
        if owned.isEmpty {
            Text("Aucun objet. Les objets mythiques se méritent. Ou s'empruntent à un cousin.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted)
        }
        ForEach(owned) { item in
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name.uppercased()).font(.display(24))
                Text(item.description).font(.system(size: 14)).foregroundStyle(Theme.text.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(item.clashBonus.sorted { $0.key.rawValue < $1.key.rawValue }, id: \.key) { move, bonus in
                    Text("EN CLASH : \(move.label.uppercased()) +\(bonus) NIV.")
                        .font(.mono(10, weight: .bold)).foregroundStyle(Theme.accent)
                }
                if let secret = item.secret {
                    Text("TECHNIQUE SECRÈTE : \(secret.name.uppercased())")
                        .font(.mono(10, weight: .bold)).foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                }
            }
            .padding(.vertical, 6)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}
