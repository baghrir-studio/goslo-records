import SwiftUI

private let hqGold = Color(red: 1, green: 0.85, blue: 0.3)

/// The HQ between careers: the laverie seen in cross-section, its rooms lit once built.
/// Gold records come from finished careers; each room gives the next careers a head start.
struct HQView: View {
    @Environment(AppModel.self) private var model
    @State private var picked: HQRoom?
    @State private var glow = false

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        let hq = model.profile.hq
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BackButton(title: "Accueil") { model.go(.home) }
                Spacer()
            }
            .padding(.horizontal, Theme.gutter)

            HStack(alignment: .lastTextBaseline) {
                Text("Le QG").font(.display(52))
                Spacer()
                Text("💿 \(hq.discs)")
                    .font(.display(30))
                    .foregroundStyle(hqGold)
            }
            .padding(.horizontal, Theme.gutter)
            Text("La laverie de goslo records grandit avec tes carrières. Chaque carrière finie rapporte des disques d'or ; chaque salle donne un coup de pouce aux suivantes.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 14) {
                    building(hq)
                    if let picked {
                        detail(picked, hq: hq)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Text("Touche une salle pour la construire ou l'améliorer.")
                            .font(.mono(11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    /// The building: a neon sign, two rooms per floor, the shopfront at the bottom.
    private func building(_ hq: Headquarters) -> some View {
        VStack(spacing: 0) {
            Text("LAVERIE")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.white)
                .shadow(color: Color(red: 1, green: 0.3, blue: 0.6).opacity(glow ? 0.9 : 0.4), radius: glow ? 10 : 4)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.12, green: 0.1, blue: 0.14))
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(HQRoom.allCases) { item in roomTile(item, level: hq.level(item)) }
            }
            .padding(6)
            .background(Color(red: 0.32, green: 0.26, blue: 0.24))
            // The shopfront: washing machines.
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { _ in
                    ZStack {
                        Rectangle().fill(Color(white: 0.85)).frame(width: 34, height: 34)
                        Circle().fill(Color(red: 0.35, green: 0.6, blue: 0.95)).frame(width: 22, height: 22)
                        Circle().stroke(Color(white: 0.4), lineWidth: 2).frame(width: 24, height: 24)
                    }
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.15, green: 0.15, blue: 0.18))
        }
        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
    }

    private func roomTile(_ room: HQRoom, level: Int) -> some View {
        let built = level > 0
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { picked = room }
        } label: {
            VStack(spacing: 4) {
                Text(room.emoji)
                    .font(.system(size: 30))
                    .opacity(built ? 1 : 0.35)
                Text(room.name.uppercased())
                    .font(.mono(9, weight: .bold))
                    .foregroundStyle(built ? Color.black : Color.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 2) {
                    ForEach(0..<room.maxLevel, id: \.self) { index in
                        Text(index < level ? "★" : "☆")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(built ? Color.black : Color.white.opacity(0.4))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(built ? hqGold.opacity(glow ? 0.95 : 0.8) : Color(red: 0.08, green: 0.08, blue: 0.1))
            .overlay(Rectangle().stroke(picked == room ? Color.white : Color.black.opacity(0.6), lineWidth: picked == room ? 3 : 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
    }

    private func detail(_ room: HQRoom, hq: Headquarters) -> some View {
        let level = hq.level(room)
        let refusal = HQ.refusal(room, in: hq)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(room.emoji)  \(room.name.uppercased())").font(.mono(14, weight: .heavy))
                Spacer()
                Text("NIV. \(level)/\(room.maxLevel)").font(.mono(11, weight: .bold)).foregroundStyle(hqGold)
            }
            if level > 0 {
                Text("Maintenant : \(room.perk(at: level))").font(.system(size: 13)).foregroundStyle(Theme.text)
            }
            if level < room.maxLevel {
                Text("Niveau \(level + 1) : \(room.perk(at: level + 1))").font(.system(size: 13)).foregroundStyle(Theme.muted)
                Button(level == 0 ? "Construire · 💿 \(room.cost(toReach: 1))" : "Améliorer · 💿 \(room.cost(toReach: level + 1))") {
                    model.upgrade(room)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(refusal != nil)
                .opacity(refusal == nil ? 1 : 0.45)
                if let refusal {
                    Text(refusal).font(.mono(10, weight: .bold)).foregroundStyle(Theme.accent)
                }
            } else {
                Text("Au maximum.").font(.mono(11, weight: .bold)).foregroundStyle(hqGold)
            }
        }
        .padding(14)
        .overlay(Rectangle().stroke(hqGold.opacity(0.6), lineWidth: 1))
    }
}
