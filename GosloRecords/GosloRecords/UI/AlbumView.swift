import SwiftUI

/// The notebook's album page: record one (tracklist, cover, title), then watch it sell semester after semester.
struct AlbumSection: View {
    @Environment(AppModel.self) private var model
    let state: GameState

    @State private var title = ""
    @State private var picked: [String] = []
    @State private var cover: AlbumCover = .portrait
    @State private var justReleased: Album?

    var body: some View {
        let engine = model.engine
        VStack(alignment: .leading, spacing: 18) {
            if let album = justReleased {
                releaseCard(album)
            }
            if engine.canRecordAlbum(in: state) {
                studio(candidates: engine.albumCandidates(in: state))
            } else if state.chapter < AlbumRules.fromChapter {
                Text("Ton premier album se prépare après ta première vraie scène (chapitre \(AlbumRules.fromChapter)). Pour l'instant, remplis ton carnet.")
                    .font(.system(size: 15)).foregroundStyle(Theme.muted)
            } else if let last = state.albums.last {
                let wait = max(1, AlbumRules.cooldown - (state.turn - last.releasedTurn))
                Text("Prochain album possible dans \(wait) semestre\(wait > 1 ? "s" : ""). Le public digère encore « \(last.title) ».")
                    .font(.system(size: 15)).foregroundStyle(Theme.muted)
            }
            ForEach(state.albums.reversed()) { album in
                AlbumCard(album: album, look: state.rapper.look, artist: state.rapper.name)
            }
        }
    }

    // MARK: Recording

