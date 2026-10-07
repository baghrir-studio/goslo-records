import SwiftUI

/// Text that appears letter by letter. Tapping shows everything at once.
struct TypewriterText: View {
    /// Seconds per letter: slow enough to read along.
    static let defaultSpeed = 0.032

    let text: String
    var font: Font = .system(size: 17, weight: .semibold, design: .monospaced)
    var speed: Double = TypewriterText.defaultSpeed
    /// Shows all the text at once (the player tapped).
    var revealAll = false
    var onFinished: () -> Void = {}

    @State private var visible = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        // The full text stays in the layout (transparent) so the box doesn't jump.
        ZStack(alignment: .topLeading) {
            Text(text).opacity(0)
            Text(revealAll ? text : String(text.prefix(visible)))
        }
        .font(font)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: start)
        .onChange(of: text) { _, _ in start() }
        .onChange(of: revealAll) { _, reveal in
            guard reveal, visible < text.count else { return }
            task?.cancel()
            visible = text.count
            onFinished()
        }
        .onDisappear { task?.cancel() }
    }

    var isDone: Bool { visible >= text.count }

    private func start() {
        task?.cancel()
        visible = 0
        task = Task { @MainActor in
            while visible < text.count {
                try? await Task.sleep(for: .seconds(speed))
                if Task.isCancelled { return }
                visible += 1
                if visible % 3 == 0, visible <= text.count, text[text.index(text.startIndex, offsetBy: visible - 1)] != " " {
                    SoundEngine.shared.play(.blip)
                }
            }
            onFinished()
        }
    }
}

/// Retro text box: thick frame, speaker label, blinking "▼".
struct DialogueFrame<Content: View>: View {
    var speaker: String?
    var showsArrow = false
    @ViewBuilder var content: Content
    @State private var blink = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let speaker {
                Text(speaker.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent)
                    .offset(x: 14, y: 6)
                    .zIndex(1)
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(.horizontal, 18)
            .padding(.top, speaker == nil ? 16 : 20)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.06, green: 0.06, blue: 0.07))
            .overlay(Rectangle().stroke(Color.white, lineWidth: 4))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 2).padding(4))
            .overlay(alignment: .bottomTrailing) {
                if showsArrow {
                    Text("▼")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.accent)
                        .padding(12)
                        .opacity(blink ? 0.2 : 1)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.45).repeatForever()) { blink = true }
                        }
                }
            }
        }
        .foregroundStyle(.white)
    }
}

/// Character portrait next to the box.
struct Portrait: View {
    let look: CharacterLook

    var body: some View {
        PixelImage(HeroSprite.bust(look), width: 84)
            .padding(6)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
    }
}

// MARK: - Encounter (event + choices)

struct EncounterBox: View {
    @Environment(AppModel.self) private var model
    let event: GameEvent
    let state: GameState

    @State private var textDone = false

    private var npc: CastMember? { event.npc.flatMap(model.engine.castMember) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if textDone {
                ChoiceMenu(choices: event.choices, state: state, engine: model.engine) { index in
                    withAnimation(.snappy) { model.choose(index) }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 8) {
                if let npc { Portrait(look: npc.look).transition(.scale.combined(with: .opacity)) }
                Spacer(minLength: 0)
            }

            DialogueFrame(speaker: npc?.name ?? state.currentLocationName ?? event.location?.name) {
                Text(TextTemplate.render(event.title, for: state.rapper).uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                TypewriterText(text: TextTemplate.render(event.text, for: state.rapper), revealAll: textDone) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { textDone = true }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { textDone = true }
            }
        }
        .id(event.id)
    }
}

private extension GameState {
    var currentLocationName: String? { currentLocation?.name }
}

/// Retro choice menu with a "▶" cursor.
struct ChoiceMenu: View {
    let choices: [EventChoice]
    let state: GameState
    let engine: GameEngine
    let onChoose: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                let lock = choice.isAvailable(in: state) ? nil : requirementText(choice.requires)
                Button {
                    onChoose(index)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(lock == nil ? "▶" : "×")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TextTemplate.render(choice.label, for: state.rapper))
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            if let lock {
                                Text(lock).font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.accent)
                            } else if choice.clash != nil {
                                Text("⚔ LANCE UN CLASH").font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.accent)
                            } else if !choice.statHints.isEmpty {
                                StatHints(hints: choice.statHints)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuRowStyle())
                .disabled(lock != nil)
                .opacity(lock == nil ? 1 : 0.45)
                if index < choices.count - 1 {
                    Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1).padding(.horizontal, 10)
                }
            }
        }
        .foregroundStyle(.white)
        .background(Color(red: 0.06, green: 0.06, blue: 0.07))
        .overlay(Rectangle().stroke(Color.white, lineWidth: 4))
    }

    private func requirementText(_ requirement: ChoiceRequirement?) -> String {
        guard let requirement else { return "" }
        var parts = requirement.skills.sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.label.uppercased()) \($0.value)" }
        parts += requirement.relations.sorted { $0.key < $1.key }.map { id, value in
            "\((engine.castMember(id)?.name ?? id).uppercased()) \(value)"
        }
        parts += requirement.stats.sorted { $0.key.rawValue < $1.key.rawValue }.map { "\($0.key.shortLabel) \($0.value)" }
        return parts.joined(separator: " · ") + " REQUIS"
    }
}

