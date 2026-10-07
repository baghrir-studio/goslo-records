import SwiftUI

// Secret techniques on screen: each `SecretFX` has its own backdrop, its own way of showing the character,
// its own burst on impact and its own sting. Plus the rhythm charge before the player's technique,
// the crowd's reaction and the boss "VS" splash.

private let gold = Color(red: 1, green: 0.85, blue: 0.3)
private let penRed = Color(red: 0.9, green: 0.1, blue: 0.12)

extension SecretFX {
    /// Sound played when the technique's cinematic starts (rays keep the classic riser).
    var sting: SoundEffect {
        switch self {
        case .rays: .secretRiser
        case .bass: .fxBass
        case .vinyl: .fxScratch
        case .adlib: .fxAdlib
        case .tear: .fxTear
        case .emojis: .fxChat
        case .glitch: .fxGlitch
        case .redpen: .fxPen
        case .spotlight: .fxSpotlight
        }
    }

    /// How long the cinematic holds (the tear takes its time).
    var cinematicSeconds: Double { self == .tear ? 2.8 : 2.2 }

    /// Symbol thrown around on impact.
    func burstSymbol(prop: String?) -> String {
        switch self {
        case .rays: prop ?? "sparkle"
        case .bass: "speaker.wave.3.fill"
        case .vinyl: "opticaldisc.fill"
        case .adlib: "music.note"
        case .tear: "drop.fill"
        case .emojis: prop ?? "heart.fill"
        case .glitch: "square.fill"
        case .redpen: "xmark"
        case .spotlight: prop ?? "star.fill"
        }
    }
}

// MARK: - Cinematic backdrop

/// What fills the screen behind the character during the technique's cinematic.
struct SecretFXBackdrop: View {
    let fx: SecretFX
    let prop: String?

    var body: some View {
        switch fx {
        case .rays: RaysLayer()
        case .bass: BassRings()
        case .vinyl: VinylSpin()
        case .adlib: AdlibEcho()
        case .tear: TearFall()
        case .emojis: ChatStream(symbols: prop.map { [$0, "heart.fill", "flame.fill"] }
                                 ?? ["heart.fill", "flame.fill", "hand.thumbsup.fill", "star.fill", "face.smiling"])
        case .glitch: GlitchBars()
        case .redpen: PenStrokes()
        case .spotlight: Spotlights()
        }
    }
}

/// The classic: radiating rays, slowly turning.
private struct RaysLayer: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Rectangle()
                    .fill((index % 2 == 0 ? Theme.accent : gold).opacity(0.35))
                    .frame(width: 26, height: 900)
                    .rotationEffect(.degrees(Double(index) * 15))
            }
        }
        .rotationEffect(.degrees(spin ? 40 : 0))
        .onAppear { withAnimation(.linear(duration: 2.2)) { spin = true } }
    }
}

/// Sub-bass: rings pulse out from the centre, an equalizer pumps at the bottom.
private struct BassRings: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    let phase = (t * 1.6 + Double(index) / 5).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke((index % 2 == 0 ? Theme.accent : gold).opacity(1 - phase), lineWidth: 3 + 12 * (1 - phase))
                        .frame(width: 40 + phase * 720, height: 40 + phase * 720)
                }
                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(0..<14, id: \.self) { index in
                            let level = 0.3 + 0.7 * abs(sin(t * (5 + Double(index % 4)) + Double(index)))
                            Rectangle()
                                .fill(index % 3 == 0 ? gold : Theme.accent)
                                .frame(width: 12, height: 20 + 90 * level)
                        }
                    }
                    .opacity(0.8)
                }
            }
        }
    }
}

