import SwiftUI

/// Plays one song: clock, beat sounds, automatic misses, taps.
@Observable
@MainActor
final class ConcertRunner {
    static let leadTime = 1.6

    let notes: [ConcertNote]
    let song: ConcertSong
    let goodWindow: Double
    let sceneLevel: Int
    private(set) var judged: [Int: ConcertJudgment] = [:]
    private(set) var order: [ConcertJudgment] = []
    private(set) var feedback: (judgment: ConcertJudgment, id: Int)?
    private(set) var flash: [Int: Int] = [:]
    private(set) var running = false
    private var start = Date()
    private var task: Task<Void, Never>?
    private var lastHalfBeat = -1
    var onFinished: (([ConcertJudgment]) -> Void)?

    init(notes: [ConcertNote], song: ConcertSong, sceneLevel: Int) {
        self.notes = notes
        self.song = song
        self.sceneLevel = sceneLevel
        goodWindow = ConcertEngine.goodWindow(sceneLevel: sceneLevel)
    }

    var elapsed: Double { running ? Date().timeIntervalSince(start) : 0 }

    func play() {
        start = Date()
        running = true
        lastHalfBeat = -1
        task = Task { [weak self] in
            while let self, self.running, !Task.isCancelled {
                self.tick()
                try? await Task.sleep(for: .milliseconds(8))
            }
        }
    }

    func stop() {
        running = false
        task?.cancel()
    }

    private func tick() {
        let t = elapsed
        // The beat: kick on 1 and 3, snare on 2 and 4, hi-hat on every half-beat.
        let halfBeat = Int(t / (song.beat / 2))
        if halfBeat != lastHalfBeat {
            lastHalfBeat = halfBeat
            if halfBeat < (ConcertEngine.countInBeats + song.bars * 4) * 2 {
                let beatInBar = (halfBeat / 2) % 4
                if halfBeat % 2 == 0 {
                    if halfBeat / 2 < ConcertEngine.countInBeats {
                        SoundEngine.shared.play(.concertHit)
                    } else {
                        SoundEngine.shared.play(beatInBar % 2 == 0 ? .concertKick : .concertSnare)
                    }
                }
                if halfBeat / 2 >= ConcertEngine.countInBeats { SoundEngine.shared.play(.concertHat) }
            }
        }
        for note in notes where judged[note.id] == nil && t - note.time > goodWindow {
            record(.miss, for: note)
        }
        if t > song.duration {
            stop()
            onFinished?(order)
        }
    }

    func tap(_ lane: Int) {
        guard running else { return }
        flash[lane, default: 0] += 1
        // The calibrated latency: a tap that came late because the sound did is moved back.
        let t = elapsed - ConcertCalibration.latency
        let candidates = notes.filter { $0.lane == lane && judged[$0.id] == nil && abs($0.time - t) <= goodWindow }
        guard let note = candidates.min(by: { abs($0.time - t) < abs($1.time - t) }),
              let judgment = ConcertEngine.judge(offset: t - note.time, sceneLevel: sceneLevel) else { return }
        record(judgment, for: note)
        SoundEngine.shared.play(.concertHit)
    }

    private func record(_ judgment: ConcertJudgment, for note: ConcertNote) {
        judged[note.id] = judgment
        order.append(judgment)
        feedback = (judgment, note.id)
    }
}

/// The concert: crowd, highway of notes, three lanes to tap, interludes between songs.
struct ConcertView: View {
    @Environment(AppModel.self) private var model
    let concert: ConcertState
    let state: GameState

    private enum Stage: Equatable { case title, playing, result, interlude, reaction, finished }
    @State private var showCalibration = false

    @State private var stage: Stage = .title
    @State private var runner: ConcertRunner?
    @State private var lastSong: [ConcertJudgment] = []
    @State private var reaction = ""
    @State private var typed = false
    @State private var revealAll = false
    @State private var quip: String?
    @State private var missStreak = 0

    private var data: Concert? { model.engine.concert(concert.id) }
    private var song: ConcertSong? {
        guard let data, data.songs.indices.contains(concert.songIndex) else { return nil }
        return data.songs[concert.songIndex]
    }

    /// Hype shown live: committed value + the song being played.
    private var liveHype: Int {
        var preview = concert
        if let runner { ConcertEngine.apply(runner.order, to: &preview) }
        return preview.hype
    }

