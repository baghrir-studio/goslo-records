import XCTest
@testable import GosloRecords

final class StatsTests: XCTestCase {
    func testInitClampsValues() {
        let stats = Stats(streams: -10, credibilite: 150, argent: 50, mental: 100)
        XCTAssertEqual(stats.streams, 0)
        XCTAssertEqual(stats.credibilite, 100)
        XCTAssertEqual(stats.argent, 50)
        XCTAssertEqual(stats.mental, 100)
    }

    func testApplyClampsAndReturnsRealDeltas() {
        var stats = Stats(streams: 95, credibilite: 3, argent: 50, mental: 50)
        let applied = stats.apply([.streams: 20, .credibilite: -10, .argent: 0, .mental: 5])
        XCTAssertEqual(stats.streams, 100)
        XCTAssertEqual(stats.credibilite, 0)
        XCTAssertEqual(applied, [.streams: 5, .credibilite: -3, .mental: 5])
    }

    func testSubscriptSetterClamps() {
        var stats = Stats(streams: 10, credibilite: 10, argent: 10, mental: 10)
        stats[.mental] = 9999
        stats[.argent] = -9999
        XCTAssertEqual(stats.mental, 100)
        XCTAssertEqual(stats.argent, 0)
    }

    func testDecodingOutOfRangeValuesClamps() throws {
        let json = #"{"streams": 300, "credibilite": -4, "argent": 20, "mental": 40}"#
        let stats = try JSONDecoder().decode(Stats.self, from: Data(json.utf8))
        XCTAssertEqual(stats.streams, 100)
        XCTAssertEqual(stats.credibilite, 0)
    }

    func testStylesModifyStartingStatsAndSkills() {
        XCTAssertGreaterThan(Style.boomBap.startingStats.credibilite, Style.trap.startingStats.credibilite)
        XCTAssertGreaterThan(Style.trap.startingStats.streams, Style.boomBap.startingStats.streams)
        XCTAssertLessThan(Style.melancolique.startingStats.mental, Style.baseStats.mental)
        XCTAssertEqual(GameState(rapper: Rapper(name: "x", city: .lille, style: .boomBap)).skills.level(.plume), 2)
        for style in Style.allCases {
            for kind in StatKind.allCases {
                XCTAssertGreaterThan(style.startingStats[kind], 0, "\(style) commence avec \(kind) à 0")
            }
        }
    }

    func testSkillLevelsAndLevelUps() {
        var skills = Skills()
        XCTAssertEqual(skills.level(.plume), 1)
        XCTAssertEqual(skills.gain([.plume: 59]), [])
        XCTAssertEqual(skills.gain([.plume: 1, .flow: 10]), [.plume])
        XCTAssertEqual(skills.level(.plume), 2)
        skills.gain([.scene: 100_000])
        XCTAssertEqual(skills.level(.scene), Skills.maxLevel)
        XCTAssertEqual(skills.progress(.scene), 1)
    }
}

final class ConditionTests: XCTestCase {
    private func state(turn: Int = 0, flags: Set<String> = [], stats: Stats? = nil) -> GameState {
        var s = GameState(rapper: Rapper(name: "Test", city: .lyon, style: .trap),
                          stats: stats ?? Stats(streams: 50, credibilite: 50, argent: 50, mental: 50))
        s.turn = turn
        s.flags = flags
        return s
    }

    func testYearBoundsWithSemesters() {
        let c = EventConditions(minYear: 2, maxYear: 3)
        XCTAssertFalse(c.isSatisfied(by: state(turn: 1)))  // année 1, S2
        XCTAssertTrue(c.isSatisfied(by: state(turn: 2)))   // année 2
        XCTAssertTrue(c.isSatisfied(by: state(turn: 5)))   // année 3, S2
        XCTAssertFalse(c.isSatisfied(by: state(turn: 6)))  // année 4
    }

    func testRequiredAndExcludedFlags() {
        let c = EventConditions(requiredFlags: ["signe_goslo"], excludedFlags: ["en_clash"])
        XCTAssertFalse(c.isSatisfied(by: state()))
        XCTAssertTrue(c.isSatisfied(by: state(flags: ["signe_goslo"])))
        XCTAssertFalse(c.isSatisfied(by: state(flags: ["signe_goslo", "en_clash"])))
    }

