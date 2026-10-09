import SwiftUI

private let studioGold = Color(red: 1, green: 0.85, blue: 0.3)

/// The studio (from the HUD): the Top goslo radio, recording a single, the season's challenges and the artist level.
struct StudioView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable, Identifiable {
        case top = "Top", studio = "Studio", defis = "Défis"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .top

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Studio").font(.display(44))
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 18)

            if let state = model.state {
                LevelBar(xp: state.artistXP)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 10)

                HStack(spacing: 8) {
                    ForEach(Tab.allCases) { item in
                        Button { tab = item } label: {
                            Text(item.rawValue.uppercased())
                                .font(.mono(12, weight: .bold))
                                .foregroundStyle(tab == item ? Theme.background : Theme.text)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(tab == item ? Theme.accent : Color.clear)
                                .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.gutter)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        switch tab {
                        case .top: TopList(state: state)
                        case .studio: RecordingPanel(state: state) { dismiss() }
                        case .defis: ChallengeList(state: state)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

/// "NIV. 3 · Nom qui circule" and the bar to the next level.
struct LevelBar: View {
    let xp: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("NIV. \(ArtistLevel.level(xp: xp))")
                    .font(.mono(12, weight: .heavy))
                    .foregroundStyle(studioGold)
                Text(ArtistLevel.title(xp: xp).uppercased())
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            GeometryReader { bar in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12))
                    Rectangle().fill(studioGold).frame(width: bar.size.width * ArtistLevel.progress(xp: xp))
                }
            }
            .frame(height: 5)
        }
    }
}

/// The Top goslo radio: your singles in gold.
private struct TopList: View {
    @Environment(AppModel.self) private var model
    let state: GameState