    private var liveCombo: Int {
        var preview = concert
        preview.combo = 0
        if let runner { ConcertEngine.apply(runner.order, to: &preview) }
        return preview.combo
    }

    var body: some View {
        if let data {
            VStack(spacing: 8) {
                header(data)
                CrowdView(hype: Double(liveHype), bpm: song?.bpm ?? 90, look: state.rapper.look, quip: quip)
                    .frame(height: 150)
                HypeMeter(hype: liveHype, pass: data.passHype, combo: stage == .playing ? liveCombo : 0)
                    .padding(.horizontal, 14)
                content(data)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            .onAppear {
                stage = concert.isOver ? .finished : (concert.inInterlude ? .interlude : .title)
                typed = false
            }
            .onDisappear { runner?.stop() }
        }
    }

    private func header(_ data: Concert) -> some View {
        HStack(spacing: 8) {
            Text("EN CONCERT")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.background)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color(red: 0.88, green: 0.31, blue: 0.69))
            Text(data.venue.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(min(concert.songIndex + 1, data.songs.count))/\(data.songs.count)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func content(_ data: Concert) -> some View {
        switch stage {
        case .title:
            VStack(spacing: 10) {
                if concert.songIndex == 0 && !data.intro.isEmpty {
                    DialogueFrame(speaker: nil) {
                        Text(TextTemplate.render(data.intro, for: state.rapper))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let song {
                    VStack(spacing: 4) {
                        Text("MORCEAU \(concert.songIndex + 1)").font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("« \(song.title.uppercased()) »").font(.display(30)).foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("\(Int(song.bpm)) BPM · tape quand une note touche la ligne")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Button("C'est parti") { startSong() }.buttonStyle(PrimaryButtonStyle())
                Button(ConcertCalibration.isSet ? "Régler le timing (\(ConcertCalibration.label))" : "Régler le timing") {
                    showCalibration = true
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            }
            .transition(.opacity)
            .sheet(isPresented: $showCalibration) {
                CalibrationView().presentationBackground(Theme.background)
            }
        case .playing:
            if let runner {
                VStack(spacing: 8) {
                    Highway(runner: runner)
                    LaneButtons { runner.tap($0) }
                }
            }
        case .result:
            let counts = (lastSong.filter { $0 == .perfect }.count, lastSong.filter { $0 == .good }.count,
                          lastSong.filter { $0 == .miss }.count)
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    resultCount("PARFAIT", counts.0, Color(red: 1, green: 0.85, blue: 0.3))
                    resultCount("BIEN", counts.1, .white)
                    resultCount("RATÉ", counts.2, Theme.accent)
                }
                Button(concert.inInterlude ? "Le public réagit…" : (concert.isOver ? "Fin du concert" : "Morceau suivant")) {
                    withAnimation { stage = concert.inInterlude ? .interlude : (concert.isOver ? .finished : .title) }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        case .interlude:
            if let interlude = song?.interlude {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(spacing: 0) {
                        ForEach(Array(interlude.options.enumerated()), id: \.offset) { index, option in
                            Button {
                                if let text = model.concertInterlude(index) {
                                    SoundEngine.shared.play(option.hype >= 0 ? .crowdCheer : .crowdGroan)
                                    reaction = text
                                    typed = false
                                    revealAll = false
                                    withAnimation { stage = .reaction }
                                }
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("▶").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(Theme.accent)
                                    Text(TextTemplate.render(option.label, for: state.rapper))
                                        .font(.system(size: 15, weight: .bold))
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(MenuRowStyle())
                        }
                    }
                    .background(Color(red: 0.06, green: 0.06, blue: 0.07))
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 4))
                    DialogueFrame(speaker: "Entre deux morceaux") {
                        Text(TextTemplate.render(interlude.text, for: state.rapper))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .reaction:
            DialogueFrame(speaker: nil, showsArrow: typed) {
                TypewriterText(text: TextTemplate.render(reaction, for: state.rapper), revealAll: revealAll) { typed = true }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if typed { withAnimation { stage = concert.isOver ? .finished : .title } } else { revealAll = true }
            }
        case .finished:
            VStack(spacing: 10) {
                Text(concert.passed ? "LA SALLE EST À TOI" : "LE PUBLIC EST PARTI AU BAR")
                    .font(.display(30))
                    .foregroundStyle(concert.passed ? Theme.accent : .white)
                    .multilineTextAlignment(.center)
                Text("Combo max : \(concert.maxCombo) · Parfaits : \(concert.perfects)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Button("Sortir de scène") { model.finishConcert() }.buttonStyle(PrimaryButtonStyle())
            }
            .onAppear { SoundEngine.shared.play(concert.passed ? .crowdCheer : .crowdGroan) }
        }
    }

    private func resultCount(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.display(34)).foregroundStyle(color)
            Text(label).font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func startSong() {
        guard let song else { return }
        let notes = model.engine.concertChart(in: state)
        let level = model.engine.clashLevels(in: state)(.scene)
        let new = ConcertRunner(notes: notes, song: song, sceneLevel: level)
        new.onFinished = { judgments in
            lastSong = judgments
            // The song is now committed to the concert: stop previewing it, or it would count twice.
            runner = nil
            model.concertSongFinished(judgments)
            withAnimation { stage = .result }
        }
        runner = new
        missStreak = 0
        quip = nil
        withAnimation { stage = .playing }
        new.play()
        watchQuips(new)
    }

    /// The crowd reacts to streaks.
    private func watchQuips(_ runner: ConcertRunner) {
        Task {
            var seen = 0
            while runner.running {
                try? await Task.sleep(for: .milliseconds(100))
                guard runner.order.count > seen else { continue }
                for judgment in runner.order[seen...] {
                    missStreak = judgment == .miss ? missStreak + 1 : 0
                }
                seen = runner.order.count
                if missStreak == 3 {
                    showQuip(ConcertQuips.bad.randomElement()!)
                    SoundEngine.shared.play(.crowdGroan)
                } else if liveCombo > 0 && liveCombo % 8 == 0 && runner.order.last != .miss {
                    showQuip(ConcertQuips.good.randomElement()!)
                    SoundEngine.shared.play(.crowdCheer)
                }
            }
        }
    }

    private func showQuip(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { quip = text }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation { if quip == text { quip = nil } }
        }
    }
}

enum ConcertQuips {
    static let good = [
        "Quelqu'un au fond crie « ENCORE ! »",
        "Un vigile hoche la tête. Contre son règlement.",
        "Ta mère filme. En portrait. Mais elle filme.",
        "Le premier rang connaît les paroles. Comment ?",
        "Un briquet s'allume. Puis trente.",
    ]
    static let bad = [
        "Un mec regarde son téléphone.",
        "Quelqu'un demande où sont les toilettes. Fort.",
        "Le bar n'a jamais eu autant de monde.",
        "Un spectateur bâille. En rythme, au moins.",
    ]
}

// MARK: - Pieces

private struct Highway: View {
    let runner: ConcertRunner

    private let colors: [Color] = [Theme.accent, .white, Color(red: 1, green: 0.85, blue: 0.3)]

    var body: some View {
        TimelineView(.animation) { _ in
            let t = runner.elapsed
            Canvas { context, size in
                let laneWidth = size.width / CGFloat(ConcertEngine.lanes)
                let hitY = size.height - 18
                for lane in 0..<ConcertEngine.lanes {
                    let rect = CGRect(x: CGFloat(lane) * laneWidth + 3, y: 0, width: laneWidth - 6, height: size.height)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.05)))
                }
                context.fill(Path(CGRect(x: 0, y: hitY - 2, width: size.width, height: 4)), with: .color(.white.opacity(0.85)))
                for note in runner.notes where runner.judged[note.id] == nil {
                    let ahead = note.time - t
                    guard ahead < ConcertRunner.leadTime, ahead > -0.3 else { continue }
                    let y = hitY - CGFloat(ahead / ConcertRunner.leadTime) * hitY
                    let rect = CGRect(x: CGFloat(note.lane) * laneWidth + 10, y: y - 9, width: laneWidth - 20, height: 18)
                    context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(colors[note.lane]))
                    context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.black), lineWidth: 2)
                }
                // Count-in: 4, 3, 2, 1.
                let beat = runner.song.beat
                if t < Double(ConcertEngine.countInBeats) * beat {
                    let left = ConcertEngine.countInBeats - Int(t / beat)
                    context.draw(Text("\(left)").font(.display(64)).foregroundColor(.white),
                                 at: CGPoint(x: size.width / 2, y: size.height * 0.4))
                }
            }
            .overlay(alignment: .top) {
                if let feedback = runner.feedback {
                    Text(label(feedback.judgment))
                        .font(.display(30))
                        .foregroundStyle(color(feedback.judgment))
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                        .id(feedback.id)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                        .padding(.top, 20)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: runner.feedback?.id)
        }
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
        .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 2))
    }

    private func label(_ judgment: ConcertJudgment) -> String {
        switch judgment {
        case .perfect: "PARFAIT !"
        case .good: "BIEN"
        case .miss: "RATÉ"
        }
    }

    private func color(_ judgment: ConcertJudgment) -> Color {
        switch judgment {
        case .perfect: Color(red: 1, green: 0.85, blue: 0.3)
        case .good: .white
        case .miss: Theme.accent
        }
    }
}

private struct LaneButtons: View {
    let onTap: (Int) -> Void
    private let labels = ["PUNCH", "FLOW", "HYPE"]
    private let colors: [Color] = [Theme.accent, .white, Color(red: 1, green: 0.85, blue: 0.3)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { lane in
                LaneButton(label: labels[lane], color: colors[lane]) { onTap(lane) }
            }
        }
        .frame(height: 76)
    }
}