    func testStatThresholdsAreInclusive() {
        let c = EventConditions(minStats: [.streams: 50], maxStats: [.mental: 50])
        XCTAssertTrue(c.isSatisfied(by: state()))
        XCTAssertFalse(c.isSatisfied(by: state(stats: Stats(streams: 49, credibilite: 50, argent: 50, mental: 50))))
        XCTAssertFalse(c.isSatisfied(by: state(stats: Stats(streams: 50, credibilite: 50, argent: 50, mental: 51))))
    }

    func testCounterSkillAndRelationThresholds() {
        let c = EventConditions(minCounters: [.projets: 1], minSkills: [.plume: 3],
                                minRelations: ["yanis": 60], maxRelations: ["le_baron": 40])
        var s = state()
        s.counters.increment(.projets)
        s.skills.gain([.plume: 120])
        s.relations = ["yanis": 60, "le_baron": 40]
        XCTAssertTrue(c.isSatisfied(by: s))
        s.relations["yanis"] = 59
        XCTAssertFalse(c.isSatisfied(by: s))
        s.relations["yanis"] = 80
        s.relations["le_baron"] = 41
        XCTAssertFalse(c.isSatisfied(by: s))
    }

    func testChoiceRequirement() {
        let requirement = ChoiceRequirement(skills: [.flow: 4], relations: ["orphee": 60])
        var s = state()
        XCTAssertFalse(requirement.isMet(by: s))
        s.skills.gain([.flow: 180])
        s.relations["orphee"] = 60
        XCTAssertTrue(requirement.isMet(by: s))
    }
}

final class GameEngineTests: XCTestCase {
    private let rapper = Rapper(name: "Kiki Prélèvement", city: .marseille, style: .boomBap)
    private var rng = SeededGenerator(seed: 1)

    private func choice(_ effects: [StatKind: Int] = [:], set: [String] = [], clear: [String] = [],
                        counters: [CounterKind: Int] = [:], xp: [Skill: Int] = [:], relations: [String: Int] = [:],
                        requires: ChoiceRequirement? = nil, clash: ClashSpec? = nil,
                        followUp: String? = nil, skip: Int = 0) -> EventChoice {
        EventChoice(label: "c", effects: effects, setFlags: set, clearFlags: clear, counters: counters, xp: xp,
                    relations: relations, requires: requires, clash: clash, consequence: "conséquence",
                    followUp: followUp, skipTurns: skip)
    }

    private func event(_ id: String, at location: Location? = .studio, npc: String? = nil, weight: Int = 10,
                       unique: Bool = false, conditions: EventConditions = EventConditions(),
                       choices: [EventChoice]? = nil) -> GameEvent {
        GameEvent(id: id, title: id, text: "", location: location, npc: npc, weight: weight, unique: unique,
                  conditions: conditions, choices: choices ?? [choice()])
    }

    private func neutralState(_ engine: GameEngine) -> GameState {
        var s = engine.newGame(rapper: rapper)
        s.stats = Stats(streams: 50, credibilite: 50, argent: 50, mental: 50)
        s.chapter = 2 // The laverie (label) opens in chapter 2.
        return s
    }

    /// Visit + choice in one go.
    @discardableResult
    private func play(_ engine: GameEngine, _ s: inout GameState, at location: Location = .studio,
                      choice index: Int = 0) throws -> Resolution {
        _ = try engine.visit(location, in: &s, using: &rng)
        return try engine.resolve(choiceAt: index, in: &s)
    }

    private func outcome(_ resolution: Resolution) throws -> TurnOutcome {
        guard case .outcome(let outcome) = resolution else { throw XCTSkip("pas un outcome") }
        return outcome
    }

    // MARK: Map & encounters

    func testVisitSpendsActionAndDrawsAtThatLocation() throws {
        let engine = GameEngine(events: [event("studio_ev", at: .studio), event("label_ev", at: .label)])
        var s = neutralState(engine)
        let drawn = try engine.visit(.label, in: &s, using: &rng)
        XCTAssertEqual(drawn.id, "label_ev")
        XCTAssertEqual(s.actionsLeft, GameState.actionsPerTurn - 1)
        XCTAssertEqual(s.currentEventId, "label_ev")
        XCTAssertThrowsError(try engine.visit(.studio, in: &s, using: &rng)) {
            XCTAssertEqual($0 as? GameEngineError, .cannotVisit)
        }
    }

    func testLockedLocationThrows() {
        let engine = GameEngine(events: [event("e", at: .scene)])
        var s = neutralState(engine)
        XCTAssertFalse(engine.isUnlocked(.scene, in: s))
        XCTAssertThrowsError(try engine.visit(.scene, in: &s, using: &rng)) {
            XCTAssertEqual($0 as? GameEngineError, .locationLocked(.scene))
        }
        s.counters.increment(.projets)
        XCTAssertTrue(engine.isUnlocked(.scene, in: s))
    }

