import SwiftUI

/// The shop: gear that stays (a level more in a clash move) and services (once a year). Paid in Argent.
struct ShopView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Boutique").font(.display(44))
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 18)

            if let state = model.state {
                Text("ARGENT : \(state.stats.argent) · à 0, c'est le retour au taf")
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, Theme.gutter)
                if let message {
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                        .padding(.horizontal, Theme.gutter)
                        .padding(.top, 6)
                        .transition(.opacity)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Matos (pour toujours)")
                        ForEach(Shop.gear) { offer in row(offer, in: state) }
                        Kicker(text: "Services (une fois par an)")
                            .padding(.top, 10)
                        ForEach(Shop.services) { offer in row(offer, in: state) }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func row(_ offer: ShopOffer, in state: GameState) -> some View {
        let refusal = Shop.refusal(offer, in: state)
        return Button {
            if let refusal = model.buy(offer) {
                withAnimation { message = refusal }
            } else {
                withAnimation { message = "« \(offer.name) » : c'est fait." }
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.name.uppercased())
                        .font(.mono(13, weight: .bold))
                        .foregroundStyle(refusal == nil ? Theme.text : Theme.faint)
                    Text(offer.pitch)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let refusal {
                        Text(refusal.uppercased())
                            .font(.mono(10, weight: .bold))
                            .foregroundStyle(Theme.accent.opacity(0.8))
                    }
                }
                Spacer(minLength: 0)
                Text("\(offer.price)")
                    .font(.display(28))
                    .foregroundStyle(refusal == nil ? Color(red: 1, green: 0.85, blue: 0.3) : Theme.faint)
            }
            .padding(12)
            .overlay(Rectangle().stroke(refusal == nil ? Theme.line : Theme.line.opacity(0.5), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(refusal != nil)
    }
}
