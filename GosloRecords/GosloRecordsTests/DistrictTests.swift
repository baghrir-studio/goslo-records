import XCTest
@testable import GosloRecords

/// The city grows with the career: districts open by chapter, the metro takes you there.
final class DistrictTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func game(chapter: Int) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Métro", city: .paris, style: .trap))
        state.chapter = chapter
        state.pendingCinematic = nil
        return state
    }

    func testDistrictsOpenWithTheStory() {
        XCTAssertEqual(engine.openDistricts(in: game(chapter: 1)), [.bloc])
        XCTAssertEqual(engine.openDistricts(in: game(chapter: 2)), [.bloc])
        XCTAssertEqual(engine.openDistricts(in: game(chapter: 3)), [.bloc, .centre])
        XCTAssertEqual(engine.openDistricts(in: game(chapter: 4)), [.bloc, .centre, .hauts])
        XCTAssertEqual(engine.openDistricts(in: game(chapter: 6)), District.allCases)
    }

    func testMetroTakesYouToTheStation() throws {
        var state = game(chapter: 3)
        XCTAssertEqual(state.district, .bloc)
        XCTAssertThrowsError(try engine.travel(to: .dome, in: &state)) {
            XCTAssertEqual($0 as? GameEngineError, .districtLocked(.dome))
        }
        try engine.travel(to: .centre, in: &state)
        let centre = try XCTUnwrap(world.map(for: .centre))
        XCTAssertEqual(state.district, .centre)
        XCTAssertEqual(state.position, centre.arrival)
        XCTAssertEqual(engine.currentMap(in: state)?.rows, centre.rows)

        try engine.travel(to: .bloc, in: &state)
        XCTAssertEqual(state.position, world.map?.arrival)
    }

    func testOldSavesStayInLeBloc() throws {
        var state = game(chapter: 4)
        try engine.travel(to: .hauts, in: &state)
        let restored = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.district, .hauts)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["district"] = nil
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.district, .bloc)
    }

    func testObjectiveShowsWhichDistrictToGoTo() throws {
        var state = game(chapter: 3)
        let chapter = try XCTUnwrap(engine.story.chapter(3))
        state.objectiveIndex = try XCTUnwrap(chapter.objectives.firstIndex { $0.trigger?.npc == "dj_bobine" })
        XCTAssertEqual(engine.objectiveDistrict(in: state), .centre, "DJ Bobine est en centre-ville")
        try engine.travel(to: .centre, in: &state)
        XCTAssertNil(engine.objectiveDistrict(in: state), "tu y es")

        state.objectiveIndex = try XCTUnwrap(chapter.objectives.firstIndex { $0.trigger?.location == .scene })
        XCTAssertNil(engine.objectiveDistrict(in: state), "la scène est ici")
        try engine.travel(to: .bloc, in: &state)
        XCTAssertEqual(engine.objectiveDistrict(in: state), .centre)

        state.objectiveIndex = try XCTUnwrap(chapter.objectives.firstIndex { $0.trigger?.location == .chezToi })
        XCTAssertNil(engine.objectiveDistrict(in: state), "chez toi, c'est au Bloc")
    }

    func testTheFinaleIsAtTheDome() throws {
        var state = game(chapter: 6)
        let chapter = try XCTUnwrap(engine.story.chapter(6))
        state.objectiveIndex = try XCTUnwrap(chapter.objectives.firstIndex { $0.trigger?.npc == "le_baron" })
        XCTAssertEqual(engine.objectiveDistrict(in: state), .dome, "le Baron attend devant son arène")
        state.objectiveIndex = try XCTUnwrap(chapter.objectives.firstIndex { $0.trigger?.location == .scene })
        XCTAssertEqual(engine.objectiveDistrict(in: state), .dome)
    }

    func testStoryScenesBringYouBackToLeBloc() throws {
        var state = game(chapter: 3)
        try engine.travel(to: .centre, in: &state)
        let talk = Cinematic(id: "t", steps: [CinematicStep(narration: "Le téléphone sonne.")])
        XCTAssertFalse(engine.stageCinematic(talk, in: &state), "une scène sans déplacement se joue sur place")
        XCTAssertEqual(state.district, .centre)

        let staged = Cinematic(id: "s", steps: [CinematicStep(camera: TilePoint(x: 3, y: 3))])
        XCTAssertTrue(engine.stageCinematic(staged, in: &state))
        XCTAssertEqual(state.district, .bloc)
        XCTAssertEqual(state.position, world.map?.arrival)
    }
}

extension DistrictTests {
    func testEachDistrictWelcomesYouOnce() throws {
        var state = game(chapter: 6)
        XCTAssertNil(engine.arrivalEvent(in: &state), "pas de scène d'arrivée au Bloc")
        for district in District.allCases where district != .bloc {
            try engine.travel(to: district, in: &state)
            let event = try XCTUnwrap(engine.arrivalEvent(in: &state), "\(district)")
            XCTAssertEqual(event.id, GameEngine.arrivalEventId(district))
            XCTAssertEqual(state.currentEventId, event.id)
            let actions = state.actionsLeft
            _ = try engine.resolve(choiceAt: 1, in: &state)
            XCTAssertEqual(state.actionsLeft, actions, "l'arrivée ne coûte pas d'action")
            try engine.travel(to: .bloc, in: &state)
            try engine.travel(to: district, in: &state)
            XCTAssertNil(engine.arrivalEvent(in: &state), "\(district) : une seule fois")
        }
    }

    func testCentreWelcomeIsAStreetCypher() throws {
        var state = game(chapter: 3)
        try engine.travel(to: .centre, in: &state)
        _ = try XCTUnwrap(engine.arrivalEvent(in: &state))
        let resolution = try engine.resolve(choiceAt: 0, in: &state)
        guard case .clash(let clash) = resolution else { return XCTFail("le cypher lance un clash") }
        XCTAssertEqual(clash.opponentId, "diva_decibel")
    }
}