    func testEmptyLocationUsesFallback() throws {
        let engine = GameEngine(events: [event("ailleurs", at: .label)])
        var s = neutralState(engine)
        XCTAssertEqual(try engine.visit(.media, in: &s, using: &rng).id, GameEngine.fallbackEvent.id)
        XCTAssertNoThrow(try engine.resolve(choiceAt: 0, in: &s))
    }

    func testEligibilityRespectsWeightUniqueConditions() {
        let engine = GameEngine(events: [
            event("normal"),
            event("zero", weight: 0),
            event("unique_vu", unique: true),
            event("annee5", conditions: EventConditions(minYear: 5)),
            event("autre_lieu", at: .media),
        ])
        var s = neutralState(engine)
        s.seenUniqueEvents = ["unique_vu"]
        XCTAssertEqual(engine.eligibleEvents(at: .studio, in: s).map(\.id), ["normal"])
    }

    func testWeightedDrawFollowsWeights() {
        let heavy = event("heavy", weight: 90), light = event("light", weight: 10)
        var heavyCount = 0
        for _ in 0..<10_000 where GameEngine.weightedPick([heavy, light], using: &rng)?.id == "heavy" {
            heavyCount += 1
        }
        XCTAssertEqual(Double(heavyCount) / 10_000, 0.9, accuracy: 0.03)
    }

    func testCharactersPresentAndMetCast() throws {
        let cast = [CastMember(id: "momo", name: "Momo", role: "Patron")]
        let engine = GameEngine(events: [event("e", at: .label, npc: "momo")], cast: cast)
        var s = neutralState(engine)
        XCTAssertEqual(engine.charactersPresent(at: .label, in: s).map(\.id), ["momo"])
        XCTAssertTrue(engine.charactersPresent(at: .studio, in: s).isEmpty)
        _ = try engine.visit(.label, in: &s, using: &rng)
        XCTAssertTrue(s.metCast.contains("momo"))
    }

    // MARK: Choices

    func testResolveAppliesEffectsFlagsCountersRelationsAndXP() throws {
        let cast = [CastMember(id: "momo", name: "Momo", role: "Patron", startRelation: 50)]
        let e = event("e", choices: [choice([.streams: 10, .mental: -5], set: ["en_clash"], clear: ["independant"],
                                            counters: [.featurings: 2], xp: [.plume: 60], relations: ["momo": 15])])
        let engine = GameEngine(events: [e], cast: cast)
        var s = neutralState(engine)
        s.flags = ["independant"]

        let result = try outcome(play(engine, &s))

        XCTAssertEqual(s.stats.streams, 60)
        XCTAssertEqual(s.stats.mental, 45)
        XCTAssertEqual(s.flags, ["en_clash"])
        XCTAssertEqual(s.counters[.featurings], 2)
        XCTAssertEqual(s.relation("momo"), 65)
        XCTAssertEqual(result.relationChanges["momo"], 15)
        XCTAssertEqual(s.skills.xp(.flow), Style.boomBap.startingXP[.flow]! + Location.studio.visitXP[.flow]!)
        XCTAssertTrue(result.levelUps.contains(.plume))
        XCTAssertEqual(result.deltas[.streams], 10)
        XCTAssertFalse(result.semesterEnded)
        XCTAssertNil(s.currentEventId)
    }

    func testLockedChoiceThrows() throws {
        let e = event("e", choices: [choice(requires: ChoiceRequirement(skills: [.plume: 9])), choice()])
        let engine = GameEngine(events: [e])
        var s = neutralState(engine)
        _ = try engine.visit(.studio, in: &s, using: &rng)
        XCTAssertFalse(e.choices[0].isAvailable(in: s))
        XCTAssertThrowsError(try engine.resolve(choiceAt: 0, in: &s)) {
            XCTAssertEqual($0 as? GameEngineError, .requirementNotMet)
        }
        XCTAssertNoThrow(try engine.resolve(choiceAt: 1, in: &s))
    }

