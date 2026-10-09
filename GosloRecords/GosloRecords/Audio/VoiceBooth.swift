import AVFoundation

/// The voice booth: records the player rapping their own verse over their instrumental, then plays both back
/// together. The beat is played from a WAV file by AVAudioPlayer and the voice is recorded by AVAudioRecorder,
/// both started on the same audio clock (`play(atTime:)` / `record(atTime:)`) so they stay in sync.
/// The booth takes the audio session over (`.playAndRecord`) and gives it back to `SoundEngine` when it's done.
@MainActor
@Observable
final class VoiceBooth {
    enum Phase: Equatable {
        case idle
        /// Rendering the beat, asking for the microphone.
        case preparing
        case recording
        case playing
        /// No microphone access.
        case denied
        case failed(String)
    }

    let track: PlayerTrack
    private(set) var phase: Phase = .idle
    /// When the beat started (count-in included), for the karaoke. nil when nothing plays.
    private(set) var startedAt: Date?
    /// A take exists for this track.
    private(set) var hasTake: Bool

    @ObservationIgnored private var beatURL: URL?
    @ObservationIgnored private var beatPlayer: AVAudioPlayer?
    @ObservationIgnored private var voicePlayer: AVAudioPlayer?
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var endTask: Task<Void, Never>?
    @ObservationIgnored private var tookOverSession = false

    /// Lead time before the beat starts, so both players start together.
    private static let lead: TimeInterval = 0.35
    /// The voice is a hair late on the recording (the sound goes out, then comes back in the microphone).
    private static let latencyKey = "booth.latency"

    init(track: PlayerTrack) {
        self.track = track
        hasTake = FileManager.default.fileExists(atPath: VoiceBooth.takeURL(for: track).path)
    }