/// A giant record spinning, scratched back and forth, with rewind lines.
private struct VinylSpin: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ZStack {
                    Circle().fill(Color(white: 0.06)).frame(width: 340, height: 340)
                    ForEach(0..<7, id: \.self) { index in
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            .frame(width: CGFloat(320 - index * 30), height: CGFloat(320 - index * 30))
                    }
                    Circle().fill(Theme.accent).frame(width: 96, height: 96)
                    Rectangle().fill(gold).frame(width: 40, height: 6).offset(y: -22)
                    Circle().fill(Color.black).frame(width: 10, height: 10)
                }
                .rotationEffect(.degrees(t * 220 + sin(t * 7) * 70))
                // Rewind: white lines racing up.
                GeometryReader { geo in
                    ForEach(0..<6, id: \.self) { index in
                        let y = (1 - (t * 1.8 + Double(index) / 6).truncatingRemainder(dividingBy: 1)) * geo.size.height
                        Rectangle().fill(Color.white.opacity(0.18))
                            .frame(width: geo.size.width, height: CGFloat(2 + index % 3 * 2))
                            .position(x: geo.size.width / 2, y: y)
                    }
                }
            }
        }
    }
}

/// Ad-libs popping all over the screen, one after the other.
private struct AdlibEcho: View {
    static let words = ["SKRRT", "YEAH", "HEIN", "OUAIS", "BRRR", "AH !", "LET'S GO", "WOO", "SKRRT", "EH", "OKAY", "GANG"]
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<16, id: \.self) { index in
                let x = CGFloat((index * 37 + 11) % 100) / 100
                let y = CGFloat((index * 61 + 7) % 100) / 100
                Text(Self.words[index % Self.words.count])
                    .font(.display(CGFloat(22 + (index * 7) % 26)))
                    .foregroundStyle(index % 3 == 0 ? Theme.accent : (index % 3 == 1 ? gold : .white))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                    .rotationEffect(.degrees(Double((index * 13) % 30) - 15))
                    .scaleEffect(shown ? 1 : 0.1)
                    .opacity(shown ? 0.9 : 0)
                    .position(x: geo.size.width * x, y: geo.size.height * y)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5).delay(Double(index) * 0.09), value: shown)
            }
        }
        .onAppear { shown = true }
    }
}

/// Black and white, rain of grey streaks, and a single blue tear falling in slow motion.
private struct TearFall: View {
    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(colors: [Color(white: 0.25), .black], center: .center, startRadius: 10, endRadius: geo.size.height)
                ForEach(0..<20, id: \.self) { index in
                    Rectangle().fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 40)
                        .position(x: geo.size.width * CGFloat((index * 41 + 5) % 100) / 100,
                                  y: fallen ? geo.size.height + 40 : -40 - CGFloat(index * 17 % 120))
                        .animation(.linear(duration: 2.6).delay(Double(index % 5) * 0.1), value: fallen)
                }
                Image(systemName: "drop.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(red: 0.35, green: 0.7, blue: 1))
                    .shadow(color: Color(red: 0.35, green: 0.7, blue: 1), radius: 10)
                    .position(x: geo.size.width * 0.56, y: fallen ? geo.size.height * 0.92 : geo.size.height * 0.32)
                    .animation(.easeIn(duration: 2.4).delay(0.2), value: fallen)
            }
        }
        .onAppear { fallen = true }
    }
}

/// A live stream going wild: reactions flying up, a LIVE badge and a viewer count racing.
private struct ChatStream: View {
    let symbols: [String]
    @State private var rising = false
    @State private var start = Date()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.3), .black], startPoint: .bottom, endPoint: .top)
                ForEach(0..<20, id: \.self) { index in
                    Image(systemName: symbols[index % symbols.count])
                        .font(.system(size: CGFloat(20 + (index * 5) % 18), weight: .bold))
                        .foregroundStyle(index % 3 == 0 ? Theme.accent : (index % 3 == 1 ? gold : .white))
                        .position(x: geo.size.width * (0.55 + CGFloat((index * 29) % 45) / 100),
                                  y: rising ? -40 : geo.size.height + 40)
                        .animation(.easeOut(duration: 1.8).delay(Double(index) * 0.07), value: rising)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("● LIVE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.red)
                            .foregroundStyle(.white)
                        TimelineView(.periodic(from: .now, by: 0.05)) { context in
                            let viewers = Int(context.date.timeIntervalSince(start) * 1_400_000) + 1_337
                            Text("👁 \(viewers.formatted())")
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
        .onAppear {
            start = Date()
            rising = true
        }
    }
}

/// The picture breaks: colour bars flicker across the screen.
private struct GlitchBars: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.07)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 14)
            GeometryReader { geo in
                ZStack {
                    Color.black
                    ForEach(0..<9, id: \.self) { index in
                        let roll = Self.hash(tick, index)
                        Rectangle()
                            .fill([Color.cyan, Color(red: 1, green: 0, blue: 0.6), Color.green, Color.white][roll % 4].opacity(0.55))
                            .frame(width: geo.size.width * CGFloat(30 + roll % 70) / 100, height: CGFloat(4 + roll % 26))
                            .position(x: geo.size.width * CGFloat(roll % 100) / 100,
                                      y: geo.size.height * CGFloat((roll / 7) % 100) / 100)
                    }
                }
            }
        }
    }

    static func hash(_ tick: Int, _ index: Int) -> Int {
        var h = UInt32(truncatingIfNeeded: tick &* 2_654_435_761 &+ index &* 40_503)
        h ^= h >> 13
        h = h &* 1_274_126_177
        h ^= h >> 16
        return Int(h % 10_000)
    }
}