    func testSemesterEndsAfterAllActionsWithUpkeep() throws {
        let engine = GameEngine(events: [event("e")])
        var s = neutralState(engine)
        let first = try outcome(play(engine, &s))
        XCTAssertFalse(first.semesterEnded)
        XCTAssertEqual(s.turn, 0)

        let second = try outcome(play(engine, &s))
        XCTAssertTrue(second.semesterEnded)
        XCTAssertEqual(s.turn, 1)
        XCTAssertEqual(s.actionsLeft, GameState.actionsPerTurn)
        XCTAssertEqual(s.stats.argent, 50 + GameEngine.semesterUpkeep[.argent]!)
        XCTAssertEqual(s.stats.streams, 50 + GameEngine.semesterUpkeep[.streams]!)
        XCTAssertEqual(second.deltas[.argent], GameEngine.semesterUpkeep[.argent])
    }

    func testFollowUpCostsNoActionAndDelaysSemesterEnd() throws {
        let engine = GameEngine(events: [
            event("debut", choices: [choice(followUp: "suite")]),
            event("suite", at: nil, weight: 0),
        ])
        var s = neutralState(engine)
        s.actionsLeft = 1
        let first = try outcome(play(engine, &s))
        XCTAssertFalse(first.semesterEnded, "le semestre attend la suite")
        XCTAssertFalse(engine.canVisit(s))

        let followUp = try XCTUnwrap(engine.takeFollowUp(in: &s))
        XCTAssertEqual(followUp.id, "suite")
        XCTAssertEqual(s.actionsLeft, 0)
        let second = try outcome(engine.resolve(choiceAt: 0, in: &s))
        XCTAssertTrue(second.semesterEnded)
    }

    func testUniqueEventHappensOnlyOnce() throws {
        let engine = GameEngine(events: [event("once", weight: 1000, unique: true), event("filler", weight: 1)])
        var s = neutralState(engine)
        var onceCount = 0
        for _ in 0..<20 where !s.isOver {
            if try engine.visit(.studio, in: &s, using: &rng).id == "once" { onceCount += 1 }
            _ = try engine.resolve(choiceAt: 0, in: &s)
        }
        XCTAssertEqual(onceCount, 1)
    }

    func testSkipTurnsJumpsAheadAndClosesSemester() throws {
        let engine = GameEngine(events: [event("pause", choices: [choice(skip: 3)])])
        var s = neutralState(engine)
        let result = try outcome(play(engine, &s))
        XCTAssertTrue(result.semesterEnded)
        XCTAssertEqual(s.turn, 4)
        XCTAssertEqual(s.year, 3)
    }

    // MARK: Clashes

    private let weakRival = CastMember(id: "faible", name: "Faible", role: "",
                                       clash: ClashProfile(stats: [.punchline: 1, .flow: 1, .presence: 1, .story: 1]))
    private let boss = CastMember(id: "boss", name: "Boss", role: "",
                                  clash: ClashProfile(stats: [.punchline: 10, .flow: 10, .presence: 10, .story: 10],
                                                      resistance: .flow))

    private func clashSpec(_ opponent: String) -> ClashSpec {
        ClashSpec(opponent: opponent,
                  win: ClashResultSpec(effects: [.credibilite: 10], consequence: "gagné"),
                  lose: ClashResultSpec(effects: [.credibilite: -10], consequence: "perdu"))
    }

    private func runClash(against member: CastMember, playerXP: [Skill: Int], move: ClashMove = .flow) throws -> (GameState, TurnOutcome) {
        let engine = GameEngine(events: [event("defi", choices: [choice(clash: clashSpec(member.id))])], cast: [member])
        var s = neutralState(engine)
        s.skills.gain(playerXP)
        guard case .clash(let started) = try play(engine, &s) else { XCTFail("pas de clash"); throw XCTSkip() }
        XCTAssertEqual(started.opponentId, member.id)
        XCTAssertThrowsError(try engine.finishClash(in: &s))
        while try !engine.clashMove(move, in: &s, using: &rng).isOver {}
        let result = try engine.finishClash(in: &s)
        XCTAssertNil(s.clash)
        return (s, result)
    }

    func testWinningAClash() throws {
        let (s, result) = try runClash(against: weakRival, playerXP: [.flow: 600])
        XCTAssertTrue(try XCTUnwrap(result.clash).playerWon)
        XCTAssertEqual(result.consequence, "gagné")
        XCTAssertEqual(s.stats.credibilite, 60)
        XCTAssertEqual(s.counters[.beefs], 1)
        XCTAssertEqual(s.counters[.clashsGagnes], 1)
        XCTAssertTrue(s.flags.contains("clash_gagne_faible"))
        XCTAssertEqual(result.relationChanges["faible"], GameEngine.clashRelationPenalty.win)
    }

