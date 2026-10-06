import Foundation

/// Tiny offline synthesizer: drums, 808, keys, chiptune. Every sound in the game
/// is generated here, so there's no audio file and no rights to clear.
enum Synth {
    static let sampleRate = 32_000.0

    static func count(_ seconds: Double) -> Int { max(1, Int(seconds * sampleRate)) }
    static func frequency(_ midiNote: Int) -> Double { 440 * pow(2, Double(midiNote - 69) / 12) }

    /// Deterministic noise (xorshift): every render sounds the same.
    struct Noise {
        private var state: UInt32

        init(seed: UInt32 = 0x9E37_79B9) { state = seed | 1 }

        mutating func next() -> Float {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return Float(state) / Float(UInt32.max) * 2 - 1
        }
    }

    /// Short fade-in/out so notes don't click.
    private static func edges(_ i: Int, _ n: Int, attack: Double = 0.003, release: Double = 0.012) -> Double {
        let t = Double(i) / sampleRate, remaining = Double(n - i) / sampleRate
        return min(1, t / attack) * min(1, remaining / release)
    }

    // MARK: - Drums

    static func kick(punch: Double = 1, length: Double = 0.42) -> [Float] {
        let n = count(length)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += 2 * .pi * (48 + 120 * punch * exp(-t * 28)) / sampleRate
            out[i] = Float(sin(phase) * exp(-t * 6.5) * edges(i, n, attack: 0.0005))
        }
        for i in 0..<min(n, 40) { out[i] += Float(1 - Double(i) / 40) * 0.25 }
        return out
    }

    static func snare(seed: UInt32 = 7) -> [Float] {
        let n = count(0.22)
        var noise = Noise(seed: seed)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += 2 * .pi * 185 / sampleRate
            out[i] = noise.next() * Float(exp(-t * 20)) * 0.55 + Float(sin(phase) * exp(-t * 28)) * 0.45
        }
        return out
    }

    static func clap(seed: UInt32 = 11) -> [Float] {
        let n = count(0.26)
        var noise = Noise(seed: seed)
        var out = [Float](repeating: 0, count: n)
        let bursts = [0.0, 0.011, 0.022]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var env = 0.0
            for (k, start) in bursts.enumerated() where t >= start {
                env += exp(-(t - start) * (k == bursts.count - 1 ? 16 : 140))
            }
            out[i] = noise.next() * Float(env) * 0.5
        }
        lowpass(&out, cutoff: 5_000)
        return out
    }

    static func hat(open: Bool = false, seed: UInt32 = 3) -> [Float] {
        let n = count(open ? 0.24 : 0.05)
        var noise = Noise(seed: seed)
        var out = [Float](repeating: 0, count: n)
        var previous: Float = 0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let x = noise.next()
            out[i] = (x - previous) * 0.45 * Float(exp(-t * (open ? 13 : 85)))
            previous = x
        }
        return out
    }

    /// Vinyl crackle and hiss (boom bap texture).
    static func crackle(length: Double, clicks: Int, seed: UInt32 = 21) -> [Float] {
        let n = count(length)
        var noise = Noise(seed: seed)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n { out[i] = noise.next() * 0.008 }
        for _ in 0..<clicks {
            let at = Int((noise.next() + 1) / 2 * Float(n - 20))
            let amp = 0.08 + abs(noise.next()) * 0.12
            for k in 0..<12 { out[at + k] += amp * Float(1 - Double(k) / 12) * (k % 2 == 0 ? 1 : -1) }
        }
        lowpass(&out, cutoff: 6_000)
        return out
    }

    // MARK: - Tonal

    /// Saturated 808 sub bass, with an optional slide from another note.
    static func bass808(note: Int, length: Double, slideFrom: Int? = nil) -> [Float] {
        let n = count(length)
        let target = frequency(note), start = slideFrom.map(frequency) ?? target
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += 2 * .pi * (target + (start - target) * exp(-t * 14)) / sampleRate
            let x = sin(phase) * exp(-t * 1.1) * edges(i, n, attack: 0.004, release: 0.03)
            out[i] = Float(tanh(x * 2.2) / tanh(2.2))
        }
        return out
    }

    /// Square/pulse wave (chiptune): duty 0.5 = square, 0.125 = thin.
    static func pulse(note: Int, length: Double, duty: Double = 0.5, decay: Double = 4, glideTo: Int? = nil) -> [Float] {
        let n = count(length)
        let from = frequency(note), to = glideTo.map(frequency) ?? from
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += (from + (to - from) * Double(i) / Double(n)) / sampleRate
            phase -= floor(phase)
            out[i] = Float((phase < duty ? 1 : -1) * exp(-t * decay) * edges(i, n) * 0.35)
        }
        return out
    }

    /// Soft electric-piano-ish chord (triangle + slightly detuned sine).
    static func keys(_ notes: [Int], length: Double, decay: Double = 1.4) -> [Float] {
        let n = count(length)
        var out = [Float](repeating: 0, count: n)
        for note in notes {
            let f = frequency(note)
            var phase = 0.0, detuned = 0.0
            for i in 0..<n {
                let t = Double(i) / sampleRate
                phase += f / sampleRate
                phase -= floor(phase)
                detuned += 2 * .pi * f * 1.003 / sampleRate
                let triangle = 4 * abs(phase - 0.5) - 1
                let env = exp(-t * decay) * edges(i, n, attack: 0.008, release: 0.05)
                out[i] += Float((triangle * 0.6 + sin(detuned) * 0.4) * env) / Float(notes.count)
            }
        }
        lowpass(&out, cutoff: 2_800)
        return out
    }

    /// Noise and tone rising together (tension before a secret technique).
    static func riser(length: Double, seed: UInt32 = 5) -> [Float] {
        let n = count(length)
        var noise = Noise(seed: seed)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let progress = Double(i) / Double(n)
            phase += (180 + 1_400 * progress * progress) / sampleRate
            phase -= floor(phase)
            let tone = phase < 0.5 ? 0.25 : -0.25
            out[i] = Float((Double(noise.next()) * 0.3 + tone) * progress * progress * edges(i, n))
        }
        return out
    }

    /// Record scratch: back-and-forth sawtooth with noise.
    static func scratch(length: Double = 0.36, seed: UInt32 = 9) -> [Float] {
        let n = count(length)
        var noise = Noise(seed: seed)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += (260 + 820 * abs(sin(t * 2 * .pi * 5.5))) / sampleRate
            phase -= floor(phase)
            out[i] = Float(((phase * 2 - 1) * 0.5 + Double(noise.next()) * 0.25) * edges(i, n, attack: 0.002, release: 0.04))
        }
        lowpass(&out, cutoff: 3_500)
        return out
    }

    // MARK: - DSP

    static func lowpass(_ x: inout [Float], cutoff: Double) {
        let rc = 1 / (2 * .pi * cutoff), dt = 1 / sampleRate
        let alpha = Float(dt / (rc + dt))
        var y: Float = 0
        for i in x.indices {
            y += alpha * (x[i] - y)
            x[i] = y
        }
    }

    /// Mixes `source` into `destination` at `offset`; with `wrap`, the tail loops back to the start.
    static func add(_ source: [Float], into destination: inout [Float], at offset: Int, gain: Float, wrap: Bool = false) {
        guard !destination.isEmpty else { return }
        for i in source.indices {
            var j = offset + i
            if j >= destination.count {
                guard wrap else { return }
                j %= destination.count
            }
            destination[j] += source[i] * gain
        }
    }

    /// Normalizes to `peak` (soft limiting so nothing clips).
    static func normalize(_ x: inout [Float], peak: Float = 0.85) {
        let maximum = x.reduce(0) { max($0, abs($1)) }
        guard maximum > 0 else { return }
        let gain = peak / maximum
        for i in x.indices { x[i] *= gain }
    }

    /// Several sounds placed in time: (sound, start in seconds, gain).
    static func layer(_ parts: [([Float], Double, Float)], tail: Double = 0.05) -> [Float] {
        let length = parts.map { Double($0.0.count) / sampleRate + $0.1 }.max() ?? 0
        var out = [Float](repeating: 0, count: count(length + tail))
        for (sound, start, gain) in parts {
            add(sound, into: &out, at: Int(start * sampleRate), gain: gain)
        }
        return out
    }
}
