import SwiftUI

// MARK: - Cinematic

/// Black cinema bars plus the current caption (narration, line or chapter title).
/// First tap shows the whole text, second tap moves on.
struct CinematicOverlay: View {
    @Environment(AppModel.self) private var model
    @State private var typed = false
    @State private var revealAll = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    Color.black.frame(height: model.letterbox ? geo.size.height * 0.11 : 0)
                    Spacer(minLength: 0)
                    Color.black.frame(height: model.letterbox ? geo.size.height * 0.11 : 0)
                }
                .ignoresSafeArea()

                if let caption = model.caption {
                    content(caption, size: geo.size)
                        .id(caption.id)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard model.caption != nil else { return }
                if typed { model.advanceCinematic() } else { revealAll = true }
            }
            .onChange(of: model.caption?.id) { _, _ in
                typed = false
                revealAll = false
            }
        }
        .allowsHitTesting(model.letterbox)
    }

    @ViewBuilder
    private func content(_ caption: CinematicCaption, size: CGSize) -> some View {
        switch caption.kind {
        case .title(let subtitle):
            TitleCard(text: caption.text, subtitle: subtitle)
                .onAppear { typed = true }
        case .narration:
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    TypewriterText(text: caption.text, font: .system(size: 18, weight: .semibold, design: .serif).italic(),
                                   revealAll: revealAll) { typed = true }
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("▼").font(.system(size: 11, weight: .black)).foregroundStyle(Theme.accent).opacity(typed ? 1 : 0)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.82))
                .padding(.bottom, size.height * 0.11 + 8)
            }
        case .speech(let name, let look):
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                Portrait(look: look).transition(.scale.combined(with: .opacity))
                DialogueFrame(speaker: name, showsArrow: typed) {
                    TypewriterText(text: caption.text, revealAll: revealAll) { typed = true }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, size.height * 0.11 + 8)
        }
    }
}

private struct TitleCard: View {
    let text: String
    let subtitle: String?
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(text)
                    .font(.display(46))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .offset(y: shown ? 0 : 24)
                Rectangle().fill(Theme.accent).frame(width: shown ? 110 : 0, height: 5)
                if let subtitle {
                    Text(subtitle.uppercased())
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 24)
            .opacity(shown ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { shown = true } }
    }
}

// MARK: - Objective banner

/// Current story objective, under the HUD.
struct ObjectiveBanner: View {
    let chapter: Chapter
    let objective: Objective?
    /// The objective is in another district: say which (take the metro).
    var elsewhere: District? = nil
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("★").foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                    Text("\(chapter.isFinale ? "ÉPILOGUE" : "CH.\(chapter.number)") · \(chapter.title.uppercased())")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                Text(objective?.label ?? "Chapitre terminé")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                if let elsewhere {
                    Text("Ⓜ︎ \(elsewhere.name.uppercased()) · PRENDS LE MÉTRO")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                }
                if expanded, let hint = objective?.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.72))
            .overlay(alignment: .leading) {
                Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.3)).frame(width: 3)
            }
        }
        .buttonStyle(.plain)
        .id(objective?.id)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }
}

// MARK: - goslo radio ticker

/// "Flash goslo radio": a headline that scrolls across the top of the map.
struct RadioTicker: View {
    let text: String
    @State private var offset: CGFloat = 0
    @State private var onAir = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                RadioLogo(pixel: 0.6, color: Theme.background).opacity(onAir ? 1 : 0.55)
                Text("goslo radio")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .foregroundStyle(Theme.background)
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            .background(Color(red: 1, green: 0.82, blue: 0.48))

            GeometryReader { geo in
                Text(text)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .offset(x: offset)
                    .onAppear {
                        offset = geo.size.width
                        withAnimation(.linear(duration: 10.5)) { offset = -CGFloat(text.count) * 8.2 }
                    }
            }
            .clipped()
            .padding(.leading, 6)
        }
        .frame(height: 26)
        .background(Color.black.opacity(0.85))
        .overlay(Rectangle().stroke(Color(red: 1, green: 0.82, blue: 0.48).opacity(0.6), lineWidth: 1))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { onAir = true }
        }
    }
}

// MARK: - Interview

/// Live on air: host, audience gauge, timed questions, answers.
struct InterviewView: View {
    @Environment(AppModel.self) private var model
    let interview: InterviewState
    let state: GameState

    private enum Stage: Equatable { case intro, question, reaction, finished }

    @State private var stage: Stage = .intro
    @State private var typed = false
    @State private var revealAll = false
    @State private var timeLeft: Double = 1
    @State private var timerTask: Task<Void, Never>?
    @State private var hype = 0.0
    @State private var reaction: InterviewLogEntry?
    @State private var onAir = false
    @State private var shownLog = 0

    private var data: Interview? { model.engine.interview(interview.id) }
    private var host: CastMember? { data.flatMap { model.engine.castMember($0.host) } }

    var body: some View {
        if let data {
            VStack(spacing: 10) {
                header(data)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 10) {
                    if let host { Portrait(look: host.look) }
                    AudienceGauge(hype: hype, pass: Double(data.passHype))
                }
                bottom(data)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .onAppear {
                hype = Double(interview.hype)
                shownLog = interview.log.count
                stage = interview.isOver ? .finished : (interview.questionIndex == 0 ? .intro : .question)
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { onAir = true }
            }
            .onDisappear { timerTask?.cancel() }
        }
    }

