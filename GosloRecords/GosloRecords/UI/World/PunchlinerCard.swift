import SwiftUI

/// Punchliner's result screen: the personal records (« Record perso ! » when beaten) and the card to share.
struct PunchlinerRecordsPanel: View {
    @Environment(AppModel.self) private var model
    let minigame: MinigameState

    private static let gold = Color(red: 1, green: 0.85, blue: 0.3)
    @State private var blink = false

    var body: some View {
        let record = model.profile.punchliner
        let broken = model.punchlinerBreak
        VStack(alignment: .leading, spacing: 8) {
            if broken?.newBestScore == true {
                Text("RECORD PERSO !")
                    .font(.display(26))
                    .foregroundStyle(Self.gold)
                    .shadow(color: Theme.accent, radius: 0, x: 2, y: 2)
                    .scaleEffect(blink ? 1.04 : 0.98, anchor: .leading)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { blink = true }
                    }
            }
            HStack(spacing: 0) {
                cell("\(record.bestScore) %", "RECORD")
                cell("\(record.richRhymes)", "RIMES RICHES")
                cell("\(model.profile.daily.best)", "SÉRIE CLASH\nDU JOUR")
            }
            if let pair = minigame.bestRhyme {
                HStack(spacing: 6) {
                    Text(broken?.newBestRhyme == true ? "NOUVELLE MEILLEURE RIME" : "TA RIME")
                        .font(.mono(10, weight: .bold))
                        .foregroundStyle(broken?.newBestRhyme == true ? Self.gold : Theme.muted)
                    Text("\(pair.word) / \(pair.target)")
                        .font(.mono(12, weight: .heavy))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            PunchlinerShareButton(minigame: minigame, newRecord: broken?.newBestScore == true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }

    private func cell(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.display(24)).foregroundStyle(Theme.text)
            Text(label).font(.mono(9, weight: .bold)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// « Partager » : renders the Punchliner card and hands it to the share sheet (the card stays on the phone
/// until the player shares it; there is no online leaderboard).
private struct PunchlinerShareButton: View {
    @Environment(AppModel.self) private var model
    let minigame: MinigameState
    let newRecord: Bool
    @State private var image: UIImage?

    var body: some View {
        // The clear pixel is always there, so the card renders as soon as the result shows.
        ZStack(alignment: .leading) {
            Color.clear.frame(width: 1, height: 1)
            if let image, let rapper = model.state?.rapper {
                let picture = Image(uiImage: image)
                ShareLink(item: picture,
                          subject: Text("Punchliner sur goslo radio"),
                          message: Text("\(rapper.name) : \(score) % au Punchliner. @goslo_radio_lejeu"),
                          preview: SharePreview("\(rapper.name) · Punchliner \(score) %", image: picture)) {
                    Label("Partager ma carte", systemImage: "square.and.arrow.up")
                        .font(.mono(13, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 1, green: 0.85, blue: 0.3))
                }
            }
        }
        .onAppear { render() }
    }

    private var score: Int { Int((model.engine.minigameScore(minigame) * 100).rounded()) }

    private func render() {
        guard image == nil, let rapper = model.state?.rapper else { return }
        let card = PunchlinerCard(rapper: rapper, title: model.engine.minigame(minigame.id)?.title ?? "Punchliner",
                                  score: score,
                                  // This game's rhyme, else its punchline, else the best rhyme ever written.
                                  pair: minigame.bestRhyme ?? (minigame.hook == nil ? model.profile.punchliner.bestRhyme : nil),
                                  pairIsThisGame: minigame.bestRhyme != nil, hook: minigame.hook,
                                  richRhymes: minigame.richRhymes ?? 0, best: model.profile.punchliner.bestScore,
                                  newRecord: newRecord)
        image = PunchlinerCard.render(card)
    }
}

/// The card to share after a Punchliner game (1080×1920): the score, the best rhyme written, the artist.
struct PunchlinerCard: View {
    static let size = CGSize(width: 360, height: 640)
    private static let gold = Color(red: 1, green: 0.85, blue: 0.3)

    let rapper: Rapper
    let title: String
    let score: Int
    /// This game's best rhyme, or the best ever when none was written this time.
    let pair: RhymePair?
    let pairIsThisGame: Bool
    /// The first real punchline found (when no rhyme was written).
    let hook: String?
    let richRhymes: Int
    let best: Int
    let newRecord: Bool

    private var pose: CrowdSprite.Pose {
        switch score {
        case 70...: .cheer
        case 40...: .nodUp
        default: .crossed
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.04, green: 0.04, blue: 0.045)
            LinearGradient(colors: [Color(red: 0.25, green: 0.05, blue: 0.2), .clear], startPoint: .bottom, endPoint: .center)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("GOSLO RADIO · PUNCHLINER")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if newRecord {
                        Text("RECORD PERSO")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Self.gold)
                            .foregroundStyle(.black)
                    }
                }

                Text(title.uppercased())
                    .font(.mono(10, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .padding(.top, 6)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(score)")
                        .font(.display(96))
                        .foregroundStyle(.white)
                    Text("%")
                        .font(.display(44))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.top, 8)

                rhyme
                    .padding(.top, 4)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 10) {
                    PixelImage(HeroSprite.image(rapper.look, facing: .down, frame: 1), width: 80)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rapper.name.uppercased())
                            .font(.display(40))
                            .foregroundStyle(Self.gold)
                            .lineLimit(2)
                            .minimumScaleFactor(0.4)
                        HStack(spacing: 14) {
                            figure("\(richRhymes)", "RIMES\nRICHES")
                            figure("\(best) %", "RECORD\nPERSO")
                        }
                    }
                }

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<9, id: \.self) { index in
                        PixelImage(CrowdSprite.image(pose, palette: index), width: 30)
                            .offset(y: pose == .cheer && index % 2 == 0 ? -6 : 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.vertical, 12)

                HStack(alignment: .lastTextBaseline) {
                    HStack(spacing: 0) {
                        Text("goslo radio")
                        Text(".").foregroundStyle(Theme.accent)
                    }
                    .font(.display(20))
                    .foregroundStyle(.white)
                    Spacer()
                    Text("@goslo_radio_lejeu")
                        .font(.mono(10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var rhyme: some View {
        if let pair {
            VStack(alignment: .leading, spacing: 6) {
                Text(pairIsThisGame ? "MEILLEURE RIME" : "MEILLEURE RIME PERSO")
                    .font(.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
                (Text(pair.word.uppercased()).foregroundStyle(Theme.accent)
                    + Text("  ×  ").foregroundStyle(Color.white.opacity(0.5))
                    + Text(pair.target.uppercased()).foregroundStyle(Color.white))
                    .font(.display(32))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("« \(pair.ending) »")
                    .font(.system(size: 16, weight: .medium))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Text(pair.quality.label.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(pair.quality == .riche ? Self.gold : Color.white.opacity(0.8))
                    .foregroundStyle(.black)
            }
        } else if let hook {
            VStack(alignment: .leading, spacing: 6) {
                Text("LA PUNCHLINE")
                    .font(.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
                Text("« \(hook) »")
                    .font(.system(size: 18, weight: .semibold))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.display(26)).foregroundStyle(.white)
            Text(label).font(.mono(8, weight: .semibold)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @MainActor
    static func render(_ card: PunchlinerCard) -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
