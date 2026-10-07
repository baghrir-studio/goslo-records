import XCTest
@testable import GosloRecords

final class AlbumTests: XCTestCase {
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        engine = GameEngine(world: try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self)))
    }

    private func career(chapter: Int = 3) -> GameState {
        var state = engine.newGame(rapper: Rapper(name: "Album", city: .lille, style: .boomBap))
        state.chapter = chapter
        state.flags = ["premier_texte", "micro_ouvert_fait", "signe_goslo", "concert_reussi"]
        state.hooks = ["essoré, mais jamais délavé"]
        return state
    }

    func testCandidatesComeFromYourCareer() {
        let tracks = engine.albumCandidates(in: career())
        XCTAssertEqual(tracks.first?.title, "Essoré, mais jamais délavé", "tes refrains d'abord")
        XCTAssertTrue(tracks.contains { $0.title == "Première Scène" })
        XCTAssertFalse(tracks.contains { $0.title == "Le Trône" }, "pas encore vécu")
        XCTAssertEqual(Set(tracks.map(\.id)).count, tracks.count)
        XCTAssertTrue(tracks.allSatisfy { (1...10).contains($0.quality) })
    }

    func testAlbumNeedsChapterThreeAndEnoughTracks() throws {
        var early = career(chapter: 2)
        XCTAssertFalse(engine.canRecordAlbum(in: early))
        XCTAssertThrowsError(try engine.releaseAlbum(title: "X", trackIds: [], cover: .neon, in: &early))

        var state = career()
        let ids = engine.albumCandidates(in: state).map(\.id)
        XCTAssertThrowsError(try engine.releaseAlbum(title: "Court", trackIds: Array(ids.prefix(3)), cover: .neon, in: &state))
        XCTAssertThrowsError(try engine.releaseAlbum(title: "Doublon", trackIds: [ids[0], ids[0], ids[1], ids[2]], cover: .neon, in: &state))
    }

    func testReleaseSellsThenFades() throws {
        var state = career()
        let ids = Array(engine.albumCandidates(in: state).map(\.id).prefix(5))
        let projects = state.counters[.projets]
        let album = try engine.releaseAlbum(title: "  Laverie Gold  ", trackIds: ids, cover: .gold, in: &state)
        XCTAssertEqual(album.title, "Laverie Gold")
        XCTAssertEqual(album.tracks.count, 5)
        XCTAssertEqual(state.counters[.projets], projects + 1)
        XCTAssertGreaterThan(album.sales.first ?? 0, 0)
        XCTAssertFalse(engine.canRecordAlbum(in: state), "un album à la fois")

        for _ in 0..<(AlbumRules.salesSemesters + 2) { _ = engine.sellAlbums(in: &state) }
        let sold = try XCTUnwrap(state.albums.first)
        XCTAssertEqual(sold.sales.count, AlbumRules.salesSemesters, "il finit par quitter les rayons")
        XCTAssertEqual(sold.sales, sold.sales.sorted(by: >), "les ventes baissent")
        XCTAssertFalse(sold.isSelling)

        state.turn += AlbumRules.cooldown
        XCTAssertTrue(engine.canRecordAlbum(in: state))
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(saved.albums, state.albums)
    }

    func testBetterAlbumsSellMore() {
        let stats = Stats(streams: 60, credibilite: 60, argent: 50, mental: 50)
        XCTAssertGreaterThan(AlbumRules.firstSemester(quality: 9, stats: stats, fame: 2),
                             AlbumRules.firstSemester(quality: 4, stats: stats, fame: 2))
        XCTAssertGreaterThan(AlbumRules.firstSemester(quality: 7, stats: stats, fame: 3),
                             AlbumRules.firstSemester(quality: 7, stats: stats, fame: 0))
    }

    func testRefrainTitles() {
        XCTAssertEqual(AlbumRules.title(fromHook: "le bitume est mon costume, et la nuit ma plume"), "Le bitume est mon")
        XCTAssertLessThanOrEqual(AlbumRules.title(fromHook: String(repeating: "anticonstitutionnellement ", count: 4)).count,
                                 AlbumRules.maxTitleLength)
    }
}
