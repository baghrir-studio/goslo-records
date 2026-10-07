import SwiftUI

/// The concert's timing offset, saved on this device (the latency depends on the phone and the headphones).
enum ConcertCalibration {
    private static let key = "concertLatency"

    static var latency: Double {
        get { UserDefaults.standard.double(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var isSet: Bool { UserDefaults.standard.object(forKey: key) != nil }

    /// "+42 ms".
    static var label: String { format(latency) }

    static func format(_ seconds: Double) -> String {
        let ms = Int((seconds * 1000).rounded())
        return "\(ms >= 0 ? "+" : "")\(ms) ms"
    }
}

/// Tap on the clicks: the median gap becomes the offset applied to every concert tap.
struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date?
    @State private var taps: [Double] = []
    @State private var clicks = 0
    @State private var result: Double?
    @State private var task: Task<Void, Never>?
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RÉGLER LE TIMING").font(.display(28))
            Text("Tape le gros bouton en même temps que chaque clic, au son. Avec un casque Bluetooth, fais le réglage casque sur les oreilles.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                guard let start, result == nil else { return }
                taps.append(Date().timeIntervalSince(start))
            } label: {
                Circle()
                    .fill(pulse ? Theme.accent : Theme.accent.opacity(0.35))
                    .frame(width: 180, height: 180)
                    .overlay(Text(start == nil ? "PRÊT ?" : "\(taps.count)").font(.display(36)).foregroundStyle(.white))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .disabled(start == nil || result != nil)

            if let result {
                Text("Décalage mesuré : \(ConcertCalibration.format(result))")
                    .font(.mono(15, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                    .frame(maxWidth: .infinity)
            } else if start != nil && clicks >= ConcertEngine.calibrationClicks {
                Text("Pas assez de tapes. On recommence ?")
                    .font(.mono(13, weight: .bold)).foregroundStyle(Theme.accent).frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)

            if result != nil {
                Button("Enregistrer") {
                    if let result { ConcertCalibration.latency = result }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            HStack(spacing: 10) {
                Button(start == nil ? "Lancer les clics" : "Recommencer") { begin() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Remettre à zéro") {
                    ConcertCalibration.latency = 0
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(Theme.gutter)
        .onDisappear { task?.cancel() }
    }

    private func begin() {
        task?.cancel()
        taps = []
        clicks = 0
        result = nil
        let begun = Date()
        start = begun
        task = Task { @MainActor in
            while clicks < ConcertEngine.calibrationClicks, !Task.isCancelled {
                let next = Double(clicks + 1) * ConcertEngine.calibrationInterval
                try? await Task.sleep(for: .seconds(max(0, next - Date().timeIntervalSince(begun))))
                guard !Task.isCancelled else { return }
                SoundEngine.shared.play(.concertHit)
                clicks += 1
                withAnimation(.easeOut(duration: 0.08)) { pulse = true }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeIn(duration: 0.2)) { pulse = false }
            }
            // A last moment for the final tap.
            try? await Task.sleep(for: .milliseconds(400))
            result = ConcertEngine.latency(taps: taps)
        }
    }
}
