import Foundation
import Observation
import SwiftUI

enum Route: Equatable {
    case home
    case creation
    case game
    case ending(CareerRecord)
    case history
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
    /// A scripted scene is playing.
    case cinematic
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
}

/// Glue between the engine, persistence and the UI: current run, overworld, routing.
@Observable
@MainActor
final class AppModel {
    static let stepDuration: Duration = .milliseconds(170)
    static let stepSeconds = 0.17

    private(set) var route: Route = .home
    private(set) var state: GameState?
    private(set) var phase: GamePhase = .overworld
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
    private var stepsSinceSave = 0

    init(engine: GameEngine, store: GameStore, loadError: String? = nil) {
        self.engine = engine
        self.store = store
        self.loadError = loadError
        history = store.loadHistory()
        state = store.loadCurrentRun().flatMap { $0.isOver ? nil : $0 }
    }

    static func live() -> AppModel {
        do {
            return AppModel(engine: GameEngine(world: try EventLoader.loadWorld()), store: GameStore())
        } catch {
            return AppModel(engine: GameEngine(events: []), store: GameStore(), loadError: "\(error)")
        }
    }

    /// The neighbourhood as it is in the current chapter.
    var map: WorldMap? { engine.world.map?.forChapter(state?.chapter ?? 1, flags: state?.flags ?? []) }
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
        fresh.position = map?.spawn
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
        } else if let event = engine.currentEvent(in: current) ?? engine.takeFollowUp(in: &current) {
            state = current
            phase = .encounter(event)
        } else if current.pendingCinematic != nil {
            Task { await playPendingCinematic() }
        }
        route = .game
    }

    #if DEBUG
    enum DebugAction {
        case chapter(Int)
        case lastSemester
        case maxOut
    }

    /// Debug builds only (menu "…" in the HUD): jumps around the story to test it quickly.
    func debug(_ action: DebugAction) {
        guard var current = state, canMove else { return }
        switch action {
        case .chapter(let number): engine.debugJump(toChapter: number, in: &current)
        case .lastSemester: engine.debugLastSemester(in: &current)
        case .maxOut: engine.debugMaxOut(in: &current)
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

        if let door = map.door(at: point) {
            heldDirection = nil
            await enter(door)
        } else if let rival = OverworldRules.spotter(of: point, on: map, canChallenge: { engine.canChallenge($0, in: current) }) {
            heldDirection = nil
            await challenge(by: rival)
        } else if OverworldRules.rollWild(on: map.tile(at: point), stepsSinceLast: current.stepsSinceWild, using: &rng) {
            heldDirection = nil
            await startWild()
        }
    }

    // MARK: - Interactions

    /// "A" button: talk to whoever is in front of you, or sit on the bench.
    func interact() {
        guard canMove, let map, var current = state else { return }
        switch OverworldRules.interaction(from: position, facing: facing, on: map) {
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
                phase = .dialogue(speaker: member?.name, lines: [idleLine(for: member)])
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

    private func idleLine(for member: CastMember?) -> String {
        if let taunt = member?.clash?.taunts.randomElement() { return "« \(taunt) »" }
        return ["« Repasse plus tard, je suis sous l'eau. »",
                "« On se capte bientôt, promis. »",
                "« J'ai rien pour toi là, frère. »"].randomElement()!
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
        guard var current = state, case .concert = phase else { return }
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

    /// Triggers the secret technique (gauge full).
    @discardableResult
    func clashSecret() -> ClashState? {
        guard var current = state, case .clash = phase else { return nil }
        guard let clash = try? engine.clashSecret(in: &current, using: &rng) else { return nil }
        state = current
        phase = .clash(clash)
        persist()
        return clash
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
            phase = .overworld
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
        phase = .cinematic
        withAnimation(.easeInOut(duration: 0.45)) { letterbox = true }
        try? await Task.sleep(for: .milliseconds(450))
        for step in cinematic.steps {
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
                store.clearCurrentRun()
                busy = false
                phase = .overworld
                state = nil
                route = .ending(record)
                return
            }
        }
        phase = .overworld
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
        if outcome.semesterEnded { pendingSemesterCard = true }
        playOutcomeSound(outcome)
        if outcome.ending != nil {
            // Archive immediately so nothing is lost if the app is killed.
            let record = CareerRecord(state: current)
            finishedRecord = record
            history.insert(record, at: 0)
            store.saveHistory(history)
            store.clearCurrentRun()
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

    func persist() {
        guard var current = state, !current.isOver, finishedRecord == nil else { return }
        current.position = position
        current.facing = facing
        state = current
        stepsSinceSave = 0
        store.saveCurrentRun(current)
    }
}
