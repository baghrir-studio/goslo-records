import SwiftUI

private let tournamentGold = Color(red: 1, green: 0.85, blue: 0.3)

/// « Le Tournoi goslo radio »: the ladder of bosses, one per artist level, each with a technique to win.
/// Opened by talking to the radio host, or from the notebook.
struct TournamentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Called with the boss's id when the player challenges them (the presenter closes the sheet).
    var onChallenge: ((String) -> Void)? = nil

    var body: some View {
        if let state = model.state {
            content(state)
        } else {
            Color.clear
        }
    }

    private func content(_ state: GameState) -> some View {
        let rungs = model.engine.tournamentBosses(in: state)
        let beaten = rungs.filter { $0.status == .beaten }.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("TOURNOI").font(.display(40))
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 6) {
                Kicker(text: "goslo radio · DJ Noize aux platines", color: tournamentGold)
                Text("Niveau d'artiste \(ArtistLevel.level(xp: state.artistXP)) — \(ArtistLevel.title(xp: state.artistXP))")
                    .font(.system(size: 15, weight: .semibold))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.line)
                        Rectangle().fill(tournamentGold)
                            .frame(width: geo.size.width * CGFloat(rungs.isEmpty ? 0 : Double(beaten) / Double(rungs.count)))
                    }
                }
                .frame(height: 3)
                Text("\(beaten) / \(rungs.count) tours gagnés")
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if state.flags.contains(GameEngine.tournamentChampionFlag) {
                        Text("CHAMPION DU TOURNOI. DJ Noize passe encore ton son en boucle.")
                            .font(.mono(11, weight: .bold))
                            .foregroundStyle(Theme.background)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(tournamentGold)
                    }
                    ForEach(rungs) { rung in
                        row(rung, state: state)
                    }
                    Text("Chaque tour coûte une action. Une défaite t'apprend le jeu du boss : +1 niveau contre lui au prochain essai (jusqu'à +\(GameEngine.maxBossExperience)).")
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
    }

    @ViewBuilder
    private func row(_ rung: TournamentRung, state: GameState) -> some View {
        let locked = rung.status == .locked
        let available = rung.status == .available
        let canStart = model.engine.canStartTournament(rung.id, in: state)
        // The weak spot shows once you've lost to them, or when the chroniqueur briefs you.
        let scouted = state.bossLosses[rung.id, default: 0] > 0 || model.engine.scoutingReport(for: rung.id, in: state) != nil
        // Locked and never met: a silhouette, no name.
        let unknown = locked && !state.metCast.contains(rung.id)
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                PixelImage(HeroSprite.bust(rung.member.look), width: 56)
                    .grayscale(locked ? 1 : 0)
                    .colorMultiply(unknown ? Color.black : Color.white)
                    .opacity(locked ? 0.45 : 1)
                if rung.status == .beaten {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tournamentGold)
                }
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(rung.round == model.engine.story.tournament.count ? "FINALE" : "TOUR \(rung.round)")
                        .font(.mono(10, weight: .bold))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text(statusLabel(rung.status))
                        .font(.mono(9, weight: .bold))
                        .foregroundStyle(available ? Theme.background : (rung.status == .beaten ? tournamentGold : Theme.faint))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(available ? Theme.accent : Color.clear)
                        .overlay(Rectangle().stroke(available ? Theme.accent : Theme.line, lineWidth: 1))
                }
                Text(unknown ? "???" : rung.member.name.uppercased())
                    .font(.display(24))
                Text("NIVEAU \(rung.boss.minArtistLevel) REQUIS")
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(locked ? Theme.faint : Theme.muted)
                if !locked {
                    Text(TextTemplate.render(rung.member.bio, for: state.rapper))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let technique = rung.technique {
                    HStack(spacing: 6) {
                        Image(systemName: technique.secret.prop ?? "star.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("À GAGNER : \(technique.secret.name.uppercased())")
                            .font(.mono(10, weight: .bold))
                    }
                    .foregroundStyle(rung.status == .beaten ? Theme.muted : tournamentGold)
                }
                if available, let profile = rung.member.clash {
                    Text(scouted ? "Point faible : \(profile.weakness?.label ?? "aucun") · Résiste à : \(profile.resistance?.label ?? "rien")"
                                 : "Point faible : inconnu. Perds une fois, ou demande au chroniqueur.")
                        .font(.mono(10))
                        .foregroundStyle(Theme.muted)
                    Text(TextTemplate.render(rung.boss.intro, for: state.rapper))
                        .font(.system(size: 13).italic())
                        .foregroundStyle(Theme.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        if let onChallenge { onChallenge(rung.id) } else { model.startTournament(rung.id) }
                    } label: {
                        Text(canStart ? "Défier" : "Pas maintenant")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canStart)
                    .opacity(canStart ? 1 : 0.5)
                    .padding(.top, 4)
                } else if let reason = rung.lockReason {
                    Text(reason)
                        .font(.mono(10, weight: .semibold))
                        .foregroundStyle(Theme.faint)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(available ? Theme.accent.opacity(0.6) : Theme.line, lineWidth: 1))
    }

    private func statusLabel(_ status: TournamentRung.Status) -> String {
        switch status {
        case .locked: "VERROUILLÉ"
        case .available: "OUVERT"
        case .beaten: "GAGNÉ"
        }
    }
}

extension View {
    /// Presents the Tournoi when the model asks for it (talking to the radio host).
    func tournamentSheet(_ model: AppModel) -> some View {
        sheet(isPresented: Binding(get: { model.showingTournament }, set: { model.showingTournament = $0 })) {
            TournamentView()
                .environment(model)
                .presentationBackground(Theme.background)
                .presentationDragIndicator(.visible)
        }
    }
}