    var body: some View {
        Kicker(text: "Top goslo radio · cette période")
        let top = model.engine.chart(in: state)
        ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.display(26))
                    .foregroundStyle(entry.isPlayer ? studioGold : Theme.muted)
                    .frame(width: 34, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: entry.isPlayer ? .bold : .semibold))
                        .foregroundStyle(entry.isPlayer ? studioGold : Theme.text)
                        .lineLimit(1)
                    Text(entry.artist.uppercased())
                        .font(.mono(10, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let id = entry.singleId, let single = state.singles.first(where: { $0.id == id }),
                   let last = single.ranks.last ?? nil {
                    let now = index + 1
                    Text(last > now ? "▲\(last - now)" : (last < now ? "▼\(now - last)" : "="))
                        .font(.mono(11, weight: .bold))
                        .foregroundStyle(last >= now ? Color.green : Theme.accent)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(entry.isPlayer ? studioGold.opacity(0.1) : Color.clear)
            .overlay(Rectangle().stroke(entry.isPlayer ? studioGold : Theme.line, lineWidth: entry.isPlayer ? 1.5 : 1))
        }
        if !top.contains(where: \.isPlayer) {
            Text(state.singles.isEmpty ? "Aucun de tes sons dans le Top. Passe au studio : un single, et le classement change."
                                       : "Tes singles sont sortis du Top. Le public a la mémoire courte : il en faut un nouveau.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)
        }
    }
}

/// Recording a single: pick the material, nail the takes, add a clip or a featuring, release.
private struct RecordingPanel: View {
    @Environment(AppModel.self) private var model
    let state: GameState
    let close: () -> Void

    @State private var picked: String?
    @State private var takes: Int?
    @State private var clip = false
    @State private var feat: String?

    var body: some View {
        if let refusal = model.engine.studioRefusal(in: state) {
            Text(refusal)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
        } else if picked == nil {
            Kicker(text: "Qu'est-ce qu'on enregistre ? · studio \(ChartRules.studioPrice) d'argent, 1 action")
            ForEach(model.engine.singleCandidates(in: state)) { track in
                Button { picked = track.id } label: {
                    HStack {
                        Text(track.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                        Spacer()
                        Text(String(repeating: "★", count: max(1, track.quality / 2)))
                            .font(.system(size: 11)).foregroundStyle(studioGold)
                    }
                    .padding(12)
                    .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else if takes == nil {
            Kicker(text: "En cabine · tape quand le curseur est dans la zone dorée")
            TakesGame { takes = $0 }
        } else if let picked, let takes {
            let material = model.engine.singleCandidates(in: state).first { $0.id == picked }
            let director = model.engine.hasPerk(.clipReal, in: state)
            let quality = min(10, ChartRules.quality(material: material?.quality ?? 5, perfectTakes: takes, feat: feat != nil)
                              + (director ? 1 : 0))
            Text("\(takes) prise\(takes > 1 ? "s" : "") parfaite\(takes > 1 ? "s" : "") sur \(ChartRules.takes)")
                .font(.display(28))
                .foregroundStyle(takes >= 3 ? studioGold : Theme.text)
            Text("Qualité du son : \(quality)/10")
                .font(.mono(13, weight: .bold))
                .foregroundStyle(Theme.muted)

            if director {
                Text("🎬 Ton réal est booké : clip offert, +1 qualité.").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(studioGold)
            } else if ArtistLevel.unlocks(.clip, in: state) {
                Toggle(isOn: $clip) {
                    Text("Tourner un clip (+\(ChartRules.clipPrice) d'argent, gros buzz)").font(.system(size: 14, weight: .semibold))
                }
                .tint(Theme.accent)
            } else {
                Text("🔒 Clips : niveau \(ArtistLevel.Unlock.clip.level)").font(.mono(11, weight: .bold)).foregroundStyle(Theme.faint)
            }
            if ArtistLevel.unlocks(.feat, in: state) {
                let guests = model.engine.featCandidates(in: state)
                if !guests.isEmpty {
                    Kicker(text: "Featuring (+1 qualité)")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(guests) { guest in
                                Button { feat = feat == guest.id ? nil : guest.id } label: {
                                    Text(guest.name)
                                        .font(.mono(11, weight: .bold))
                                        .foregroundStyle(feat == guest.id ? Theme.background : Theme.text)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(feat == guest.id ? Theme.accent : Color.clear)
                                        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                Text("🔒 Featurings : niveau \(ArtistLevel.Unlock.feat.level)").font(.mono(11, weight: .bold)).foregroundStyle(Theme.faint)
            }

            let price = ChartRules.studioPrice + (clip && !director ? ChartRules.clipPrice : 0)
            Button("Sortir le single · \(price) d'argent") {
                if model.releaseSingle(sourceId: picked, perfectTakes: takes, clip: clip, feat: feat) { close() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(state.stats.argent <= price)
            .padding(.top, 8)
        }
    }
}

/// Four takes: a cursor sweeps the bar, tap while it's in the gold zone. It speeds up each take.
private struct TakesGame: View {
    let finish: (Int) -> Void

    @State private var take = 0
    @State private var perfect = 0
    @State private var start = Date()
    @State private var flash: Bool?

    private static let zone = 0.42...0.58

    private func position(at date: Date) -> Double {
        let speed = 0.9 + Double(take) * 0.35
        let phase = (date.timeIntervalSince(start) * speed).truncatingRemainder(dividingBy: 2)
        return phase < 1 ? phase : 2 - phase
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PRISE \(min(take + 1, ChartRules.takes)) / \(ChartRules.takes) · \(perfect) parfaite\(perfect > 1 ? "s" : "")")
                .font(.mono(12, weight: .bold))
                .foregroundStyle(Theme.muted)
            TimelineView(.animation) { timeline in
                let x = position(at: timeline.date)
                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.1))
                        Rectangle().fill(studioGold.opacity(0.5))
                            .frame(width: bar.size.width * (Self.zone.upperBound - Self.zone.lowerBound))
                            .offset(x: bar.size.width * Self.zone.lowerBound)
                        Rectangle().fill(.white)
                            .frame(width: 4)
                            .offset(x: (bar.size.width - 4) * x)
                    }
                }
                .frame(height: 44)
                .overlay(Rectangle().stroke(flash == true ? studioGold : (flash == false ? Theme.accent : Theme.line), lineWidth: 2))
            }
            Button("🎙 ENREGISTRER") { tap() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func tap() {
        guard take < ChartRules.takes else { return }
        let hit = Self.zone.contains(position(at: Date()))
        if hit { perfect += 1 }
        SoundEngine.shared.play(hit ? .concertHit : .miss)
        withAnimation(.easeOut(duration: 0.15)) { flash = hit }
        take += 1
        start = Date()
        if take == ChartRules.takes {
            let result = perfect
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                finish(result)
            }
        }
    }
}

/// The season's challenges, with their progress.
private struct ChallengeList: View {
    let state: GameState

    var body: some View {
        Kicker(text: "Défis de la saison · \(Challenges.reward.xp) XP chacun")
        if state.challenges.isEmpty {
            Text("Les défis arrivent avec la prochaine action.").font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
        ForEach(state.challenges) { challenge in
            let progress = Challenges.progress(challenge, in: state), goal = Challenges.goal(challenge)
            HStack(spacing: 10) {
                Image(systemName: challenge.done ? "checkmark.seal.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(challenge.done ? studioGold : Theme.muted)
                Text(challenge.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(challenge.done ? Theme.muted : Theme.text)
                    .strikethrough(challenge.done)
                Spacer()
                Text("\(challenge.done ? goal : progress) / \(goal)")
                    .font(.mono(12, weight: .bold))
                    .foregroundStyle(challenge.done ? studioGold : Theme.accent)
            }
            .padding(12)
            .overlay(Rectangle().stroke(challenge.done ? studioGold.opacity(0.5) : Theme.line, lineWidth: 1))
        }
        Kicker(text: "Ce que débloquent les niveaux").padding(.top, 14)
        ForEach(ArtistLevel.Unlock.allCases, id: \.self) { unlock in
            let open = ArtistLevel.unlocks(unlock, in: state)
            HStack(alignment: .top, spacing: 8) {
                Text(open ? "✓" : "NIV. \(unlock.level)")
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(open ? studioGold : Theme.faint)
                    .frame(width: 48, alignment: .leading)
                Text(unlock.label)
                    .font(.system(size: 13))
                    .foregroundStyle(open ? Theme.text : Theme.muted)
            }
        }
    }
}