    func testLosingAClash() throws {
        let (s, result) = try runClash(against: boss, playerXP: [:])
        XCTAssertFalse(try XCTUnwrap(result.clash).playerWon)
        XCTAssertEqual(result.consequence, "perdu")
        XCTAssertEqual(s.counters[.beefs], 1)
        XCTAssertEqual(s.counters[.clashsGagnes], 0)
        XCTAssertFalse(s.flags.contains("clash_gagne_boss"))
    }

    func testClashLastsAtMostFourRounds() throws {
        let (_, result) = try runClash(against: weakRival, playerXP: [:], move: .presence)
        let clash = try XCTUnwrap(result.clash)
        XCTAssertLessThanOrEqual(clash.log.filter(\.byPlayer).count, ClashState.maxRounds)
    }

    func testStoryMoveCostsCredibility() throws {
        let engine = GameEngine(events: [event("defi", choices: [choice(clash: clashSpec("boss"))])], cast: [boss])
        var s = neutralState(engine)
        _ = try play(engine, &s)
        _ = try engine.clashMove(.story, in: &s, using: &rng)
        XCTAssertEqual(s.stats.credibilite, 50 - ClashState.storyCredCost)
    }

    func testStoryMoveNeverEndsTheCareer() throws {
        let engine = GameEngine(events: [event("defi", choices: [choice(clash: clashSpec("boss"))])], cast: [boss])
        var s = neutralState(engine)
        s.stats = Stats(streams: 50, credibilite: 3, argent: 50, mental: 50)
        _ = try play(engine, &s)
        _ = try engine.clashMove(.story, in: &s, using: &rng)
        XCTAssertEqual(s.stats.credibilite, 1, "le coup Story s'arrête à 1 de respect")
        _ = try engine.clashMove(.story, in: &s, using: &rng)
        XCTAssertEqual(s.stats.credibilite, 1)
        XCTAssertNil(EndingResolver.prematureEnding(for: s.stats))
    }

    func testWeaknessAndResistanceMultipliers() {
        let profile = ClashProfile(stats: [:], weakness: .punchline, resistance: .story)
        XCTAssertEqual(ClashEngine.multiplier(for: .punchline, against: profile), ClashState.weaknessMultiplier)
        XCTAssertEqual(ClashEngine.multiplier(for: .story, against: profile), ClashState.resistanceMultiplier)
        XCTAssertEqual(ClashEngine.multiplier(for: .flow, against: profile), 1)
        let (damage, impact) = ClashEngine.damage(move: .flow, level: 5, boosted: false,
                                                  multiplier: ClashState.weaknessMultiplier, using: &rng)
        XCTAssertEqual(impact, .strong)
        XCTAssertGreaterThanOrEqual(damage, Int((Double(6 + 2 * 5) * 0.8 * 1.5).rounded(.down)))
        XCTAssertEqual(ClashMove.flow.missChance(level: 1), 0)
        XCTAssertEqual(ClashMove.punchline.missChance(level: 10), 5)
    }

    func testScoutingNeedsTheChroniqueur() {
        let engine = GameEngine(events: [], cast: [boss])
        var s = neutralState(engine)
        s.relations[GameEngine.chroniqueurId] = GameEngine.scoutingRelation - 1
        XCTAssertNil(engine.scoutingReport(for: "boss", in: s))
        s.relations[GameEngine.chroniqueurId] = GameEngine.scoutingRelation
        XCTAssertEqual(engine.scoutingReport(for: "boss", in: s)?.resistance, .flow)
    }

    // MARK: Quests

    func testQuestStepsAdvanceInOrderAndPayOut() throws {
        let quest = Quest(id: "q", title: "Q", steps: [
            QuestStep(label: "1", location: .label, conditions: EventConditions(requiredFlags: ["a"])),
            QuestStep(label: "2", conditions: EventConditions(requiredFlags: ["b"])),
        ], reward: QuestReward(effects: [.argent: 10]))
        let engine = GameEngine(events: [
            event("pose_b", choices: [choice(set: ["b"])]),
            event("pose_a", at: .label, choices: [choice(set: ["a"])]),
        ], quests: [quest])
        var s = neutralState(engine)
        XCTAssertEqual(engine.questMarkers(in: s), [.label])

        _ = try play(engine, &s, at: .studio)   // b before a: nothing moves
        XCTAssertEqual(s.questProgress["q"], 0)

        let result = try outcome(play(engine, &s, at: .label))
        XCTAssertEqual(result.completedQuests.map(\.id), ["q"])
        XCTAssertTrue(s.completedQuests.contains("q"))
        XCTAssertTrue(s.flags.contains("quete_q"))
        XCTAssertEqual(s.stats.argent, 50 + 10 + GameEngine.semesterUpkeep[.argent]!)
        XCTAssertTrue(engine.activeQuests(in: s).isEmpty)
    }

