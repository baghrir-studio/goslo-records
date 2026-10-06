import SwiftUI

enum Theme {
    static let background = Color(red: 0.055, green: 0.055, blue: 0.06)
    static let surface = Color(white: 0.10)
    static let line = Color.white.opacity(0.14)
    static let text = Color.white
    static let muted = Color.white.opacity(0.55)
    static let faint = Color.white.opacity(0.3)
    /// The only accent color in the app.
    static let accent = Color(red: 1.0, green: 0.30, blue: 0.18)

    static let gutter: CGFloat = 20
}

extension Font {
    /// Big condensed type for titles.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Small uppercase monospaced label.
struct Kicker: View {
    let text: String
    var color: Color = Theme.muted

    var body: some View {
        Text(text.uppercased())
            .font(.mono(11, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { SoundEngine.shared.play(.tap) } }
            .font(.display(22))
            .textCase(.uppercase)
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { SoundEngine.shared.play(.tap) } }
            .font(.display(22))
            .textCase(.uppercase)
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 58)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Plain top bar button ("← Retour").
struct BackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("← \(title)")
                .font(.mono(13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .padding(.vertical, 8)
        }
    }
}

/// Music and sound effect switches (menu items).
struct SoundToggles: View {
    @State private var music = SoundEngine.shared.musicEnabled
    @State private var effects = SoundEngine.shared.effectsEnabled

    var body: some View {
        Toggle("Musique", isOn: $music)
            .onChange(of: music) { _, on in SoundEngine.shared.setMusicEnabled(on) }
        Toggle("Bruitages", isOn: $effects)
            .onChange(of: effects) { _, on in SoundEngine.shared.setEffectsEnabled(on) }
    }
}

/// Speaker buttons for the home screen.
struct SoundSwitches: View {
    @State private var music = SoundEngine.shared.musicEnabled
    @State private var effects = SoundEngine.shared.effectsEnabled

    var body: some View {
        HStack(spacing: 18) {
            switchButton(music ? "♪ MUSIQUE ON" : "♪ MUSIQUE OFF", on: music) {
                music.toggle()
                SoundEngine.shared.setMusicEnabled(music)
            }
            switchButton(effects ? "SONS ON" : "SONS OFF", on: effects) {
                effects.toggle()
                SoundEngine.shared.setEffectsEnabled(effects)
            }
        }
    }

    private func switchButton(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.mono(11, weight: .bold))
                .foregroundStyle(on ? Theme.accent : Theme.faint)
        }
        .buttonStyle(.plain)
    }
}
