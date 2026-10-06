import Foundation

/// The game's music loops, composed in code. Each one loops seamlessly.
enum SoundTrack: String, CaseIterable {
    /// Menus: slow, dusty lo-fi.
    case menu
    /// The neighbourhood: 8-bit boom bap.
    case street
    /// Wild clashes: trap with hi-hat rolls.
    case battle
    /// Rival clashes: drill with sliding 808s.
    case drill

    var groove: Sequencer {
        switch self {
        case .menu: Sequencer(bpm: 80, bars: 4, swing: 0.18)
        case .street: Sequencer(bpm: 90, bars: 4, swing: 0.12)
        case .battle: Sequencer(bpm: 140, bars: 4, swing: 0)
        case .drill: Sequencer(bpm: 142, bars: 4, swing: 0)
        }
    }

    func render() -> [Float] {
        var seq = groove
        switch self {
        case .menu: Self.lofi(&seq)
        case .street: Self.boomBap(&seq)
        case .battle: Self.trap(&seq)
        case .drill: Self.drillBeat(&seq)
        }
        Synth.normalize(&seq.buffer, peak: 0.8)
        return seq.buffer
    }

    // MARK: Compositions

    /// A minor: Am7, Dm7, Fmaj7, E7.
    private static let minorChords = [[57, 60, 64, 67], [50, 53, 57, 60], [53, 57, 60, 64], [52, 56, 59, 62]]

    private static func lofi(_ seq: inout Sequencer) {
        let kick = Synth.kick(punch: 0.7), snare = Synth.snare(), hat = Synth.hat()
        for bar in 0..<seq.bars {
            let base = Double(bar * 16), chord = minorChords[bar % 4]
            seq.hit(Synth.keys(chord, length: 2.2), step: base, gain: 0.55)
            seq.hit(Synth.keys(chord.map { $0 + 12 }, length: 0.5, decay: 4), step: base + 10, gain: 0.22)
            seq.hit(Synth.bass808(note: chord[0] - 12, length: 0.6), step: base, gain: 0.35)
            for step in [0.0, 7, 10] { seq.hit(kick, step: base + step, gain: 0.6) }
            for step in [4.0, 12] { seq.hit(snare, step: base + step, gain: 0.35) }
            for step in stride(from: 0.0, to: 16, by: 2) { seq.hit(hat, step: base + step, gain: 0.18) }
        }
        Synth.add(Synth.crackle(length: seq.duration, clicks: 24), into: &seq.buffer, at: 0, gain: 1, wrap: true)
        Synth.lowpass(&seq.buffer, cutoff: 3_800)
    }

    private static func boomBap(_ seq: inout Sequencer) {
        let kick = Synth.kick(), snare = Synth.snare(seed: 13), hat = Synth.hat(), openHat = Synth.hat(open: true)
        // A minor pentatonic chiptune hook (step, MIDI note) per bar.
        let hook: [[(Double, Int)]] = [
            [(0, 76), (3, 74), (6, 72), (8, 69), (11, 72)],
            [(0, 74), (3, 72), (6, 69), (10, 67), (12, 69)],
            [(0, 72), (2, 74), (4, 76), (8, 79), (11, 76)],
            [(0, 76), (3, 74), (6, 71), (8, 68), (12, 71)],
        ]
        for bar in 0..<seq.bars {
            let base = Double(bar * 16), chord = minorChords[bar % 4]
            seq.hit(Synth.keys(chord, length: 2.0), step: base, gain: 0.42)
            seq.hit(Synth.bass808(note: chord[0] - 12, length: 0.45), step: base, gain: 0.5)
            seq.hit(Synth.bass808(note: chord[0] - 12, length: 0.3), step: base + 10, gain: 0.4)
            for step in [0.0, 7, 9] { seq.hit(kick, step: base + step, gain: 0.85) }
            for step in [4.0, 12] { seq.hit(snare, step: base + step, gain: 0.6) }
            for step in stride(from: 0.0, to: 16, by: 2) { seq.hit(hat, step: base + step, gain: step.truncatingRemainder(dividingBy: 4) == 2 ? 0.3 : 0.18) }
            seq.hit(openHat, step: base + 14, gain: 0.16)
            for (step, note) in hook[bar % 4] {
                seq.hit(Synth.pulse(note: note, length: 0.18, duty: 0.25, decay: 9), step: base + step, gain: 0.32)
            }
        }
        Synth.add(Synth.crackle(length: seq.duration, clicks: 10), into: &seq.buffer, at: 0, gain: 0.7, wrap: true)
    }