/// Fires on touch-down (not on release): rhythm needs it.
private struct LaneButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.display(20))
            .foregroundStyle(pressed ? Theme.background : color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(pressed ? color : Color(red: 0.1, green: 0.1, blue: 0.12))
            .overlay(Rectangle().stroke(color, lineWidth: 3))
            .scaleEffect(pressed ? 0.94 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            action()
                        }
                    }
                    .onEnded { _ in pressed = false }
            )
            .animation(.easeOut(duration: 0.06), value: pressed)
    }
}

private struct HypeMeter: View {
    let hype: Int
    let pass: Int
    let combo: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("AMBIANCE").font(.system(size: 10, weight: .heavy, design: .monospaced))
                if combo >= 3 {
                    Text("COMBO ×\(combo)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                        .contentTransition(.numericText(value: Double(combo)))
                }
                Spacer()
                Text("\(hype) %").font(.system(size: 13, weight: .black, design: .monospaced))
                    .contentTransition(.numericText(value: Double(hype)))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12))
                    Rectangle()
                        .fill(hype >= pass ? Theme.accent : Color.white.opacity(0.85))
                        .frame(width: geo.size.width * CGFloat(hype) / 100)
                    Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.3)).frame(width: 2)
                        .offset(x: geo.size.width * CGFloat(pass) / 100)
                }
            }
            .frame(height: 10)
            .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
        }
        .foregroundStyle(.white)
        .animation(.easeOut(duration: 0.25), value: hype)
    }
}