    // MARK: Endings

    func testEachDepletedStatTriggersItsEnding() throws {
        let cases: [(StatKind, Ending)] = [(.mental, .burnOut), (.argent, .retourAuTaf),
                                           (.credibilite, .vendu), (.streams, .oublie)]
        for (kind, expected) in cases {
            let engine = GameEngine(events: [event("coup", choices: [choice([kind: -100])])])
            var s = neutralState(engine)
            let result = try outcome(play(engine, &s))
            XCTAssertEqual(result.ending, expected, "\(kind)")
            XCTAssertTrue(expected.isPremature)
            XCTAssertThrowsError(try engine.visit(.studio, in: &s, using: &rng))
        }
    }

    func testPrematureEndingPriority() {
        XCTAssertEqual(EndingResolver.prematureEnding(for: Stats(streams: 0, credibilite: 0, argent: 0, mental: 0)), .burnOut)
        XCTAssertEqual(EndingResolver.prematureEnding(for: Stats(streams: 0, credibilite: 0, argent: 5, mental: 5)), .vendu)
        XCTAssertNil(EndingResolver.prematureEnding(for: Stats(streams: 1, credibilite: 1, argent: 1, mental: 1)))
    }

    func testSurvivalEndings() {
        func ending(_ stats: Stats, flags: Set<String> = []) -> Ending {
            var s = GameState(rapper: rapper, stats: stats)
            s.flags = flags
            return EndingResolver.finalEnding(for: s)
        }
        XCTAssertEqual(ending(Stats(streams: 60, credibilite: 40, argent: 20, mental: 20), flags: ["clash_gagne_le_baron"]), .heritier)
        XCTAssertEqual(ending(Stats(streams: 80, credibilite: 80, argent: 20, mental: 20)), .legende)
        XCTAssertEqual(ending(Stats(streams: 80, credibilite: 30, argent: 50, mental: 50)), .starCommerciale)
        XCTAssertEqual(ending(Stats(streams: 30, credibilite: 80, argent: 10, mental: 50)), .culteMaisFauche)
        XCTAssertEqual(ending(Stats(streams: 40, credibilite: 50, argent: 90, mental: 50)), .rentier)
        XCTAssertEqual(ending(Stats(streams: 40, credibilite: 50, argent: 40, mental: 90)), .sageDuGame)
        XCTAssertEqual(ending(Stats(streams: 40, credibilite: 50, argent: 40, mental: 40)), .carriereHonnete)
        XCTAssertGreaterThanOrEqual(Ending.allCases.filter { !$0.isPremature }.count, 4)
    }

    func testLastSemesterGivesSurvivalEnding() throws {
        let engine = GameEngine(events: [event("e", choices: [choice([.argent: 2, .streams: 4])])])
        var s = neutralState(engine)
        s.turn = GameState.totalTurns - 1
        s.actionsLeft = 1
        let result = try outcome(play(engine, &s))
        XCTAssertEqual(result.ending, .carriereHonnete)
        XCTAssertEqual(s.turn, GameState.totalTurns)
        XCTAssertThrowsError(try engine.visit(.studio, in: &s, using: &rng))
    }

    // MARK: Misc

    func testTemplateReplacesNameAndCity() {
        XCTAssertEqual(TextTemplate.render("{nom} de {ville}", for: rapper), "Kiki Prélèvement de Marseille")
    }

    func testCareerRecordSummaryUsesFlags() {
        var s = GameState(rapper: rapper)
        s.flags = ["clash_gagne_le_baron"]
        s.ending = .heritier
        let record = CareerRecord(state: s)
        XCTAssertTrue(record.summary.contains("Baron"))
        XCTAssertEqual(record.ending, .heritier)
    }

    func testGameStateRoundTripsThroughJSON() throws {
        let engine = GameEngine(events: [event("defi", choices: [choice(clash: clashSpec("boss"))])], cast: [boss])
        var s = neutralState(engine)
        s.flags = ["signe_goslo"]
        s.counters.increment(.disquesOr, by: 2)
        s.metCast = ["boss"]
        _ = try play(engine, &s)
        _ = try engine.clashMove(.punchline, in: &s, using: &rng)
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), s)
    }
}
