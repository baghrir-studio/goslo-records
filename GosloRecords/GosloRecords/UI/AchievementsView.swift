import SwiftUI

private let gold = Color(red: 1, green: 0.85, blue: 0.3)

/// "Succès": every achievement, unlocked or not, and the legacy bonuses they open up.
struct AchievementsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let unlocked = model.profile.unlocked
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BackButton(title: "Accueil") { model.go(.home) }
                Spacer()
            }
            .padding(.horizontal, Theme.gutter)

            HStack(alignment: .lastTextBaseline) {
                Text("Succès").font(.display(52))
                Spacer()
                Text("\(unlocked.count) / \(Achievement.allCases.count)")
                    .font(.mono(15, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 4)
            Text("Certains succès débloquent un héritage : un bonus à choisir en créant ta prochaine carrière.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Achievement.allCases) { achievement in
                        AchievementRow(achievement: achievement, date: model.profile.achievements[achievement])
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let date: Date?

    var body: some View {
        let done = date != nil
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? achievement.symbol : "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(done ? Theme.background : Theme.faint)
                .frame(width: 40, height: 40)
                .background(done ? gold : Color.clear)
                .overlay(Rectangle().stroke(done ? gold : Theme.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title.uppercased())
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(done ? Theme.text : Theme.muted)
                Text(achievement.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                if let heritage = achievement.heritage {
                    Text("Héritage : \(heritage.name)")
                        .font(.mono(11, weight: .semibold))
                        .foregroundStyle(done ? Theme.accent : Theme.faint)
                }
            }
            Spacer(minLength: 0)
            if let date {
                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.mono(10, weight: .medium))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(12)
        .overlay(Rectangle().stroke(done ? gold.opacity(0.5) : Theme.line, lineWidth: 1))
        .opacity(done ? 1 : 0.75)
    }
}

/// The banner that slides down when an achievement unlocks.
struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 42, height: 42)
                .background(gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("SUCCÈS DÉBLOQUÉ")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(gold)
                Text(achievement.title)
                    .font(.display(22))
                    .foregroundStyle(.white)
                if let heritage = achievement.heritage {
                    Text("Nouvel héritage : \(heritage.name)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.black.opacity(0.92))
        .overlay(Rectangle().stroke(gold, lineWidth: 2))
        .padding(.horizontal, 14)
        .allowsHitTesting(false)
    }
}