    /// Documents/Voix/voix-<titre>.m4a — one per track title, overwritten by a new take.
    static func takeURL(for track: PlayerTrack) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Voix", isDirectory: true).appendingPathComponent(track.voiceFileName)
    }

    var isBusy: Bool { phase == .preparing || phase == .recording || phase == .playing }

    // MARK: Microphone

    private func microphoneAllowed() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        case .undetermined: return await AVAudioApplication.requestRecordPermission()
        @unknown default: return false
        }
    }

    /// Back from the Settings app with the microphone allowed: the booth opens again.
    func refreshPermission() {
        if phase == .denied, AVAudioApplication.shared.recordPermission == .granted { phase = .idle }
    }

    // MARK: Recording

    func record() async {
        guard !isBusy else { return }
        phase = .preparing
        guard await microphoneAllowed() else {
            phase = .denied
            return
        }
        do {
            let beat = try await prepareBeat()
            takeOverSession()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)

            let url = VoiceBooth.takeURL(for: track)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: url)
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ])
            let player = try AVAudioPlayer(contentsOf: beat)
            player.volume = 0.9
            guard recorder.prepareToRecord(), player.prepareToPlay() else { throw BoothError.audio }

            let latency = session.inputLatency + session.outputLatency
            UserDefaults.standard.set(latency, forKey: VoiceBooth.latencyKey)
            let when = player.deviceCurrentTime + VoiceBooth.lead
            let recordWhen = recorder.deviceCurrentTime + VoiceBooth.lead
            guard player.play(atTime: when), recorder.record(atTime: recordWhen) else { throw BoothError.audio }
            self.recorder = recorder
            beatPlayer = player
            startedAt = Date().addingTimeInterval(VoiceBooth.lead)
            phase = .recording
            finish(after: VoiceBooth.lead + track.song.duration)
        } catch {
            stop()
            phase = .failed("Le studio a coupé. Réessaie dans un instant.")
        }
    }

    // MARK: Listening

    /// Plays the beat and the recorded voice together.
    func play() {
        guard !isBusy, hasTake else { return }
        do {
            let beat = beatURL ?? VoiceBooth.beatFile(for: track)
            guard FileManager.default.fileExists(atPath: beat.path) else {
                Task { await renderThenPlay() }
                return
            }
            takeOverSession()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            let beatPlayer = try AVAudioPlayer(contentsOf: beat)
            let voicePlayer = try AVAudioPlayer(contentsOf: VoiceBooth.takeURL(for: track))
            beatPlayer.volume = 0.75
            voicePlayer.volume = 1
            guard beatPlayer.prepareToPlay(), voicePlayer.prepareToPlay() else { throw BoothError.audio }
            voicePlayer.currentTime = VoiceBooth.voiceOffset
            let when = beatPlayer.deviceCurrentTime + VoiceBooth.lead
            beatPlayer.play(atTime: when)
            voicePlayer.play(atTime: when)
            self.beatPlayer = beatPlayer
            self.voicePlayer = voicePlayer
            startedAt = Date().addingTimeInterval(VoiceBooth.lead)
            phase = .playing
            finish(after: VoiceBooth.lead + max(track.song.duration, voicePlayer.duration - voicePlayer.currentTime))
        } catch {
            stop()
            phase = .failed("Impossible de lire ta prise.")
        }
    }

    /// Seconds to skip at the start of the take: the round trip the sound made through the speaker and the
    /// microphone. Used by the playback and by the shared mix, so both sound the same.
    static var voiceOffset: TimeInterval {
        min(max(0, UserDefaults.standard.double(forKey: latencyKey)), 0.5)
    }

    // MARK: Sharing

    /// « Partager mon freestyle » : the beat and the take mixed into one file in the temporary directory.
    /// With a picture, a short vertical video (.mp4) of it over the mix; without one, or if the video fails,
    /// the sound alone (.m4a).
    func renderFreestyle(cover: CGImage?) async throws -> URL {
        guard hasTake, !isBusy else { throw BoothError.audio }
        let beat = try await prepareBeat()
        let directory = FileManager.default.temporaryDirectory
        // voix-<titre>.m4a → freestyle-<titre>: the name the file keeps once shared.
        let name = "freestyle-" + String(track.voiceFileName.dropFirst("voix-".count).dropLast(".m4a".count))
        let audio = directory.appendingPathComponent(name + ".m4a")
        try await FreestyleExport.mixAudio(beat: beat, voice: VoiceBooth.takeURL(for: track),
                                           voiceOffset: VoiceBooth.voiceOffset, to: audio)
        guard let cover else { return audio }
        let video = directory.appendingPathComponent(name + ".mp4")
        do {
            try await FreestyleExport.video(image: cover, audio: audio, to: video)
            return video
        } catch {
            return audio
        }
    }

    private func renderThenPlay() async {
        phase = .preparing
        do {
            _ = try await prepareBeat()
            phase = .idle
            play()
        } catch {
            phase = .failed("Impossible de préparer le beat.")
        }
    }

    // MARK: Stop

    /// Stops whatever plays or records, keeps the take, and gives the sound back to the game.
    func stop() {
        endTask?.cancel()
        endTask = nil
        recorder?.stop()
        recorder = nil
        beatPlayer?.stop()
        beatPlayer = nil
        voicePlayer?.stop()
        voicePlayer = nil
        startedAt = nil
        hasTake = FileManager.default.fileExists(atPath: VoiceBooth.takeURL(for: track).path)
        if phase != .denied { phase = .idle }
        giveSessionBack()
    }

    /// Ends the take (or the playback) when the song is over.
    private func finish(after seconds: TimeInterval) {
        endTask?.cancel()
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds + 0.3))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    // MARK: Session

    private func takeOverSession() {
        guard !tookOverSession else { return }
        tookOverSession = true
        SoundEngine.shared.suspendForBooth()
    }

    private func giveSessionBack() {
        guard tookOverSession else { return }
        tookOverSession = false
        SoundEngine.shared.resumeAfterBooth()
    }

    // MARK: Beat

    private enum BoothError: Error { case audio }

    private static func beatFile(for track: PlayerTrack) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("beat-\(track.seed)-\(Int(track.song.bpm))-\(track.lines.count).wav")
    }

    /// The instrumental, rendered once and written as a WAV file.
    private func prepareBeat() async throws -> URL {
        let url = VoiceBooth.beatFile(for: track)
        if FileManager.default.fileExists(atPath: url.path) {
            beatURL = url
            return url
        }
        let track = self.track
        let data = await Task.detached(priority: .userInitiated) {
            PlayerTrack.wav(ConcertMix.render(track.song, seed: track.seed, style: track.style), sampleRate: Synth.sampleRate)
        }.value
        try data.write(to: url, options: .atomic)
        beatURL = url
        return url
    }
}
