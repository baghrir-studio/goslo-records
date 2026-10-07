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
                }
            }
            .transition(.opacity)
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
