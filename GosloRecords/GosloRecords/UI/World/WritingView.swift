import SwiftUI

/// Writing session: the couplet in the notebook, the line to find before the timer runs out.
/// In a duel, the opponent's line lands first.
struct WritingView: View {
    @Environment(AppModel.self) private var model
    let writing: WritingState
    let state: GameState

    private enum Stage: Equatable { case intro, attack, write, reaction, finished }

    @State private var stage: Stage = .intro
    @State private var typed = false
    @State private var revealAll = false
    @State private var score = 0.0
    @State private var timeLeft = 1.0
    @State private var timerTask: Task<Void, Never>?
    @State private var showOptions = false
    @State private var hit: Int?
    @State private var reaction: WritingLogEntry?
    @State private var stamp = false

    private var data: Writing? { model.engine.writing(writing.id) }
    private var partner: CastMember? { data.flatMap { model.engine.castMember($0.partner) } }

    var body: some View {
        if let data {
            VStack(spacing: 10) {
                header(data)
                Notebook(couplets: couplets(data), title: data.title)
                    .animation(.easeOut(duration: 0.3), value: writing.log.count)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 10) {
                    if let partner { Portrait(look: partner.look) }
                    VStack(alignment: .leading, spacing: 6) {
                        if let hit {
                            Text("\(partner?.name.uppercased() ?? "ATTAQUE") −\(abs(hit))")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black)
                                .overlay(Rectangle().stroke(Color(red: 0.9, green: 0.15, blue: 0.15), lineWidth: 2))
                                .transition(.scale.combined(with: .opacity))
                        }
                        ScoreGauge(label: data.duel ? "AVANTAGE" : "VIBE DU STUDIO", value: score,
                                   pass: Double(data.passScore),
                                   hint: writing.log.isEmpty ? "Objectif : \(data.passScore) à la fin du couplet" : nil)
                    }
                }
                bottom(data)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .onAppear {
                score = Double(writing.score)
                stage = writing.isOver ? .finished : (writing.roundIndex == 0 && !writing.attacked ? .intro : nextStage(data))
            }
            .onDisappear { timerTask?.cancel() }
        }
    }

    // MARK: Notebook content

    private func couplets(_ data: Writing) -> [Couplet] {
        var result = writing.log.map { entry -> Couplet in
            let round = data.rounds[entry.round]
            let line = entry.option.map { round.options[$0].line } ?? WritingEngine.blankLine
            return Couplet(id: entry.round, setup: render(round.setup), line: render(line),
                           crossed: entry.scoreDelta < 0 || entry.option == nil, blank: entry.option == nil)
        }
        if stage != .finished, let round = model.engine.currentWritingRound(in: state), stage != .reaction {
            result.append(Couplet(id: writing.roundIndex, setup: render(round.setup), line: nil, crossed: false, blank: false))
        }
        // Keep the page readable: the last two couplets while writing, everything at the end.
        return stage == .finished ? result : Array(result.suffix(2))
    }

    private func render(_ text: String) -> String { TextTemplate.render(text, for: state.rapper) }

    private func nextStage(_ data: Writing) -> Stage {
        guard let round = model.engine.currentWritingRound(in: state) else { return .finished }
        return round.attack != nil && !writing.attacked ? .attack : .write
    }

    // MARK: Header

    private func header(_ data: Writing) -> some View {
        HStack(spacing: 8) {
            if data.boss {
                Text("BOSS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(Color(red: 1, green: 0.85, blue: 0.3))
            }
            Text(data.duel ? "DUEL À LA PLUME" : "SESSION STUDIO")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 1.5))
            Spacer()
            Text("COUPLET \(min(writing.roundIndex + (stage == .reaction ? 0 : 1), data.rounds.count))/\(data.rounds.count)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 6)
    }

    // MARK: Bottom

    @ViewBuilder
    private func bottom(_ data: Writing) -> some View {
        switch stage {
        case .intro:
            tapBox(speaker: partner?.name, text: render(data.intro)) { stage = nextStage(data) }
        case .attack:
            if let attack = model.engine.currentWritingRound(in: state)?.attack {
                DialogueFrame(speaker: partner?.name, showsArrow: typed) {
                    TypewriterText(text: render(attack.line), revealAll: revealAll) { landAttack() }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if typed {
                        typed = false
                        revealAll = false
                        withAnimation(.easeOut(duration: 0.25)) {
                            hit = nil
                            stage = .write
                        }
                    } else {
                        revealAll = true
                    }
                }
                .id("a\(writing.roundIndex)")
            }
        case .write:
            if let round = model.engine.currentWritingRound(in: state) {
                VStack(alignment: .leading, spacing: 8) {
                    TimerBar(fraction: timeLeft)
                    VStack(spacing: 0) {
                        ForEach(Array(round.options.enumerated()), id: \.offset) { index, option in
                            optionRow(index, option)
                        }
                    }
                    .background(Color(red: 0.06, green: 0.06, blue: 0.07))
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 4))
                    .opacity(showOptions ? 1 : 0)
                    .offset(x: showOptions ? 0 : 40)
                    Text("Choisis la suite. Ça doit rimer. Et faire mal.")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .id("w\(writing.roundIndex)")
                .onAppear { startRound() }
            }
        case .reaction:
            if let reaction {
                VStack(alignment: .leading, spacing: 8) {
                    Text(reaction.scoreDelta >= 0 ? "PLUME +\(reaction.scoreDelta)" : "PLUME −\(abs(reaction.scoreDelta))")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(reaction.scoreDelta >= 0 ? Theme.background : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(reaction.scoreDelta >= 0 ? Theme.accent : Color.black)
                        .transition(.scale.combined(with: .opacity))
                    tapBox(speaker: nil, text: render(reaction.reaction)) {
                        stage = writing.isOver ? .finished : nextStage(data)
                    }
                }
                .id("r\(reaction.round)")
            }
        case .finished:
            VStack(spacing: 10) {
                Text(finishedTitle(data))
                    .font(.display(34))
                    .foregroundStyle(writing.passed ? Theme.accent : .white)
                    .padding(.horizontal, 12)
                    .overlay(Rectangle().stroke(writing.passed ? Theme.accent : Color.white, lineWidth: 4))
                    .rotationEffect(.degrees(-6))
                    .scaleEffect(stamp ? 1 : 2)
                    .opacity(stamp ? 1 : 0)
                    .onAppear {
                        SoundEngine.shared.play(writing.passed ? .crowdCheer : .crowdGroan)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { stamp = true }
                    }
                Button(data.duel ? "Poser le stylo" : "Sortir du Bunker") { model.finishWriting() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func finishedTitle(_ data: Writing) -> String {
        if data.duel { return writing.passed ? "K.O. À LA PLUME" : "RATURÉ" }
        return writing.passed ? "C'EST LE SINGLE" : "ON LA REFAIT"
    }

    private func optionRow(_ index: Int, _ option: WritingOption) -> some View {
        let available = option.isAvailable(in: state)
        return Button {
            write(index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(available ? "✎" : "×").font(.system(size: 14, weight: .black)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(render(option.line))
                        .font(.system(size: 15, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !available, let requires = option.requires {
                        Text(requires.skills.map { "\($0.key.label.uppercased()) \($0.value)" }.joined(separator: " · ") + " REQUIS")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowStyle())
        .disabled(!available || !showOptions)
        .opacity(available ? 1 : 0.45)
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

    // MARK: Actions

    private func landAttack() {
        typed = true
        guard let updated = model.writingAttack() else { return }
        SoundEngine.shared.play(.statDown)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { hit = updated.attackDelta == 0 ? nil : updated.attackDelta }
        withAnimation(.easeOut(duration: 0.7)) { score = Double(updated.score) }
    }

    private func startRound() {
        timerTask?.cancel()
        timeLeft = 1
        showOptions = false
        let round = writing.roundIndex
        let seconds = model.engine.writingTime(in: state)
        timerTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showOptions = true }
            let ticks = max(1, Int(seconds * 10))
            for tick in 0..<ticks {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                withAnimation(.linear(duration: 0.1)) { timeLeft = 1 - Double(tick + 1) / Double(ticks) }
            }
            if !Task.isCancelled && stage == .write && writing.roundIndex == round { write(nil) }
        }
    }

    private func write(_ index: Int?) {
        guard stage == .write else { return }
        timerTask?.cancel()
        guard let updated = model.writeLine(index), let entry = updated.log.last else { return }
        SoundEngine.shared.play(entry.scoreDelta >= 0 ? .statUp : .statDown)
        typed = false
        revealAll = false
        withAnimation(.easeOut(duration: 0.8)) { score = Double(updated.score) }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            reaction = entry
            stage = .reaction
        }
    }
}

// MARK: - Pieces

private struct Couplet: Identifiable, Equatable {
    let id: Int
    let setup: String
    /// nil while it's being written.
    let line: String?
    let crossed: Bool
    let blank: Bool
}

/// Lined notebook page, red margin, handwriting. The rhyme is underlined.
private struct Notebook: View {
    let couplets: [Couplet]
    let title: String

    private let ink = Color(red: 0.1, green: 0.16, blue: 0.42)
    private let rhymeInk = Color(red: 0.85, green: 0.2, blue: 0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Noteworthy-Bold", size: 13))
                .foregroundStyle(ink.opacity(0.6))
                .lineLimit(1)
            ForEach(couplets) { couplet in
                VStack(alignment: .leading, spacing: 2) {
                    rhymed(couplet.setup)
                    if let line = couplet.line {
                        if couplet.blank {
                            Text(line).foregroundStyle(ink.opacity(0.35))
                        } else {
                            rhymed(line)
                                .strikethrough(couplet.crossed, color: rhymeInk)
                                .opacity(couplet.crossed ? 0.55 : 1)
                        }
                    } else {
                        Text("________________________").foregroundStyle(ink.opacity(0.3))
                    }
                }
                .font(.custom("Noteworthy-Bold", size: 15))
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.leading, 30)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(paper)
        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
        .rotationEffect(.degrees(-0.8))
    }

    private var paper: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.97, green: 0.96, blue: 0.9)))
            var y: CGFloat = 26
            while y < size.height {
                context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
                               with: .color(Color(red: 0.55, green: 0.7, blue: 0.9).opacity(0.5)), lineWidth: 1)
                y += 22
            }
            context.stroke(Path { $0.move(to: CGPoint(x: 22, y: 0)); $0.addLine(to: CGPoint(x: 22, y: size.height)) },
                           with: .color(rhymeInk.opacity(0.6)), lineWidth: 1.5)
        }
    }

    /// The line with its last word (the rhyme) underlined in red.
    private func rhymed(_ line: String) -> Text {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var end = trimmed.endIndex
        while end > trimmed.startIndex, ",.;:!?…»\" ".contains(trimmed[trimmed.index(before: end)]) {
            end = trimmed.index(before: end)
        }
        let start = trimmed[..<end].lastIndex(of: " ").map { trimmed.index(after: $0) } ?? trimmed.startIndex
        let head = String(trimmed[..<start])
        let word = String(trimmed[start..<end])
        let tail = String(trimmed[end...])
        return Text(head).foregroundColor(ink)
            + Text(word).foregroundColor(rhymeInk).underline(true, color: rhymeInk)
            + Text(tail).foregroundColor(ink)
    }
}

private struct ScoreGauge: View {
    let label: String
    let value: Double
    let pass: Double
    let hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 10, weight: .heavy, design: .monospaced))
                Spacer()
                Text("\(Int(value.rounded()))")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .contentTransition(.numericText(value: value))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12))
                    Rectangle()
                        .fill(value >= pass ? Theme.accent : Color.white.opacity(0.85))
                        .frame(width: geo.size.width * min(value / 100, 1))
                    Rectangle()
                        .fill(Color(red: 1, green: 0.85, blue: 0.3))
                        .frame(width: 2)
                        .offset(x: geo.size.width * pass / 100)
                }
            }
            .frame(height: 12)
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
}

private struct TimerBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.15))
                Rectangle()
                    .fill(fraction < 0.3 ? Color.red : Color(red: 1, green: 0.85, blue: 0.3))
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
    }
}
