import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: CareerRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BackButton(title: "Accueil") { model.go(.home) }
                Spacer()
            }
            .padding(.horizontal, Theme.gutter)

            Text("Mes\ncarrières")
                .font(.display(52))
                .lineSpacing(-8)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 16)

            if model.history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rien pour l'instant.")
                        .font(.display(26))
                    Text("Aucune carrière terminée. Le game t'attend, et il n'est pas patient.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, Theme.gutter)
                Spacer()
            } else {
                List {
                    ForEach(model.history) { record in
                        Button { selected = record } label: {
                            HistoryRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.background)
                        .listRowSeparatorTint(Theme.line)
                        .listRowInsets(EdgeInsets(top: 14, leading: Theme.gutter, bottom: 14, trailing: Theme.gutter))
                    }
                    .onDelete { model.deleteHistory(at: $0) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(item: $selected) { record in
            EndingView(record: record, isArchive: true)
                .environment(model)
                .presentationBackground(Theme.background)
        }
    }
}

private struct HistoryRow: View {
    let record: CareerRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(TextTemplate.agree(record.ending.title, record.rapper.gender).uppercased())
                    .font(.display(24))
                    .foregroundStyle(record.ending.isPremature ? Theme.text : Theme.accent)
                Spacer()
                Text(record.finishedAt.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.mono(10))
                    .foregroundStyle(Theme.faint)
            }
            Text("\(record.rapper.name) · \(record.rapper.city.rawValue) · \(record.rapper.style.rawValue) · \(record.yearsActive) an\(record.yearsActive > 1 ? "s" : "")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 12) {
                ForEach(StatKind.allCases) { kind in
                    HStack(spacing: 3) {
                        Text(kind.shortLabel).foregroundStyle(Theme.faint)
                        Text("\(record.stats[kind])")
                    }
                }
                Spacer()
                Text("OR \(record.counters[.disquesOr]) · CLASH \(record.counters[.beefs])")
                    .foregroundStyle(Theme.faint)
            }
            .font(.mono(9, weight: .semibold))
        }
        .contentShape(Rectangle())
    }
}
