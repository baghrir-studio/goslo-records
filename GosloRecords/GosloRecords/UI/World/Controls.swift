import SwiftUI

/// Touch D-pad: hold to walk, slide your finger to change direction.
struct DPad: View {
    let onChange: (Direction?) -> Void
    @State private var active: Direction?

    private let size: CGFloat = 150

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.35))
            ForEach(Direction.allCases, id: \.self) { direction in
                arrow(direction)
            }
            Circle().fill(Color.white.opacity(0.08)).frame(width: 30, height: 30)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let direction = direction(for: value.location)
                    if direction != active {
                        active = direction
                        onChange(direction)
                    }
                }
                .onEnded { _ in
                    active = nil
                    onChange(nil)
                }
        )
        .sensoryFeedback(.selection, trigger: active)
        .accessibilityElement()
        .accessibilityLabel("Croix directionnelle")
    }

    private func arrow(_ direction: Direction) -> some View {
        let pressed = active == direction
        return RoundedRectangle(cornerRadius: 6)
            .fill(pressed ? Theme.accent : Color.white.opacity(0.16))
            .overlay(
                Image(systemName: "triangle.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(pressed ? Theme.background : .white.opacity(0.8))
                    .rotationEffect(.degrees(rotation(direction)))
            )
            .frame(width: 46, height: 46)
            .offset(x: CGFloat(direction.dx) * 48, y: CGFloat(direction.dy) * 48)
            .scaleEffect(pressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }

    private func rotation(_ direction: Direction) -> Double {
        switch direction {
        case .up: 0
        case .right: 90
        case .down: 180
        case .left: 270
        }
    }

    private func direction(for point: CGPoint) -> Direction? {
        let dx = point.x - size / 2, dy = point.y - size / 2
        guard dx * dx + dy * dy > 14 * 14 else { return nil }
        if abs(dx) > abs(dy) { return dx > 0 ? .right : .left }
        return dy > 0 ? .down : .up
    }
}

/// The "A" button (talk / interact).
struct ActionButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Theme.background)
                .frame(width: 74, height: 74)
                .background(Circle().fill(Theme.accent))
                .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 3))
                .shadow(color: Theme.accent.opacity(0.5), radius: 10)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Parler")
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { SoundEngine.shared.play(.tap) } }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
