import CoreMotion
import SwiftUI

/// Reads the accelerometer for a sharp flick of the phone (the mic drop gesture).
/// No permission needed: plain device motion, read only while the prompt is on screen.
enum FlickDetector {
    private static let motion = CMMotionManager()
    /// Acceleration from the user's hand, in g, that counts as a flick.
    static let threshold = 1.3

    static var available: Bool { motion.isDeviceMotionAvailable }

    static func start() {
        guard available, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60
        motion.startDeviceMotionUpdates()
    }

    static func stop() {
        motion.stopDeviceMotionUpdates()
    }

    static var flicked: Bool {
        guard let a = motion.deviceMotion?.userAcceleration else { return false }
        return (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot() > threshold
    }
}

/// After a won clash against a rival or a boss: the mic sways in the air, the player flicks
/// the phone (or taps), and it crashes onto the stage. Drops on its own after a few seconds.
struct MicDropOverlay: View {
    /// Called once, at the moment the mic hits the floor.
    let onDrop: () -> Void

    static let waitSeconds = 6.0

    @State private var dropped = false
    @State private var landed = false
    @State private var sway = false
    @State private var flash = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(landed ? 0.3 : 0.65)

                VStack(spacing: 10) {
                    Text(landed ? "MIC DROP !" : "LÂCHE LE MIC")
                        .font(.display(landed ? 58 : 50))
                        .foregroundStyle(landed ? Color(red: 1, green: 0.85, blue: 0.3) : .white)
                        .shadow(color: Theme.accent, radius: 0, x: 4, y: 4)
                        .rotationEffect(.degrees(landed ? -6 : 0))
                        .scaleEffect(landed ? 1.1 : 1)
                    if !dropped {
                        Text(FlickDetector.available ? "Un coup sec vers le bas avec ton téléphone\n(ou tape l'écran)"
                                                     : "Tape l'écran")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.8))
                            .transition(.opacity)
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.24)

                Image(systemName: "music.mic")
                    .font(.system(size: 70, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.accent, radius: 0, x: 4, y: 4)
                    .rotationEffect(.degrees(dropped ? 160 : (sway ? -14 : 14)))
                    .position(x: geo.size.width / 2,
                              y: dropped ? geo.size.height * 0.78 : geo.size.height * 0.48 + (sway ? -6 : 6))

                if flash {
                    Color.white.transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { drop() }
        .accessibilityLabel("Lâche le micro : tape l'écran")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { sway = true }
        }
        .task {
            FlickDetector.start()
            defer { FlickDetector.stop() }
            var waited = 0.0
            while !dropped && waited < MicDropOverlay.waitSeconds && !Task.isCancelled {
                if FlickDetector.flicked { break }
                try? await Task.sleep(for: .milliseconds(16))
                waited += 0.016
            }
            drop()
        }
    }

    private func drop() {
        guard !dropped else { return }
        withAnimation(.easeIn(duration: 0.3)) { dropped = true }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            SoundEngine.shared.play(.micDrop)
            Haptics.shared.play(.micDrop)
            withAnimation(.easeOut(duration: 0.06)) { flash = true }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { landed = true }
            onDrop()
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeIn(duration: 0.35)) { flash = false }
        }
    }
}
