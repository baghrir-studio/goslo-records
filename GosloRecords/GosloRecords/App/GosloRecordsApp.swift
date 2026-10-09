import SwiftUI

@main
struct GosloRecordsApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    /// Loop matching the current screen.
    private var musicTrack: SoundTrack? {
        guard model.route == .game else { return .menu }
        // A concert plays its own beat.
        if case .concert = model.phase { return nil }
        if case .clash(let clash) = model.phase { return clash.isWild ? .battle : .drill }
        if case .interview = model.phase { return .menu }
        if case .negotiation = model.phase { return .menu }
        if case .minigame(let running) = model.phase {
            switch running.kind {
            case .punchliner: return .drill
            case .fuite: return .battle
            case .platine, .signing: return .menu
            // The beatboxer is the music.
            case .beatbox: return nil
            }
        }
        if case .writing(let running) = model.phase {
            return model.engine.writing(running.id)?.duel == true ? .drill : .menu
        }
        return .street
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                switch model.route {
                case .home: HomeView()
                case .creation: CreationView()
                case .game: GameView()
                case .ending(let record): EndingView(record: record)
                case .history: HistoryView()
                case .achievements: AchievementsView()
                case .arcade: ArcadeView()
                case .hq: HQView()
                }
            }
            .transition(.opacity)

            if let moment = model.celebration {
                Text(moment)
                    .font(.display(30))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(red: 1, green: 0.85, blue: 0.3))
                    .overlay(Rectangle().stroke(.black, lineWidth: 3))
                    .shadow(color: Color(red: 1, green: 0.85, blue: 0.3).opacity(0.7), radius: 16)
                    .rotationEffect(.degrees(-3))
                    .frame(maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .zIndex(20)
            }

            if let gain = model.cardReveal {
                CrewCardReveal(gain: gain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.55).ignoresSafeArea())
                    .contentShape(Rectangle())
                    .onTapGesture { model.dismissCardReveal() }
                    .transition(.opacity)
                    .zIndex(21)
            }

            if let toast = model.achievementToast {
                AchievementToast(achievement: toast)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.route)
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.persist() } else { SoundEngine.shared.resume() }
        }
        .onAppear { SoundEngine.shared.start() }
        .onChange(of: musicTrack, initial: true) { _, track in SoundEngine.shared.setMusic(track) }
    }
}
