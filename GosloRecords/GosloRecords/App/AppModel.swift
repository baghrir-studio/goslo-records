import Foundation
import Observation
import SwiftUI

enum Route: Equatable {
    case home
    case creation
    case game
    case ending(CareerRecord)
    case history
    case achievements
    case arcade
    case hq
}

/// What triggered the current encounter (decides the backdrop and where you come back to).
enum EncounterSource: Equatable {
    case building(MapDoor)
    case npc(String)
    case bench
    case phone
    case wild
}

enum GamePhase: Equatable {
    /// Free to move around.
    case overworld
    /// Simple lines (a busy character, a locked door…).
    case dialogue(speaker: String?, lines: [String])
    case encounter(GameEvent)
    case consequence(GameEvent?, TurnOutcome)
    case clash(ClashState)
    case interview(InterviewState)
    case concert(ConcertState)
    case negotiation(NegotiationState)
    case writing(WritingState)
    case minigame(MinigameState)
    /// A scripted scene is playing.
    case cinematic
    /// The metro map: pick a district.
    case metro
    /// The finale is played: retire as a legend, or keep clashing the new generation.
    case finaleChoice
}

/// What a cinematic shows at the bottom of the screen.
struct CinematicCaption: Equatable {
    enum Kind: Equatable {
        case narration
        case speech(name: String, look: CharacterLook)
        case title(subtitle: String?)
    }

    let kind: Kind
    let text: String
    let id: Int
}

/// Full-screen transitions.
enum WorldTransition: Equatable {
    case fade
    case battle
    case semester(title: String, subtitle: String)
    /// A metro ride to another district.
    case metro(District)
}

/// Glue between the engine, persistence and the UI: current run, overworld, routing.
@Observable
@MainActor
final class AppModel {
    static let stepDuration: Duration = .milliseconds(170)
    static let stepSeconds = 0.17

    private(set) var route: Route = .home
    private(set) var state: GameState?
    private(set) var phase: GamePhase = .overworld {
        didSet {
            // A card with its own sound (a phone call rings once when it shows up).
            if case .encounter(let event) = phase, oldValue != phase,
               let name = event.sound, let effect = SoundEffect(rawValue: name) {
                SoundEngine.shared.play(effect)
            }
        }
    }
    private(set) var source: EncounterSource?
    private(set) var history: [CareerRecord]
    private(set) var lastDeltas: [StatKind: Int] = [:]
    private(set) var deltaToken = 0
    private(set) var transition: WorldTransition?
    let loadError: String?
    let engine: GameEngine

    // Overworld
    private(set) var position = TilePoint(x: 0, y: 0)
    private(set) var facing: Direction = .down
    private(set) var walkFrame = 0
    private(set) var npcPositions: [String: TilePoint] = [:]
    private(set) var npcFacing: [String: Direction] = [:]
    private(set) var npcWalkFrame: [String: Int] = [:]
    private(set) var exclaiming: String?

    // Cinematics
    private(set) var caption: CinematicCaption?
    private(set) var letterbox = false
    private(set) var cameraFocus: TilePoint?
    /// Characters placed by a cinematic who aren't on the map in this chapter.
    private(set) var extraActors: [String: TilePoint] = [:]
    private(set) var hiddenActors: Set<String> = []
    private var captionWaiter: CheckedContinuation<Void, Never>?
    private var captionSerial = 0

    // goslo radio
    private(set) var radioHeadline: String?
    private var radioTask: Task<Void, Never>?
    private var lastHeadline: String?

    private let store: GameStore
    private let sound = SoundEngine.shared
    private var rng = SystemRandomNumberGenerator()
    private var finishedRecord: CareerRecord?
    private var busy = false
    private var heldDirection: Direction?
    private var walkTask: Task<Void, Never>?
    private var pendingSemesterCard = false
    /// The period briefing card (what the last turn paid, the goals for this one), shown over the map for a moment.
    private(set) var briefing: PeriodBriefing?
    /// Set when a turn closes (with what it paid, if known), shown once back on the map.
    private var pendingBriefing: PeriodSummary??
    private var stepsSinceSave = 0
    /// Achievements unlocked on this device (they unlock the legacy bonuses).
    private(set) var profile: TrophyCase
    /// The achievement being announced at the top of the screen.
    private(set) var achievementToast: Achievement?
    private var toastQueue: [Achievement] = []
    /// Driss offered a ride: the next tap opens the destinations.
    private var taxiRideOffered = false
    private var taxiTalks = 0
    private var bunkerKnocks = 0
    /// Something going on a few steps away on the map (walk onto it to join in).
    private(set) var happening: StreetHappening?
    private var happeningTurn = -1
    /// Construction mode: the decoration being placed in front of the player (bought on "Poser").
    private(set) var placingDecor: Decor?
    /// When the decoration being placed is one already on the map, being moved (free).
    private(set) var movingDecorId: Int?
    /// The placed decoration the player is looking at (collect, upgrade, move, sell).
    private(set) var inspectedDecorId: Int?
    /// A big moment to celebrate at the top of the screen (level up, n°1, challenge).
    private(set) var celebration: String?
    /// The daily clash being played (the career waits in `careerAside`, untouched).
    private(set) var dailyClash: DailyChallenge?
    private var careerAside: GameState?
    /// The arcade game being played (a throwaway game too).
    private(set) var arcadePlaying: ArcadeGame?
    /// The Punchliner's French dictionary, read once in the background the first time it's needed.
    @ObservationIgnored private var dictionaryTask: Task<FrenchDictionary?, Never>?
    /// What the Punchliner game that just ended did to the personal records (for its result screen).
    private(set) var punchlinerBreak: PunchlinerRecordBreak?
    /// The philosopher's analysis being read, to share as a card (cleared when the dialogue ends).
    private(set) var philosophyCard: PhilosophyCard?
    /// « Le Tournoi goslo radio » is open (talking to the radio host opens it).
    var showingTournament = false
    /// The radio host's dialogue ends on the Tournoi's ladder.
    private var tournamentAfterDialogue = false
    static let tournamentInvite = "Le Tournoi goslo radio t'attend. DJ Noize est aux platines, le tableau est affiché. On regarde qui tu peux défier ?"

    init(engine: GameEngine, store: GameStore, loadError: String? = nil) {
        self.engine = engine
        self.store = store
        self.loadError = loadError
        history = store.loadHistory()
        profile = store.loadProfile()
        state = store.loadCurrentRun().flatMap { $0.isOver ? nil : $0 }
        // Careers saved before the free career get it too: no clock will end them any more.
        state?.freeCareer = true
        // Careers finished before achievements existed still count.
        checkAchievements(in: state, announce: false)
    }

    static func live() -> AppModel {
        do {
            return AppModel(engine: GameEngine(world: try EventLoader.loadWorld()), store: GameStore())
        } catch {
            return AppModel(engine: GameEngine(events: []), store: GameStore(), loadError: "\(error)")
        }
    }

    /// The district the player is in, as it is in the current chapter.
    var map: WorldMap? {
        if let state { return engine.currentMap(in: state) }
        return engine.world.map?.forChapter(1)
    }
    var district: District { state?.district ?? .bloc }
    /// Where the current objective is, when it's in another district (shown under the objective).
    var objectiveDistrict: District? { state.flatMap { engine.objectiveDistrict(in: $0) } }
    var objective: Objective? { state.flatMap { engine.currentObjective(in: $0) } }
    var chapter: Chapter? { state.flatMap { engine.currentChapter(in: $0) } }
    var resumableRun: GameState? { state }
    var canMove: Bool { phase == .overworld && transition == nil && !busy }

    /// Building being visited (shows the interior).
    var interior: Location? {
        if case .building(let door) = source { return door.location }
        return nil
    }

    func go(_ route: Route) {
        self.route = route
    }

    // MARK: - Career

