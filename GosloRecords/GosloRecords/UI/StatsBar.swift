import SwiftUI

/// The four stats, always visible, with a floating +/- on each change.
struct StatsBar: View {
    let stats: Stats
    let deltas: [StatKind: Int]
    let token: Int
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatKind.allCases) { kind in
                StatCell(kind: kind, value: stats[kind], delta: deltas[kind], token: token, compact: compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, compact ? 4 : 8)
        .padding(.bottom, compact ? 8 : 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

private struct StatCell: View {
    let kind: StatKind
    let value: Int
    let delta: Int?
    let token: Int
    var compact = false

    @State private var shownDelta: Int?
    /// 0 = hidden below, 1 = visible, 2 = gone above.
    @State private var stage = 0

    private var isDanger: Bool { value <= 15 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kind.shortLabel)
                .font(.mono(10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(isDanger ? Theme.accent : Theme.muted)

            Text("\(value)")
                .font(.display(compact ? 24 : 34))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .foregroundStyle(isDanger ? Theme.accent : Theme.text)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.line)
                    Rectangle()
                        .fill(isDanger ? Theme.accent : Theme.text)
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 2)
            .padding(.trailing, 12)
        }
        .overlay(alignment: .topTrailing) {
            if let shownDelta {
                Text(shownDelta > 0 ? "+\(shownDelta)" : "−\(abs(shownDelta))")
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(shownDelta > 0 ? Theme.accent : Theme.text.opacity(0.75))
                    .padding(.trailing, 12)
                    .offset(y: stage == 0 ? 22 : (stage == 1 ? 12 : -4))
                    .opacity(stage == 1 ? 1 : 0)
            }
        }
        .animation(.snappy(duration: 0.4), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.label) \(value) sur 100")
        .onChange(of: token) { _, _ in
            guard let delta, delta != 0 else { return }
            shownDelta = delta
            stage = 0
            withAnimation(.spring(duration: 0.35)) { stage = 1 }
            Task {
                try? await Task.sleep(for: .seconds(1.3))
                withAnimation(.easeIn(duration: 0.45)) { stage = 2 }
            }
        }
    }
}
