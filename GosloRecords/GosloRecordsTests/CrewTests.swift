import XCTest
@testable import GosloRecords

/// Crew cards: earning them, fragments and levels, the active crew's slots, the perks, older saves.
final class CrewTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func game(city: City = .lyon) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Crew", city: city, style: .trap))
        state.pendingCinematic = nil
        state.chapter = 3
        state.stats = Stats(streams: 50, credibilite: 50, argent: 60, mental: 60)
        state.hooks = ["le bitume est mon costume"]
        state.challenges = []
        state.challengeSeason = Challenges.season(of: state.turn)
        return state
    }

    /// Wins a clash against `id` (a story clash, or the terrain vague).
    @discardableResult
    private func win(_ id: String, wild: Bool = false, in state: inout GameState) throws -> TurnOutcome {
        var clash = ClashState(spec: ClashSpec(opponent: id, win: ClashResultSpec(consequence: "gagné"),
                                               lose: ClashResultSpec(consequence: "perdu")), isWild: wild)
        clash.opponentHype = 0
        state.clash = clash
        state.actionsLeft = GameState.actionsPerTurn
        return try engine.finishClash(in: &state)
    }

    // MARK: Catalog

    func testEveryCardIsACastMemberWithASource() {
        XCTAssertEqual(Set(Crew.catalog.map(\.id)).count, Crew.catalog.count, "une carte par personnage")
        let tournament = Set(world.story.tournament.map(\.opponent))
        let quests = Set(world.quests.map(\.id))
        for spec in Crew.catalog {
            let member = engine.castMember(spec.id)
            XCTAssertNotNil(member, "\(spec.id) absent de cast.json")
            for quest in spec.quests { XCTAssertTrue(quests.contains(quest), "\(spec.id) : quête \(quest) inconnue") }
            XCTAssertTrue(member?.clash != nil || !spec.quests.isEmpty || tournament.contains(spec.id),
                          "\(spec.id) : aucune façon de gagner la carte")
        }
        for rarity in CrewRarity.allCases {
            XCTAssertTrue(Crew.catalog.contains { $0.rarity == rarity }, "aucune carte \(rarity.label)")
        }
        XCTAssertEqual(Crew.spec("le_baron")?.rarity, .legendaire)
    }

    // MARK: Earning

    func testBeatingARivalGivesTheirCardAndOneFragmentPerPeriod() throws {
        var state = game()
        let outcome = try win("scalpel", in: &state)
        XCTAssertTrue(state.crew.owns("scalpel"))
        XCTAssertEqual(outcome.crewCards, [CrewGain(cardId: "scalpel", isNew: true, level: 1, leveledUp: false, joinedCrew: true)])
        XCTAssertEqual(state.crew.active, ["scalpel"], "une place libre : elle rejoint le crew")
        XCTAssertTrue(outcome.notes.contains { $0.hasPrefix("NOUVELLE CARTE") })

        // Same period: no fragment (no farming the same rival).
        let again = try win("scalpel", in: &state)
        XCTAssertTrue(again.crewCards.isEmpty)
        XCTAssertEqual(state.crew.fragments["scalpel"], 0)

        state.turn += 1
        try win("scalpel", in: &state)
        XCTAssertEqual(state.crew.fragments["scalpel"], 1)
        state.turn += 1
        let levelUp = try win("scalpel", in: &state)
        XCTAssertEqual(state.crew.level("scalpel"), 2)
        XCTAssertEqual(levelUp.crewCards.first?.leveledUp, true)
    }

    func testTheTerrainVagueOnlyPaysACardWhileItsGateIsOpen() throws {
        var state = game()
        try win("rappeur_soiree", wild: true, in: &state)
        XCTAssertTrue(state.crew.owns("rappeur_soiree"))

        state.turn += 1
        state.gatePeriodUses[Gate.terrain.rawValue] = 99
        let spent = try win("rappeur_soiree", wild: true, in: &state)
        XCTAssertTrue(spent.crewCards.isEmpty, "le terrain ne paie plus : pas de fragment")
        XCTAssertEqual(state.crew.fragments["rappeur_soiree"], 0)
    }

    func testFinishingTheirQuestGivesTheCard() {
        let engine = GameEngine(events: [], cast: [CastMember(id: "papy_groove", name: "Papy Groove", role: "")],
                                quests: [Quest(id: "face_b_papy", title: "La face B",
                                               steps: [QuestStep(label: "Rendre", conditions: EventConditions(requiredFlags: ["rendu"]))])])
        var state = engine.newGame(rapper: Rapper(name: "Q", city: .lyon, style: .trap))
        var outcome = TurnOutcome(consequence: "")
        engine.applyQuestProgress(&outcome, in: &state)
        XCTAssertFalse(state.crew.owns("papy_groove"))
        state.flags.insert("rendu")
        engine.applyQuestProgress(&outcome, in: &state)
        XCTAssertTrue(state.crew.owns("papy_groove"))
        XCTAssertEqual(outcome.crewCards.map(\.cardId), ["papy_groove"])
    }

    func testRecordingAFeatGivesTheCard() throws {
        var state = game()
        state.artistXP = ArtistLevel.thresholds[ArtistLevel.Unlock.feat.level - 1]
        state.metCast.insert("orphee")
        state.relations["orphee"] = 70
        let outcome = try engine.releaseSingle(sourceId: "refrain_0", perfectTakes: 2, clip: false, feat: "orphee", in: &state)
        XCTAssertEqual(state.singles.last?.feat, "orphee")
        XCTAssertTrue(state.crew.owns("orphee"))
        XCTAssertEqual(outcome.crewCards.first?.isNew, true)
    }

    func testCityCardsStayInTheirCity() {
        var lyon = game(city: .lyon)
        XCTAssertNil(engine.grantCrewCard(id: "zanga", in: &lyon))
        XCTAssertFalse(Crew.cards(for: .lyon).contains { $0.id == "zanga" })
        var casa = game(city: .casablanca)
        XCTAssertNotNil(engine.grantCrewCard(id: "zanga", in: &casa))
        XCTAssertNil(engine.grantCrewCard(id: "personne", in: &casa), "pas de carte pour un inconnu")
    }

    // MARK: Levels

    func testFragmentThresholds() {
        let levels = [0: 1, 1: 1, 2: 2, 5: 2, 6: 3, 13: 3, 14: 4, 29: 4, 30: 5, 99: 5]
        for (fragments, level) in levels { XCTAssertEqual(Crew.level(fragments: fragments), level, "\(fragments) fragments") }
        XCTAssertEqual(Crew.progress(fragments: 0)?.need, 2)
        XCTAssertEqual(Crew.progress(fragments: 3)?.have, 1)
        XCTAssertEqual(Crew.progress(fragments: 3)?.need, 4)
        XCTAssertNil(Crew.progress(fragments: 30), "niveau max")

        var state = game()
        for _ in 0...(Crew.maxFragments + 5) { engine.grantCrewCard(id: "lingot", in: &state) }
        XCTAssertEqual(state.crew.fragments["lingot"], Crew.maxFragments, "les fragments s'arrêtent au niveau 5")
        XCTAssertEqual(state.crew.level("lingot"), Crew.maxLevel)
    }

    // MARK: Active crew

    func testTheActiveCrewHasThreeSlotsThenFour() {
        var state = game()
        for id in ["scalpel", "kolosse", "saphir", "lingot", "lil_croon"] { engine.grantCrewCard(id: id, in: &state) }
        XCTAssertEqual(state.crew.active, ["scalpel", "kolosse", "saphir"])
        XCTAssertEqual(engine.crewSlots(in: state), 3)
        XCTAssertFalse(engine.setCrewMember("lingot", active: true, in: &state))
        XCTAssertNotNil(engine.crewJoinRefusal("lingot", in: state))
        XCTAssertFalse(engine.setCrewMember("le_baron", active: true, in: &state), "carte pas gagnée")

        state.artistXP = ArtistLevel.thresholds[ArtistLevel.Unlock.crew.level - 1]
        XCTAssertEqual(engine.crewSlots(in: state), 4)
        XCTAssertTrue(engine.setCrewMember("lingot", active: true, in: &state))
        XCTAssertFalse(engine.setCrewMember("lil_croon", active: true, in: &state), "4 places au maximum")

        XCTAssertTrue(engine.setCrewMember("kolosse", active: false, in: &state))
        XCTAssertTrue(engine.setCrewMember("lil_croon", active: true, in: &state))
        XCTAssertEqual(state.crew.active, ["scalpel", "saphir", "lingot", "lil_croon"])
        XCTAssertFalse(engine.setCrewMember("lil_croon", active: true, in: &state), "déjà dans le crew")
    }

    // MARK: Perks

    func testTheGaugePerkScalesWithTheCardLevel() {
        var state = game()
        XCTAssertEqual(engine.startingMeter(in: state), 0)
        engine.grantCrewCard(id: "le_baron", in: &state)
        XCTAssertEqual(engine.startingMeter(in: state), 5)
        state.crew.fragments["le_baron"] = Crew.maxFragments
        XCTAssertEqual(engine.startingMeter(in: state), 12)
        state.rapper.heritage = .flow
        XCTAssertLessThan(engine.startingMeter(in: state), ClashState.secretThreshold, "jamais prête d'avance")
        _ = engine.setCrewMember("le_baron", active: false, in: &state)
        XCTAssertEqual(engine.startingMeter(in: state), ClashState.secretThreshold / 2, "hors du crew : plus d'effet")
    }

    func testTheCounterPerkAddsTaps() throws {
        var state = game()
        engine.grantCrewCard(id: "scalpel", in: &state)
        XCTAssertEqual(Crew.counterTaps(in: state), 2)
        state.crew.fragments["scalpel"] = Crew.maxFragments
        XCTAssertEqual(Crew.counterTaps(in: state), 6)

        let pending = PendingCounter(secret: SecretTechnique(name: "X", line: "x"), damage: 40)
        var clash = ClashState(spec: ClashSpec(opponent: "le_baron", win: ClashResultSpec(consequence: ""),
                                               lose: ClashResultSpec(consequence: "")))
        clash.pendingCounter = pending
        var bare = state
        bare.crew = CrewState()
        state.clash = clash
        bare.clash = clash
        let withCrew = try engine.counterSecret(taps: 6, in: &state)
        let without = try engine.counterSecret(taps: 6, in: &bare)
        XCTAssertGreaterThan(withCrew.playerHype, without.playerHype)
    }

    func testPeriodPerksAreCapped() {
        var state = game()
        for id in ["lil_karaoke", "coach_burpee", "rappeur_soiree"] {
            engine.grantCrewCard(id: id, in: &state)
        }
        XCTAssertEqual(Crew.periodEffects(in: state), [.mental: 3])
        XCTAssertEqual(Economy.turnEnd(for: state).effects[.mental], 3)
        for id in state.crew.active { state.crew.fragments[id] = Crew.maxFragments }
        XCTAssertEqual(Crew.periodEffects(in: state), [.mental: Crew.periodCap])
    }

    func testFeatPerkPaysMoreStreams() {
        XCTAssertEqual(Crew.boosted(3, by: 0.2), 4)
        XCTAssertEqual(Crew.boosted(3, by: 0), 3)
        var state = game()
        state.stats = Stats(streams: 70, credibilite: 70, argent: 60, mental: 60)
        state.turn = 4
        state.singles = [Single(id: 1, title: "Feat", sourceId: "refrain_0", quality: 10, releasedTurn: 3, clip: true, feat: "orphee")]
        XCTAssertEqual(Crew.featBonus("orphee", in: state), 0)
        var featured = state
        engine.grantCrewCard(id: "orphee", in: &featured)
        XCTAssertEqual(Crew.featBonus("orphee", in: featured), 0.2, accuracy: 0.001)
        XCTAssertEqual(Crew.featBonus("scalpel", in: featured), 0)

        var plain = TurnOutcome(consequence: ""), boosted = TurnOutcome(consequence: "")
        let before = state.stats.streams
        engine.payChart(&plain, in: &state)
        engine.payChart(&boosted, in: &featured)
        XCTAssertNotNil(state.singles[0].ranks.last ?? nil, "le single est dans le Top")
        XCTAssertGreaterThan(featured.stats.streams - before, state.stats.streams - before)
    }

    func testBuildingPerkBoostsItsBuilding() {
        var state = game()
        state.placed = [PlacedDecor(id: 1, decor: .studioPerso, district: .bloc, x: 2, y: 2)]
        var withFred = state
        engine.grantCrewCard(id: "fred", in: &withFred)
        XCTAssertEqual(Crew.buildingBonus(.studioPerso, in: withFred), 0.15, accuracy: 0.001)
        XCTAssertEqual(Crew.buildingBonus(.snack, in: withFred), 0)
        _ = engine.decorIncome(in: &state)
        _ = engine.decorIncome(in: &withFred)
        XCTAssertGreaterThan(withFred.placed[0].stored, state.placed[0].stored)
        XCTAssertGreaterThan(withFred.stats.streams, state.stats.streams)
    }

    // MARK: Saves

    func testOlderSavesLoadWithTheCardsTheyEarned() throws {
        var state = game()
        state.flags = ["clash_gagne_kolosse", "clash_gagne_le_baron", "clash_gagne_inconnu"]
        state.completedQuests = ["prod_sami"]
        state.crew = CrewState(fragments: ["x": 3])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "crew")
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(Set(old.crew.fragments.keys), ["kolosse", "le_baron", "petit_sami"])
        XCTAssertEqual(old.crew.active.first, "le_baron", "les meilleures cartes forment le crew")
        XCTAssertEqual(old.crew.active.count, 3)

        json["flags"] = []
        json["completedQuests"] = []
        let fresh = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(fresh.crew, CrewState())

        // The crew itself round-trips, and a partial one decodes.
        var full = game()
        engine.grantCrewCard(id: "saphir", in: &full)
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(full))
        XCTAssertEqual(back.crew, full.crew)
        let partial = try JSONDecoder().decode(CrewState.self, from: Data(#"{"fragments":{"saphir":2}}"#.utf8))
        XCTAssertEqual(partial.level("saphir"), 2)
        XCTAssertTrue(partial.active.isEmpty)
    }
}
