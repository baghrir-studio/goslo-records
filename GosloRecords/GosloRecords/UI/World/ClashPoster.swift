import SwiftUI

/// After a won clash: a poster of the fight to share (1080×1920), your face up front, theirs crossed out.
struct ClashPoster: View {
    static let size = CGSize(width: 360, height: 640)

    let player: Rapper
    let opponentName: String
    let opponentLook: CharacterLook
    let clash: ClashState

    private static let gold = Color(red: 1, green: 0.85, blue: 0.3)

    private var dealt: Int { clash.log.filter(\.byPlayer).map(\.damage).reduce(0, +) }
    private var best: ClashLogEntry? { clash.log.filter(\.byPlayer).max { $0.damage < $1.damage } }

    private var bestLabel: String {
        guard let best else { return "—" }
        if let secret = best.secret { return secret.name }
        if let rhymes = best.freestyle { return "Freestyle · \(rhymes) rimes" }
        return best.move.label
    }

    var body: some View {
        ZStack {
            Color.black
            // Diagonal bands.
            Rectangle().fill(Theme.accent)
                .frame(width: 700, height: 260)
                .rotationEffect(.degrees(-18))
                .offset(y: -40)
            Rectangle().fill(Self.gold)
                .frame(width: 700, height: 20)
                .rotationEffect(.degrees(-18))
                .offset(y: 100)

            VStack(spacing: 0) {
                HStack {
                    Text("GOSLO RADIO · CLASH")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if clash.isBoss {
                        Text("BOSS")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Self.gold)
                            .foregroundStyle(.black)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Text("K.O.\nVERBAL")
                    .font(.display(84))
                    .lineSpacing(-18)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 0, x: 5, y: 5)
                    .padding(.top, 16)

                ZStack(alignment: .bottomTrailing) {
                    PixelImage(HeroSprite.image(player.look, facing: .down, frame: 1), width: 190)
                    ZStack {
                        PixelImage(HeroSprite.bust(opponentLook), width: 74)
                            .grayscale(1)
                            .opacity(0.8)
                        Image(systemName: "xmark")
                            .font(.system(size: 64, weight: .black))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.8))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                    .offset(x: 70, y: -10)
                }
                .padding(.top, 6)

                VStack(spacing: 4) {
                    Text(player.name.uppercased())
                        .font(.display(40))
                        .foregroundStyle(Self.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("bat \(opponentName)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.top, 8)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    stat("\(dealt)", "DÉGÂTS")
                    stat("\(clash.playerHype)", "PUBLIC")
                    stat(bestLabel, "MEILLEUR COUP")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                Text("@goslo_radio_lejeu")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 20)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    static func render(player: Rapper, opponentName: String, opponentLook: CharacterLook, clash: ClashState) -> UIImage? {
        let renderer = ImageRenderer(content: ClashPoster(player: player, opponentName: opponentName,
                                                          opponentLook: opponentLook, clash: clash))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