    func startCareer(_ rapper: Rapper) {
        var fresh = engine.newGame(rapper: rapper)
        HQ.apply(profile.hq, to: &fresh)
        fresh.freeCareer = true
        fresh.position = engine.world.map?.spawn
        state = fresh
        finishedRecord = nil
        lastDeltas = [:]
        enterWorld()
        persist()
        route = .game
        Task { await playPendingCinematic() }
    }

    func resume() {
        guard var current = state else { return }
        enterWorld()
        if let clash = current.clash {
            source = clash.isWild ? .wild : nil
            phase = .clash(clash)
        } else if let interview = current.interview {
            source = map?.door(for: .media).map { .building($0) }
            phase = .interview(interview)
        } else if let concert = current.concert {
            source = map?.door(for: .scene).map { .building($0) }
            phase = .concert(concert)
        } else if let negotiation = current.negotiation {
            phase = .negotiation(negotiation)
        } else if let writing = current.writing {
            phase = .writing(writing)
        } else if let minigame = current.minigame {
            phase = .minigame(minigame)
        } else if let event = engine.currentEvent(in: current) ?? engine.takeFollowUp(in: &current) {
            state = current
            phase = .encounter(event)
        } else if current.pendingCinematic != nil {
            Task { await playPendingCinematic() }
        } else if current.finaleChoicePending {
            phase = .finaleChoice
        }
        route = .game
    }

    #if DEBUG
    enum DebugAction {
        case chapter(Int)
        case lastSemester
        case maxOut
        /// Shows this event's card right away (e.g. a mini-game), without spending an action.
        case event(String)
    }

    /// Debug builds only (menu "…" in the HUD): jumps around the story to test it quickly.
    func debug(_ action: DebugAction) {
        guard var current = state, canMove else { return }
        switch action {
        case .chapter(let number): engine.debugJump(toChapter: number, in: &current)
        case .lastSemester: engine.debugLastSemester(in: &current)
        case .maxOut: engine.debugMaxOut(in: &current)
        case .event(let id):
            guard let event = engine.event(withId: id) else { return }
            current.currentEventId = id
            state = current
            phase = .encounter(event)
            persist()
            return
        }
        state = current
        enterWorld()
        persist()
        Task { await playPendingCinematic() }
    }
    #endif

    /// Leaves the game (autosaved).
    func leaveGame() {
        if finishedRecord != nil {
            state = nil
            finishedRecord = nil
        }
        persist()
        heldDirection = nil
        radioTask?.cancel()
        radioHeadline = nil
        advanceCinematic()
        route = .home
    }

    private func enterWorld() {
        guard let state else { return }
        position = state.position ?? map?.spawn ?? TilePoint(x: 0, y: 0)
        facing = state.facing
        walkFrame = 0
        resetNPCs()
        phase = .overworld
        source = nil
        transition = nil
        busy = false
        caption = nil
        letterbox = false
        cameraFocus = nil
        extraActors = [:]
        startRadio()
    }

    private func resetNPCs() {
        npcPositions = Dictionary(uniqueKeysWithValues: (map?.npcs ?? []).map { ($0.id, $0.point) })
        npcFacing = Dictionary(uniqueKeysWithValues: (map?.npcs ?? []).map { ($0.id, $0.facing) })
        npcWalkFrame = [:]
        exclaiming = nil
        hiddenActors = []
    }

    // MARK: - Movement

    /// Held direction on the D-pad (nil = released). Walks as long as it's held.
    func hold(_ direction: Direction?) {
        heldDirection = direction
        if direction != nil, inspectedDecorId != nil { closeInspected() }
        guard direction != nil, walkTask == nil else { return }
        walkTask = Task { [weak self] in
            while let self, let direction = self.heldDirection {
                if self.canMove { await self.step(direction) }
                try? await Task.sleep(for: .milliseconds(30))
            }
            self?.walkTask = nil
        }
    }

    private func step(_ direction: Direction) async {
        guard canMove, let map else { return }
        facing = direction
        let target = position.moved(direction)

        if let door = map.door(at: target), let state, !engine.isUnlocked(door.location, in: state) {
            heldDirection = nil
            sound.play(.miss)
            phase = .dialogue(speaker: door.location.name, lines: ["C'est fermé.", door.location.lockedHint])
            return
        }
        guard OverworldRules.canStep(to: target, on: map) else { return }
        if let state, state.district == .bloc, OverworldRules.blockedByScenery(target, in: state.rapper.city) { return }
        if let state, engine.isBlockedByDecor(target, in: state) { return }

        busy = true
        walkFrame = walkFrame == 1 ? 2 : 1
        sound.play(.step)
        withAnimation(.linear(duration: AppModel.stepSeconds)) { position = target }
        try? await Task.sleep(for: AppModel.stepDuration)
        walkFrame = 0
        busy = false
        await arrived(at: target, on: map)
    }

    private func arrived(at point: TilePoint, on map: WorldMap) async {
        guard var current = state else { return }
        current.position = point
        current.facing = facing
        if map.tile(at: point).isWildZone { current.stepsSinceWild += 1 }
        state = current
        stepsSinceSave += 1
        if stepsSinceSave >= 10 { persist() }

        if map.metro == point {
            heldDirection = nil
            openMetro()
        } else if let door = map.door(at: point) {
            heldDirection = nil
            await enter(door)
        } else if let spot = happening, spot.point == point {
            heldDirection = nil
            await join(spot)
        } else if let rival = OverworldRules.spotter(of: point, on: map, canChallenge: { engine.canChallenge($0, in: current) }) {
            heldDirection = nil
            await challenge(by: rival)
        } else if OverworldRules.rollWild(on: map.tile(at: point), stepsSinceLast: current.stepsSinceWild, using: &rng) {
            heldDirection = nil
            await startWild()
        } else {
            spawnHappening(near: point, on: map)
        }
    }

    // MARK: - Street happenings

    /// Now and then (once a turn at most), something starts a few steps away.
    private func spawnHappening(near point: TilePoint, on map: WorldMap) {
        guard let current = state, dailyClash == nil, arcadePlaying == nil, phase == .overworld,
              engine.canVisit(current), current.chapter >= 2 else { return }
        if let spot = happening, happeningTurn != current.turn || spot.point == point { happening = nil }
        guard happening == nil, happeningTurn != current.turn,
              Int.random(in: 0..<100, using: &rng) < Happenings.chancePercent,
              let spot = Happenings.spot(near: point, on: map, city: current.rapper.city, using: &rng),
              !engine.decorTiles(in: current.district, state: current).contains(spot) else { return }
        let kind = Happenings.pick(canClash: !engine.wildOpponents(in: current.rapper.city).isEmpty, using: &rng)
        happeningTurn = current.turn
        sound.play(.exclaim)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { happening = StreetHappening(kind: kind, point: spot) }
    }

    private func join(_ spot: StreetHappening) async {
        happening = nil
        guard var current = state, engine.canVisit(current) else { return }
        switch spot.kind {
        case .cypher:
            // A rapper from the terrain vague takes the mic: a wild clash, no action spent.
            await startWild()
        case .selfie:
            let before = current.stats
            let selfie = engine.takeSelfie(in: &current, using: &rng)
            state = current
            publishDeltas(from: before, to: current.stats)
            sound.play(.statUp)
            Haptics.shared.play(.good)
            phase = .dialogue(speaker: selfie.fan, lines: [spot.kind.intro, selfie.line,
                                                           "Elle poste la photo : « vu en vrai !! » Ça tourne dans le quartier."])
            persist()
        case .beatbox:
            guard let running = try? engine.startStreetBeatbox(in: &current) else { return }
            state = current
            source = nil
            phase = .minigame(running)
            persist()
        }
    }

