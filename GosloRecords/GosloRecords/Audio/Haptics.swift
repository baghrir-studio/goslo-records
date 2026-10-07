import CoreHaptics
import Foundation

/// Vibrations that follow the music and the hits (Core Haptics).
/// Silent on devices without a Taptic Engine and when the player turns them off.
final class Haptics {
    static let shared = Haptics()

    private static let enabledKey = "haptics.enabled"

    private(set) var enabled: Bool
    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    enum Pattern {
        /// Concert: kick drum on 1 and 3, snare on 2 and 4.
        case kick, snare
        /// A note hit in rhythm.
        case perfect, good
        /// Clash hits.
        case hit, strongHit, weakHit, miss
        /// A secret technique charging up (follows the cinematic), then landing.
        case secretRiser, secretHit
        case victory, defeat
        /// The mic hits the floor: thud, two bounces, a feedback buzz.
        case micDrop
    }

    private init() {
        enabled = UserDefaults.standard.object(forKey: Haptics.enabledKey) as? Bool ?? true
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        UserDefaults.standard.set(on, forKey: Haptics.enabledKey)
        if !on { engine?.stop() }
    }

    func play(_ pattern: Pattern) {
        guard enabled, supported, let engine = startedEngine() else { return }
        do {
            let player = try engine.makePlayer(with: try Haptics.pattern(pattern))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // The engine was stopped by the system (background, audio interruption): start again next time.
            self.engine = nil
        }
    }

    private func startedEngine() -> CHHapticEngine? {
        if let engine { return engine }
        guard let engine = try? CHHapticEngine() else { return nil }
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak engine] in try? engine?.start() }
        do { try engine.start() } catch { return nil }
        self.engine = engine
        return engine
    }

    // MARK: Patterns

    private static func tap(_ time: Double, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private static func rumble(_ time: Double, _ duration: Double, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    /// Intensity multiplier over time for the whole pattern.
    private static func curve(_ points: [(Double, Float)]) -> CHHapticParameterCurve {
        CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                               controlPoints: points.map { CHHapticParameterCurve.ControlPoint(relativeTime: $0.0, value: $0.1) },
                               relativeTime: 0)
    }

    private static func pattern(_ pattern: Pattern) throws -> CHHapticPattern {
        var curves: [CHHapticParameterCurve] = []
        let events: [CHHapticEvent]
        switch pattern {
        case .kick:
            events = [tap(0, 0.75, 0.15)]
        case .snare:
            events = [tap(0, 0.4, 0.7)]
        case .perfect:
            events = [tap(0, 0.9, 0.9)]
        case .good:
            events = [tap(0, 0.5, 0.6)]
        case .weakHit:
            events = [tap(0, 0.45, 0.4)]
        case .hit:
            events = [tap(0, 0.8, 0.5), rumble(0.02, 0.12, 0.5, 0.2)]
        case .strongHit:
            events = [tap(0, 1, 0.6), rumble(0.02, 0.3, 0.9, 0.15), tap(0.16, 0.7, 0.3)]
            curves = [curve([(0, 1), (0.3, 0.1)])]
        case .miss:
            events = [tap(0, 0.3, 0.9), tap(0.09, 0.2, 0.9)]
        case .secretRiser:
            // Builds over the cinematic (~2 s): faint and soft, then hard and sharp.
            events = [rumble(0, 2, 1, 0.1)] + (0..<10).map { tap(0.6 + Double($0) * 0.14, 0.3 + Float($0) * 0.07, 0.8) }
            curves = [curve([(0, 0.1), (1.2, 0.45), (2, 1)])]
        case .secretHit:
            events = [tap(0, 1, 1), rumble(0, 0.8, 1, 0.05), tap(0.25, 0.8, 0.4), tap(0.45, 0.6, 0.3)]
            curves = [curve([(0, 1), (0.8, 0)])]
        case .victory:
            // Like the jingle: three quick notes, then the chord.
            events = [tap(0, 0.6, 0.8), tap(0.12, 0.7, 0.8), tap(0.24, 0.8, 0.8), tap(0.36, 1, 0.5), rumble(0.36, 0.6, 0.7, 0.3)]
            curves = [curve([(0, 1), (0.36, 1), (0.96, 0)])]
        case .defeat:
            events = [rumble(0, 0.9, 0.7, 0.05), tap(0, 0.6, 0.2)]
            curves = [curve([(0, 1), (0.9, 0)])]
        case .micDrop:
            events = [tap(0, 1, 0.3), rumble(0, 0.25, 1, 0.1), tap(0.2, 0.55, 0.7), tap(0.32, 0.3, 0.8),
                      rumble(0.4, 0.9, 0.3, 1)]
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }
}
