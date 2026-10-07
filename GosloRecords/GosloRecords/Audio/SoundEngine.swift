import AVFoundation

/// Plays the music loops (with a crossfade) and the sound effects.
/// Sounds are synthesized once, in the background, at launch.
/// Uses the "ambient" audio session: respects the silent switch and doesn't cut other apps.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    private static let musicKey = "sound.music"
    private static let effectsKey = "sound.effects"
    static let musicVolume: Float = 0.32

    private(set) var musicEnabled: Bool
    private(set) var effectsEnabled: Bool

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!
    private let musicPlayers = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private let tickPlayer = AVAudioPlayerNode()
    /// A concert song, played whole (see `playSong`).
    private let songPlayer = AVAudioPlayerNode()
    private let effectPlayers = (0..<6).map { _ in AVAudioPlayerNode() }
    private var activeMusic = 0
    private var nextEffect = 0
    private var tracks: [SoundTrack: AVAudioPCMBuffer] = [:]
    private var effects: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var wantedTrack: SoundTrack?
    private var playingTrack: SoundTrack?
    private var fadeTask: Task<Void, Never>?
    private var started = false

    private init() {
        let defaults = UserDefaults.standard
        musicEnabled = defaults.object(forKey: SoundEngine.musicKey) as? Bool ?? true
        effectsEnabled = defaults.object(forKey: SoundEngine.effectsKey) as? Bool ?? true
    }

    // MARK: Setup

    func start() {
        guard !started else { return }
        started = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        for player in musicPlayers + effectPlayers + [tickPlayer, songPlayer] {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        startEngine()

        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                               queue: .main) { _ in
            Task { @MainActor in SoundEngine.shared.resume() }
        }

        // Effects first (short), then the loops.
        Task.detached(priority: .userInitiated) {
            let rendered = SoundEffect.allCases.map { ($0, $0.render()) }
            await SoundEngine.shared.installEffects(rendered)
            for track in SoundTrack.allCases {
                let samples = track.render()
                await SoundEngine.shared.installTrack(track, samples)
            }
        }
    }

    /// Restarts the engine after an interruption or a return to the foreground.
    func resume() {
        guard started, !engine.isRunning else { return }
        startEngine()
        playingTrack = nil
        setMusic(wantedTrack)
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    private func installEffects(_ rendered: [(SoundEffect, [Float])]) {
        for (effect, samples) in rendered { effects[effect] = buffer(samples) }
    }

    private func installTrack(_ track: SoundTrack, _ samples: [Float]) {
        tracks[track] = buffer(samples)
        if wantedTrack == track && playingTrack != track { setMusic(track) }
    }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        return buffer
    }

    // MARK: Music

    /// Switches loop with a crossfade. nil = silence.
    func setMusic(_ track: SoundTrack?) {
        wantedTrack = track
        guard started, musicEnabled else { return }
        guard track != playingTrack else { return }
        guard let track else {
            fade(from: musicPlayers[activeMusic], to: nil)
            playingTrack = nil
            return
        }
        guard let buffer = tracks[track] else { return } // Will start once rendered.
        startEngine()
        let old = musicPlayers[activeMusic]
        activeMusic = 1 - activeMusic
        let new = musicPlayers[activeMusic]
        new.stop()
        new.volume = 0
        new.scheduleBuffer(buffer, at: nil, options: .loops)
        new.play()
        playingTrack = track
        fade(from: old, to: new)
    }

    private func fade(from old: AVAudioPlayerNode, to new: AVAudioPlayerNode?) {
        fadeTask?.cancel()
        fadeTask = Task {
            let steps = 20
            for i in 1...steps {
                try? await Task.sleep(for: .milliseconds(35))
                let k = Float(i) / Float(steps)
                if Task.isCancelled {
                    old.stop()
                    new?.volume = SoundEngine.musicVolume
                    return
                }
                new?.volume = SoundEngine.musicVolume * k
                old.volume = SoundEngine.musicVolume * (1 - k)
            }
            old.stop()
        }
    }

    // MARK: Effects

    func play(_ effect: SoundEffect) {
        guard started, effectsEnabled, let buffer = effects[effect] else { return }
        startEngine()
        let player: AVAudioPlayerNode
        if effect.isTick {
            player = tickPlayer
        } else {
            player = effectPlayers[nextEffect]
            nextEffect = (nextEffect + 1) % effectPlayers.count
        }
        player.volume = effect.volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    // MARK: Concert songs

    /// Plays a rendered concert song, starting a hair from now at a precise audio time.
    /// Returns that moment: the notes on screen run on the same clock.
    func playSong(_ samples: [Float]) -> Date {
        let lead = 0.15
        guard started, musicEnabled || effectsEnabled, let buffer = buffer(samples) else {
            return Date().addingTimeInterval(lead)
        }
        startEngine()
        songPlayer.stop()
        songPlayer.volume = 0.95
        songPlayer.scheduleBuffer(buffer, at: nil, options: [])
        songPlayer.play(at: AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: lead)))
        return Date().addingTimeInterval(lead)
    }

    func stopSong() {
        songPlayer.stop()
    }

    // MARK: Settings

    func setMusicEnabled(_ enabled: Bool) {
        musicEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: SoundEngine.musicKey)
        if enabled {
            playingTrack = nil
            setMusic(wantedTrack)
        } else {
            fadeTask?.cancel()
            musicPlayers.forEach { $0.stop() }
            playingTrack = nil
        }
    }

    func setEffectsEnabled(_ enabled: Bool) {
        effectsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: SoundEngine.effectsKey)
    }
}