    /// Shows the biggest moment of an outcome as a banner, with a fanfare.
    private func celebrate(_ outcome: TurnOutcome) {
        let notes = outcome.notes
        let moment = notes.first { $0.hasPrefix("NIVEAU") }
            ?? notes.first { $0.contains("n°1") }.map { _ in "N°1 DU TOP GOSLO RADIO !" }
            ?? notes.first { $0.hasPrefix("Défi réussi") }.map { _ in "DÉFI RÉUSSI !" }
        guard let moment else { return }
        sound.play(.levelUp)
        Haptics.shared.play(.victory)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { celebration = moment }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(.easeIn(duration: 0.3)) { if celebration == moment { celebration = nil } }
        }
    }

    // MARK: - Interactions

    /// "A" button: talk to whoever is in front of you, or sit on the bench.
    func interact() {
        guard canMove, let map, var current = state else { return }
        if current.rapper.city == .casablanca, current.district == .bloc,
           OverworldRules.parkedTaxi.contains(position.moved(facing)) {
            talkToTaxi(current)
            return
        }
        // Secret: knock on the Bunker's wall, right next to its door, until a brick gives way.
        let front = position.moved(facing)
        if current.district == .bloc, !current.flags.contains(Secrets.archiveFlag), let studio = map.door(for: .studio),
           map.tile(at: front) == .wall, front.y == studio.y, abs(front.x - studio.x) == 1 {
            bunkerKnocks += 1
            sound.play(.tap)
            if bunkerKnocks >= Secrets.bunkerKnocks {
                current.flags.insert(Secrets.archiveFlag)
                state = current
                persist()
                sound.play(.quest)
                phase = .dialogue(speaker: nil, lines: Secrets.archiveLines)
            } else if bunkerKnocks == Secrets.bunkerKnocks / 2 {
                phase = .dialogue(speaker: nil, lines: ["Toc. Toc. Ce mur sonne creux…"])
            }
            return
        }
        if placingDecor == nil, let item = placedDecor(at: front) {
            inspect(item)
            return
        }
        switch OverworldRules.interaction(from: position, facing: facing, on: map) {
        case .npc(let npc) where npc.id == Philosopher.id:
            // goslo radio's philosopher reads your latest punchline.
            sound.play(.select)
            npcFacing[npc.id] = facing.opposite
            philosophyCard = engine.philosophyCard(in: current)
            let lines = engine.philosopherReading(in: &current)
            state = current
            persist()
            phase = .dialogue(speaker: engine.castMember(npc.id)?.name, lines: lines.map { TextTemplate.render($0, for: current.rapper) })
        case .npc(let npc) where npc.id == GameEngine.tournamentHostId && engine.storyEvent(forNPC: npc.id, in: current) == nil:
            // The radio host runs the Tournoi goslo radio (the story still comes first when it needs them):
            // a word from them, then the ladder.
            sound.play(.select)
            npcFacing[npc.id] = facing.opposite
            current.metCast.insert(npc.id)
            let lines = engine.smallTalk(with: npc.id, in: &current) + [AppModel.tournamentInvite]
            state = current
            tournamentAfterDialogue = true
            phase = .dialogue(speaker: engine.castMember(npc.id)?.name, lines: lines)
            persist()
        case .npc(let npc):
            sound.play(.select)
            npcFacing[npc.id] = facing.opposite
            let member = engine.castMember(npc.id)
            if engine.canVisit(current), let event = try? engine.talk(to: npc.id, in: &current, using: &rng) {
                state = current
                source = .npc(npc.id)
                phase = .encounter(event)
                persist()
            } else {
                let lines = engine.smallTalk(with: npc.id, in: &current)
                state = current
                phase = .dialogue(speaker: member?.name, lines: lines)
                persist()
            }
        case .bench:
            sound.play(.select)
            guard let event = try? engine.visit(.quartier, in: &current, using: &rng) else { return }
            state = current
            source = .bench
            phase = .encounter(event)
            persist()
        case .nothing:
            break
        }
    }

    /// Phone button: social media and DMs (1 action).
    func openPhone() {
        guard canMove, var current = state, let event = try? engine.visit(.reseaux, in: &current, using: &rng) else { return }
        sound.play(.select)
        state = current
        source = .phone
        phase = .encounter(event)
        persist()
    }

    // MARK: - Metro

    /// Stepping on a metro entrance: the metro map, or closed gates while only Le Bloc is open.
    private func openMetro() {
        guard let current = state else { return }
        sound.play(.door)
        if engine.openDistricts(in: current).count < 2 {
            let transit = Transit.of(current.rapper.city)
            phase = .dialogue(speaker: transit.name,
                              lines: transit.closedLines.map { TextTemplate.render($0, for: current.rapper) })
        } else {
            phase = .metro
        }
    }

    /// Casablanca: the petit taxi parked on the main road. Driss, its driver, has a word for you,
    /// and once other districts are open he takes you there.
    private func talkToTaxi(_ current: GameState) {
        sound.play(.select)
        let driss = engine.castMember("driss_taxi")
        let idle = driss?.idle ?? []
        var lines = idle.isEmpty ? [] : [idle[taxiTalks % idle.count]]
        taxiTalks += 1
        if engine.openDistricts(in: current).count > 1 {
            lines.append("Monte, je t'emmène où tu veux. Le compteur est cassé depuis 2009, c'est gratuit.")
            taxiRideOffered = true
        } else {
            lines.append("Le jour où t'auras des endroits où aller, {khoya|khti}, je t'y emmène. En attendant, je fais le tour du rond-point.")
        }
        phase = .dialogue(speaker: driss?.name ?? "Le taxi",
                          lines: lines.map { TextTemplate.render($0, for: current.rapper) })
    }

    /// Secret: the goslo radio poster in the studio, tapped enough times, plays the hidden jingle.
    func playSecretJingle() {
        sound.play(.radioJingle)
        Haptics.shared.play(.victory)
        guard var current = state, !current.flags.contains(Secrets.jingleFlag) else { return }
        current.flags.insert(Secrets.jingleFlag)
        state = current
        persist()
    }

    func closeMetro() {
        guard phase == .metro else { return }
        phase = .overworld
    }

    /// The HUD's metro button: the metro map from anywhere on the map (the engine only asks for an open district).
    var canTakeMetro: Bool { state.map { engine.openDistricts(in: $0).count > 1 } ?? false }

    func takeMetro() {
        guard canMove, canTakeMetro, placingDecor == nil else { return }
        heldDirection = nil
        briefing = nil
        sound.play(.door)
        phase = .metro
    }

    // MARK: - Period briefing

    /// A new period starts: a short card over the map, gone after a few seconds or on a tap.
    private func presentBriefing() {
        guard let summary = pendingBriefing, let current = state, !current.isOver else { return }
        pendingBriefing = nil
        let card = engine.periodBriefing(in: current, summary: summary)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { briefing = card }
        Task {
            try? await Task.sleep(for: .seconds(6))
            if briefing == card { dismissBriefing() }
        }
    }

    func dismissBriefing() {
        guard briefing != nil else { return }
        withAnimation(.easeIn(duration: 0.25)) { briefing = nil }
    }

    /// Rides to another district: the train crosses the screen, the district's card, then its station.
    func travel(to district: District) {
        guard phase == .metro, var current = state else { return }
        guard district != current.district else {
            phase = .overworld
            return
        }
        guard (try? engine.travel(to: district, in: &current)) != nil else { return }
        happening = nil
        placingDecor = nil
        movingDecorId = nil
        inspectedDecorId = nil
        let arrived = current
        busy = true
        heldDirection = nil
        Task {
            sound.play(.wipe)
            withAnimation(.easeIn(duration: 0.3)) { transition = .metro(district) }
            try? await Task.sleep(for: .milliseconds(1100))
            state = arrived
            position = arrived.position ?? position
            facing = .down
            walkFrame = 0
            resetNPCs()
            phase = .overworld
            persist()
            try? await Task.sleep(for: .milliseconds(1300))
            withAnimation(.easeOut(duration: 0.45)) { transition = nil }
            busy = false
            // First time here: the district's welcome scene.
            if var welcomed = state, let event = engine.arrivalEvent(in: &welcomed) {
                try? await Task.sleep(for: .milliseconds(450))
                state = welcomed
                source = event.npc.map { .npc($0) } ?? .bench
                phase = .encounter(event)
                persist()
            }
        }
    }

    private func enter(_ door: MapDoor) async {
        guard var current = state else { return }
        busy = true
        sound.play(door.location == .media ? .radioJingle : .door)
        withAnimation(.easeIn(duration: 0.25)) { transition = .fade }
        try? await Task.sleep(for: .milliseconds(280))
        if let event = try? engine.visit(door.location, in: &current, using: &rng) {
            state = current
            source = .building(door)
            phase = .encounter(event)
            persist()
        } else {
            position = door.point.moved(.down)
            facing = .down
        }
        withAnimation(.easeOut(duration: 0.3)) { transition = nil }
        busy = false
    }

    private func challenge(by rival: MapNPC) async {
        busy = true
        exclaiming = rival.id
        sound.play(.exclaim)
        try? await Task.sleep(for: .milliseconds(700))
        exclaiming = nil
        for tile in OverworldRules.approach(of: rival, to: position) {
            npcWalkFrame[rival.id] = npcWalkFrame[rival.id] == 1 ? 2 : 1
            withAnimation(.linear(duration: AppModel.stepSeconds)) { npcPositions[rival.id] = tile }
            try? await Task.sleep(for: AppModel.stepDuration)
        }
        npcWalkFrame[rival.id] = 0
        facing = rival.facing.opposite
        guard var current = state, let event = try? engine.talk(to: rival.id, challenge: true, in: &current, using: &rng) else {
            busy = false
            return
        }
        state = current
        source = .npc(rival.id)
        phase = .encounter(event)
        busy = false
        persist()
    }

    private func startWild() async {
        guard var current = state, let clash = engine.startWildClash(in: &current, using: &rng) else { return }
        busy = true
        state = current
        sound.play(.wipe)
        withAnimation(.easeIn(duration: 0.5)) { transition = .battle }
        try? await Task.sleep(for: .milliseconds(650))
        source = .wild
        phase = .clash(clash)
        withAnimation(.easeOut(duration: 0.4)) { transition = nil }
        busy = false
        persist()
    }

    // MARK: - Tournoi goslo radio

    /// Opens the Tournoi's ladder.
    func openTournament() {
        guard state != nil, dailyClash == nil, arcadePlaying == nil else { return }
        sound.play(.radioJingle)
        showingTournament = true
    }

    /// Challenges a Tournoi boss: one action, then the clash, like a story clash. `finishClash` records the win.
    func startTournament(_ opponentId: String) {
        guard dailyClash == nil, arcadePlaying == nil, phase == .overworld, !busy, var current = state,
              let clash = try? engine.startTournamentClash(opponentId, in: &current) else { return }
        showingTournament = false
        state = current
        source = nil
        philosophyCard = nil
        persist()
        busy = true
        Task {
            // Let the sheet slide away before the battle wipe.
            try? await Task.sleep(for: .milliseconds(350))
            sound.play(.wipe)
            withAnimation(.easeIn(duration: 0.5)) { transition = .battle }
            try? await Task.sleep(for: .milliseconds(650))
            phase = .clash(clash)
            withAnimation(.easeOut(duration: 0.4)) { transition = nil }
            busy = false
        }
    }

    // MARK: - Encounters & clashes

    func choose(_ choiceIndex: Int) {
        guard var current = state, case .encounter(let event) = phase else { return }
        let before = current.stats
        guard let resolution = try? engine.resolve(choiceAt: choiceIndex, in: &current) else { return }
        sound.play(.select)
        state = current
        publishDeltas(from: before, to: current.stats)

        switch resolution {
        case .clash(let clash):
            Task {
                busy = true
                sound.play(.wipe)
                withAnimation(.easeIn(duration: 0.5)) { transition = .battle }
                try? await Task.sleep(for: .milliseconds(650))
                phase = .clash(clash)
                withAnimation(.easeOut(duration: 0.4)) { transition = nil }
                busy = false
            }
            persist()
        case .interview(let running):
            phase = .interview(running)
            persist()
        case .concert(let running):
            phase = .concert(running)
            persist()
        case .negotiation(let running):
            phase = .negotiation(running)
            persist()
        case .writing(let running):
            phase = .writing(running)
            persist()
        case .minigame(let running):
            phase = .minigame(running)
            persist()
        case .outcome(let outcome):
            show(outcome, for: event)
        }
    }

    // MARK: - Interviews

    /// Answers the current question (nil = ran out of time).
    @discardableResult
    func answerInterview(_ answerIndex: Int?) -> InterviewState? {
        guard var current = state, case .interview = phase else { return nil }
        let before = current.stats
        guard let running = try? engine.answerInterview(answerIndex, in: &current) else { return nil }
        state = current
        publishDeltas(from: before, to: current.stats)
        phase = .interview(running)
        persist()
        return running
    }

    // MARK: - Concerts

    /// Commits a played song (the concert screen plays the song itself).
    @discardableResult
    func concertSongFinished(_ judgments: [ConcertJudgment]) -> ConcertState? {
        guard var current = state, case .concert = phase else { return nil }
        guard let running = try? engine.concertSongFinished(judgments, in: &current) else { return nil }
        state = current
        phase = .concert(running)
        persist()
        return running
    }

    /// Answers a crowd interlude. Returns the reaction.
    func concertInterlude(_ option: Int) -> String? {
        guard var current = state, case .concert = phase else { return nil }
        guard let reaction = try? engine.concertInterlude(option, in: &current) else { return nil }
        state = current
        if let running = current.concert { phase = .concert(running) }
        persist()
        return reaction
    }

    func finishConcert() {
        guard var current = state, case .concert(let running) = phase else { return }
        if let game = arcadePlaying {
            finishArcade(game, score: running.hype)
            return
        }
        let before = current.stats
        guard let outcome = try? engine.finishConcert(in: &current) else { return }
        state = current
        publishDeltas(from: before, to: current.stats)
        show(outcome, for: nil)
    }

    // MARK: - Negotiations

    @discardableResult
    func negotiate(_ option: Int) -> NegotiationState? {
        guard var current = state, case .negotiation = phase else { return nil }
        guard let running = try? engine.negotiate(option, in: &current) else { return nil }
        state = current
        phase = .negotiation(running)
        persist()
        return running
    }

    // MARK: - Writing sessions

    @discardableResult
    func writingAttack() -> WritingState? {
        guard var current = state, case .writing = phase else { return nil }
        guard let running = try? engine.writingAttack(in: &current) else { return nil }
        state = current
        phase = .writing(running)
        persist()
        return running
    }

    @discardableResult
    func writeLine(_ option: Int?) -> WritingState? {
        guard var current = state, case .writing = phase else { return nil }
        guard let running = try? engine.writeLine(option, in: &current) else { return nil }
        state = current
        phase = .writing(running)
        persist()
        return running
    }

    func finishWriting() {
        guard var current = state, case .writing = phase else { return }
        let before = current.stats
        guard let outcome = try? engine.finishWriting(in: &current) else { return }
        state = current
        publishDeltas(from: before, to: current.stats)
        show(outcome, for: nil)
    }

    func finishNegotiation() {
        guard var current = state, case .negotiation = phase else { return }
        let before = current.stats
        guard let outcome = try? engine.finishNegotiation(in: &current) else { return }
        state = current
        publishDeltas(from: before, to: current.stats)
        show(outcome, for: nil)
    }

    func finishInterview() {
        guard var current = state, case .interview = phase else { return }
        let before = current.stats
        guard let outcome = try? engine.finishInterview(in: &current) else { return }
        state = current
        publishDeltas(from: before, to: current.stats)
        show(outcome, for: nil)
    }

    /// Plays a round. Returns the updated clash (the battle screen animates it).
    @discardableResult
    func clashMove(_ move: ClashMove) -> ClashState? {
        guard var current = state, case .clash = phase else { return nil }
        let before = current.stats
        guard let clash = try? engine.clashMove(move, in: &current, using: &rng) else { return nil }
        state = current
        publishDeltas(from: before, to: current.stats)
        phase = .clash(clash)
        persist()
        return clash
    }

    /// Releases an album from the notebook.
    @discardableResult
    func releaseAlbum(title: String, trackIds: [String], cover: AlbumCover) -> Album? {
        guard var current = state else { return nil }
        let before = current.stats
        guard let album = try? engine.releaseAlbum(title: title, trackIds: trackIds, cover: cover, in: &current) else { return nil }
        state = current
        publishDeltas(from: before, to: current.stats)
        sound.play(.levelUp)
        Haptics.shared.play(.victory)
        persist()
        return album
    }

    /// Freestyle: the rhymes chained in the overlay.
    @discardableResult
    func clashFreestyle(rhymes: Int) -> ClashState? {
        guard var current = state, case .clash = phase else { return nil }
        guard let clash = try? engine.clashFreestyle(rhymes: rhymes, in: &current, using: &rng) else { return nil }
        state = current
        phase = .clash(clash)
        persist()
        return clash
    }

    /// Triggers the secret technique (gauge full), charged in rhythm at `charge` (0…1).
    @discardableResult
    func clashSecret(charge: Double? = nil) -> ClashState? {
        guard var current = state, case .clash = phase else { return nil }
        guard let clash = try? engine.clashSecret(charge: charge, in: &current, using: &rng) else { return nil }
        state = current
        phase = .clash(clash)
        persist()
        return clash
    }

    // MARK: - Mini-games

    /// Punchliner: drops the chosen ending (nil = time ran out). Returns the reaction.
    @discardableResult
    func dropPunchline(_ choice: Int?) -> String? {
        guard var current = state, case .minigame = phase else { return nil }
        guard let reaction = try? engine.dropPunchline(choice, in: &current) else { return nil }
        state = current
        if let running = current.minigame { phase = .minigame(running) }
        persist()
        recordPunchlinerIfOver()
        return reaction
    }

    /// The Punchliner game just ended (story or arcade): its score and rhymes go into the personal records.
    private func recordPunchlinerIfOver() {
        guard let running = state?.minigame, running.kind == .punchliner, running.isOver else { return }
        let score = Int((engine.minigameScore(running) * 100).rounded())
        guard let broken = profile.recordPunchliner(running, score: score) else { return }
        punchlinerBreak = broken
        store.saveProfile(profile)
    }

    /// The French dictionary (nil if the file is missing). Read off the main thread, once.
    func frenchDictionary() async -> FrenchDictionary? {
        if dictionaryTask == nil {
            dictionaryTask = Task.detached(priority: .userInitiated) { try? EventLoader.loadDictionary(bundle: .main) }
        }
        return await dictionaryTask?.value
    }

    /// Punchliner: the player typed their own ending. Returns how it was judged.
    func dropWrittenPunchline(_ text: String, dictionary: FrenchDictionary) -> WrittenEnding? {
        guard var current = state, case .minigame = phase else { return nil }
        guard let written = try? engine.dropWrittenPunchline(text, dictionary: dictionary, in: &current) else { return nil }
        state = current
        if let running = current.minigame { phase = .minigame(running) }
        persist()
        recordPunchlinerIfOver()
        return written
    }

    /// Cale la platine: stops the fader `elapsed` seconds into the run.
    func stopPlatine(after elapsed: Double) -> (pitch: Double, reaction: String)? {
        guard var current = state, case .minigame = phase else { return nil }
        guard let result = try? engine.stopPlatine(after: elapsed, in: &current) else { return nil }
        state = current
        if let running = current.minigame { phase = .minigame(running) }
        persist()
        return result
    }

    /// The studio: records and releases a single (1 action), then shows how it went.
    @discardableResult
    func releaseSingle(sourceId: String, perfectTakes: Int, clip: Bool, feat: String?) -> Bool {
        guard var current = state, canMove else { return false }
        let before = current.stats
        guard let outcome = try? engine.releaseSingle(sourceId: sourceId, perfectTakes: perfectTakes, clip: clip,
                                                      feat: feat, in: &current) else { return false }
        state = current
        publishDeltas(from: before, to: current.stats)
        sound.play(.levelUp)
        show(outcome, for: nil)
        return true
    }

    /// The shop's clothes: buys a piece and puts it on.
    @discardableResult
    func buy(_ item: Wearable) -> String? {
        guard var current = state else { return "Pas de carrière en cours" }
        if let refusal = Wardrobe.refusal(item, in: current) { return refusal }
        let before = current.stats
        guard (try? engine.buy(item, in: &current)) != nil else { return "Impossible pour l'instant" }
        state = current
        publishDeltas(from: before, to: current.stats)
        sound.play(.statUp)
        Haptics.shared.play(.good)
        persist()
        return nil
    }

    /// Puts on (or takes off) an owned piece.
    func wear(_ item: Wearable) {
        guard var current = state else { return }
        engine.wear(item, in: &current)
        state = current
        sound.play(.select)
        persist()
    }

    // MARK: - Construction mode

    /// Where the decoration being placed would go: in front of the player.
    var placementAnchor: TilePoint? {
        placingDecor.map { GameEngine.placementAnchor(for: $0, front: position.moved(facing), facing: facing) }
    }

    /// Why it can't go there (nil: it can).
    var placementRefusal: String? {
        guard let decor = placingDecor, let anchor = placementAnchor, let state else { return "—" }
        return engine.placementRefusal(decor, at: anchor, in: state, player: position, moving: movingDecorId)
    }

    /// What putting it there would start with the neighbours (shown under the ghost's verdict).
    var placementSynergies: [String] {
        guard let decor = placingDecor, let anchor = placementAnchor, let state else { return [] }
        return engine.placementSynergies(decor, at: anchor, in: state, moving: movingDecorId)
    }

    /// From the shop: walk around with the decoration in front of you, then put it down.
    func beginPlacing(_ decor: Decor) {
        sound.play(.select)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { placingDecor = decor }
    }

    func cancelPlacing() {
        withAnimation(.easeOut(duration: 0.2)) { placingDecor = nil; movingDecorId = nil }
    }

    /// Buys the decoration and puts it down where it stands. Returns why not, nil when done.
    @discardableResult
    func confirmPlacing() -> String? {
        guard let decor = placingDecor, let anchor = placementAnchor, var current = state else { return "—" }
        if let refusal = engine.placementRefusal(decor, at: anchor, in: current, player: position, moving: movingDecorId) {
            sound.play(.miss)
            return refusal
        }
        if let moving = movingDecorId {
            guard (try? engine.move(moving, to: anchor, in: &current, player: position)) != nil else { return "Impossible" }
            state = current
            sound.play(.select)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { placingDecor = nil; movingDecorId = nil }
            persist()
            return nil
        }
        let before = current.stats
        guard (try? engine.place(decor, at: anchor, in: &current, player: position)) != nil else { return "Impossible" }
        state = current
        publishDeltas(from: before, to: current.stats)
        sound.play(.levelUp)
        Haptics.shared.play(.victory)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { placingDecor = nil }
        persist()
        return nil
    }

    // MARK: - Your buildings

    /// The placed decoration on the tile in front of the player, if any.
    func placedDecor(at point: TilePoint) -> PlacedDecor? {
        state?.placed.first { $0.district == state?.district && $0.tiles.contains(point) }
    }

    var inspectedDecor: PlacedDecor? {
        inspectedDecorId.flatMap { id in state?.placed.first { $0.id == id } }
    }

    /// Walking up to one of your decorations: the money it made goes straight in your pocket,
    /// and its card opens (upgrade, move, sell).
    func inspect(_ item: PlacedDecor) {
        guard var current = state else { return }
        if item.stored > 0 {
            let before = current.stats
            let amount = engine.collect(item.id, in: &current)
            state = current
            publishDeltas(from: before, to: current.stats)
            if amount > 0 {
                sound.play(.statUp)
                Haptics.shared.play(.good)
            }
            persist()
        } else {
            sound.play(.select)
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { inspectedDecorId = item.id }
    }

    func closeInspected() {
        withAnimation(.easeOut(duration: 0.2)) { inspectedDecorId = nil }
    }

    func upgradeRefusal(_ item: PlacedDecor) -> String? {
        state.flatMap { engine.upgradeRefusal(item.id, in: $0) }
    }

    /// Upgrades the building being looked at. Returns why not, nil when done.
    @discardableResult
    func upgradeInspected() -> String? {
        guard let id = inspectedDecorId, var current = state else { return "—" }
        if let refusal = engine.upgradeRefusal(id, in: current) { return refusal }
        let before = current.stats
        guard (try? engine.upgrade(id, in: &current)) != nil else { return "Impossible" }
        state = current
        publishDeltas(from: before, to: current.stats)
        sound.play(.levelUp)
        Haptics.shared.play(.victory)
        if let item = current.placed.first(where: { $0.id == id }) {
            celebration = "\(item.decor.name.uppercased()) · NIVEAU \(item.level)"
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation { celebration = nil }
            }
        }
        persist()
        return nil
    }

    /// Sells the decoration being looked at: half of what it cost comes back.
    func sellInspected() {
        guard let id = inspectedDecorId, var current = state else { return }
        let before = current.stats
        engine.sell(id, in: &current)
        state = current
        publishDeltas(from: before, to: current.stats)
        sound.play(.statUp)
        withAnimation(.easeOut(duration: 0.2)) { inspectedDecorId = nil }
        persist()
    }

    /// Picks the decoration up to put it somewhere else (free).
    func moveInspected() {
        guard let item = inspectedDecor else { return }
        sound.play(.select)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            inspectedDecorId = nil
            movingDecorId = item.id
            placingDecor = item.decor
        }
    }

    /// Buys goslo radio.
    @discardableResult
    func buyRadio() -> String? {
        guard var current = state else { return "Pas de carrière en cours" }
        if let refusal = RadioDeal.refusal(in: current) { return refusal }
        let before = current.stats
        guard (try? engine.buyRadio(in: &current)) != nil else { return "Impossible" }
        state = current
        publishDeltas(from: before, to: current.stats)
        celebration = "GOSLO RADIO EST À TOI !"
        sound.play(.victory)
        Haptics.shared.play(.victory)
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation { celebration = nil }
        }
        persist()
        return nil
    }

    /// The shop's decorations: buys one and puts it on a free spot of the map.
    @discardableResult
    func placeDecor(_ decor: Decor, plot: String) -> String? {
        guard var current = state else { return "Pas de carrière en cours" }
        if let refusal = engine.decorRefusal(decor, plot: plot, in: current) { return refusal }
        let before = current.stats
        guard (try? engine.placeDecor(decor, plot: plot, in: &current)) != nil else { return "Impossible pour l'instant" }
        state = current
        publishDeltas(from: before, to: current.stats)
        sound.play(.levelUp)
        Haptics.shared.play(.good)
        persist()
        return nil
    }

    /// The shop: buys an offer. Returns why it failed, nil when it went through.
    @discardableResult
    func buy(_ offer: ShopOffer) -> String? {
        guard var current = state else { return "Pas de carrière en cours" }
        if let refusal = Shop.refusal(offer, in: current) { return refusal }
        let before = current.stats
        guard (try? engine.buy(offer, in: &current)) != nil else { return "Impossible pour l'instant" }
        state = current
        publishDeltas(from: before, to: current.stats)
        sound.play(.statUp)
        persist()
        return nil
    }

    /// Beatbox Simon: the pattern was played back (or not).
    func beatbox(repeated: Bool) {
        guard var current = state, case .minigame = phase else { return }
        guard (try? engine.beatbox(repeated: repeated, in: &current)) != nil else { return }
        state = current
        if let running = current.minigame { phase = .minigame(running) }
        persist()
    }

    /// Fuir la foule: the chase is over.
    func endChase(escaped: Bool) {
        guard var current = state, case .minigame = phase else { return }
        guard (try? engine.endChase(escaped: escaped, in: &current)) != nil else { return }
        state = current
        if let running = current.minigame { phase = .minigame(running) }
        persist()
    }

    /// Auditions: signs these artists.
    func sign(_ ids: [String]) {
        guard var current = state, case .minigame = phase else { return }
        guard (try? engine.sign(ids, in: &current)) != nil else { return }
        state = current
        if let running = current.minigame { phase = .minigame(running) }
        persist()
    }

    func finishMinigame() {
        guard var current = state, case .minigame(let running) = phase else { return }
        if let game = arcadePlaying {
            finishArcade(game, score: Arcade.score(of: running, engine: engine))
            return
        }
        let before = current.stats
        guard let outcome = try? engine.finishMinigame(in: &current) else { return }
        state = current
        publishDeltas(from: before, to: current.stats)
        show(outcome, for: nil)
    }

    /// Notebook: picks the secret technique used in clashes.
    func equipTechnique(_ id: String) {
        guard var current = state else { return }
        engine.equipTechnique(id, in: &current)
        state = current
        persist()
    }

    /// The player tapped against a boss's technique: it lands, softened.
    @discardableResult
    func counterSecret(taps: Int) -> ClashState? {
        guard var current = state, case .clash = phase else { return nil }
        guard let clash = try? engine.counterSecret(taps: taps, in: &current) else { return nil }
        state = current
        phase = .clash(clash)
        persist()
        return clash
    }

    func finishClash() {
        guard var current = state, case .clash = phase else { return }
        if let challenge = dailyClash {
            finishDaily(challenge, won: current.clash?.playerWon ?? false)
            return
        }
        let before = current.stats
        guard let outcome = try? engine.finishClash(in: &current) else { return }
        state = current
        publishDeltas(from: before, to: current.stats)
        show(outcome, for: nil)
    }

    func flee() {
        guard var current = state, engine.fleeWildClash(in: &current) else { return }
        state = current
        source = nil
        phase = .dialogue(speaker: nil, lines: ["Tu t'éclipses avant que ça dégénère. Personne n'a rien filmé. Normalement."])
        persist()
    }

    /// Next step after a line of dialogue or a consequence.
    func advance() {
        switch phase {
        case .dialogue:
            philosophyCard = nil
            if tournamentAfterDialogue {
                tournamentAfterDialogue = false
                phase = .overworld
                openTournament()
            } else if taxiRideOffered {
                // Driss drives you: same destinations as the tram.
                taxiRideOffered = false
                phase = .metro
            } else {
                phase = .overworld
            }
        case .consequence:
            continueAfterConsequence()
        default:
            break
        }
    }

    private func continueAfterConsequence() {
        if let record = finishedRecord {
            state = nil
            finishedRecord = nil
            route = .ending(record)
            return
        }
        guard var current = state else { return }
        if let followUp = engine.takeFollowUp(in: &current) {
            state = current
            phase = .encounter(followUp)
            persist()
            return
        }
        Task { await backToStreet() }
    }

    private func backToStreet() async {
        busy = true
        if case .building(let door) = source {
            withAnimation(.easeIn(duration: 0.25)) { transition = .fade }
            try? await Task.sleep(for: .milliseconds(280))
            position = door.point.moved(.down)
            facing = .down
            source = nil
            phase = .overworld
            withAnimation(.easeOut(duration: 0.3)) { transition = nil }
        } else {
            source = nil
            phase = .overworld
        }
        resetNPCs()
        if var current = state {
            current.position = position
            current.facing = facing
            state = current
        }
        if pendingSemesterCard, let state {
            pendingSemesterCard = false
            sound.play(.semester)
            withAnimation(.easeInOut(duration: 0.4)) { transition = .semester(title: state.periodLabel, subtitle: state.semesterCardLabel) }
            try? await Task.sleep(for: .milliseconds(1900))
            withAnimation(.easeInOut(duration: 0.5)) { transition = nil }
        }
        busy = false
        persist()
        await playPendingCinematic()
        presentBriefing()
    }

    // MARK: - Cinematics

    /// Tap during a cinematic: next line.
    func advanceCinematic() {
        guard let waiter = captionWaiter else { return }
        captionWaiter = nil
        waiter.resume()
    }

    private func playPendingCinematic() async {
        guard phase == .overworld, let id = state?.pendingCinematic, let cinematic = engine.story.cinematic(id) else { return }
        await play(cinematic)
    }

    private func play(_ cinematic: Cinematic) async {
        busy = true
        heldDirection = nil
        if var current = state, engine.stageCinematic(cinematic, in: &current) {
            // The scene happens in Le Bloc: back home first.
            state = current
            position = current.position ?? position
            facing = current.facing
            resetNPCs()
        }
        phase = .cinematic
        withAnimation(.easeInOut(duration: 0.45)) { letterbox = true }
        try? await Task.sleep(for: .milliseconds(450))
        for step in cinematic.steps where step.plays(in: state) {
            guard route == .game else { return }
            await perform(step)
        }
        caption = nil
        withAnimation(.easeInOut(duration: 0.45)) {
            letterbox = false
            cameraFocus = nil
        }
        extraActors = [:]
        resetNPCs()
        if var current = state {
            engine.cinematicFinished(cinematic.id, in: &current)
            current.position = position
            current.facing = facing
            state = current
            if current.isOver {
                // The finale's outro ends the career.
                let record = CareerRecord(state: current)
                history.insert(record, at: 0)
                store.saveHistory(history)
                checkAchievements(in: current)
                rewardHQ(for: current)
                store.clearCurrentRun()
                busy = false
                phase = .overworld
                state = nil
                route = .ending(record)
                return
            }
        }
        phase = state?.finaleChoicePending == true ? .finaleChoice : .overworld
        busy = false
        persist()
        // A new chapter's intro can follow an outro.
        if let next = state?.pendingCinematic, next != cinematic.id {
            await playPendingCinematic()
        }
    }

    private func perform(_ step: CinematicStep) async {
        guard let rapper = state?.rapper else { return }
        if let text = step.narration {
            await show(.narration, TextTemplate.render(text, for: rapper))
        } else if let line = step.say {
            let speaker = actor(line.who)
            await show(.speech(name: speaker.name, look: speaker.look), TextTemplate.render(line.text, for: rapper))
        } else if let title = step.title {
            sound.play(.semester)
            await show(.title(subtitle: title.subtitle.map { TextTemplate.render($0, for: rapper) }),
                       TextTemplate.render(title.text, for: rapper), autoAdvance: 3.2)
        } else if let target = step.move {
            await walk(target.who, to: target.point)
            if let facing = target.facing { turn(target.who, to: facing) }
        } else if let target = step.place {
            place(target)
        } else if let who = step.despawn {
            extraActors[who] = nil
            hiddenActors.insert(who)
        } else if let face = step.face {
            turn(face.who, to: face.facing)
        } else if let who = step.exclaim {
            exclaiming = who
            sound.play(.exclaim)
            try? await Task.sleep(for: .milliseconds(800))
            exclaiming = nil
        } else if let point = step.camera {
            withAnimation(.easeInOut(duration: 0.8)) { cameraFocus = point }
            try? await Task.sleep(for: .milliseconds(850))
        } else if step.cameraReset == true {
            withAnimation(.easeInOut(duration: 0.8)) { cameraFocus = nil }
            try? await Task.sleep(for: .milliseconds(850))
        } else if let fade = step.fade {
            withAnimation(.easeInOut(duration: 0.4)) { transition = fade ? .fade : nil }
            try? await Task.sleep(for: .milliseconds(450))
        } else if let seconds = step.wait {
            try? await Task.sleep(for: .seconds(seconds))
        } else if let name = step.sound, let effect = SoundEffect(rawValue: name) {
            sound.play(effect)
        }
    }

    /// Shows a caption and waits for the tap (or the timer for titles).
    private func show(_ kind: CinematicCaption.Kind, _ text: String, autoAdvance: Double? = nil) async {
        captionSerial += 1
        let serial = captionSerial
        withAnimation(.easeOut(duration: 0.25)) { caption = CinematicCaption(kind: kind, text: text, id: serial) }
        if let autoAdvance {
            Task {
                try? await Task.sleep(for: .seconds(autoAdvance))
                if captionSerial == serial { advanceCinematic() }
            }
        }
        await withCheckedContinuation { captionWaiter = $0 }
        withAnimation(.easeIn(duration: 0.15)) { caption = nil }
        try? await Task.sleep(for: .milliseconds(150))
    }

    private func actor(_ who: String) -> (name: String, look: CharacterLook) {
        if who == "player", let rapper = state?.rapper { return (rapper.name, rapper.look) }
        let member = engine.castMember(who)
        return (member?.name ?? who, member?.look ?? CharacterLook())
    }

    private func isOnMap(_ who: String) -> Bool { map?.npcs.contains { $0.id == who } ?? false }

    private func place(_ target: CinematicStep.Placement) {
        if target.who == "player" {
            position = target.point
            if let facing = target.facing { self.facing = facing }
            return
        }
        hiddenActors.remove(target.who)
        if isOnMap(target.who) {
            npcPositions[target.who] = target.point
        } else {
            extraActors[target.who] = target.point
        }
        if let facing = target.facing { npcFacing[target.who] = facing }
    }

    private func turn(_ who: String, to direction: Direction) {
        if who == "player" { facing = direction } else { npcFacing[who] = direction }
    }

    /// Walks in straight lines: x first, then y.
    private func walk(_ who: String, to target: TilePoint) async {
        let isPlayer = who == "player"
        var current = isPlayer ? position : (extraActors[who] ?? npcPositions[who] ?? target)
        while current != target {
            let direction: Direction = current.x != target.x
                ? (target.x > current.x ? .right : .left)
                : (target.y > current.y ? .down : .up)
            current = current.moved(direction)
            let point = current
            if isPlayer {
                facing = direction
                walkFrame = walkFrame == 1 ? 2 : 1
                sound.play(.step)
                withAnimation(.linear(duration: AppModel.stepSeconds)) { position = point }
            } else {
                npcFacing[who] = direction
                npcWalkFrame[who] = npcWalkFrame[who] == 1 ? 2 : 1
                withAnimation(.linear(duration: AppModel.stepSeconds)) {
                    if extraActors[who] != nil { extraActors[who] = point } else { npcPositions[who] = point }
                }
            }
            try? await Task.sleep(for: AppModel.stepDuration)
        }
        if isPlayer { walkFrame = 0 } else { npcWalkFrame[who] = 0 }
    }

    // MARK: - goslo radio

    /// Every now and then, a "Flash goslo radio" headline scrolls across the top of the map.
    private func startRadio() {
        radioTask?.cancel()
        radioTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            while !Task.isCancelled {
                guard let self else { return }
                if self.phase == .overworld, self.transition == nil, let state = self.state {
                    let options = self.engine.radioHeadlines(in: state).filter { $0 != self.lastHeadline }
                    if let pick = options.randomElement() {
                        self.lastHeadline = pick
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            self.radioHeadline = TextTemplate.render(pick, for: state.rapper)
                        }
                        try? await Task.sleep(for: .seconds(11))
                        withAnimation(.easeIn(duration: 0.3)) { self.radioHeadline = nil }
                    }
                }
                try? await Task.sleep(for: .seconds(26))
            }
        }
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        store.saveHistory(history)
    }

    // MARK: - Private

    private func show(_ outcome: TurnOutcome, for event: GameEvent?) {
        guard let current = state else { return }
        phase = .consequence(event, outcome)
        celebrate(outcome)
        // The year card: once a year, not every turn.
        if outcome.semesterEnded, state?.isNewYear == true { pendingSemesterCard = true }
        if outcome.semesterEnded, outcome.ending == nil { pendingBriefing = .some(outcome.period) }
        playOutcomeSound(outcome)
        if outcome.ending != nil {
            // Archive immediately so nothing is lost if the app is killed.
            let record = CareerRecord(state: current)
            finishedRecord = record
            history.insert(record, at: 0)
            store.saveHistory(history)
            store.clearCurrentRun()
            checkAchievements(in: current)
            rewardHQ(for: current)
        } else {
            persist()
        }
    }

    /// The most notable thing that happened wins: quest > level up > overall stat direction.
    private func playOutcomeSound(_ outcome: TurnOutcome) {
        if let writing = outcome.writing {
            sound.play(writing.passed ? .victory : .defeat)
        } else if let negotiation = outcome.negotiation {
            sound.play(negotiation.passed ? .victory : .defeat)
        } else if let concert = outcome.concert {
            sound.play(concert.passed ? .victory : .defeat)
        } else if let interview = outcome.interview {
            sound.play(interview.passed ? .victory : .defeat)
        } else if !outcome.completedQuests.isEmpty || !outcome.completedObjectives.isEmpty {
            sound.play(.quest)
        } else if !outcome.levelUps.isEmpty {
            sound.play(.levelUp)
        } else if outcome.clash == nil, outcome.ending == nil {
            let total = outcome.deltas.values.reduce(0, +)
            if total > 0 { sound.play(.statUp) } else if total < 0 { sound.play(.statDown) }
        }
    }

    private func publishDeltas(from before: Stats, to after: Stats) {
        var deltas: [StatKind: Int] = [:]
        for kind in StatKind.allCases where after[kind] != before[kind] {
            deltas[kind] = after[kind] - before[kind]
        }
        guard !deltas.isEmpty else { return }
        lastDeltas = deltas
        deltaToken += 1
    }

    /// A clash tip has been read: it won't show again this career.
    func learn(_ tip: ClashTip) {
        guard var current = state else { return }
        current.flags.insert(tip.flag)
        state = current
        persist()
    }

    // MARK: - Daily clash

    /// Today's daily clash (the same for every player).
    var dailyToday: DailyChallenge? { engine.dailyChallenge() }
    var canPlayDaily: Bool { dailyToday.map { profile.daily.canPlay(on: $0.day) } ?? false }
    var dailyStreak: Int {
        profile.daily.currentStreak(today: DailyClash.dayKey(Date()), yesterday: DailyClash.yesterdayKey(Date()))
    }

    /// Starts today's clash. The attempt counts as soon as it starts: quitting doesn't give a second go.
    func startDailyClash() {
        guard dailyClash == nil, let challenge = dailyToday, profile.daily.canPlay(on: challenge.day) else { return }
        profile.daily.start(on: challenge.day)
        store.saveProfile(profile)
        careerAside = state
        let rapper = state?.rapper ?? history.last?.rapper ?? Rapper(name: "MC Personne", city: .paris, style: .boomBap)
        let game = engine.dailyGame(challenge, rapper: rapper)
        state = game
        dailyClash = challenge
        source = nil
        philosophyCard = nil
        if let clash = game.clash { phase = .clash(clash) }
        sound.play(.select)
        route = .game
    }

    private func finishDaily(_ challenge: DailyChallenge, won: Bool) {
        profile.daily.finish(on: challenge.day, won: won, yesterday: DailyClash.yesterdayKey(Date()))
        store.saveProfile(profile)
        state = careerAside
        careerAside = nil
        dailyClash = nil
        source = nil
        phase = .overworld
        route = .home
    }

    // MARK: - HQ

    /// A finished career brings gold records home.
    private func rewardHQ(for career: GameState) {
        let discs = HQ.reward(for: career)
        profile.hq.discs += discs
        profile.hq.earned += discs
        profile.hq.lastReward = discs
        store.saveProfile(profile)
    }

    /// Builds or improves a room of the laverie.
    @discardableResult
    func upgrade(_ room: HQRoom) -> Bool {
        guard HQ.upgrade(room, in: &profile.hq) else { return false }
        store.saveProfile(profile)
        sound.play(.levelUp)
        Haptics.shared.play(.victory)
        return true
    }

    // MARK: - Arcade

    func isUnlocked(_ game: ArcadeGame) -> Bool { Arcade.isUnlocked(game, in: profile) }

    /// Starts an arcade mini-game in a throwaway game. The freestyle has no game: the arcade screen plays it.
    func startArcade(_ game: ArcadeGame) {
        guard dailyClash == nil, arcadePlaying == nil, isUnlocked(game), game.mode != .freestyle else { return }
        let rapper = state?.rapper ?? history.last?.rapper ?? Rapper(name: "MC Personne", city: .paris, style: .boomBap)
        guard let sandbox = engine.arcadeGame(game, rapper: rapper) else { return }
        careerAside = state
        state = sandbox
        arcadePlaying = game
        source = nil
        philosophyCard = nil
        if let running = sandbox.minigame { phase = .minigame(running) }
        if let running = sandbox.concert { phase = .concert(running) }
        sound.play(.select)
        route = .game
    }

    /// Keeps the record of an arcade game.
    func recordArcade(_ game: ArcadeGame, score: Int) {
        profile.record(arcade: game, score: score)
        store.saveProfile(profile)
    }

    private func finishArcade(_ game: ArcadeGame, score: Int) {
        recordArcade(game, score: score)
        state = careerAside
        careerAside = nil
        arcadePlaying = nil
        source = nil
        phase = .overworld
        route = .arcade
    }

    func persist() {
        // The daily clash is a throwaway game: never saved over the career.
        guard dailyClash == nil, arcadePlaying == nil else { return }
        guard var current = state, !current.isOver, finishedRecord == nil else { return }
        current.position = position
        current.facing = facing
        state = current
        stepsSinceSave = 0
        store.saveCurrentRun(current)
        checkAchievements(in: current)
    }

    // MARK: - Hanging up the mic

    var canRetire: Bool {
        guard let state, phase == .overworld || phase == .finaleChoice, transition == nil, !busy else { return false }
        return engine.canRetire(state)
    }

    /// Ends the career now: the ending its stats and story give, then the ending screen.
    func retire() {
        guard canRetire, var current = state, (try? engine.retire(in: &current)) != nil else { return }
        let record = CareerRecord(state: current)
        history.insert(record, at: 0)
        store.saveHistory(history)
        store.clearCurrentRun()
        checkAchievements(in: current)
        rewardHQ(for: current)
        heldDirection = nil
        radioTask?.cancel()
        radioHeadline = nil
        finishedRecord = nil
        state = nil
        phase = .overworld
        route = .ending(record)
    }

    /// After the finale: the career goes on, and the new generation comes for your crown.
    func keepGoing() {
        guard phase == .finaleChoice, var current = state else { return }
        engine.keepGoing(in: &current)
        state = current
        persist()
        sound.play(.exclaim)
        phase = .dialogue(speaker: nil, lines: [
            "Une nouvelle génération débarque au Bloc : filtres chien, refrains de quatre mots, et une seule ambition. Te faire tomber.",
            "La carrière continue, sans limite de temps. Le jour où tu veux partir, « Raccrocher le micro » est dans le menu.",
        ])
    }

    // MARK: - Achievements

    /// Unlocks what this career and the finished ones have earned; new ones are announced one at a time.
    func checkAchievements(in current: GameState? = nil, announce: Bool = true) {
        var earned = AchievementRules.earned(from: history)
        if let current { earned.formUnion(AchievementRules.earned(in: current)) }
        let new = Achievement.allCases.filter { earned.contains($0) && !profile.unlocked.contains($0) }
        guard !new.isEmpty else { return }
        for achievement in new { profile.achievements[achievement] = Date() }
        store.saveProfile(profile)
        guard announce else { return }
        toastQueue.append(contentsOf: new)
        if achievementToast == nil { showNextToast() }
    }

    private func showNextToast() {
        guard !toastQueue.isEmpty else { return }
        let next = toastQueue.removeFirst()
        Task {
            sound.play(.quest)
            Haptics.shared.play(.victory)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { achievementToast = next }
            try? await Task.sleep(for: .seconds(3.2))
            withAnimation(.easeIn(duration: 0.3)) { achievementToast = nil }
            try? await Task.sleep(for: .milliseconds(400))
            showNextToast()
        }
    }
}