/// Lined paper, and red pen strokes slashing across it.
private struct PenStrokes: View {
    @State private var drawn = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.95, green: 0.93, blue: 0.86).opacity(0.18)
                ForEach(0..<14, id: \.self) { index in
                    Rectangle().fill(Color(red: 0.4, green: 0.6, blue: 1).opacity(0.25))
                        .frame(height: 1)
                        .position(x: geo.size.width / 2, y: CGFloat(index + 1) * geo.size.height / 15)
                }
                ForEach(0..<4, id: \.self) { index in
                    Slash(from: UnitPoint(x: 0.05, y: 0.15 + CGFloat(index) * 0.22),
                          to: UnitPoint(x: 0.95, y: 0.05 + CGFloat(index) * 0.22 + (index % 2 == 0 ? 0.12 : -0.02)))
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(penRed, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .animation(.easeOut(duration: 0.22).delay(0.2 + Double(index) * 0.28), value: drawn)
                }
            }
        }
        .onAppear { drawn = true }
    }
}

private struct Slash: Shape {
    let from: UnitPoint
    let to: UnitPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * from.x, y: rect.height * from.y))
        path.addLine(to: CGPoint(x: rect.width * to.x, y: rect.height * to.y))
        return path
    }
}

/// Stage spotlights sweeping, then locking on the centre.
private struct Spotlights: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    Color(red: 0.08, green: 0.04, blue: 0.12)
                    ForEach(0..<3, id: \.self) { index in
                        let base = Double(index - 1) * 28
                        Cone()
                            .fill(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.02)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 180, height: geo.size.height * 1.3)
                            .rotationEffect(.degrees(base * (0.4 + 0.6 * abs(sin(t * 1.3 + Double(index))))), anchor: .top)
                            .position(x: geo.size.width * (0.2 + 0.3 * CGFloat(index)), y: geo.size.height * 0.62)
                            .blendMode(.screen)
                    }
                    ForEach(0..<8, id: \.self) { index in
                        let blink = sin(t * 9 + Double(index) * 2.1) > 0.85
                        Image(systemName: "sparkle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(gold)
                            .opacity(blink ? 1 : 0)
                            .position(x: geo.size.width * CGFloat((index * 31 + 9) % 100) / 100,
                                      y: geo.size.height * CGFloat((index * 47 + 13) % 90) / 100)
                    }
                }
            }
        }
    }
}

/// A light cone: narrow at the top, wide at the bottom.
private struct Cone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + 8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - The character during the cinematic

/// The big character in the cinematic, treated to match the technique.
struct SecretFXCharacter: View {
    let image: UIImage
    let width: CGFloat
    let fx: SecretFX

