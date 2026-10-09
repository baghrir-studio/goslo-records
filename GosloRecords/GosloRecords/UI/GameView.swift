import SwiftUI

/// The game screen: the neighbourhood, and on top of it the interiors, dialogues and clashes.
struct GameView: View {
    @Environment(AppModel.self) private var model
    @State private var showCarnet = false
    @State private var showShop = false
    @State private var showStudio = false
    @State private var showCalibration = false
    @State private var confirmRetire = false

    var body: some View {
        if let state = model.state, let map = model.map {
            ZStack {
                WorldView(map: map, state: state)
                    .ignoresSafeArea()

                if let location = model.interior {
                    InteriorView(location: location, npc: interiorNPC, player: state.rapper.look,
                                 showsBanner: !isInterview)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if model.phase == .cinematic || model.letterbox {
                    CinematicOverlay()
                        .zIndex(5)
                } else {
                    // Full-screen modes hide the map, including behind the translucent HUD.
                    if let backdrop = fullScreenBackdrop {
                        backdrop
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                    VStack(spacing: 0) {
                        if let daily = model.dailyClash {
                            DailyHeader(challenge: daily, opponent: model.engine.castMember(daily.opponentId)?.name ?? "???")
                        } else if let game = model.arcadePlaying {
                            ArcadeHeader(game: game)
                        } else {
                            hud(state)
                        }
                        if case .clash(let clash) = model.phase {
                            BattleView(clash: clash, state: state)
                                .background(Color(red: 0.05, green: 0.05, blue: 0.06).ignoresSafeArea(edges: .bottom))
                                .transition(.opacity)
                        } else if case .interview(let interview) = model.phase {
                            InterviewView(interview: interview, state: state)
                                .background(Color.black.opacity(0.35).ignoresSafeArea(edges: .bottom))
                                .transition(.opacity)
                        } else if case .writing(let writing) = model.phase {
                            WritingView(writing: writing, state: state)
                                .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea(edges: .bottom))
                                .transition(.opacity)
                        } else if case .negotiation(let negotiation) = model.phase {
                            NegotiationView(negotiation: negotiation, state: state)
                                .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea(edges: .bottom))
                                .transition(.opacity)
                        } else if case .minigame(let minigame) = model.phase {
                            MinigameView(minigame: minigame, state: state)
                                .background(Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea(edges: .bottom))
                                .transition(.opacity)
                        } else if case .concert(let concert) = model.phase {
                            ConcertView(concert: concert, state: state)
                                .background(Color(red: 0.05, green: 0.03, blue: 0.06).ignoresSafeArea(edges: .bottom))
                                .transition(.opacity)
                        } else {
                            if model.phase == .overworld {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let chapter = model.chapter {
                                        ObjectiveBanner(chapter: chapter, objective: model.objective,
                                                        elsewhere: model.objectiveDistrict,
                                                        transit: Transit.of(state.rapper.city))
                                    }
                                    if let headline = model.radioHeadline {
                                        RadioTicker(text: headline)
                                            .id(headline)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.radioHeadline)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.objective?.id)
                            }
                            Spacer(minLength: 0)
                            bottom(state)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 8)
                        }
                    }
                }

                if let transition = model.transition {
                    TransitionOverlay(transition: transition)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .animation(.easeOut(duration: 0.25), value: model.phase)
            .animation(.easeInOut(duration: 0.3), value: model.interior)
            .sensoryFeedback(.impact(weight: .light), trigger: model.deltaToken)
            .confirmationDialog("Raccrocher le micro ?", isPresented: $confirmRetire, titleVisibility: .visible) {
                Button("Finir ma carrière maintenant", role: .destructive) { model.retire() }
                Button("Pas encore", role: .cancel) {}
            } message: {
                Text("Ta fin dépend de là où tu en es : streams, respect, argent, mental, et ce que tu as accompli.")
            }
            .sheet(isPresented: $showCalibration) {
                CalibrationView().presentationBackground(Theme.background)
            }
            .sheet(isPresented: $showStudio) {
                StudioView()
                    .environment(model)
                    .presentationBackground(Theme.background)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showShop) {
                ShopView()
                    .environment(model)
                    .presentationBackground(Theme.background)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCarnet) {
                CarnetView(state: state)
                    .environment(model)
                    .presentationBackground(Theme.background)
                    .presentationDragIndicator(.visible)
            }
        } else {
            VStack(spacing: 16) {
                Text("Aucune carrière en cours.").font(.display(28))
                Button("Accueil") { model.go(.home) }.buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.gutter)
        }
    }

