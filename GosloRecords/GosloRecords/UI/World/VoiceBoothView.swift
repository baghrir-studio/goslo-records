import SwiftUI
import UIKit

/// « La cabine » : the player raps their own verse over their instrumental. The lines show up karaoke-style,
/// one per bar, while the microphone records; then « Écouter » plays the beat and the voice together.
struct VoiceBoothView: View {
    let track: PlayerTrack
    let look: CharacterLook
    let artist: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var booth: VoiceBooth

    init(track: PlayerTrack, look: CharacterLook, artist: String) {
        self.track = track
        self.look = look
        self.artist = artist
        _booth = State(initialValue: VoiceBooth(track: track))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(booth.phase == .recording ? "● REC" : "LA CABINE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button("Fermer") {
                    booth.stop()
                    dismiss()
                }
                .font(.mono(13, weight: .bold))
                .foregroundStyle(Theme.muted)
            }
            HStack(alignment: .bottom, spacing: 14) {
                PixelImage(HeroSprite.image(look, facing: .down, frame: booth.phase == .recording ? 1 : 0), width: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title.uppercased())
                        .font(.display(26))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text("\(artist) · \(Int(track.song.bpm)) BPM")
                        .font(.mono(12, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
            }
            Text(hint)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                karaoke(current: currentLine(at: context.date), date: context.date)
            }

            controls
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background.ignoresSafeArea())
        .onChange(of: scenePhase) { _, phase in
            // Not on .inactive: the microphone permission alert makes the scene inactive.
            if phase == .background { booth.stop() } else if phase == .active { booth.refreshPermission() }
        }
        .onDisappear { booth.stop() }
    }

    private var hint: String {
        switch booth.phase {
        case .denied:
            "Pas d'accès au micro. Autorise-le dans Réglages › goslo radio › Micro. En attendant, « Écouter ton son » marche toujours avec la voix du téléphone."
        case .failed(let message):
            message
        case .recording:
            "Rappe chaque ligne quand elle s'allume. DJ Noize a les yeux fermés, il écoute."
        case .playing:
            "Ta voix, ton beat. Pas de retouche."
        case .preparing:
            "DJ Noize branche le micro…"
        case .idle:
            booth.hasTake
                ? "Ta prise est gardée sur ton téléphone. Écoute-la, ou refais-la."
                : "Mets des écouteurs : le beat reste dans tes oreilles, ta voix seule sur la prise. Deux mesures d'intro, puis une ligne par mesure."
        }
    }

    /// The line being rapped (-1 before the first one, `lines.count` after the last).
    private func currentLine(at date: Date) -> Int {
        guard let start = booth.startedAt, booth.phase == .recording || booth.phase == .playing else { return -1 }
        let elapsed = date.timeIntervalSince(start)
        return track.lines.indices.last { elapsed >= track.lineStart($0) } ?? -1
    }

    private func karaoke(current: Int, date: Date) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if current < 0, let start = booth.startedAt {
                        let left = start.addingTimeInterval(track.lineStart(0)).timeIntervalSince(date)
                        Text(left > 0 ? "Intro… \(Int(left.rounded(.up)))" : " ")
                            .font(.mono(14, weight: .heavy))
                            .foregroundStyle(Theme.accent)
                    }
                    ForEach(Array(track.lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: index == current ? 22 : 17, weight: .heavy))
                            .foregroundStyle(index == current ? Theme.accent
                                             : Theme.text.opacity(index < current ? 0.6 : (current < 0 ? 0.85 : 0.35)))
                            .fixedSize(horizontal: false, vertical: true)
                            .id(index)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: current) { _, line in
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(max(line, 0), anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch booth.phase {
        case .recording, .playing:
            Button(booth.phase == .recording ? "■ Couper la prise" : "■ Stop") { booth.stop() }
                .buttonStyle(PrimaryButtonStyle())
        case .preparing:
            Button("Préparation…") {}
                .buttonStyle(PrimaryButtonStyle())
                .disabled(true)
                .opacity(0.6)
        case .denied:
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PrimaryButtonStyle())
        case .idle, .failed:
            if booth.hasTake {
                HStack(spacing: 10) {
                    Button("Refaire") { Task { await booth.record() } }
                        .font(.mono(14, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                    Button("▶ Écouter") { booth.play() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button("● Enregistrer") { Task { await booth.record() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}
