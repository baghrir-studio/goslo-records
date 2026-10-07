import AVFoundation
import SwiftUI

/// « Ton son tourne » : the player's own song from a Punchliner. Their instrumental plays,
/// their verse scrolls karaoke-style, and the phone's voice raps it, one line per bar.
struct TrackView: View {
    let track: PlayerTrack
    let look: CharacterLook
    let artist: String
    @Environment(\.dismiss) private var dismiss

    @State private var voice = TrackVoice()
    @State private var current = -1
    @State private var bounce = false
    @State private var playing = false
    @State private var run = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TON SON TOURNE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            HStack(alignment: .bottom, spacing: 14) {
                PixelImage(HeroSprite.image(look, facing: .down, frame: bounce ? 1 : 2), width: 70)
                    .offset(y: bounce ? -3 : 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title.uppercased())
                        .font(.display(30))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text("\(artist) · \(Int(track.song.bpm)) BPM")
                        .font(.mono(12, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(track.lines.enumerated()), id: \.offset) { index, line in
                            lyric(line, index: index)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: current) { _, line in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(max(line, 0), anchor: .center) }
                }
            }
            HStack(spacing: 10) {
                Button(playing ? "En cours…" : "Rejouer") { run += 1 }
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                    .disabled(playing)
                ShareLink(item: shareText) {
                    Text("Partager")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background.ignoresSafeArea())
        .task(id: run) { await play() }
        .onDisappear {
            voice.stop()
            SoundEngine.shared.stopSong()
            SoundEngine.shared.restoreMusic()
        }
    }

    private func lyric(_ line: String, index: Int) -> some View {
        let isCurrent = index == current
        let words = line.split(separator: " ").map(String.init)
        let spoken = isCurrent ? voice.spokenWords : (index < current ? words.count : 0)
        return words.enumerated().reduce(Text("")) { text, item in
            let (position, word) = item
            let color = position < spoken ? (isCurrent ? Theme.accent : Theme.text) : Theme.text.opacity(isCurrent ? 0.85 : 0.35)
            return text + Text(position == 0 ? word : " " + word).foregroundStyle(color)
        }
        .font(.system(size: isCurrent ? 21 : 17, weight: .heavy))
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeOut(duration: 0.2), value: current)
    }

    private var shareText: String {
        "« \(track.title) » — \(artist), sur goslo records.\n\n" + track.lines.joined(separator: "\n")
    }

    private func play() async {
        playing = true
        current = -1
        defer { playing = false }
        let track = self.track
        let samples = await Task.detached(priority: .userInitiated) {
            ConcertMix.render(track.song, seed: track.seed, style: track.style)
        }.value
        guard !Task.isCancelled else { return }
        SoundEngine.shared.silenceMusic()
        let start = SoundEngine.shared.playSong(samples)
        Task {
            // The rapper nods on the beat.
            while !Task.isCancelled && Date() < start.addingTimeInterval(track.song.duration) {
                bounce.toggle()
                try? await Task.sleep(for: .seconds(track.song.beat))
            }
        }
        for index in track.lines.indices {
            let wait = start.addingTimeInterval(track.lineStart(index)).timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            current = index
            voice.say(track.lines[index], within: track.barSeconds)
        }
        let end = start.addingTimeInterval(track.song.duration).timeIntervalSinceNow
        if end > 0 { try? await Task.sleep(for: .seconds(end)) }
        current = track.lines.count
    }
}

/// The phone's voice, rapping one line at a time and reporting how far it got.
@Observable
final class TrackVoice: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    /// Words of the current line already spoken (for the karaoke).
    private(set) var spokenWords = 0
    @ObservationIgnored private var line = ""

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Says `text`, fast enough to fit in about `seconds`.
    func say(_ text: String, within seconds: Double) {
        synthesizer.stopSpeaking(at: .immediate)
        line = text
        spokenWords = 0
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        // About 14 characters a second at 0.5; speed up for long lines, never past 0.62.
        let needed = Double(text.count) / max(seconds * 0.9, 0.5)
        utterance.rate = Float(min(0.62, max(0.48, 0.5 * needed / 14)))
        utterance.pitchMultiplier = 0.85
        utterance.volume = 1
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        let spoken = (utterance.speechString as NSString).substring(to: min(characterRange.location + characterRange.length,
                                                                            utterance.speechString.utf16.count))
        let count = spoken.split(separator: " ").count
        DispatchQueue.main.async { self.spokenWords = count }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let count = utterance.speechString.split(separator: " ").count
        DispatchQueue.main.async { self.spokenWords = count }
    }
}
