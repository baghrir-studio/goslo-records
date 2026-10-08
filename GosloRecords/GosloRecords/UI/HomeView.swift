import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmNewCareer = false
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            RadioLogo(pixel: 3)
                .padding(.bottom, 22)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

            Logo(size: 84)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

            HStack(spacing: -12) {
                ForEach(Array(Style.allCases.enumerated()), id: \.offset) { index, style in
                    WalkingSprite(look: Rapper(name: "", city: .paris, style: style, skinTone: [1, 3, 0, 4][index],
                                               hairStyle: [.fade, .braids, .short, .puff][index], hat: [.cap, .none, .beanie, .none][index],
                                               outfit: [.hoodie, .jacket, .puffer, .jersey][index], outfitColor: [0, 3, 1, 4][index],
                                               gender: index % 2 == 1 ? .rappeuse : .rappeur).look,
                                  facing: .down, size: 64)
                }
            }
            .padding(.top, 16)
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : -40)

            Text("Simulateur de carrière. Le rap, c'est 10 % de talent et 90 % de choix douteux.")
                .font(.system(size: 17))
                .foregroundStyle(Theme.muted)
                .padding(.top, 20)
                .frame(maxWidth: 300, alignment: .leading)
                .opacity(appeared ? 1 : 0)

            if let error = model.loadError {
                Text(error)
                    .font(.mono(11))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 16)
            }

            Spacer()

            VStack(spacing: 12) {
                DailyClashCard()
                if let run = model.resumableRun {
                    Button {
                        model.resume()
                    } label: {
                        VStack(spacing: 2) {
                            Text("Reprendre")
                            Text("\(run.rapper.name) · \(run.isOvertime && !run.freeCareer ? "Prolongation" : "Année \(run.year)")")
                                .font(.mono(11, weight: .semibold))
                                .textCase(nil)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("Nouvelle carrière") {
                    if model.resumableRun != nil {
                        confirmNewCareer = true
                    } else {
                        model.go(.creation)
                    }
                }
                .buttonStyle(model.resumableRun == nil ? AnyButtonStyle(PrimaryButtonStyle()) : AnyButtonStyle(SecondaryButtonStyle()))
                .disabled(model.loadError != nil)

                Button("Arcade · mini-jeux") { model.go(.arcade) }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(model.loadError != nil)

                HStack(spacing: 12) {
                    Button("Mes carrières") { model.go(.history) }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Succès \(model.profile.unlocked.count)/\(Achievement.allCases.count)") { model.go(.achievements) }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }

            SoundSwitches()
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

            // Instagram: the game's account and the radio's.
            HStack(spacing: 18) {
                Link(destination: Socials.gameURL) {
                    Label("@\(Socials.game)", systemImage: "gamecontroller.fill")
                }
                Link(destination: Socials.radioURL) {
                    Label("@\(Socials.radio)", systemImage: "dot.radiowaves.left.and.right")
                }
            }
            .font(.mono(11, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .confirmationDialog("Ta carrière en cours sera abandonnée.", isPresented: $confirmNewCareer, titleVisibility: .visible) {
            Button("Recommencer à zéro", role: .destructive) { model.go(.creation) }
            Button("Annuler", role: .cancel) {}
        }
    }
}

struct Logo: View {
    var size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: -size * 0.22) {
            Text("goslo")
                .foregroundStyle(Theme.text)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("radio")
                Text(".").foregroundStyle(Theme.accent)
            }
            .foregroundStyle(Theme.text.opacity(0.92))
        }
        .font(.display(size))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("goslo radio")
    }
}

/// Lets the button style change based on state.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

/// The Instagram accounts: the game's, and goslo radio's.
enum Socials {
    static let game = "goslo_radio_lejeu"
    static let radio = "goslo_radio"
    static let gameURL = URL(string: "https://www.instagram.com/\(game)/")!
    static let radioURL = URL(string: "https://www.instagram.com/\(radio)/")!
}