    var body: some View {
        switch fx {
        case .glitch:
            TimelineView(.periodic(from: .now, by: 0.08)) { context in
                let k = Int(context.date.timeIntervalSinceReferenceDate * 12) % 6
                ZStack {
                    PixelImage(image, width: width).colorMultiply(Color(red: 1, green: 0.2, blue: 0.4))
                        .offset(x: k == 0 ? -9 : -3).opacity(0.7)
                    PixelImage(image, width: width).colorMultiply(.cyan)
                        .offset(x: k == 0 ? 9 : 3).opacity(0.7)
                    PixelImage(image, width: width).opacity(k == 3 ? 0.05 : 1)
                }
            }
        case .bass:
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                PixelImage(image, width: width).offset(x: sin(t * 70) * 4, y: cos(t * 55) * 3)
            }
        case .tear:
            PixelImage(image, width: width).grayscale(1)
        case .vinyl:
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                PixelImage(image, width: width).rotationEffect(.degrees(sin(t * 7) * 6))
            }
        default:
            PixelImage(image, width: width)
        }
    }
}

// MARK: - Impact

/// What bursts out of the target when the technique lands.
struct ImpactBurst: View {
    let fx: SecretFX
    let prop: String?
    @State private var go = false

    var body: some View {
        ZStack {
            switch fx {
            case .bass:
                ForEach(0..<3, id: \.self) { index in
                    Circle().stroke(index == 1 ? gold : Theme.accent, lineWidth: 7)
                        .frame(width: go ? 340 : 16, height: go ? 340 : 16)
                        .opacity(go ? 0 : 1)
                        .animation(.easeOut(duration: 0.7).delay(Double(index) * 0.12), value: go)
                }
            case .redpen:
                ForEach(0..<3, id: \.self) { index in
                    Capsule().fill(penRed)
                        .frame(width: go ? 190 : 0, height: 9)
                        .rotationEffect(.degrees(-35 + Double(index) * 35))
                        .animation(.easeOut(duration: 0.16).delay(Double(index) * 0.1), value: go)
                }
            default:
                let symbol = fx.burstSymbol(prop: prop)
                ForEach(0..<10, id: \.self) { index in
                    let angle = Double(index) / 10 * 2 * .pi
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(index % 2 == 0 ? gold : Theme.accent)
                        .offset(x: go ? cos(angle) * 130 : 0, y: go ? sin(angle) * 130 : 0)
                        .opacity(go ? 0 : 1)
                        .animation(.easeOut(duration: 0.8), value: go)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}

/// Three stars circling above a stunned character.
struct DizzyStars: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let angle = t * 4 + Double(index) * 2 * .pi / 3
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(gold)
                        .offset(x: cos(angle) * 30, y: sin(angle) * 8)
                        .scaleEffect(sin(angle) > 0 ? 1.1 : 0.8)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The crowd shouting after a big hit.
struct ReactionBubble: View {
    let text: String
    @State private var shown = false

    var body: some View {
        Text(text)
            .font(.display(26))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.85))
            .overlay(Rectangle().stroke(gold, lineWidth: 2))
            .rotationEffect(.degrees(4))
            .scaleEffect(shown ? 1 : 0.2)
            .onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shown = true } }
            .allowsHitTesting(false)
    }

    static let lines = ["OHHHHH !", "AÏE AÏE AÏE", "QUELLE FRAPPE !", "C'EST FINI !", "LA SALLE EXPLOSE", "APPELEZ UN MÉDECIN"]
}

// MARK: - Charging the player's technique

/// Before the player's technique lands: four beats, a ring closing on the target. Each tap on the beat
/// adds power (0…1 overall).
struct ChargeOverlay: View {
    let technique: String
    let onFinish: (Double) -> Void

    static let period = 0.6
    static let target: CGFloat = 46
    static let window = 0.18
    private var beats: Int { ClashState.chargeBeats }

    @State private var start = Date()
    @State private var scores = [Double](repeating: 0, count: ClashState.chargeBeats)
    @State private var judged: Set<Int> = []
    @State private var feedback: String?
    @State private var feedbackId = 0

