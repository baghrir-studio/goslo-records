import SwiftUI

/// The metro map: one line, four stations. Open districts can be picked; the others say when they open.
struct MetroMapView: View {
    let transit: Transit
    let current: District
    let open: [District]
    /// District holding the current objective (starred).
    let objective: District?
    let travel: (District) -> Void
    let close: () -> Void

    private static let gold = Color(red: 1, green: 0.85, blue: 0.3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(transit.badge)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(transit.color)
                Text(transit == .tramway ? "TRAM · LIGNE GOSLO" : "MÉTRO · LIGNE GOSLO")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.bottom, 10)

            ForEach(Array(District.allCases.enumerated()), id: \.element) { index, district in
                station(district, first: index == 0, last: index == District.allCases.count - 1)
            }

            Button("Rester ici", action: close)
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 10)
        }
        .padding(14)
        .background(Color.black.opacity(0.92))
        .overlay(Rectangle().stroke(transit.color, lineWidth: 2))
    }

    private func station(_ district: District, first: Bool, last: Bool) -> some View {
        let isOpen = open.contains(district)
        let isHere = district == current
        return Button {
            travel(district)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // The line and the station dot.
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle().fill(first ? Color.clear : transit.color).frame(width: 6)
                        Rectangle().fill(last ? Color.clear : transit.color).frame(width: 6)
                    }
                    Circle()
                        .fill(isHere ? Self.gold : (isOpen ? Color.white : Color.white.opacity(0.25)))
                        .frame(width: isHere ? 20 : 16, height: isHere ? 20 : 16)
                        .overlay(Circle().stroke(transit.color, lineWidth: 3))
                }
                .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(district.name.uppercased())
                            .font(.display(22))
                            .foregroundStyle(isOpen ? .white : .white.opacity(0.35))
                        if objective == district {
                            Text("★ OBJECTIF")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Self.gold)
                        }
                    }
                    Text(isHere ? "TU ES ICI" : (isOpen ? district.tagline : "Ouvre au chapitre \(district.fromChapter)"))
                        .font(.system(size: 11, weight: isHere ? .heavy : .regular, design: isHere ? .monospaced : .default))
                        .foregroundStyle(isHere ? Self.gold : .white.opacity(isOpen ? 0.65 : 0.3))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if isOpen && !isHere {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isOpen || isHere)
    }
}

extension Transit {
    /// Blue for the metro, Casablanca's tram red.
    var color: Color {
        self == .tramway ? Color(red: 0.85, green: 0.16, blue: 0.12) : Color(red: 0.2, green: 0.5, blue: 1)
    }
}
