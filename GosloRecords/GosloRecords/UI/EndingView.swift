import SwiftUI

/// Ending screen. Also used from "Mes carrières" (archive mode) to re-share a card.
struct EndingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let record: CareerRecord
    var isArchive = false

    @State private var image: UIImage?
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isArchive {
                    HStack {
                        Spacer()
                        Button("Fermer") { dismiss() }
                            .font(.mono(13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Kicker(text: record.ending.isPremature ? "Fin prématurée" : "Fin de carrière",
                           color: Theme.accent)
                    Text(record.ending.title.uppercased())
                        .font(.display(54))
                    Text(record.ending.description)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 12)

                ScaledShareCard(record: record)
                    .frame(maxWidth: 340)
                    .frame(maxWidth: .infinity)
                    .opacity(revealed ? 1 : 0)
                    .scaleEffect(revealed ? 1 : 0.96)

                VStack(spacing: 12) {
                    if let image {
                        let shareImage = Image(uiImage: image)
                        ShareLink(item: shareImage,
                                  subject: Text("Ma carrière sur goslo records"),
                                  message: Text("\(record.rapper.name) — \(record.ending.title). @goslo_records"),
                                  preview: SharePreview("\(record.rapper.name) — \(record.ending.title)", image: shareImage)) {
                            Text("Partager")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    if !isArchive {
                        Button("Nouvelle carrière") { model.go(.creation) }
                            .buttonStyle(SecondaryButtonStyle())
                        Button("Accueil") { model.go(.home) }
                            .font(.mono(13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            image = ShareCardView.renderImage(for: record)
            if !isArchive { SoundEngine.shared.play(record.ending.isPremature ? .defeat : .victory) }
            withAnimation(.easeOut(duration: 0.7).delay(0.1)) { revealed = true }
        }
    }
}