/// Which stats a choice touches: a dot per stat, bigger when the effect is big. Never the direction.
struct StatHints: View {
    let hints: [(kind: StatKind, size: Int)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(hints, id: \.kind) { hint in
                HStack(spacing: 4) {
                    Circle().fill(Color.white.opacity(0.85))
                        .frame(width: hint.size > 1 ? 8 : 5, height: hint.size > 1 ? 8 : 5)
                    Text(hint.kind.shortLabel)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Touche : " + hints.map { $0.kind.label + ($0.size > 1 ? " beaucoup" : "") }.joined(separator: ", "))
    }
}

struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { SoundEngine.shared.play(.tap) } }
            .background(configuration.isPressed ? Theme.accent.opacity(0.25) : Color.clear)
            .offset(x: configuration.isPressed ? 4 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Consequence

struct ConsequenceBox: View {
    @Environment(AppModel.self) private var model
    let outcome: TurnOutcome
    let state: GameState

    @State private var textDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(outcome.completedObjectives, id: \.self) { label in
                ObjectiveDoneBanner(label: label)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ForEach(outcome.completedQuests) { quest in
                QuestBanner(quest: quest)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if textDone && !chips.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                        Text(chip.text)
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(chip.positive ? Theme.background : .white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(chip.positive ? Theme.accent : Color.black.opacity(0.85))
                            .overlay(Rectangle().stroke(Color.white.opacity(chip.positive ? 0 : 0.4), lineWidth: 1))
                            .transition(.scale(scale: 0.3).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.6).delay(Double(index) * 0.07)))
                    }
                }
            }

            DialogueFrame(speaker: speaker, showsArrow: textDone) {
                TypewriterText(text: TextTemplate.render(outcome.consequence, for: state.rapper), revealAll: textDone) {
                    withAnimation { textDone = true }
                }
                if textDone && outcome.semesterEnded && outcome.ending == nil {
                    Text("Fin du semestre : loyer payé, l'algorithme t'oublie un peu.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if textDone { model.advance() } else { withAnimation { textDone = true } }
            }
        }
    }

    private var speaker: String? {
        if let clash = outcome.clash { return clash.playerWon ? "Victoire" : "Défaite" }
        if let interview = outcome.interview { return interview.passed ? "Émission réussie" : "Au suivant" }
        if let concert = outcome.concert { return concert.passed ? "Concert réussi" : "Concert raté" }
        if let writing = outcome.writing { return writing.passed ? "Couplet validé" : "Couplet raturé" }
        if let deal = outcome.negotiation { return deal.passed ? "Contrat signé" : (deal.walkedOut ? "Il est parti" : "Pas de deal") }
        if outcome.ending != nil { return "Fin de carrière" }
        return nil
    }

    private var chips: [(text: String, positive: Bool)] {
        StatKind.allCases.compactMap { kind in
            outcome.deltas[kind].map { ("\(kind.shortLabel) \($0 > 0 ? "+" : "−")\(abs($0))", $0 > 0) }
        }
        + outcome.relationChanges.sorted { $0.key < $1.key }.map { id, delta in
            ("\((model.engine.castMember(id)?.name ?? id).uppercased()) \(delta > 0 ? "+" : "−")\(abs(delta))", delta > 0)
        }
        + outcome.levelUps.map { ("\($0.label.uppercased()) NIV. \(state.skills.level($0)) ↑", true) }
        + outcome.gainedItems.map { ("OBJET : \($0.uppercased())", true) }
        + outcome.unlockedTechniques.map { ("TECHNIQUE : \($0.uppercased())", true) }
    }
}

private struct QuestBanner: View {
    let quest: Quest
    @State private var shine = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("★ QUÊTE TERMINÉE").font(.system(size: 11, weight: .heavy, design: .monospaced))
            Text(quest.title.uppercased()).font(.display(24))
            if !quest.reward.text.isEmpty {
                Text(quest.reward.text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.background)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent)
        .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
        .scaleEffect(shine ? 1 : 0.9)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { shine = true } }
    }
}

// MARK: - Simple lines

struct LinesBox: View {
    @Environment(AppModel.self) private var model
    let speaker: String?
    let lines: [String]
    @State private var index = 0
    @State private var done = false

    var body: some View {
        DialogueFrame(speaker: speaker, showsArrow: done) {
            TypewriterText(text: lines.isEmpty ? "" : lines[index], revealAll: done) { done = true }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !done { done = true; return }
            if index + 1 < lines.count {
                done = false
                index += 1
            } else {
                model.advance()
            }
        }
    }
}

/// Wrapping row layout (chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: .unspecified)
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty && rows[rows.count - 1].width + spacing + size.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// "Objective complete" banner for the main story.
private struct ObjectiveDoneBanner: View {
    let label: String
    @State private var shown = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("★").font(.system(size: 20, weight: .black))
            VStack(alignment: .leading, spacing: 2) {
                Text("OBJECTIF ACCOMPLI").font(.system(size: 11, weight: .heavy, design: .monospaced))
                Text(label).font(.system(size: 15, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.background)
        .padding(12)
        .background(Color(red: 1, green: 0.85, blue: 0.3))
        .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
        .scaleEffect(shown ? 1 : 0.85)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { shown = true } }
    }
}