    private func studio(candidates: [AlbumTrack]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Kicker(text: "Enregistrer un album")
            TextField("", text: $title, prompt: Text("Titre de l'album").foregroundStyle(Theme.faint))
                .font(.display(28))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onChange(of: title) { _, value in
                    if value.count > AlbumRules.maxTitleLength { title = String(value.prefix(AlbumRules.maxTitleLength)) }
                }
            Rectangle().fill(Theme.line).frame(height: 1)

            HStack {
                Text("TRACKLIST").font(.mono(11, weight: .bold)).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(picked.count) / \(AlbumRules.maxTracks) · min \(AlbumRules.minTracks)")
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(picked.count >= AlbumRules.minTracks ? Theme.accent : Theme.muted)
            }
            ForEach(candidates) { track in
                let index = picked.firstIndex(of: track.id)
                Button {
                    toggle(track.id)
                } label: {
                    HStack(spacing: 10) {
                        Text(index.map { String(format: "%02d", $0 + 1) } ?? "··")
                            .font(.mono(13, weight: .bold))
                            .foregroundStyle(index == nil ? Theme.faint : Theme.accent)
                            .frame(width: 24)
                        Text(track.title)
                            .font(.system(size: 15, weight: index == nil ? .regular : .semibold))
                            .foregroundStyle(index == nil ? Theme.muted : Theme.text)
                            .lineLimit(1)
                        Spacer()
                        Text(String(repeating: "★", count: max(1, track.quality / 2)))
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(index == nil ? Color.clear : Theme.accent.opacity(0.1))
                    .overlay(Rectangle().stroke(index == nil ? Theme.line : Theme.accent, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text("POCHETTE").font(.mono(11, weight: .bold)).foregroundStyle(Theme.muted).padding(.top, 6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AlbumCover.allCases) { option in
                        Button { cover = option } label: {
                            VStack(spacing: 4) {
                                AlbumCoverArt(cover: option, look: state.rapper.look, title: title.isEmpty ? "Sans Titre" : title,
                                              artist: state.rapper.name, size: 96)
                                    .overlay(Rectangle().stroke(cover == option ? Theme.accent : Color.clear, lineWidth: 3))
                                Text(option.label).font(.mono(10, weight: .bold))
                                    .foregroundStyle(cover == option ? Theme.accent : Theme.muted)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Sortir l'album") {
                if let album = model.releaseAlbum(title: title, trackIds: picked, cover: cover) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { justReleased = album }
                    title = ""
                    picked = []
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!(AlbumRules.minTracks...AlbumRules.maxTracks).contains(picked.count))
            .opacity((AlbumRules.minTracks...AlbumRules.maxTracks).contains(picked.count) ? 1 : 0.4)
        }
    }

    private func toggle(_ id: String) {
        if let index = picked.firstIndex(of: id) {
            picked.remove(at: index)
        } else if picked.count < AlbumRules.maxTracks {
            picked.append(id)
        }
    }

    private func releaseCard(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("C'EST DANS LES BACS").font(.display(28)).foregroundStyle(Theme.accent)
            Text("« \(album.title) » : \(album.sales.first?.formatted() ?? "0") exemplaires le premier semestre.")
                .font(.system(size: 15, weight: .semibold))
            Text(album.quality >= 7 ? "La critique adore. Le Bloc tourne ton album en boucle."
                 : album.quality < 5 ? "La critique est dure. Ta mère l'écoute quand même." : "Un bon album. Le public suit.")
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Theme.accent, lineWidth: 1.5))
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

/// A released album: cover, certification, sales per semester, tracklist.
private struct AlbumCard: View {
    let album: Album
    let look: CharacterLook
    let artist: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                AlbumCoverArt(cover: album.cover, look: look, title: album.title, artist: artist, size: 110)
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title).font(.display(24)).lineLimit(2)
                    if let certification = album.certification {
                        Text("◉ DISQUE \(certification.uppercased())")
                            .font(.mono(11, weight: .bold))
                            .foregroundStyle(certification == "Or" ? Color(red: 1, green: 0.8, blue: 0.3)
                                             : certification == "Platine" ? Color(white: 0.85) : Color(red: 0.6, green: 0.9, blue: 1))
                    }
                    Text("\(album.totalSales.formatted()) ventes")
                        .font(.mono(13, weight: .semibold))
                    Text(album.isSelling ? "En rayon" : "Plus en rayon")
                        .font(.mono(10, weight: .medium)).foregroundStyle(Theme.muted)
                }
            }
            // Sales per semester.
            let peak = max(1, album.sales.max() ?? 1)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(album.sales.enumerated()), id: \.offset) { index, sold in
                    VStack(spacing: 3) {
                        Rectangle()
                            .fill(index == 0 ? Theme.accent : Theme.accent.opacity(0.55))
                            .frame(width: 26, height: max(3, 60 * CGFloat(sold) / CGFloat(peak)))
                        Text("S\(index + 1)").font(.mono(9, weight: .medium)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .frame(height: 76, alignment: .bottom)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(album.tracks.enumerated()), id: \.offset) { index, track in
                    Text("\(String(format: "%02d", index + 1))  \(track.title)")
                        .font(.mono(12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

/// The album cover, drawn from the style picked, with the rapper's face.
struct AlbumCoverArt: View {
    let cover: AlbumCover
    let look: CharacterLook
    let title: String
    let artist: String
    let size: CGFloat

    var body: some View {
        ZStack {
            background
            face
            VStack(spacing: 1) {
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: size * 0.11, weight: .black))
                    .foregroundStyle(cover == .gold ? Color.black : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(artist.uppercased())
                    .font(.system(size: size * 0.07, weight: .bold, design: .monospaced))
                    .foregroundStyle(cover == .gold ? Color.black.opacity(0.7) : .white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(size * 0.06)
        }
        .frame(width: size, height: size)
        .clipped()
    }

    @ViewBuilder
    private var background: some View {
        switch cover {
        case .portrait:
            LinearGradient(colors: [Color(red: 0.25, green: 0.22, blue: 0.3), .black], startPoint: .top, endPoint: .bottom)
        case .neon:
            ZStack {
                Color.black
                Rectangle().stroke(Color(red: 1, green: 0.3, blue: 0.7), lineWidth: size * 0.03).padding(size * 0.08)
                Rectangle().stroke(Color.cyan, lineWidth: size * 0.015).padding(size * 0.14)
            }
        case .street:
            ZStack {
                Color(white: 0.42)
                ForEach(0..<6, id: \.self) { index in
                    Rectangle().fill(Color(white: index % 2 == 0 ? 0.36 : 0.48)).frame(height: size / 6)
                        .offset(y: CGFloat(index) * size / 6 - size / 2 + size / 12)
                }
                Text("GOSLO").font(.system(size: size * 0.2, weight: .black)).foregroundStyle(Theme.accent.opacity(0.8))
                    .rotationEffect(.degrees(-14)).offset(y: -size * 0.28)
            }
        case .gold:
            LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.45), Color(red: 0.75, green: 0.55, blue: 0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    @ViewBuilder
    private var face: some View {
        let bust = PixelImage(HeroSprite.bust(look), width: size * (cover == .portrait ? 0.78 : 0.55))
        switch cover {
        case .portrait: bust.offset(y: size * 0.02)
        case .neon: bust.shadow(color: Color(red: 1, green: 0.3, blue: 0.7), radius: size * 0.06).offset(y: -size * 0.04)
        case .street: bust.offset(y: -size * 0.02)
        case .gold: bust.colorMultiply(.black).offset(y: -size * 0.04)
        }
    }
}