    private static func trap(_ seq: inout Sequencer) {
        // C minor: Cm, Ab, Fm, G.
        let roots = [36, 32, 29, 31]
        let triads = [[60, 63, 67], [56, 60, 63], [53, 56, 60], [55, 59, 62]]
        let kick = Synth.kick(punch: 1.2), clap = Synth.clap(), hat = Synth.hat(seed: 17), openHat = Synth.hat(open: true)
        for bar in 0..<seq.bars {
            let base = Double(bar * 16), root = roots[bar]
            for step in [0.0, 10] { seq.hit(kick, step: base + step, gain: 0.8) }
            if bar % 2 == 1 { seq.hit(kick, step: base + 13, gain: 0.6) }
            seq.hit(clap, step: base + 8, gain: 0.75)
            seq.hit(Synth.bass808(note: root, length: 0.9), step: base, gain: 0.8)
            seq.hit(Synth.bass808(note: root + 7, length: 0.5, slideFrom: root), step: base + 10, gain: 0.6)
            // Hi-hats: 8ths, then rolls (32nds or triplets) at the end of the bar.
            for step in stride(from: 0.0, to: 12, by: 2) { seq.hit(hat, step: base + step, gain: 0.32) }
            if bar % 2 == 1 {
                for step in stride(from: 12.0, to: 16, by: 0.5) { seq.hit(hat, step: base + step, gain: 0.22 + Float(step - 12) * 0.03) }
            } else {
                for step in stride(from: 12.0, to: 16, by: 4.0 / 3) { seq.hit(hat, step: base + step, gain: 0.3) }
            }
            seq.hit(openHat, step: base + 6, gain: 0.14)
            // Dark arpeggio.
            let triad = triads[bar]
            for (index, step) in stride(from: 0.0, to: 16, by: 2).enumerated() {
                let note = triad[index % 3] + (index >= 6 ? 12 : 0)
                seq.hit(Synth.pulse(note: note, length: 0.16, duty: 0.125, decay: 10), step: base + step, gain: 0.22)
            }
        }
    }

    private static func drillBeat(_ seq: inout Sequencer) {
        // E minor, sliding 808 line.
        let line: [(Double, Int, Double)] = [(0, 40, 0.8), (6, 43, 0.5), (11, 38, 0.6)]
        let kick = Synth.kick(punch: 1.3, length: 0.3), snare = Synth.snare(seed: 29), hat = Synth.hat(seed: 31)
        let melody = [76, 79, 83, 84, 83, 79, 76, 74]
        var previous = 40
        for bar in 0..<seq.bars {
            let base = Double(bar * 16)
            seq.hit(snare, step: base + 8, gain: 0.75)
            if bar % 2 == 1 { seq.hit(snare, step: base + 14, gain: 0.5) }
            for step in [0.0, 11] { seq.hit(kick, step: base + step, gain: 0.7) }
            // Drill hats: syncopated "triplet" feel.
            for (step, gain) in [(0.0, 0.3), (3, 0.22), (6, 0.3), (8, 0.2), (10, 0.26), (13, 0.22), (14, 0.3)] {
                seq.hit(hat, step: base + step, gain: Float(gain))
            }
            for (step, note, length) in line {
                let transposed = note + (bar == 3 ? -2 : 0)
                seq.hit(Synth.bass808(note: transposed, length: length, slideFrom: previous), step: base + step, gain: 0.8)
                previous = transposed
            }
            // Eerie melody, one note per beat.
            for beat in 0..<4 {
                let note = melody[(bar * 4 + beat) % melody.count]
                seq.hit(Synth.pulse(note: note, length: 0.5, duty: 0.5, decay: 2.5), step: base + Double(beat * 4), gain: 0.14)
            }
        }
    }
}

/// Step sequencer: 16 steps per bar, optional swing on off-beats.
struct Sequencer {
    let bpm: Double
    let bars: Int
    let swing: Double
    var buffer: [Float]

