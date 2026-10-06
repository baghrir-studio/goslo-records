import SwiftUI

/// Contract negotiation: the clause on paper, the other side's pitch, your answer.
struct NegotiationView: View {
    @Environment(AppModel.self) private var model
    let negotiation: NegotiationState
    let state: GameState

    private enum Stage: Equatable { case intro, clause, reaction, walkout, finished }

    @State private var stage: Stage = .intro
    @State private var typed = false
    @State private var revealAll = false
    @State private var royalties = 0.0
    @State private var patience = 0.0
    @State private var reaction: NegotiationLogEntry?
    @State private var shake = 0.0
    @State private var stamp = false

    private var data: Negotiation? { model.engine.negotiation(negotiation.id) }
    private var opponent: CastMember? { data.flatMap { model.engine.castMember($0.opponent) } }

    var body: some View {
        if let data {
            VStack(spacing: 10) {
                header(data)
                if stage == .intro {
                    ContractCover(title: data.title, rapper: state.rapper, clauses: data.clauses.count)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if stage == .clause || stage == .reaction {
                    ContractPaper(number: clauseShown(data) + 1,
                                  text: TextTemplate.render(clauseText(data), for: state.rapper))
                        .id("paper\(clauseShown(data))")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                ClauseHistory(entries: Array(negotiation.log.prefix(historyCount)
                    .suffix(stage == .finished || stage == .walkout ? data.clauses.count : 2)), clauses: data.clauses,
                              rapper: state.rapper)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 10) {
                    if let opponent {
                        Portrait(look: opponent.look)
                            .modifier(ShakeEffect(amount: shake))
                    }
                    VStack(spacing: 6) {
                        DealGauge(label: "TES ROYALTIES", value: royalties, max: Double(NegotiationState.royaltiesRange.upperBound),
                                  target: Double(data.targetRoyalties), suffix: " %",
                                  hint: showsHints ? "Objectif : \(data.targetRoyalties) % minimum" : nil)
                        DealGauge(label: "SA PATIENCE", value: patience, max: 100, target: nil, suffix: "",
                                  hint: showsHints ? "À zéro, il quitte la table" : nil)
                    }
                }
                bottom(data)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .onAppear {
                royalties = Double(negotiation.royalties)
                patience = Double(negotiation.patience)
                stage = negotiation.isOver ? (negotiation.walkedOut ? .walkout : .finished)
                    : (negotiation.clauseIndex == 0 ? .intro : .clause)
            }
        }
    }

    /// Gauge explanations only until the first answer: after that, space goes to the contract.
    private var showsHints: Bool { negotiation.log.isEmpty }

    /// The answer being shown in the reaction stays out of the history until the next clause.
    private var historyCount: Int { stage == .reaction ? max(0, negotiation.log.count - 1) : negotiation.log.count }

    private func clauseShown(_ data: Negotiation) -> Int {
        stage == .reaction ? max(0, negotiation.clauseIndex - 1) : negotiation.clauseIndex
    }

    private func clauseText(_ data: Negotiation) -> String {
        data.clauses[min(clauseShown(data), data.clauses.count - 1)].text
    }

    private func header(_ data: Negotiation) -> some View {
        HStack(spacing: 8) {
            Text("BOSS")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.background)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color(red: 1, green: 0.85, blue: 0.3))
            Text("NÉGOCIATION")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 1.5))
            Text(data.title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text("\(min(clauseShown(data) + 1, data.clauses.count))/\(data.clauses.count)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func bottom(_ data: Negotiation) -> some View {
        switch stage {
        case .intro:
            tapBox(speaker: opponent?.name, text: TextTemplate.render(data.intro, for: state.rapper)) {
                stage = .clause
            }
        case .clause:
            let clause = data.clauses[min(negotiation.clauseIndex, data.clauses.count - 1)]
            VStack(alignment: .leading, spacing: 8) {
                if typed {
                    VStack(spacing: 0) {
                        ForEach(Array(clause.options.enumerated()), id: \.offset) { index, option in
                            optionRow(index, option)
                        }
                    }
                    .background(Color(red: 0.06, green: 0.06, blue: 0.07))
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 4))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                DialogueFrame(speaker: opponent?.name) {
                    TypewriterText(text: TextTemplate.render(clause.pitch, for: state.rapper), revealAll: revealAll) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { typed = true }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { revealAll = true }
            }
            .id("c\(negotiation.clauseIndex)")
        case .reaction:
            if let reaction {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        DeltaChip(label: "ROYALTIES", delta: reaction.royaltiesDelta, suffix: " %",
                                  good: Theme.accent)
                        DeltaChip(label: "PATIENCE", delta: reaction.patienceDelta, suffix: "",
                                  good: Color(red: 1, green: 0.85, blue: 0.3))
                    }
                    .transition(.scale.combined(with: .opacity))
                    tapBox(speaker: opponent?.name, text: TextTemplate.render(reaction.reaction, for: state.rapper)) {
                        if negotiation.walkedOut {
                            stage = .walkout
                        } else {
                            stage = negotiation.isOver ? .finished : .clause
                        }
                    }
                }
                .id("r\(reaction.clause)")
            }
        case .walkout:
            VStack(spacing: 10) {
                Text("IL QUITTE LA TABLE")
                    .font(.display(30))
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                if !data.walkout.isEmpty {
                    DialogueFrame(speaker: opponent?.name) {
                        TypewriterText(text: TextTemplate.render(data.walkout, for: state.rapper))
                    }
                }
                Button("Rentrer à pied") { model.finishNegotiation() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .finished:
            VStack(spacing: 10) {
                Text(negotiation.passed ? "SIGNÉ" : "CONTRAT POURRI")
                    .font(.display(38))
                    .foregroundStyle(negotiation.passed ? Theme.accent : .white)
                    .padding(.horizontal, 14)
                    .overlay(Rectangle().stroke(negotiation.passed ? Theme.accent : Color.white, lineWidth: 4))
                    .rotationEffect(.degrees(-8))
                    .scaleEffect(stamp ? 1 : 2.2)
                    .opacity(stamp ? 1 : 0)
                    .onAppear {
                        SoundEngine.shared.play(.concertKick)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { stamp = true }
                    }
                Text("\(negotiation.royalties) % de royalties · objectif \(data.targetRoyalties) %")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                Button("Sortir du bureau") { model.finishNegotiation() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func optionRow(_ index: Int, _ option: NegotiationOption) -> some View {
        let available = option.isAvailable(in: state)
        return Button {
            choose(index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(available ? "▶" : "×").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(TextTemplate.render(option.label, for: state.rapper))
                        .font(.system(size: 15, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !available, let requires = option.requires {
                        Text(requirementText(requires))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowStyle())
        .disabled(!available)
        .opacity(available ? 1 : 0.45)
    }

    private func requirementText(_ requirement: ChoiceRequirement) -> String {
        var parts = requirement.skills.map { "\($0.key.label.uppercased()) \($0.value)" }
        parts += requirement.relations.map { "\((model.engine.castMember($0.key)?.name ?? $0.key).uppercased()) \($0.value)" }
        parts += requirement.stats.map { "\($0.key.shortLabel) \($0.value)" }
        return parts.joined(separator: " · ") + " REQUIS"
    }

    private func tapBox(speaker: String?, text: String, then next: @escaping () -> Void) -> some View {
        DialogueFrame(speaker: speaker, showsArrow: typed) {
            TypewriterText(text: text, revealAll: revealAll) { typed = true }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if typed {
                typed = false
                revealAll = false
                withAnimation(.easeOut(duration: 0.25)) { next() }
            } else {
                revealAll = true
            }
        }
        .id(text)
    }

    private func choose(_ index: Int) {
        guard stage == .clause, let updated = model.negotiate(index), let entry = updated.log.last else { return }
        SoundEngine.shared.play(entry.royaltiesDelta > 0 ? .statUp : .statDown)
        typed = false
        revealAll = false
        withAnimation(.easeOut(duration: 0.8)) {
            royalties = Double(updated.royalties)
            patience = Double(updated.patience)
        }
        if entry.patienceDelta <= -10 {
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            reaction = entry
            stage = .reaction
        }
    }
}

private struct DeltaChip: View {
    let label: String
    let delta: Int
    let suffix: String
    let good: Color

    var body: some View {
        Text("\(label) \(delta >= 0 ? "+" : "−")\(abs(delta))\(suffix)")
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(delta >= 0 ? Theme.background : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(delta >= 0 ? good : Color.black)
            .overlay(Rectangle().stroke(delta >= 0 ? good : Color(red: 0.9, green: 0.15, blue: 0.15), lineWidth: 2))
    }
}

/// Clauses already negotiated, like initials in the margin.
private struct ClauseHistory: View {
    let entries: [NegotiationLogEntry]
    let clauses: [NegotiationClause]
    let rapper: Rapper

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entries, id: \.clause) { entry in
                    HStack(spacing: 8) {
                        Text("ART. \(entry.clause + 1)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 48, alignment: .leading)
                        Text(label(entry))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 4)
                        Text("\(entry.royaltiesDelta >= 0 ? "+" : "−")\(abs(entry.royaltiesDelta)) %")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(entry.royaltiesDelta > 0 ? Theme.accent : .white.opacity(0.5))
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
    }

    private func label(_ entry: NegotiationLogEntry) -> String {
        guard clauses.indices.contains(entry.clause), clauses[entry.clause].options.indices.contains(entry.option) else { return "" }
        return TextTemplate.render(clauses[entry.clause].options[entry.option].label, for: rapper)
    }
}

/// First page of the contract, before the clauses.
private struct ContractCover: View {
    let title: String
    let rapper: Rapper
    let clauses: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("CONTRAT D'ARTISTE")
                .font(.system(size: 20, weight: .black, design: .serif))
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .italic()
            Rectangle().fill(Color.black.opacity(0.25)).frame(height: 1)
            Text("Entre HEXAGONE MUSIC, ci-après « le Label »,\net \(rapper.name.uppercased()), ci-après « l'Artiste » (pour l'instant).")
                .font(.system(size: 12, design: .serif))
                .multilineTextAlignment(.center)
            Text("84 pages · \(clauses) articles à négocier · police 7")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .opacity(0.55)
        }
        .foregroundStyle(Color(red: 0.12, green: 0.1, blue: 0.08))
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.95, green: 0.92, blue: 0.84))
        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
        .rotationEffect(.degrees(1))
        .padding(.top, 4)
    }
}

/// The clause, printed on a sheet of contract paper.
private struct ContractPaper: View {
    let number: Int
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ARTICLE \(number)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                Spacer()
                Text("HEXAGONE MUSIC · CONFIDENTIEL")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .opacity(0.55)
            }
            Rectangle().fill(Color.black.opacity(0.25)).frame(height: 1)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Text("Paraphe : ______")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .opacity(0.5)
            }
        }
        .foregroundStyle(Color(red: 0.12, green: 0.1, blue: 0.08))
        .padding(12)
        .background(Color(red: 0.95, green: 0.92, blue: 0.84))
        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
        .rotationEffect(.degrees(-1))
        .padding(.top, 4)
    }
}

private struct DealGauge: View {
    let label: String
    let value: Double
    let max: Double
    let target: Double?
    let suffix: String
    let hint: String?

    private var low: Bool { target == nil && value < 25 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 10, weight: .heavy, design: .monospaced))
                Spacer()
                Text("\(Int(value.rounded()))\(suffix)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .contentTransition(.numericText(value: value))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12))
                    Rectangle()
                        .fill(fill)
                        .frame(width: geo.size.width * min(value / max, 1))
                    if let target {
                        Rectangle()
                            .fill(Color(red: 1, green: 0.85, blue: 0.3))
                            .frame(width: 2)
                            .offset(x: geo.size.width * target / max)
                    }
                }
            }
            .frame(height: 10)
            .overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
            if let hint {
                Text(hint)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .foregroundStyle(.white)
        .padding(8)
        .background(Color.black.opacity(0.8))
        .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
    }

    private var fill: Color {
        if let target { return value >= target ? Theme.accent : Color.white.opacity(0.85) }
        return low ? Color(red: 0.9, green: 0.15, blue: 0.15) : Color(red: 1, green: 0.85, blue: 0.3)
    }
}

/// Short horizontal shake when the other side loses a lot of patience.
private struct ShakeEffect: GeometryEffect {
    var amount: Double
    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(amount * .pi * 6), y: 0))
    }
}