    private func header(_ data: Interview) -> some View {
        HStack(spacing: 8) {
            if data.boss {
                Text("BOSS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(Color(red: 1, green: 0.85, blue: 0.3))
            }
            HStack(spacing: 6) {
                Circle().fill(Color.red).frame(width: 9, height: 9).opacity(onAir ? 1 : 0.25)
                Text("EN DIRECT").font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.25))
            .overlay(Rectangle().stroke(Color.red, lineWidth: 1.5))
            Text(data.show.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text("\(min(interview.questionIndex + 1, data.questions.count))/\(data.questions.count)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func bottom(_ data: Interview) -> some View {
        switch stage {
        case .intro:
            tapBox(speaker: host?.name, text: TextTemplate.render(data.intro, for: state.rapper)) {
                stage = .question
            }
        case .question:
            let question = data.questions[min(interview.questionIndex, data.questions.count - 1)]
            VStack(alignment: .leading, spacing: 8) {
                if typed {
                    TimerBar(fraction: timeLeft)
                    VStack(spacing: 0) {
                        ForEach(Array(question.answers.enumerated()), id: \.offset) { index, answer in
                            answerRow(index, answer)
                        }
                    }
                    .background(Color(red: 0.06, green: 0.06, blue: 0.07))
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 4))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                DialogueFrame(speaker: host?.name) {
                    TypewriterText(text: TextTemplate.render(question.text, for: state.rapper), revealAll: revealAll) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { typed = true }
                        startTimer(question.time)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { revealAll = true }
            }
            .id("q\(interview.questionIndex)")
        case .reaction:
            if let reaction {
                VStack(alignment: .leading, spacing: 8) {
                    Text(reaction.hypeDelta >= 0 ? "AUDIENCE +\(reaction.hypeDelta)" : "AUDIENCE −\(abs(reaction.hypeDelta))")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(reaction.hypeDelta >= 0 ? Theme.background : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(reaction.hypeDelta >= 0 ? Theme.accent : Color.black)
                        .transition(.scale.combined(with: .opacity))
                    tapBox(speaker: nil, text: TextTemplate.render(reaction.reaction, for: state.rapper)) {
                        stage = interview.isOver ? .finished : .question
                    }
                }
                .id("r\(reaction.question)")
            }
        case .finished:
            VStack(spacing: 10) {
                Text(interview.passed ? "ÉMISSION RÉUSSIE" : "AU SUIVANT…")
                    .font(.display(34))
                    .foregroundStyle(interview.passed ? Theme.accent : .white)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                Button("Fin de l'émission") { model.finishInterview() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func answerRow(_ index: Int, _ option: InterviewAnswer) -> some View {
        let available = option.isAvailable(in: state)
        return Button {
            answer(index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(available ? "▶" : "×").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(TextTemplate.render(option.label, for: state.rapper))
                        .font(.system(size: 15, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !available {
                        Text(requirement(option.requires))
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

    private func requirement(_ requirement: ChoiceRequirement?) -> String {
        guard let requirement else { return "" }
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

    private func startTimer(_ seconds: Double) {
        timerTask?.cancel()
        timeLeft = 1
        let question = interview.questionIndex
        timerTask = Task {
            let ticks = Int(seconds * 10)
            for tick in 0..<ticks {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                withAnimation(.linear(duration: 0.1)) { timeLeft = 1 - Double(tick + 1) / Double(ticks) }
            }
            if !Task.isCancelled && stage == .question && interview.questionIndex == question {
                answer(nil)
            }
        }
    }

    private func answer(_ index: Int?) {
        guard stage == .question else { return }
        timerTask?.cancel()
        guard let updated = model.answerInterview(index), let entry = updated.log.last else { return }
        SoundEngine.shared.play(entry.hypeDelta >= 0 ? .statUp : .statDown)
        typed = false
        revealAll = false
        withAnimation(.easeOut(duration: 0.8)) { hype = Double(updated.hype) }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            reaction = entry
            stage = .reaction
        }
    }
}

/// Audience gauge with the line you need to cross.
private struct AudienceGauge: View {
    let hype: Double
    let pass: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("AUDIENCE").font(.system(size: 10, weight: .heavy, design: .monospaced))
                Spacer()
                Text("\(Int(hype.rounded())) %")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .contentTransition(.numericText(value: hype))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12))
                    Rectangle()
                        .fill(hype >= pass ? Theme.accent : Color.white.opacity(0.85))
                        .frame(width: geo.size.width * hype / 100)
                    Rectangle()
                        .fill(Color(red: 1, green: 0.85, blue: 0.3))
                        .frame(width: 2)
                        .offset(x: geo.size.width * pass / 100)
                }
            }
            .frame(height: 12)
            .overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
            Text("Objectif : \(Int(pass)) % pour convaincre l'antenne")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .padding(10)
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

/// After the finale: hang up the mic as a legend, or keep clashing the new generation.
struct FinaleChoiceBox: View {
    let retire: () -> Void
    let keepGoing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LE TRÔNE EST À TOI")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
            Text("Tout le monde te regarde. Tu pars au sommet, ou tu restes pour défendre ta couronne ?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Button(action: retire) {
                VStack(spacing: 2) {
                    Text("Raccrocher en légende")
                    Text("Fin de carrière, au sommet").font(.mono(10, weight: .semibold)).textCase(nil)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            Button(action: keepGoing) {
                VStack(spacing: 2) {
                    Text("Clasher les petits nouveaux")
                    Text("Carrière libre, sans limite de temps").font(.mono(10, weight: .semibold)).textCase(nil)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .background(Color.black.opacity(0.9))
        .overlay(Rectangle().stroke(Color(red: 1, green: 0.85, blue: 0.3), lineWidth: 2))
    }
}