    private var charge: Double { scores.reduce(0, +) / Double(beats) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
            VStack(spacing: 16) {
                Text("CHARGE TA TECHNIQUE")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(gold)
                Text(technique.uppercased())
                    .font(.display(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSince(start)
                    let phase = max(0, t).truncatingRemainder(dividingBy: Self.period) / Self.period
                    let radius = Self.target + CGFloat(1 - phase) * 84
                    ZStack {
                        Circle().fill(gold.opacity(0.15 + 0.6 * charge))
                            .frame(width: 30 + 60 * charge, height: 30 + 60 * charge)
                            .shadow(color: gold, radius: 20 * charge)
                        Circle().stroke(Color.white.opacity(0.3), lineWidth: Self.target * 0.5)
                            .frame(width: Self.target * 2, height: Self.target * 2)
                        if t < Double(beats) * Self.period + 0.05 {
                            Circle().stroke(Theme.accent, lineWidth: 5)
                                .frame(width: radius * 2, height: radius * 2)
                        }
                        if let feedback {
                            Text(feedback)
                                .font(.display(30))
                                .foregroundStyle(feedback == "RATÉ" ? Color.white.opacity(0.6) : gold)
                                .shadow(color: .black, radius: 0, x: 2, y: 2)
                                .offset(y: -118)
                                .id(feedbackId)
                                .transition(.scale(scale: 1.6).combined(with: .opacity))
                        }
                    }
                    .frame(width: 260, height: 260)
                }
                HStack(spacing: 8) {
                    ForEach(0..<beats, id: \.self) { index in
                        Rectangle()
                            .fill(!judged.contains(index) ? Color.white.opacity(0.2)
                                  : scores[index] > 0.75 ? gold : (scores[index] > 0.3 ? Theme.accent : Color.white.opacity(0.45)))
                            .frame(width: 44, height: 12)
                    }
                }
                Text("Tape quand l'anneau touche la cible")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onEnded { _ in tap() })
        .task { await run() }
    }

    /// The beat: a kick on each of the four beats, then the result.
    private func run() async {
        start = Date()
        for beat in 1...beats {
            let wait = Double(beat) * Self.period - Date().timeIntervalSince(start)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            SoundEngine.shared.play(beat == beats ? .concertSnare : .concertKick)
            Haptics.shared.play(beat == beats ? .snare : .kick)
        }
        try? await Task.sleep(for: .seconds(Self.window + 0.25))
        onFinish(charge)
    }

    private func tap() {
        let t = Date().timeIntervalSince(start)
        let beat = Int((t / Self.period).rounded())
        guard (1...beats).contains(beat), !judged.contains(beat - 1) else { return }
        let error = abs(t - Double(beat) * Self.period)
        let score = max(0, 1 - error / Self.window)
        judged.insert(beat - 1)
        scores[beat - 1] = score
        feedbackId += 1
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            feedback = score > 0.75 ? "PARFAIT" : (score > 0.3 ? "BIEN" : "RATÉ")
        }
        SoundEngine.shared.play(score > 0.3 ? .concertHit : .tap)
        Haptics.shared.play(score > 0.75 ? .perfect : (score > 0.3 ? .good : .miss))
    }
}

// MARK: - Boss entrance

/// Before a boss: both faces slam in from each side, "VS", the boss's name.
struct VSSplash: View {
    let player: CharacterLook
    let opponent: CharacterLook
    let name: String
    let subtitle: String
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color.black
                Rectangle().fill(gold)
                    .frame(width: w * 1.4, height: h * 0.42)
                    .rotationEffect(.degrees(-8))
                    .offset(x: shown ? 0 : w * 1.4, y: -h * 0.2)
                Rectangle().fill(Theme.accent)
                    .frame(width: w * 1.4, height: h * 0.42)
                    .rotationEffect(.degrees(-8))
                    .offset(x: shown ? 0 : -w * 1.4, y: h * 0.22)
                PixelImage(HeroSprite.bust(opponent), width: 150)
                    .offset(x: shown ? w * 0.2 : w, y: -h * 0.2)
                PixelImage(HeroSprite.bust(player), width: 150)
                    .offset(x: shown ? -w * 0.2 : -w, y: h * 0.2)
                Text("VS")
                    .font(.display(96))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 0, x: 5, y: 5)
                    .scaleEffect(shown ? 1 : 3)
                    .opacity(shown ? 1 : 0)
                VStack(spacing: 4) {
                    Spacer()
                    Text(name.uppercased())
                        .font(.display(40))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.accent, radius: 0, x: 3, y: 3)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(subtitle.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
                .opacity(shown ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { shown = true } }
    }
}