    init(bpm: Double, bars: Int, swing: Double) {
        self.bpm = bpm
        self.bars = bars
        self.swing = swing
        buffer = [Float](repeating: 0, count: Synth.count(60 / bpm / 4 * 16 * Double(bars)))
    }

    var stepSeconds: Double { 60 / bpm / 4 }
    var duration: Double { Double(buffer.count) / Synth.sampleRate }

    func offset(of step: Double) -> Int {
        let swung = step.rounded() == step && Int(step) % 2 == 1 ? step + swing : step
        return Int(swung * stepSeconds * Synth.sampleRate)
    }

    /// Places a sound on a step. Tails past the end wrap to the start (seamless loop).
    mutating func hit(_ sound: [Float], step: Double, gain: Float) {
        Synth.add(sound, into: &buffer, at: offset(of: step), gain: gain, wrap: true)
    }
}

/// Sound effects and jingles.
enum SoundEffect: String, CaseIterable {
    case tap, blip, select, step, door, exclaim
    case hit, strongHit, miss
    case levelUp, quest, statUp, statDown
    case wipe, secretRiser, secretHit
    case victory, defeat, semester, radioJingle
    case concertKick, concertSnare, concertHat, concertHit, crowdCheer, crowdGroan

    /// Frequent, quiet sounds: they go to a dedicated player.
    var isTick: Bool { self == .blip || self == .step || self == .tap }

    var volume: Float {
        switch self {
        case .blip: 0.12
        case .step: 0.18
        case .tap: 0.3
        case .concertHat: 0.3
        case .concertHit: 0.45
        case .concertKick, .concertSnare: 0.7
        case .crowdCheer, .crowdGroan: 0.6
        default: 0.75
        }
    }

