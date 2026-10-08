import XCTest
@testable import GosloRecords

/// « Le Tournoi goslo radio »: the ladder of bosses unlocked by the artist level, and their techniques.
final class TournamentTests: XCTestCase {
    private var world = World(events: [])
    private var engine: GameEngine { GameEngine(world: world) }
    private var rng = SeededGenerator(seed: 2024)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    private func newGame(level: Int = 1, style: Style = .drill) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: style))
        state.pendingCinematic = nil
        state.artistXP = ArtistLevel.thresholds[level - 1]
        return state
    }

    private func beat(_ ids: [String], in state: inout GameState) {
        for id in ids { state.flags.insert(GameEngine.tournamentFlag(id)) }
    }

    // MARK: Data

    func testLadderDataIsConsistent() throws {
        let ladder = world.story.tournament
        XCTAssertGreaterThanOrEqual(ladder.count, 6)
        XCTAssertEqual(Set(ladder.map(\.id)).count, ladder.count)
        let storyBosses: Set<String> = ["kevlar_jr", "kolosse", "lingot", "scalpel", "le_baron", "le_conteur"]
        var previousLevel = 1
        var previousPower = 0.0
        for boss in ladder {
            let member = try XCTUnwrap(engine.castMember(boss.opponent), "\(boss.opponent) absent du casting")
            let profile = try XCTUnwrap(member.clash, "\(boss.opponent) n'a pas de profil de clash")
            XCTAssertNotNil(member.secret?.fx, "\(boss.opponent) : technique sans animation")
            XCTAssertFalse(member.wild, boss.opponent)
            XCTAssertFalse(storyBosses.contains(boss.opponent), "\(boss.opponent) : déjà un boss de l'histoire")
            XCTAssertGreaterThan(boss.minArtistLevel, previousLevel, "\(boss.opponent) : les niveaux doivent monter")
            XCTAssertLessThanOrEqual(boss.minArtistLevel, ArtistLevel.maxLevel)
            previousLevel = boss.minArtistLevel
            // Each rung hits harder than the one before.
            let scaled = profile.scaled(by: boss.levelBonus)
            let average = Double(ClashMove.allCases.map(scaled.stat).reduce(0, +)) / 4
            let power = average * (boss.opponentPower ?? ClashState.opponentDamageFactor) * Double(boss.rounds)
            XCTAssertGreaterThan(power, previousPower, "\(boss.opponent) n'est pas plus dur que le tour d'avant")
            previousPower = power
            // Its technique exists and unlocks with the win.
            let technique = try XCTUnwrap(world.story.techniques.first { $0.id == boss.technique }, boss.technique)
            XCTAssertEqual(technique.unlock.requiredFlags, [boss.flag])
            XCTAssertNotNil(technique.secret.fx)
            XCTAssertGreaterThan(boss.xp, 0)
            XCTAssertFalse(boss.intro.isEmpty)
        }
        // Techniques earned by the artist level alone.
        let byLevel = world.story.techniques.filter { $0.minArtistLevel != nil }
        XCTAssertGreaterThanOrEqual(byLevel.count, 2)
        for technique in byLevel {
            XCTAssertGreaterThan(technique.minArtistLevel ?? 0, 1, technique.id)
            XCTAssertLessThanOrEqual(technique.minArtistLevel ?? 0, ArtistLevel.maxLevel, technique.id)
        }
    }

    // MARK: Ladder

    func testLadderOpensByLevelAndInOrder() throws {
        var state = newGame(level: 1)
        var rungs = engine.tournamentBosses(in: state)
        XCTAssertEqual(rungs.map(\.boss), world.story.tournament)
        XCTAssertTrue(rungs.allSatisfy { $0.status == .locked })
        XCTAssertEqual(rungs.first?.lockReason, "Niveau d'artiste \(world.story.tournament[0].minArtistLevel) requis")
        let first = rungs[0].id, second = rungs[1].id
        XCTAssertThrowsError(try engine.startTournamentClash(first, in: &state))

        state = newGame(level: rungs[0].boss.minArtistLevel)
        rungs = engine.tournamentBosses(in: state)
        XCTAssertEqual(rungs[0].status, .available)
        XCTAssertEqual(rungs[1].status, .locked)

        // A high level is not enough: the previous rung has to be beaten.
        state = newGame(level: ArtistLevel.maxLevel)
        rungs = engine.tournamentBosses(in: state)
        XCTAssertEqual(rungs[0].status, .available)
        XCTAssertEqual(rungs[1].status, .locked)
        XCTAssertEqual(rungs[1].lockReason, "Bats d'abord \(rungs[0].member.name)")
        XCTAssertFalse(engine.canStartTournament(second, in: state))

        beat([first], in: &state)
        rungs = engine.tournamentBosses(in: state)
        XCTAssertEqual(rungs[0].status, .beaten)
        XCTAssertEqual(rungs[1].status, .available)
        XCTAssertEqual(engine.nextTournamentRung(in: state)?.id, second)
        XCTAssertFalse(engine.canStartTournament(first, in: state), "un tour gagné ne se rejoue pas")
    }

    func testAWinUnlocksTheTechniqueAndTheNextRung() throws {
        let boss = world.story.tournament[0]
        var state = newGame(level: world.story.tournament[1].minArtistLevel)
        let actions = state.actionsLeft
        let xp = state.artistXP
        let clash = try engine.startTournamentClash(boss.opponent, in: &state)
        XCTAssertTrue(clash.isBoss)
        XCTAssertEqual(state.actionsLeft, actions - 1, "un tour du Tournoi coûte une action")
        XCTAssertTrue(state.metCast.contains(boss.opponent))
        XCTAssertFalse(engine.canVisit(state), "pas d'autre action pendant le clash")

        state.clash?.opponentHype = 0
        let outcome = try engine.finishClash(in: &state)
        XCTAssertNil(state.clash)
        XCTAssertTrue(state.flags.contains(boss.flag))
        XCTAssertTrue(state.flags.contains("clash_gagne_\(boss.opponent)"))
        XCTAssertGreaterThanOrEqual(state.artistXP, xp + 15 + boss.xp)
        let technique = try XCTUnwrap(world.story.techniques.first { $0.id == boss.technique })
        XCTAssertTrue(outcome.unlockedTechniques.contains(technique.secret.name))
        XCTAssertEqual(state.equippedTechnique, technique.id, "la technique gagnée est équipée")
        XCTAssertTrue(engine.availableTechniques(in: state).contains { $0.id == technique.id })
        XCTAssertTrue(outcome.notes.contains { $0.contains(engine.castMember(world.story.tournament[1].opponent)!.name) })
        XCTAssertEqual(engine.tournamentBosses(in: state)[1].status, .available)
    }

    func testALossTeachesTheBossAndKeepsTheRungOpen() throws {
        let boss = world.story.tournament[0]
        var state = newGame(level: boss.minArtistLevel)
        _ = try engine.startTournamentClash(boss.opponent, in: &state)
        state.clash?.playerHype = 0
        let outcome = try engine.finishClash(in: &state)
        XCTAssertFalse(state.flags.contains(boss.flag))
        XCTAssertTrue(outcome.unlockedTechniques.isEmpty)
        XCTAssertEqual(state.bossLosses[boss.opponent], 1)
        XCTAssertEqual(engine.bossExperience(against: boss.opponent, in: state), 1)
        XCTAssertEqual(engine.tournamentBosses(in: state)[0].status, .available, "on peut retenter")
    }

    func testClearingTheLadderCrownsTheChampion() throws {
        let ladder = world.story.tournament
        var state = newGame(level: ArtistLevel.maxLevel)
        beat(ladder.dropLast().map(\.opponent), in: &state)
        let last = try XCTUnwrap(ladder.last)
        _ = try engine.startTournamentClash(last.opponent, in: &state)
        state.clash?.opponentHype = 0
        let outcome = try engine.finishClash(in: &state)
        XCTAssertTrue(state.flags.contains(GameEngine.tournamentChampionFlag))
        XCTAssertTrue(outcome.notes.contains { $0.hasPrefix("CHAMPION") })
        XCTAssertNil(engine.nextTournamentRung(in: state))
        XCTAssertTrue(engine.tournamentBosses(in: state).allSatisfy { $0.status == .beaten })
    }

    func testStoryClashesAreNotTournamentClashes() throws {
        let ring = try XCTUnwrap(world.story.events.first { $0.id == "story_ring" })
        let spec = try XCTUnwrap(ring.choices[0].clash)
        XCTAssertNil(engine.tournamentBoss(for: ClashState(spec: spec)))
    }

    // MARK: Techniques earned by level

    func testLevelTechniquesUnlockWithTheArtistLevel() throws {
        let technique = try XCTUnwrap(world.story.techniques.filter { $0.minArtistLevel != nil }.min { $0.minArtistLevel! < $1.minArtistLevel! })
        let level = try XCTUnwrap(technique.minArtistLevel)
        var state = newGame(level: level - 1)
        XCTAssertFalse(engine.availableTechniques(in: state).contains { $0.id == technique.id })
        engine.equipTechnique(technique.id, in: &state)
        XCTAssertNotEqual(state.equippedTechnique, technique.id)

        // Reaching the level announces it at the next action.
        state.artistXP = ArtistLevel.thresholds[level - 1]
        let event = try engine.visit(.chezToi, in: &state, using: &rng)
        let choice = try XCTUnwrap(event.choices.firstIndex { $0.isAvailable(in: state) && $0.followUp == nil && $0.skipTurns == 0 && $0.minigame == nil })
        guard case .outcome(let outcome) = try engine.resolve(choiceAt: choice, in: &state) else { return XCTFail() }
        XCTAssertTrue(outcome.unlockedTechniques.contains(technique.secret.name))
        XCTAssertTrue(engine.availableTechniques(in: state).contains { $0.id == technique.id })
    }

    // MARK: Saves

    func testOldSavesAndDataLoad() throws {
        let json = #"{"rapper":{"name":"Vieux","city":"Lyon","style":"Trap"},"stats":{"streams":40,"credibilite":30,"argent":20,"mental":50},"turn":3,"flags":["clash_gagne_kevlar_jr"]}"#
        let state = try JSONDecoder().decode(GameState.self, from: Data(json.utf8))
        XCTAssertEqual(engine.tournamentBosses(in: state).count, world.story.tournament.count)
        XCTAssertTrue(engine.tournamentBosses(in: state).allSatisfy { $0.status == .locked })

        let story = try JSONDecoder().decode(Story.self, from: Data(#"{"techniques":[{"id":"x","secret":{"name":"X","line":"Une ligne assez longue."},"unlock":{"required_flags":["f"]}}]}"#.utf8))
        XCTAssertTrue(story.tournament.isEmpty)
        XCTAssertNil(story.techniques.first?.minArtistLevel)
        let bare = try JSONDecoder().decode(UnlockableTechnique.self, from: Data(#"{"id":"y","secret":{"name":"Y","line":"l"},"min_artist_level":4}"#.utf8))
        XCTAssertEqual(bare.unlock, EventConditions())
        XCTAssertEqual(bare.minArtistLevel, 4)

        // A Tournoi clash saved mid-fight comes back as a Tournoi clash.
        var running = newGame(level: world.story.tournament[0].minArtistLevel)
        let clash = try engine.startTournamentClash(world.story.tournament[0].opponent, in: &running)
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(running))
        XCTAssertEqual(back.clash, clash)
        XCTAssertNotNil(engine.tournamentBoss(for: try XCTUnwrap(back.clash)))
    }

    // MARK: Balance

    /// Skill levels of an average player when they first reach each artist level (measured with PacingSim,
    /// story only: real players with singles get there sooner, so this is on the generous side for the boss).
    static let typicalSkills: [Int: [Skill: Int]] = [
        2: [.plume: 3, .flow: 2, .scene: 2, .business: 1],
        3: [.plume: 6, .flow: 4, .scene: 4, .business: 4],
        4: [.plume: 8, .flow: 5, .scene: 7, .business: 6],
        5: [.plume: 10, .flow: 7, .scene: 9, .business: 8],
        6: [.plume: 10, .flow: 8, .scene: 9, .business: 9],
    ]

    static func skills(at level: Int) -> Skills {
        // Past level 6, a career is in its free years: everything maxed.
        let levels = typicalSkills[level] ?? Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, Skills.maxLevel) })
        return Skills(xp: levels.mapValues { ($0 - 1) * Skills.xpPerLevel })
    }

    /// A prepared player reads the tell or hits the weak spot most of the time (70 %), fires their technique
    /// as soon as it's ready and half-counters the boss's.
    private func winRate(_ index: Int, smart: Bool, runs: Int = 400) throws -> Double {
        let ladder = world.story.tournament
        let boss = ladder[index]
        let profile = try XCTUnwrap(engine.castMember(boss.opponent)?.clash)
        var wins = 0
        for run in 0..<runs {
            var state = newGame(level: boss.minArtistLevel, style: Style.allCases[run % Style.allCases.count])
            state.skills = TournamentTests.skills(at: boss.minArtistLevel)
            beat(ladder.prefix(index).map(\.opponent), in: &state)
            _ = try engine.startTournamentClash(boss.opponent, in: &state)
            while let clash = state.clash, !clash.isOver {
                if clash.pendingCounter != nil {
                    _ = try engine.counterSecret(taps: smart ? 8 : 0, in: &state)
                } else if smart && clash.playerSecretReady {
                    _ = try engine.clashSecret(charge: 0.6, in: &state, using: &rng)
                } else {
                    let reads = smart && Double.random(in: 0..<1, using: &rng) < 0.7
                    let move = reads ? (ClashTactics.telegraphed(clash)?.counter ?? profile.weakness ?? .flow)
                        : ClashMove.allCases.randomElement(using: &rng)!
                    _ = try engine.clashMove(move, in: &state, using: &rng)
                }
            }
            if state.clash!.playerWon { wins += 1 }
        }
        return Double(wins) / Double(runs)
    }

    func testEveryBossIsBeatableByAPreparedPlayer() throws {
        for (index, boss) in world.story.tournament.enumerated() {
            let smart = try winRate(index, smart: true)
            let random = try winRate(index, smart: false)
            print("Tournoi \(index + 1) \(boss.opponent) (niv. \(boss.minArtistLevel)) — préparé : \(smart), hasard : \(random)")
            XCTAssertGreaterThan(smart, 0.5, "\(boss.opponent) : trop dur pour un joueur préparé")
            XCTAssertLessThan(smart, 0.9, "\(boss.opponent) : aucun enjeu")
            XCTAssertLessThan(random, 0.35, "\(boss.opponent) : trop facile au hasard")
            XCTAssertGreaterThan(smart, random + 0.3, "\(boss.opponent) : la tactique doit payer")
        }
    }
}
