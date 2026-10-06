import SwiftUI

struct CreationView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var city: City = .paris
    @State private var style: Style = .boomBap
    @State private var skinTone = 2
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton(title: "Accueil") { model.go(.home) }
                Spacer()
            }
            .padding(.horizontal, Theme.gutter)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HStack(alignment: .bottom) {
                        Text("Crée ton\nrappeur")
                            .font(.display(52))
                            .lineSpacing(-8)
                        Spacer()
                        WalkingSprite(look: Rapper(name: "", city: city, style: style, skinTone: skinTone).look, size: 110)
                            .id("\(style.rawValue)-\(skinTone)")
                            .transition(.scale.combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: style)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: skinTone)

                    nameSection
                    skinSection
                    citySection
                    styleSection
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            Button("Lancer la carrière") {
                model.startCareer(Rapper(name: trimmedName, city: city, style: style, skinTone: skinTone))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmedName.isEmpty)
            .opacity(trimmedName.isEmpty ? 0.35 : 1)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Blaze")
            TextField("", text: $name, prompt: Text("MC Personne").foregroundStyle(Theme.faint))
                .font(.display(36))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFocused)
                .onChange(of: name) { _, newValue in
                    if newValue.count > Rapper.maxNameLength {
                        name = String(newValue.prefix(Rapper.maxNameLength))
                    }
                }
            Rectangle()
                .fill(nameFocused ? Theme.accent : Theme.line)
                .frame(height: 2)
                .animation(.easeOut(duration: 0.2), value: nameFocused)
        }
    }

    private var skinSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Teint")
            HStack(spacing: 12) {
                ForEach(Rapper.skinTones.indices, id: \.self) { index in
                    Button {
                        skinTone = index
                    } label: {
                        Circle()
                            .fill(Color(uiColor: PixelColor(hex: Rapper.skinTones[index]).uiColor))
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(skinTone == index ? Theme.accent : Theme.line, lineWidth: skinTone == index ? 3 : 1))
                            .scaleEffect(skinTone == index ? 1.1 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Teint \(index + 1)")
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: skinTone)
        }
    }

    private var citySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Ville de départ")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(City.allCases) { option in
                    Button {
                        city = option
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(city == option ? Theme.background : Theme.text)
                            .background(city == option ? Theme.accent : Color.clear)
                            .overlay(Rectangle().stroke(city == option ? Theme.accent : Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.easeOut(duration: 0.15), value: city)
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Style")
            ForEach(Style.allCases) { option in
                StyleRow(style: option, selected: style == option) { style = option }
            }
        }
    }
}

private struct StyleRow: View {
    let style: Style
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(style.rawValue.uppercased())
                        .font(.display(26))
                        .foregroundStyle(selected ? Theme.accent : Theme.text)
                    Spacer()
                    if selected {
                        Text("●").foregroundStyle(Theme.accent).font(.system(size: 12))
                    }
                }
                Text(style.pitch)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 14) {
                    ForEach(StatKind.allCases) { kind in
                        let value = style.startingStats[kind]
                        HStack(spacing: 4) {
                            Text(kind.shortLabel).foregroundStyle(Theme.faint)
                            Text("\(value)").foregroundStyle(Theme.text)
                        }
                        .font(.mono(10, weight: .semibold))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}
