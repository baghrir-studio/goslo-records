import SwiftUI

struct CreationView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var city: City = .paris
    @State private var style: Style = .boomBap
    @State private var skinTone = 2
    // Look: nil keeps the style's default.
    @State private var hairColor: Int?
    @State private var hairStyle: CharacterLook.HairStyle?
    @State private var hat: CharacterLook.Hat?
    @State private var glasses: Bool?
    @State private var beard: Bool?
    @State private var chain: Bool?
    @State private var headphones: Bool?
    @State private var outfit: CharacterLook.Outfit?
    @State private var earrings: Bool?
    @State private var gender: Gender = .rappeur
    @State private var step: Step = .identity
    @FocusState private var nameFocused: Bool

    /// Three pages: who you are, how you look, how you rap. The career starts only on the last one.
    enum Step: Int, CaseIterable {
        case identity, look, style

        var title: String {
            switch self {
            case .identity: "Identité"
            case .look: "Look"
            case .style: "Style"
            }
        }
    }

    private var draft: Rapper {
        Rapper(name: trimmedName.isEmpty ? CreationView.defaultName : trimmedName, city: city, style: style, skinTone: skinTone, hairColor: hairColor, hairStyle: hairStyle,
               hat: hat, glasses: glasses, beard: beard, chain: chain, headphones: headphones, outfit: outfit, earrings: earrings, gender: gender)
    }

    /// Name used when the player leaves the field empty (the field's placeholder).
    static let defaultName = "MC Personne"

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton(title: step == .identity ? "Accueil" : "Retour") { back() }
                Spacer()
                stepper
            }
            .padding(.horizontal, Theme.gutter)

            // Pinned above the options: every change shows on the character without scrolling back up.
            HStack(alignment: .bottom) {
                Text(gender == .rappeuse ? "Crée ta\nrappeuse" : "Crée ton\nrappeur")
                    .font(.display(44))
                    .lineSpacing(-8)
                Spacer()
                WalkingSprite(look: draft.look, size: 104)
                    .id(draft.look)
                    .transition(.scale.combined(with: .opacity))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: style)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: draft.look)
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 10)
            .background(Theme.background)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    switch step {
                    case .identity:
                        nameSection
                        genderSection
                        citySection
                    case .look:
                        skinSection
                        lookSection
                    case .style:
                        styleSection
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .scrollDismissesKeyboard(.interactively)

            Button(step == .style ? "Lancer la carrière" : "Suivant") { next() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 12)
        }
    }

    /// "1 Identité · 2 Look · 3 Style", the current page lit.
    private var stepper: some View {
        HStack(spacing: 10) {
            ForEach(Step.allCases, id: \.self) { item in
                HStack(spacing: 4) {
                    Text("\(item.rawValue + 1)")
                        .font(.mono(10, weight: .bold))
                        .foregroundStyle(item == step ? Theme.background : Theme.muted)
                        .frame(width: 18, height: 18)
                        .background(item.rawValue <= step.rawValue ? Theme.accent : Color.clear)
                        .overlay(Rectangle().stroke(item.rawValue <= step.rawValue ? Theme.accent : Theme.line, lineWidth: 1))
                    if item == step {
                        Text(item.title.uppercased()).font(.mono(10, weight: .bold)).foregroundStyle(Theme.text)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private func next() {
        nameFocused = false
        if let following = Step(rawValue: step.rawValue + 1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { step = following }
        } else {
            model.startCareer(draft)
        }
    }

    private func back() {
        nameFocused = false
        if let previous = Step(rawValue: step.rawValue - 1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { step = previous }
        } else {
            model.go(.home)
        }
    }

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Tu es")
            ChoiceRow(options: Gender.allCases, selected: gender, label: { $0 == .rappeuse ? "Rappeuse" : "Rappeur" }) {
                gender = $0
                hairStyle = nil
                beard = nil
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Blaze")
            TextField("", text: $name, prompt: Text(CreationView.defaultName).foregroundStyle(Theme.faint))
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

    private var lookSection: some View {
        let look = draft.look
        return VStack(alignment: .leading, spacing: 14) {
            Kicker(text: "Look")
            HStack(spacing: 12) {
                ForEach(Rapper.hairColors.indices, id: \.self) { index in
                    Button {
                        hairColor = index
                    } label: {
                        Circle()
                            .fill(Color(uiColor: PixelColor(hex: Rapper.hairColors[index]).uiColor))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(look.hair == Rapper.hairColors[index] ? Theme.accent : Theme.line,
                                                     lineWidth: look.hair == Rapper.hairColors[index] ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Couleur de cheveux \(index + 1)")
                }
            }
            ChoiceRow(options: CharacterLook.HairStyle.allCases, selected: look.hairStyle, label: \.label) { hairStyle = $0 }
            ChoiceRow(options: CharacterLook.Hat.allCases, selected: look.hat, label: \.label) { hat = $0 }
            ChoiceRow(options: CharacterLook.Outfit.allCases, selected: look.outfit, label: \.label) { outfit = $0 }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ToggleChip(title: "Lunettes", isOn: look.glasses) { glasses = !look.glasses }
                ToggleChip(title: "Barbe", isOn: look.beard) { beard = !look.beard }
                ToggleChip(title: "Chaîne", isOn: look.chain) { chain = !look.chain }
                ToggleChip(title: "Casque", isOn: look.headphones) { headphones = !look.headphones }
                ToggleChip(title: "Boucles", isOn: look.earrings) { earrings = !look.earrings }
            }
        }
        .animation(.easeOut(duration: 0.15), value: look)
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

/// One option per chip, the current one highlighted.
private struct ChoiceRow<Option: Hashable>: View {
    let options: [Option]
    let selected: Option
    let label: (Option) -> String
    let pick: (Option) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button { pick(option) } label: {
                    Text(label(option))
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(selected == option ? Theme.background : Theme.text)
                        .background(selected == option ? Theme.accent : Color.clear)
                        .overlay(Rectangle().stroke(selected == option ? Theme.accent : Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ToggleChip: View {
    let title: String
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(isOn ? Theme.background : Theme.text)
                .background(isOn ? Theme.accent : Color.clear)
                .overlay(Rectangle().stroke(isOn ? Theme.accent : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private extension CharacterLook.HairStyle {
    var label: String {
        switch self {
        case .short: "Courts"
        case .long: "Longs"
        case .bald: "Rasé"
        case .puff: "Afro"
        case .braids: "Tresses"
        case .fade: "Dégradé"
        case .bun: "Chignon"
        }
    }
}

private extension CharacterLook.Hat {
    var label: String {
        switch self {
        case .none: "Tête nue"
        case .cap: "Casquette"
        case .beanie: "Bonnet"
        case .hood: "Capuche"
        case .bucket: "Bob"
        case .bandana: "Bandana"
        }
    }
}

private extension CharacterLook.Outfit {
    var label: String {
        switch self {
        case .hoodie: "Sweat"
        case .jacket: "Veste"
        case .jersey: "Maillot"
        case .puffer: "Doudoune"
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
