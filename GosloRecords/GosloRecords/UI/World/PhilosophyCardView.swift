import SwiftUI

/// The philosopher's analysis of a punchline, as a story to share (1080×1920), in goslo radio's style:
/// the punchline big, the thinker who reads it, the analysis.
struct PhilosophyCardView: View {
    static let size = CGSize(width: 360, height: 640)

    let card: PhilosophyCard

    private static let paper = Color(red: 0.07, green: 0.06, blue: 0.08)
    private static let gold = Color(red: 1, green: 0.85, blue: 0.3)

    var body: some View {
        ZStack {
            Self.paper
            // A thin frame, like a page of a book.
            Rectangle().stroke(Self.gold.opacity(0.5), lineWidth: 1).padding(14)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("GOSLO RADIO · PHILO")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Self.gold)
                    Spacer()
                    Text("PUNCHLINE ANALYSÉE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 34)

                Text("«")
                    .font(.system(size: 90, weight: .black, design: .serif))
                    .foregroundStyle(Theme.accent)
                    .frame(height: 70)
                    .padding(.top, 18)

                Text(card.hook)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(5)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(card.artist)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 10)

                Rectangle().fill(Self.gold).frame(width: 46, height: 3).padding(.vertical, 22)

                Text("LU PAR")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(card.thinker.uppercased())
                    .font(.display(40))
                    .foregroundStyle(Self.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(card.analysis)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(3)
                    .lineLimit(9)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Spacer(minLength: 0)

                HStack {
                    Text("@goslo_radio")
                    Spacer()
                    Text("le jeu : @goslo_radio_lejeu")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 34)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    @MainActor
    static func render(_ card: PhilosophyCard) -> UIImage? {
        let renderer = ImageRenderer(content: PhilosophyCardView(card: card))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// "Share the analysis" button shown while the philosopher speaks.
struct PhilosophyShareButton: View {
    let card: PhilosophyCard
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                let picture = Image(uiImage: image)
                ShareLink(item: picture,
                          subject: Text("Punchline analysée par goslo radio"),
                          message: Text("« \(card.hook) » lu par \(card.thinker). @goslo_radio @goslo_radio_lejeu"),
                          preview: SharePreview("« \(card.hook) »", image: picture)) {
                    Label("Partager l'analyse", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 1, green: 0.85, blue: 0.3))
                }
            }
        }
        .onAppear { image = PhilosophyCardView.render(card) }
    }
}
