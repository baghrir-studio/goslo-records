import SwiftUI

/// 9:16 career summary card. Designed at 360×640 pt,
/// exported at 3× (1080×1920 px, Instagram story size).
struct ShareCardView: View {
    static let size = CGSize(width: 360, height: 640)

    let record: CareerRecord

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.04, green: 0.04, blue: 0.045)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("FIN DE CARRIÈRE")
                    Spacer()
                    Text("\(record.yearsActive) AN\(record.yearsActive > 1 ? "S" : "") ACTIF\(record.yearsActive > 1 ? "S" : "")")
                }
                .font(.mono(9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.muted)

                Spacer(minLength: 0)

                Text(record.rapper.name.uppercased())
                    .font(.display(56))
                    .lineLimit(2)
                    .minimumScaleFactor(0.4)
                    .lineSpacing(-10)
                    .foregroundStyle(.white)

                Text("\(record.rapper.city.rawValue.uppercased()) · \(record.rapper.style.rawValue.uppercased())")
                    .font(.mono(11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 6)

                Rectangle().fill(Theme.accent).frame(width: 40, height: 4).padding(.vertical, 22)

                Text(record.ending.title.uppercased())
                    .font(.display(46))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Theme.accent)

                Text("« \(record.summary) »")
                    .font(.system(size: 17, weight: .medium))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Spacer(minLength: 0)

                HStack(alignment: .top, spacing: 0) {
                    figure("\(record.counters[.disquesOr])", "DISQUES\nD'OR")
                    figure("\(record.counters[.clashsGagnes])/\(record.counters[.beefs])", "CLASHS\nGAGNÉS")
                    figure("\(record.counters[.projets])", "PROJETS")
                    figure("\(record.counters[.featurings])", "FEATS")
                }

                HStack(spacing: 0) {
                    ForEach(StatKind.allCases) { kind in
                        HStack(spacing: 4) {
                            Text(kind.shortLabel).foregroundStyle(Theme.faint)
                            Text("\(record.stats[kind])").foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.mono(8, weight: .semibold))
                .padding(.top, 14)

                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.vertical, 16)

                HStack(alignment: .lastTextBaseline) {
                    HStack(spacing: 0) {
                        Text("goslo records")
                        Text(".").foregroundStyle(Theme.accent)
                    }
                    .font(.display(20))
                    .foregroundStyle(.white)
                    Spacer()
                    Text("@goslo_records")
                        .font(.mono(10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.display(34)).foregroundStyle(.white)
            Text(label).font(.mono(8, weight: .semibold)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Renders the card as an image (1080×1920).
    @MainActor
    static func renderImage(for record: CareerRecord) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(record: record))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// Displays the card scaled to the available width.
struct ScaledShareCard: View {
    let record: CareerRecord

    var body: some View {
        Color.clear
            .aspectRatio(ShareCardView.size.width / ShareCardView.size.height, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    ShareCardView(record: record)
                        .scaleEffect(geo.size.width / ShareCardView.size.width, anchor: .topLeading)
                }
            }
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}
