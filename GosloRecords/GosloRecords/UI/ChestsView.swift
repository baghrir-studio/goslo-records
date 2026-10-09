import SwiftUI

/// Victory chests (four slots) and the player's league: pick the chest to unlock, open the ready ones.
/// Time is counted in periods, never in real time.
struct ChestsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Int?
    @State private var opening: ChestOpening?

    var body: some View {
        ZStack {
            if let state = model.state {
                content(state)
            } else {
                Color.clear
            }
            if let opening {
                ChestOpeningView(opening: opening) {
                    withAnimation(.easeOut(duration: 0.2)) { self.opening = nil }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .foregroundStyle(Theme.text)
    }

    private func content(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("COFFRES").font(.display(40))
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LeagueCard(state: state)
                    slots(state)
                    if let id = selected, let chest = state.chests.first(where: { $0.id == id }) {
                        detail(chest, in: state)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Text("Gagne des clashs pour remplir tes \(Chests.slots) emplacements. Un seul coffre se déverrouille à la fois, et le temps se compte en périodes de ta carrière.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    LeagueLadder(state: state)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selected)
        .onAppear {
            // Straight to the chest that's ready, if any.
            if selected == nil {
                selected = state.chests.first { model.engine.chestStatus($0, in: state) == .ready }?.id ?? state.chests.first?.id
            }
        }
    }

    // MARK: Slots

    private func slots(_ state: GameState) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<Chests.slots, id: \.self) { index in
                if state.chests.indices.contains(index) {
                    let chest = state.chests[index]
                    Button {
                        selected = chest.id
                    } label: {
                        slot(chest, in: state)
                    }
                    .buttonStyle(PressScaleStyle())
                } else {
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        Text("VIDE").font(.mono(10, weight: .bold)).foregroundStyle(Theme.faint)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 112)
                    .overlay(Rectangle().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
            }
        }
    }

    private func slot(_ chest: VictoryChest, in state: GameState) -> some View {
        let status = model.engine.chestStatus(chest, in: state)
        let ready = status == .ready
        return VStack(spacing: 6) {
            PixelImage(ChestArt.chest(chest.rarity), width: 54)
                .shadow(color: ready ? chest.rarity.tint.opacity(0.9) : .clear, radius: 10)
            Text(chest.rarity.name.uppercased())
                .font(.mono(9, weight: .heavy))
                .foregroundStyle(chest.rarity.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(statusLabel(status, chest))
                .font(.mono(9, weight: .bold))
                .foregroundStyle(ready ? Theme.background : Theme.muted)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(ready ? Color.green : Color.clear)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 112)
        .background(Color.white.opacity(selected == chest.id ? 0.08 : 0.03))
        .overlay(Rectangle().stroke(selected == chest.id ? chest.rarity.tint : Theme.line, lineWidth: selected == chest.id ? 2 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coffre \(chest.rarity.name), \(statusLabel(status, chest))")
    }

    private func statusLabel(_ status: ChestStatus, _ chest: VictoryChest) -> String {
        switch status {
        case .ready: "PRÊT !"
        case .unlocking(let left): "\(left) PÉR."
        case .locked: "\(chest.rarity.unlockPeriods) PÉR. ⏸"
        }
    }

    // MARK: Detail

    private func detail(_ chest: VictoryChest, in state: GameState) -> some View {
        let engine = model.engine
        let status = engine.chestStatus(chest, in: state)
        let cost = engine.rushCost(chest, in: state)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PixelImage(ChestArt.chest(chest.rarity), width: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("COFFRE \(chest.rarity.name.uppercased())").font(.display(24)).foregroundStyle(chest.rarity.tint)
                    Text(contentsHint(chest.rarity))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            switch status {
            case .ready:
                Button("Ouvrir") { open(chest, rush: false) }
                    .buttonStyle(PrimaryButtonStyle())
            case .unlocking(let left):
                Text("Se déverrouille : encore \(left) période\(left > 1 ? "s" : "").")
                    .font(.mono(12, weight: .bold))
                rushButton(chest, cost: cost, in: state)
            case .locked:
                if let refusal = engine.unlockRefusal(chest.id, in: state) {
                    Text(refusal).font(.mono(12, weight: .bold)).foregroundStyle(Theme.muted)
                } else {
                    Button("Déverrouiller (\(chest.rarity.unlockPeriods) période\(chest.rarity.unlockPeriods > 1 ? "s" : ""))") {
                        model.startChestUnlock(chest.id)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                rushButton(chest, cost: cost, in: state)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }

    private func rushButton(_ chest: VictoryChest, cost: Int, in state: GameState) -> some View {
        let refusal = model.engine.rushRefusal(chest.id, in: state)
        return Button {
            open(chest, rush: true)
        } label: {
            Text(refusal ?? "Ouvrir maintenant · \(cost) argent")
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(refusal != nil)
        .opacity(refusal == nil ? 1 : 0.5)
    }

    private func contentsHint(_ rarity: ChestRarity) -> String {
        var parts = ["\(rarity.money.lowerBound)–\(rarity.money.upperBound) argent", "\(rarity.xp.lowerBound)–\(rarity.xp.upperBound) XP"]
        if rarity.wearableChance >= 100 { parts.append("une fringue garantie") } else if rarity.wearableChance > 0 { parts.append("parfois une fringue") }
        if rarity.crewChance > 0 { parts.append("parfois une carte crew") }
        if rarity.techniqueChance > 0 { parts.append("peut-être une technique") }
        return parts.joined(separator: " · ")
    }

    private func open(_ chest: VictoryChest, rush: Bool) {
        guard let loot = model.openChest(chest.id, rush: rush) else { return }
        selected = nil
        withAnimation(.easeOut(duration: 0.2)) {
            opening = ChestOpening(loot: loot, rewards: ChestOpening.rewards(of: loot, engine: model.engine))
        }
    }
}

// MARK: - Opening

/// A chest being opened: what came out, as the lines revealed one by one.
struct ChestOpening: Identifiable, Equatable {
    struct Reward: Identifiable, Equatable {
        let id: Int
        let symbol: String
        let text: String
        let special: Bool
    }

    let id = UUID()
    let loot: ChestLoot
    let rewards: [Reward]

    static func rewards(of loot: ChestLoot, engine: GameEngine) -> [Reward] {
        var lines: [(String, String, Bool)] = []
        if loot.money > 0 { lines.append(("banknote.fill", "+\(loot.money) ARGENT", false)) }
        lines.append(("star.fill", "+\(loot.xp) XP D'ARTISTE", false))
        if let id = loot.wearable, let item = Wardrobe.item(id) {
            lines.append(("tshirt.fill", "\(item.name.uppercased()) — PORTÉE !", true))
        }
        if let id = loot.technique, let technique = engine.story.techniques.first(where: { $0.id == id }) {
            lines.append(("bolt.fill", "TECHNIQUE : \(technique.secret.name.uppercased())", true))
        }
        if let gain = loot.crew {
            let name = (engine.castMember(gain.cardId)?.name ?? gain.cardId).uppercased()
            lines.append(("person.crop.rectangle.stack.fill",
                          gain.isNew ? "CARTE CREW : \(name)" : (gain.leveledUp ? "\(name) : NIVEAU \(gain.level) !" : "FRAGMENT : \(name)"), true))
        }
        for note in loot.notes where note.hasPrefix("NIVEAU") { lines.append(("arrow.up.circle.fill", note, true)) }
        return lines.enumerated().map { Reward(id: $0.offset, symbol: $0.element.0, text: $0.element.1, special: $0.element.2) }
    }
}

/// Shake, burst, then the contents one by one, with sounds and vibrations.
private struct ChestOpeningView: View {
    let opening: ChestOpening
    let done: () -> Void

    @State private var tilt: Double = 0
    @State private var opened = false
    @State private var flash = 0.0
    @State private var shown = 0
    @State private var spin = false

    private var rarity: ChestRarity { opening.loot.rarity }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            if opened {
                // Rays behind the open chest.
                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        Rectangle()
                            .fill(rarity.tint.opacity(0.35))
                            .frame(width: 6, height: 150)
                            .offset(y: -75)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                }
                .rotationEffect(.degrees(spin ? 360 : 0))
                .offset(y: -60)
                .transition(.scale(scale: 0.1).combined(with: .opacity))
            }

            VStack(spacing: 16) {
                Text("COFFRE \(rarity.name.uppercased())")
                    .font(.display(32))
                    .foregroundStyle(rarity.tint)
                PixelImage(ChestArt.chest(rarity, open: opened), width: 150)
                    .rotationEffect(.degrees(tilt), anchor: .bottom)
                    .scaleEffect(opened ? 1.08 : 1)
                VStack(spacing: 8) {
                    ForEach(opening.rewards.prefix(shown)) { reward in
                        HStack(spacing: 10) {
                            Image(systemName: reward.symbol)
                                .font(.system(size: 15, weight: .bold))
                            Text(reward.text)
                                .font(.mono(13, weight: .heavy))
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(reward.special ? Theme.background : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(reward.special ? rarity.tint : Color.white.opacity(0.08))
                        .overlay(Rectangle().stroke(rarity.tint.opacity(0.7), lineWidth: 1))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(minHeight: 120, alignment: .top)
                if shown >= opening.rewards.count && opened {
                    Button("Récupérer", action: done)
                        .buttonStyle(PrimaryButtonStyle())
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Theme.gutter)

            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .task { await play() }
    }

    private func play() async {
        // The chest shakes, harder and faster.
        for step in 0..<7 {
            withAnimation(.easeInOut(duration: 0.07)) { tilt = step.isMultiple(of: 2) ? 7 : -7 }
            SoundEngine.shared.play(step < 4 ? .blip : .hit)
            Haptics.shared.play(step < 4 ? .weakHit : .hit)
            try? await Task.sleep(for: .milliseconds(step < 4 ? 230 : 130))
        }
        withAnimation(.easeOut(duration: 0.1)) { tilt = 0 }
        // Burst.
        flash = 0.9
        SoundEngine.shared.play(.secretHit)
        Haptics.shared.play(.strongHit)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { opened = true }
        withAnimation(.easeOut(duration: 0.5)) { flash = 0 }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { spin = true }
        try? await Task.sleep(for: .milliseconds(450))
        // The contents, one by one.
        for reward in opening.rewards {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { shown += 1 }
            SoundEngine.shared.play(reward.special ? .levelUp : .statUp)
            Haptics.shared.play(reward.special ? .perfect : .good)
            try? await Task.sleep(for: .milliseconds(reward.special ? 750 : 520))
        }
        if rarity == .legendaire || rarity == .or {
            SoundEngine.shared.play(.victory)
            Haptics.shared.play(.victory)
        }
    }
}

// MARK: - League

/// The current league, the trophies and the way to the next one.
private struct LeagueCard: View {
    let state: GameState

    var body: some View {
        let league = state.league
        let next = league.next
        HStack(spacing: 14) {
            PixelImage(ChestArt.badge(league), width: 52)
            VStack(alignment: .leading, spacing: 4) {
                Kicker(text: "Ligue", color: league.tint)
                Text(league.name.uppercased()).font(.display(30)).foregroundStyle(league.tint)
                if let title = state.leagueTitle {
                    Text("« \(title) »").font(.system(size: 13, weight: .semibold))
                }
                Text("\(state.trophies) trophées").font(.mono(12, weight: .bold))
                if let next {
                    let low = league.threshold, high = next.threshold
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Theme.line)
                            Rectangle().fill(league.tint)
                                .frame(width: geo.size.width * CGFloat(min(1, max(0, Double(state.trophies - low) / Double(max(1, high - low))))))
                        }
                    }
                    .frame(height: 4)
                    Text("\(next.name) à \(next.threshold) · on ne redescend jamais sous \(state.bestLeague.threshold)")
                        .font(.mono(10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Tout en haut. Pour toujours.").font(.mono(10, weight: .semibold)).foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(league.tint.opacity(0.08))
        .overlay(Rectangle().stroke(league.tint.opacity(0.6), lineWidth: 1))
    }
}

/// Every league, its threshold and its one-time reward.
private struct LeagueLadder: View {
    let state: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Les ligues (pour toujours)")
            ForEach(Array(League.allCases.reversed())) { league in
                let reached = league <= state.bestLeague
                HStack(spacing: 10) {
                    PixelImage(ChestArt.badge(league), width: 22)
                        .opacity(reached ? 1 : 0.35)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(league.name.uppercased()) · \(league.threshold)")
                            .font(.mono(11, weight: .heavy))
                            .foregroundStyle(reached ? league.tint : Theme.muted)
                        if let title = league.title {
                            Text(reward(league, title: title))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    if reached {
                        Text("✓").font(.mono(13, weight: .bold)).foregroundStyle(league.tint)
                    }
                }
            }
        }
    }

    private func reward(_ league: League, title: String) -> String {
        let reward = league.reward
        let chest = reward.chest.map { " · coffre \($0.name)" } ?? ""
        return "« \(title) » · +\(reward.money) argent\(chest)"
    }
}
