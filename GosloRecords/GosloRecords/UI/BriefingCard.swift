import SwiftUI

/// A new period starts: what the last one paid, in a few chips, and up to three goals. One tap closes it
/// (it also goes away on its own after a few seconds).
struct BriefingCard: View {
    let briefing: PeriodBriefing
    let dismiss: () -> Void

    private static let gold = Color(red: 1, green: 0.85, blue: 0.3)

    private struct Chip {
        let label: String
        let value: Int
    }

    var body: some View {
        Button(action: dismiss) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(briefing.title.uppercased())
                        .font(.display(18))
                        .foregroundStyle(.white)
                    Spacer(minLength: 4)
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                if !chips.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(chips, id: \.label) { chip in
                            Text("\(chip.label) \(signed(chip.value))")
                                .font(.mono(10, weight: .bold))
                                .foregroundStyle(chip.value >= 0 ? Color.green : Theme.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                if let note = briefing.summary?.chartNotes.first {
                    Text(note)
                        .font(.mono(10, weight: .semibold))
                        .foregroundStyle(Self.gold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                ForEach(briefing.objectives, id: \.self) { objective in
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("→").foregroundStyle(Self.gold)
                        Text(objective).foregroundStyle(.white)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.82))
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.accent).frame(width: 3)
            }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint("Touche pour fermer")
    }

    /// Money only, by source: rent, bookings, the Top, album sales, what the map pays, and the total.
    private var chips: [Chip] {
        guard let summary = briefing.summary else { return [] }
        let bookings = (summary.upkeep[.argent] ?? 0) + summary.rent
        let parts = [
            Chip(label: "LOYER", value: -summary.rent),
            Chip(label: "CACHETS", value: bookings),
            Chip(label: "TOP", value: summary.chart[.argent] ?? 0),
            Chip(label: "ALBUMS", value: summary.albums[.argent] ?? 0),
            Chip(label: "DÉCOS", value: summary.income[.argent] ?? 0),
        ].filter { $0.value != 0 }
        guard parts.count > 1 else { return parts }
        // One row on a small phone: the three biggest lines (in their order), then the total.
        let biggest = Set(parts.sorted { abs($0.value) > abs($1.value) }.prefix(3).map(\.label))
        let shown = parts.filter { biggest.contains($0.label) }
        return shown + [Chip(label: "TOTAL", value: summary.net[.argent] ?? 0)]
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : (value < 0 ? "−\(-value)" : "0")
    }
}
