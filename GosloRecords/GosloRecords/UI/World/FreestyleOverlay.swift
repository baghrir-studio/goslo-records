import SwiftUI

/// Freestyle: a beat plays, the last word of your bar shows up, tap the word that rhymes. Chain as many as
/// you can before the beat stops; a wrong word costs a second.
struct FreestyleOverlay: View {
    let onFinish: (Int) -> Void

    private static let gold = Color(red: 1, green: 0.85, blue: 0.3)
    private static let beat = 0.5

    @State private var round: Freestyle.Round
    @State private var rhymes = 0
    @State private var penalty = 0.0
    @State private var start = Date()
    @State private var wrong: Int?
    @State private var flash = 0
    @State private var finished = false

    init(onFinish: @escaping (Int) -> Void) {
        self.onFinish = onFinish
        var generator = SystemRandomNumberGenerator()
        _round = State(initialValue: Freestyle.round(using: &generator))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
            VStack(spacing: 18) {
                HStack {
                    Text("🎤 FREESTYLE")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Self.gold)
                    Spacer()
                    Text("\(min(rhymes, Freestyle.maxRhymes)) RIME\(rhymes > 1 ? "S" : "")")
                        .font(.display(26))
                        .foregroundStyle(rhymes >= Freestyle.strongAt ? Self.gold : .white)
                        .id(rhymes)
                        .transition(.scale(scale: 1.8).combined(with: .opacity))
                }
                TimelineView(.animation) { context in
                    let left = max(0, 1 - (context.date.timeIntervalSince(start) + penalty) / Freestyle.seconds)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.15))
                            Rectangle().fill(left < 0.25 ? Theme.accent : Self.gold).frame(width: geo.size.width * left)
                        }
                    }
                    .frame(height: 8)
                }

                VStack(spacing: 4) {
                    Text("…ta mesure finit sur")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(round.prompt.uppercased())
                        .font(.display(46))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.accent, radius: 0, x: 3, y: 3)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .id(round.prompt)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                }
                .frame(height: 96)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(round.options.enumerated()), id: \.offset) { index, word in
                        Button { pick(index) } label: {
                            Text(word)
                                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                .foregroundStyle(wrong == index ? Theme.muted : .white)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(wrong == index ? Theme.accent.opacity(0.35) : Color.white.opacity(0.08))
                                .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(PressScaleStyle())
                        .disabled(finished)
                    }
                }
                Text("Touche le mot qui rime. Enchaîne !")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 16)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .medium), trigger: flash)
        .task { await run() }
    }

    /// The beat: a kick and a snare in turn until the time is up (wrong words shorten it).
    private func run() async {
        start = Date()
        var count = 0
        while Date().timeIntervalSince(start) + penalty < Freestyle.seconds {
            SoundEngine.shared.play(count % 2 == 0 ? .concertKick : .concertSnare)
            if count % 2 == 0 { Haptics.shared.play(.kick) }
            count += 1
            try? await Task.sleep(for: .seconds(Self.beat))
        }
        finished = true
        SoundEngine.shared.play(rhymes >= Freestyle.strongAt ? .crowdCheer : .crowdGroan)
        try? await Task.sleep(for: .milliseconds(500))
        onFinish(min(rhymes, Freestyle.maxRhymes))
    }

    private func pick(_ index: Int) {
        guard !finished else { return }
        if index == round.answer {
            SoundEngine.shared.play(.concertHit)
            Haptics.shared.play(.perfect)
            flash += 1
            var generator = SystemRandomNumberGenerator()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                rhymes += 1
                wrong = nil
                round = Freestyle.round(after: round, using: &generator)
            }
        } else {
            SoundEngine.shared.play(.miss)
            Haptics.shared.play(.miss)
            penalty += Freestyle.wrongPenalty
            withAnimation(.easeOut(duration: 0.15)) { wrong = index }
        }
    }
}
