import XCTest
@testable import GosloRecords

final class NegotiationTests: XCTestCase {
    private var world = World(events: [])
    private var rng = SeededGenerator(seed: 404)

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
    }

    private func negotiation() throws -> Negotiation {
        try XCTUnwrap(world.story.negotiation("contrat_hexagone"))
    }

    // MARK: Rules

    func testOptionsMoveBothGaugesAndClamp() {
        let data = Negotiation(id: "n", opponent: "victor_contrat", title: "t", startRoyalties: 2, targetRoyalties: 5,
                               startPatience: 10, clauses: [], win: InterviewResult(consequence: "w"),
                               lose: InterviewResult(consequence: "l"))
        var state = NegotiationState(negotiation: data)
        NegotiationEngine.apply(NegotiationOption(label: "a", royalties: -9, patience: 200, reaction: "r"),
                                optionIndex: 0, businessLevel: 1, to: &state)
        XCTAssertEqual(state.royalties, 0)
        XCTAssertEqual(state.patience, 100)
        XCTAssertEqual(state.log.last?.royaltiesDelta, -2)
        XCTAssertEqual(state.clauseIndex, 1)
    }

    func testBusinessSoftensDemandsButNeverTurnsThemPositive() {
        let data = Negotiation(id: "n", opponent: "victor_contrat", title: "t", clauses: [],
                               win: InterviewResult(consequence: "w"), lose: InterviewResult(consequence: "l"))
        let demand = NegotiationOption(label: "a", royalties: 3, patience: -4, reaction: "r")
        var rookie = NegotiationState(negotiation: data), shark = rookie
        NegotiationEngine.apply(demand, optionIndex: 0, businessLevel: 1, to: &rookie)
        NegotiationEngine.apply(demand, optionIndex: 0, businessLevel: 10, to: &shark)
        XCTAssertEqual(rookie.patience, data.startPatience - 4)
        XCTAssertEqual(shark.patience, data.startPatience, "le business adoucit, sans faire gagner de patience")
    }

    func testWalkoutEndsTheNegotiationAndLoses() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .drill))
        state.negotiation = NegotiationState(negotiation: try negotiation())
        state.negotiation?.patience = 5
        let after = try engine.negotiate(0, in: &state)
        XCTAssertTrue(after.walkedOut)
        XCTAssertTrue(after.isOver)
        XCTAssertFalse(after.passed)
        XCTAssertEqual(try engine.negotiate(0, in: &state), after, "plus rien ne bouge une fois parti")
        let outcome = try engine.finishNegotiation(in: &state)
        XCTAssertNil(state.negotiation)
        XCTAssertFalse(state.flags.contains("contrat_signe"))
        XCTAssertNotNil(outcome.negotiation)
    }

    func testLockedOptionThrows() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .drill))
        var running = NegotiationState(negotiation: try negotiation())
        running.clauseIndex = 2 // Article 7: the merch option needs Business 3.
        state.negotiation = running
        XCTAssertLessThan(state.skills.level(.business), 3)
        XCTAssertThrowsError(try engine.negotiate(2, in: &state))
    }

    func testNegotiationSurvivesSaveAndLoad() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: .drill))
        state.negotiation = NegotiationState(negotiation: try negotiation())
        _ = try engine.negotiate(1, in: &state)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(loaded.negotiation, state.negotiation)
    }

    // MARK: Data and balance

    func testNegotiationDataIsValid() throws {
        let castIds = Set(world.cast.map(\.id))
        for data in world.story.negotiations {
            XCTAssertTrue(castIds.contains(data.opponent), "\(data.id) : adversaire inconnu")
            XCTAssertGreaterThan(data.targetRoyalties, data.startRoyalties)
            XCTAssertGreaterThan(data.startPatience, 0)
            for (index, clause) in data.clauses.enumerated() {
                XCTAssertFalse(clause.text.isEmpty)
                XCTAssertFalse(clause.pitch.isEmpty)
                XCTAssertTrue((2...3).contains(clause.options.count), "\(data.id) article \(index)")
                XCTAssertTrue(clause.options.contains { $0.requires == nil }, "\(data.id) article \(index) sans option libre")
                for option in clause.options {
                    XCTAssertFalse(option.reaction.isEmpty)
                    for castId in option.requires?.relations.keys.map({ $0 }) ?? [] {
                        XCTAssertTrue(castIds.contains(castId))
                    }
                }
            }
        }
    }

    /// Plays every possible path (3^6) with the given business level and options.
    private func outcomes(business: Int, momo: Bool) throws -> (passed: Int, total: Int) {
        let data = try negotiation()
        var passed = 0, total = 0
        func available(_ option: NegotiationOption) -> Bool {
            guard let requires = option.requires else { return true }
            if let level = requires.skills[.business], business < level { return false }
            if requires.relations["momo"] != nil, !momo { return false }
            return true
        }
        func explore(_ state: NegotiationState) {
            if state.isOver {
                total += 1
                if state.passed { passed += 1 }
                return
            }
            for (index, option) in data.clauses[state.clauseIndex].options.enumerated() where available(option) {
                var next = state
                NegotiationEngine.apply(option, optionIndex: index, businessLevel: business, to: &next)
                explore(next)
            }
        }
        explore(NegotiationState(negotiation: data))
        return (passed, total)
    }

    func testContractIsWinnableButNotByMashing() throws {
        let rookie = try outcomes(business: 1, momo: false)
        let prepared = try outcomes(business: 3, momo: true)
        let rookieRate = Double(rookie.passed) / Double(rookie.total)
        let preparedRate = Double(prepared.passed) / Double(prepared.total)
        print("Négociation — débutant: \(rookie.passed)/\(rookie.total), préparé: \(prepared.passed)/\(prepared.total)")
        XCTAssertGreaterThan(rookie.passed, 0, "gagnable sans aucun prérequis")
        XCTAssertLessThan(rookieRate, 0.35, "trop facile en choisissant au hasard")
        XCTAssertGreaterThan(preparedRate, rookieRate, "se préparer (business, Momo) doit aider")

        // Always pushing hard makes him leave; always giving in leaves you short.
        let data = try negotiation()
        var greedy = NegotiationState(negotiation: data), meek = greedy
        while !greedy.isOver {
            let options = data.clauses[greedy.clauseIndex].options.filter { $0.requires == nil }
            NegotiationEngine.apply(options.max { $0.royalties < $1.royalties }!, optionIndex: 0, businessLevel: 1, to: &greedy)
        }
        while !meek.isOver {
            let options = data.clauses[meek.clauseIndex].options
            NegotiationEngine.apply(options.max { $0.patience < $1.patience }!, optionIndex: 0, businessLevel: 1, to: &meek)
        }
        XCTAssertTrue(greedy.walkedOut, "tout exiger fait partir Victor")
        XCTAssertFalse(meek.passed, "tout accepter donne un contrat pourri")
    }

    func testKolosseBossIsHardButFair() throws {
        let engine = GameEngine(world: world)
        let event = try XCTUnwrap(world.story.events.first { $0.id == "story_kolosse" })
        let spec = try XCTUnwrap(event.choices[0].clash)
        func winRate(smart: Bool) throws -> Double {
            var wins = 0
            let runs = 600
            for i in 0..<runs {
                var state = engine.newGame(rapper: Rapper(name: "T", city: .paris, style: Style.allCases[i % 4]))
                // Roughly where a player stands in chapter 4.
                state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 200) }))
                state.clash = ClashState(spec: spec)
                while !(state.clash?.isOver ?? true) {
                    if smart && state.clash!.playerSecretReady {
                        _ = try engine.clashSecret(in: &state, using: &rng)
                    } else {
                        let move: ClashMove = smart ? .story : ClashMove.allCases.randomElement(using: &rng)!
                        _ = try engine.clashMove(move, in: &state, using: &rng)
                    }
                }
                if state.clash!.playerWon { wins += 1 }
            }
            return Double(wins) / Double(runs)
        }
        let smart = try winRate(smart: true)
        let random = try winRate(smart: false)
        print("Boss Kolosse — stratégie: \(smart), hasard: \(random)")
        XCTAssertGreaterThan(smart, 0.45, "boss trop dur")
        XCTAssertLessThan(random, 0.6, "boss trop facile au hasard")
    }

    // MARK: Chapter 4, played by the engine

    func testChapterFourPlaythrough() throws {
        let engine = GameEngine(world: world)
        var state = engine.newGame(rapper: Rapper(name: "Kiki", city: .lyon, style: .melancolique))
        state.chapter = 4
        state.pendingCinematic = nil
        state.flags = ["chapitre_1", "chapitre_2", "chapitre_3", "signe_goslo", "sous_contrat", "concert_reussi"]
        state.counters.increment(.projets)
        state.stats = Stats(streams: 50, credibilite: 55, argent: 40, mental: 70)
        state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 200) }))
        func refill() { if state.actionsLeft == 0 { state.actionsLeft = GameState.actionsPerTurn } }
        let map = try XCTUnwrap(world.map(for: .hauts))
        XCTAssertEqual(world.district(ofNPC: "victor_contrat", chapter: 4), .hauts, "Victor attend dans les Hauts")
        XCTAssertNil(world.district(ofNPC: "victor_contrat", chapter: 3))

        XCTAssertEqual(engine.currentObjective(in: state)?.id, "buzz")
        XCTAssertEqual(try engine.visit(.reseaux, in: &state, using: &rng).id, "story_buzz")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(state.pendingCinematic, "appel_victor")
        engine.cinematicFinished("appel_victor", in: &state)

        refill()
        XCTAssertEqual(try engine.talk(to: "lil_sauge", in: &state, using: &rng)?.id, "story_sauge")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertTrue(state.flags.contains("feat_sauge"))

        // Boss 1: Kolosse spots you. Beating him earlier in the career does not skip it.
        refill()
        state.flags.insert("clash_gagne_kolosse")
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "kolosse")
        XCTAssertTrue(engine.canChallenge("kolosse", in: state))
        XCTAssertEqual(try engine.talk(to: "kolosse", challenge: true, in: &state, using: &rng)?.id, "story_kolosse")
        guard case .clash = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de clash") }
        while !(state.clash?.isOver ?? true) {
            if state.clash!.playerSecretReady { _ = try engine.clashSecret(in: &state, using: &rng) }
            else { _ = try engine.clashMove(.story, in: &state, using: &rng) }
            if state.clash!.isOver && !state.clash!.playerWon {
                // Retry until the win, like a player would.
                _ = try engine.finishClash(in: &state)
                refill()
                XCTAssertEqual(engine.currentObjective(in: state)?.id, "kolosse")
                _ = try engine.talk(to: "kolosse", challenge: true, in: &state, using: &rng)
                _ = try engine.resolve(choiceAt: 0, in: &state)
            }
        }
        _ = try engine.finishClash(in: &state)
        XCTAssertTrue(state.flags.contains("kolosse_ko"))

        refill()
        XCTAssertEqual(try engine.visit(.label, in: &state, using: &rng).id, "story_momo_major")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertGreaterThanOrEqual(state.relation("momo"), 65, "promettre à Momo débloque l'option Momo")

        refill()
        XCTAssertEqual(try engine.visit(.chezToi, in: &state, using: &rng).id, "story_contrat_lu")
        _ = try engine.resolve(choiceAt: 0, in: &state)
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "negociation")

        // Boss 2: the contract. A greedy first try makes Victor leave; the retry works.
        refill()
        XCTAssertEqual(try engine.talk(to: "victor_contrat", in: &state, using: &rng)?.id, "story_negociation")
        guard case .negotiation = try engine.resolve(choiceAt: 0, in: &state) else { return XCTFail("pas de négociation") }
        XCTAssertFalse(engine.canVisit(state), "on ne se balade pas pendant une négociation")
        let greedy = [0, 2, 0, 0, 0, 0]
        while let running = state.negotiation, !running.isOver {
            _ = try engine.negotiate(greedy[running.clauseIndex], in: &state)
        }
        let walkout = try engine.finishNegotiation(in: &state)
        XCTAssertTrue(try XCTUnwrap(walkout.negotiation).walkedOut)
        XCTAssertEqual(engine.currentObjective(in: state)?.id, "negociation", "on peut retenter")

        refill()
        XCTAssertEqual(try engine.talk(to: "victor_contrat", in: &state, using: &rng)?.id, "story_negociation")
        _ = try engine.resolve(choiceAt: 1, in: &state)
        // Pick the clauses that matter, give in on the rest.
        let smart = [0, 0, 2, 2, 1, 1]
        while let running = state.negotiation, !running.isOver {
            _ = try engine.negotiate(smart[running.clauseIndex], in: &state)
        }
        let deal = try engine.finishNegotiation(in: &state)
        XCTAssertTrue(try XCTUnwrap(deal.negotiation).passed)
        XCTAssertTrue(state.flags.contains("contrat_signe"))
        XCTAssertFalse(map.forChapter(4, flags: state.flags).npcs.contains { $0.id == "victor_contrat" })
        XCTAssertEqual(state.pendingCinematic, "ch4_outro")
        engine.cinematicFinished("ch4_outro", in: &state)
        XCTAssertEqual(state.chapter, 5)
        XCTAssertTrue(state.flags.contains("chapitre_4"))
    }
}