/// Stage and crowd: the more ambiance, the more the crowd jumps.
private struct CrowdView: View {
    let hype: Double
    let bpm: Double
    let look: CharacterLook
    let quip: String?

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                scene(at: context.date.timeIntervalSinceReferenceDate)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        }
    }

    private func scene(at t: Double) -> some View {
        let beat = 60 / bpm
        let pulse = abs(sin(t / beat * .pi))
        return ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.2), Color(red: 0.05, green: 0.03, blue: 0.06)],
                               startPoint: .top, endPoint: .bottom)
                Color.clear.overlay(alignment: .top) {
                    ZStack(alignment: .top) {
                        ForEach(0..<3, id: \.self) { index in
                            LinearGradient(colors: [Color(red: 0.88, green: 0.31, blue: 0.69).opacity(0.35), .clear],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(width: 50, height: 260)
                                .rotationEffect(.degrees(sin(t * 0.8 + Double(index) * 2) * 20), anchor: .top)
                                .offset(x: CGFloat(index - 1) * 120)
                                .blendMode(.screen)
                        }
                    }
                }
                SpriteView(look: look, facing: .down, frame: Int(t / beat) % 2 == 0 ? 1 : 2, size: 64)
                    .offset(y: -58)
                Rectangle().fill(Color(red: 0.2, green: 0.13, blue: 0.1)).frame(height: 10).offset(y: -48)
                HStack(spacing: 3) {
                    ForEach(0..<18, id: \.self) { index in
                        let jump = hype / 100 * 14 * abs(sin(t / beat * .pi + Double(index) * 0.7))
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 18, height: CGFloat(30 + (index * 37) % 14))
                            .offset(y: -CGFloat(jump))
                    }
                }
                .padding(.bottom, -4)
            }
            .overlay(alignment: .topLeading) {
                if let quip {
                    Text(quip)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .padding(10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(1 + pulse * hype / 100 * 0.01)
    }
}