    /// Background of the full-screen modes (the interview keeps the studio visible).
    private var fullScreenBackdrop: Color? {
        switch model.phase {
        case .clash: Color(red: 0.05, green: 0.05, blue: 0.06)
        case .writing, .negotiation: Color(red: 0.06, green: 0.06, blue: 0.08)
        case .minigame: Color(red: 0.05, green: 0.05, blue: 0.07)
        case .concert: Color(red: 0.05, green: 0.03, blue: 0.06)
        default: nil
        }
    }

    private var isInterview: Bool {
        if case .interview = model.phase { return true }
        return false
    }

    private var interiorNPC: CharacterLook? {
        switch model.phase {
        case .encounter(let event), .consequence(let event?, _):
            return event.npc.flatMap(model.engine.castMember)?.look
        case .interview(let interview):
            return model.engine.interview(interview.id).flatMap { model.engine.castMember($0.host) }?.look
        default:
            return nil
        }
    }

    // MARK: HUD

    private func hud(_ state: GameState) -> some View {
        VStack(spacing: 0) {
            StatsBar(stats: state.stats, deltas: model.lastDeltas, token: model.deltaToken, compact: true)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(state.periodLabel).font(.display(20)).lineLimit(1).minimumScaleFactor(0.6)
                        Text("NIV.\(ArtistLevel.level(xp: state.artistXP))")
                            .font(.mono(10, weight: .heavy))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                    }
                    // How far into the year.
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.15))
                            Rectangle().fill(Theme.accent).frame(width: bar.size.width * state.yearProgress)
                        }
                    }
                    .frame(width: 64, height: 3)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(state.periodLabel), \(Int(state.yearProgress * 100)) % de l'année")

                Spacer()

                hudButton(systemImage: "iphone", label: "Téléphone") { model.openPhone() }
                    .disabled(!model.canMove)
                    .overlay(alignment: .topTrailing) {
                        if model.engine.questMarkers(in: state).contains(.reseaux) {
                            Circle().fill(Theme.accent).frame(width: 9, height: 9).offset(x: 2, y: -2)
                        }
                    }
                hudButton(systemImage: "book.closed.fill", label: "Carnet") { showCarnet = true }
                hudButton(systemImage: "music.mic", label: "Studio") { showStudio = true }
                    .disabled(!model.canMove)
                hudButton(systemImage: "bag.fill", label: "Boutique") { showShop = true }
                    .disabled(!model.canMove)
                Menu {
                    SoundToggles()
                    Button("Régler le timing des concerts") { showCalibration = true }
                    #if DEBUG
                    Section("Debug") {
                        Menu("Aller au chapitre…") {
                            ForEach(model.engine.story.chapters.map(\.number), id: \.self) { number in
                                Button("Chapitre \(number)") { model.debug(.chapter(number)) }
                            }
                        }
                        Button("Dernière saison (prolongation)") { model.debug(.lastSemester) }
                        Button("Stats et compétences au max") { model.debug(.maxOut) }
                        Menu("Lancer un mini-jeu…") {
                            Button("Punchliner") { model.debug(.event("punchliner_fred")) }
                            Button("Fuir la foule") { model.debug(.event("fuite_fans")) }
                            Button("Cale la platine") { model.debug(.event("platine_bobine")) }
                        }
                    }
                    .disabled(!model.canMove)
                    #endif
                    Button("Raccrocher le micro", role: .destructive) { confirmRetire = true }
                        .disabled(!model.canRetire)
                    Button("Retour à l'accueil (sauvegardé)") { model.leaveGame() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.6))
                        .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .accessibilityLabel("Menu")
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 8)
        }
        .background(
            LinearGradient(colors: [Color.black.opacity(0.92), Color.black.opacity(0.6), .clear],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }

    private func hudButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.6))
                .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }

    // MARK: Bottom

    @ViewBuilder
    private func bottom(_ state: GameState) -> some View {
        switch model.phase {
        case .overworld:
            VStack(spacing: 10) {
                if let decor = model.placingDecor {
                    PlacementBar(decor: decor, moving: model.movingDecorId != nil, refusal: model.placementRefusal,
                                 confirm: { _ = model.confirmPlacing() }, cancel: { model.cancelPlacing() })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let item = model.inspectedDecor {
                    BuildingCard(item: item, upgradeRefusal: model.upgradeRefusal(item),
                                 upgrade: { _ = model.upgradeInspected() }, move: { model.moveInspected() },
                                 sell: { model.sellInspected() }, close: { model.closeInspected() })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                HStack(alignment: .bottom) {
                    DPad { model.hold($0) }
                    Spacer()
                    if model.placingDecor == nil {
                        ActionButton(label: "A") { model.interact() }
                            .padding(.bottom, 20)
                    }
                }
            }
            .opacity(model.transition == nil ? 1 : 0)
            .transition(.opacity)
        case .dialogue(let speaker, let lines):
            VStack(alignment: .trailing, spacing: 8) {
                if let card = model.philosophyCard {
                    PhilosophyShareButton(card: card)
                }
                LinesBox(speaker: speaker, lines: lines)
                    .id(lines.joined())
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .encounter(let event):
            EncounterBox(event: event, state: state)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .consequence(_, let outcome):
            ConsequenceBox(outcome: outcome, state: state)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .finaleChoice:
            FinaleChoiceBox(retire: { model.retire() }, keepGoing: { model.keepGoing() })
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .metro:
            MetroMapView(transit: Transit.of(state.rapper.city), current: state.district, open: model.engine.openDistricts(in: state),
                         objective: model.objectiveDistrict) { model.travel(to: $0) } close: { model.closeMetro() }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .clash, .interview, .concert, .negotiation, .writing, .minigame, .cinematic:
            EmptyView()
        }
    }
}

/// Construction mode: walk around, the ghost follows in front of you, put it down where it fits.
private struct PlacementBar: View {
    let decor: Decor
    let moving: Bool
    let refusal: String?
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PixelImage(ShopIcons.decor(decor), width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(moving ? "\(decor.name.uppercased()) · DÉPLACER" : "\(decor.name.uppercased()) · \(decor.price)")
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(.white)
                Text(refusal ?? "Ici, c'est parfait")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(refusal == nil ? Color.green : Color(red: 1, green: 0.45, blue: 0.4))
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Annuler")
            Button(action: confirm) {
                Text("POSER")
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(refusal == nil ? Color.green : Color.gray.opacity(0.6))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(refusal != nil)
        }
        .padding(10)
        .background(Color.black.opacity(0.82))
        .overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}

/// One of your decorations, up close: what it brings, and what you can do with it.
private struct BuildingCard: View {
    let item: PlacedDecor
    let upgradeRefusal: String?
    let upgrade: () -> Void
    let move: () -> Void
    let sell: () -> Void
    let close: () -> Void
    @State private var confirmSell = false

    private var income: String {
        item.perTurn.sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "+\($0.value) \($0.key.label.lowercased())" }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PixelImage(ShopIcons.decor(item.decor), width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.decor.name.uppercased())
                            .font(.mono(11, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if item.decor.isBuilding {
                            Text(String(repeating: "★", count: item.level) + String(repeating: "☆", count: Decor.maxLevel - item.level))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                        }
                    }
                    Text("\(income) par période")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
                Spacer(minLength: 4)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Fermer")
            }
            HStack(spacing: 6) {
                if item.decor.isBuilding {
                    if let cost = item.decor.upgradeCost(from: item.level) {
                        action(upgradeRefusal ?? "AMÉLIORER · \(cost)", enabled: upgradeRefusal == nil,
                               color: Color(red: 1, green: 0.85, blue: 0.3), action: upgrade)
                    } else {
                        action("NIVEAU MAX", enabled: false, color: .gray, action: {})
                    }
                }
                action("DÉPLACER", enabled: true, color: .white, action: move)
                action(confirmSell ? "SÛR ? +\(item.resale)" : "VENDRE", enabled: true,
                       color: Color(red: 1, green: 0.45, blue: 0.4)) {
                    if confirmSell { sell() } else { withAnimation { confirmSell = true } }
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.85))
        .overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }

    private func action(_ label: String, enabled: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.mono(10, weight: .bold))
                .foregroundStyle(enabled ? .black : .white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(enabled ? color : Color.white.opacity(0.12))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
    }
}