    func render() -> [Float] {
        var out: [Float]
        switch self {
        case .tap:
            out = Synth.pulse(note: 91, length: 0.025, duty: 0.25, decay: 60)
        case .blip:
            out = Synth.pulse(note: 84, length: 0.03, duty: 0.5, decay: 30)
        case .select:
            out = Synth.layer([(Synth.pulse(note: 76, length: 0.05, decay: 20), 0, 1),
                               (Synth.pulse(note: 83, length: 0.09, decay: 15), 0.05, 1)])
        case .step:
            var noise = Synth.Noise(seed: 41)
            out = (0..<Synth.count(0.05)).map { i in noise.next() * Float(exp(-Double(i) / Synth.sampleRate * 70)) }
            Synth.lowpass(&out, cutoff: 900)
        case .door:
            out = Synth.layer([(Synth.kick(punch: 0.4, length: 0.3), 0, 1),
                               (Synth.pulse(note: 45, length: 0.2, decay: 8, glideTo: 40), 0.02, 0.6)])
            Synth.lowpass(&out, cutoff: 1_600)
        case .exclaim:
            out = Synth.layer([(Synth.pulse(note: 88, length: 0.07, duty: 0.25, decay: 10), 0, 1),
                               (Synth.pulse(note: 93, length: 0.14, duty: 0.25, decay: 8), 0.07, 1)])
        case .hit:
            out = Synth.layer([(Synth.kick(length: 0.25), 0, 1), (Synth.snare(seed: 3), 0, 0.8)])
        case .strongHit:
            out = Synth.layer([(Synth.kick(punch: 1.4), 0, 1), (Synth.clap(), 0, 0.8),
                               (Synth.bass808(note: 33, length: 0.5), 0, 0.7)])
        case .miss:
            out = Synth.pulse(note: 79, length: 0.32, decay: 5, glideTo: 58)
        case .levelUp:
            out = Synth.layer([72, 76, 79, 84].enumerated().map { index, note in
                (Synth.pulse(note: note, length: 0.14, duty: 0.25, decay: 8), Double(index) * 0.07, 1)
            })
        case .quest:
            out = Synth.layer([72, 76, 79, 84, 88].enumerated().map { index, note in
                (Synth.pulse(note: note, length: 0.16, duty: 0.25, decay: 7), Double(index) * 0.08, 0.9)
            } + [(Synth.keys([72, 76, 79, 84], length: 1.1), 0.4, 1.4)])
        case .statUp:
            out = Synth.layer([(Synth.pulse(note: 79, length: 0.06, decay: 15), 0, 1),
                               (Synth.pulse(note: 86, length: 0.1, decay: 12), 0.06, 1)])
        case .statDown:
            out = Synth.layer([(Synth.pulse(note: 74, length: 0.06, decay: 15), 0, 1),
                               (Synth.pulse(note: 67, length: 0.12, decay: 10), 0.06, 1)])
        case .wipe:
            out = Synth.layer([(Synth.scratch(), 0, 1), (Synth.kick(punch: 1.3), 0.34, 1),
                               (Synth.clap(), 0.34, 0.7)])
        case .secretRiser:
            out = Synth.riser(length: 1.7)
        case .secretHit:
            out = Synth.layer([(Synth.kick(punch: 1.5, length: 0.6), 0, 1),
                               (Synth.bass808(note: 28, length: 1.3), 0, 0.9),
                               (Synth.hat(open: true, seed: 51), 0, 1.2),
                               (Synth.clap(seed: 53), 0.01, 0.8)])
        case .victory:
            out = Synth.layer([67, 72, 76, 79].enumerated().map { index, note in
                (Synth.pulse(note: note, length: index == 3 ? 0.5 : 0.13, duty: 0.25, decay: index == 3 ? 3 : 8), Double(index) * 0.12, 1)
            } + [(Synth.keys([60, 64, 67, 72], length: 1.2), 0.36, 1.3),
                 (Synth.bass808(note: 36, length: 0.8), 0.36, 0.7),
                 (Synth.kick(), 0.36, 0.8)])
        case .defeat:
            out = Synth.layer([(Synth.pulse(note: 72, length: 0.35, decay: 4, glideTo: 66), 0, 1),
                               (Synth.pulse(note: 67, length: 0.6, decay: 3, glideTo: 55), 0.32, 1),
                               (Synth.bass808(note: 29, length: 0.9), 0.32, 0.6)])
        case .semester:
            out = Synth.layer([(Synth.keys([60, 64, 67, 71], length: 1.3), 0, 1.3),
                               (Synth.pulse(note: 84, length: 0.6, duty: 0.125, decay: 4), 0.05, 0.5)])
        case .concertKick:
            out = Synth.layer([(Synth.kick(punch: 1.1, length: 0.3), 0, 1), (Synth.bass808(note: 33, length: 0.25), 0, 0.5)])
        case .concertSnare:
            out = Synth.layer([(Synth.snare(seed: 61), 0, 1), (Synth.clap(seed: 63), 0.005, 0.6)])
        case .concertHat:
            out = Synth.hat(seed: 67)
        case .concertHit:
            out = Synth.pulse(note: 88, length: 0.06, duty: 0.25, decay: 25)
        case .crowdCheer:
            var noise = Synth.Noise(seed: 71)
            let n = Synth.count(1.1)
            out = (0..<n).map { i in
                let t = Double(i) / Double(n)
                let swell = sin(t * .pi) * (0.7 + 0.3 * sin(Double(i) / Synth.sampleRate * 2 * .pi * 7))
                return noise.next() * Float(swell)
            }
            Synth.lowpass(&out, cutoff: 2_400)
        case .crowdGroan:
            var noise = Synth.Noise(seed: 73)
            let n = Synth.count(0.8)
            out = (0..<n).map { i in noise.next() * Float(sin(Double(i) / Double(n) * .pi)) }
            Synth.lowpass(&out, cutoff: 700)
            out = Synth.layer([(out, 0, 1), (Synth.pulse(note: 50, length: 0.7, decay: 3, glideTo: 43), 0, 0.5)])
        case .radioJingle:
            // "go-slo-ra-di-o": scratch, five notes, then the drop.
            out = Synth.layer([(Synth.scratch(length: 0.3), 0, 0.9)]
                + [79, 76, 72, 76, 84].enumerated().map { index, note in
                    (Synth.pulse(note: note, length: 0.12, duty: 0.25, decay: 6), 0.32 + Double(index) * 0.13, 1)
                }
                + [(Synth.kick(), 0.32, 0.9), (Synth.snare(), 0.58, 0.6), (Synth.kick(), 0.84, 0.9),
                   (Synth.bass808(note: 36, length: 0.9), 0.98, 0.8), (Synth.clap(), 0.98, 0.7)])
        }
        Synth.normalize(&out, peak: 0.85)
        return out
    }
}
