import SwiftUI

private let dailyGold = Color(red: 1, green: 0.85, blue: 0.3)

/// Home screen: today's clash, the streak, and whether you've already played.
struct DailyClashCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let challenge = model.dailyToday, let opponent = model.engine.castMember(challenge.opponentId) {
            let canPlay = model.canPlayDaily
            Button {
                model.startDailyClash()
            } label: {
                HStack(spacing: 12) {
                    PixelImage(HeroSprite.bust(opponent.look), width: 44)
                        .grayscale(canPlay ? 0 : 1)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("CLASH DU JOUR")
                                .font(.mono(11, weight: .bold))
                                .foregroundStyle(dailyGold)
                            if model.dailyStreak > 0 {
                                Text("🔥 \(model.dailyStreak)")
                                    .font(.mono(11, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        Text(canPlay ? "\(opponent.name) · \(challenge.district.name)" : resultLine)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(canPlay ? "Ce public adore : \(challenge.crowd.label.uppercased()) · 1 essai"
                                     : "Nouveau clash demain · record \(model.profile.daily.best)")
                            .font(.mono(10, weight: .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    if canPlay {
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(dailyGold)
                    }
                }
                .padding(12)
                .overlay(Rectangle().stroke(canPlay ? dailyGold : Theme.line, lineWidth: canPlay ? 1.5 : 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canPlay || model.loadError != nil)
        }
    }

    private var resultLine: String {
        switch model.profile.daily.lastResultWon {
        case true?: "Gagné aujourd'hui. Série : \(model.dailyStreak)"
        case false?: "Perdu aujourd'hui. Revanche demain."
        case nil: "Déjà joué aujourd'hui."
        }
    }
}

/// Above the battle, in the daily clash: replaces the career HUD.
struct DailyHeader: View {
    let challenge: DailyChallenge
    let opponent: String

    var body: some View {
        HStack {
            Text("CLASH DU JOUR")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(dailyGold)
            Spacer()
            Text("vs \(opponent) · \(challenge.district.name)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black)
    }
}
