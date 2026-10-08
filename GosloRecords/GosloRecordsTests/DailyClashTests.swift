import XCTest
@testable import GosloRecords

/// The daily clash: same opponent for everyone each day, one attempt, a streak of days won.
final class DailyClashTests: XCTestCase {
    private var world = World(events: [])
    private var engine = GameEngine(events: [])

    override func setUpWithError() throws {
        world = try EventLoader.loadWorld(bundle: Bundle(for: AppModel.self))
        engine = GameEngine(world: world)
    }

    private func days(_ count: Int) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        return (0..<count).map { DailyClash.dayKey(calendar.date(byAdding: .day, value: $0, to: start)!, calendar: calendar) }
    }

    func testEveryoneGetsTheSameClashEachDay() throws {
        let keys = days(40)
        XCTAssertEqual(keys[0], "2026-10-01")
        XCTAssertEqual(keys[31], "2026-11-01")
        let challenges = try keys.map { try XCTUnwrap(DailyClash.challenge(for: $0, cast: world.cast, excluding: engine.tournamentOpponents)) }
        XCTAssertEqual(DailyClash.challenge(for: keys[3], cast: world.cast, excluding: engine.tournamentOpponents), challenges[3], "même jour, même clash")
        XCTAssertGreaterThan(Set(challenges.map(\.opponentId)).count, 5, "ça change d'un jour à l'autre")
        XCTAssertGreaterThan(Set(challenges.map(\.district)).count, 2)

        let pool = Set(DailyClash.pool(world.cast, excluding: engine.tournamentOpponents).map(\.id))
        XCTAssertTrue(pool.isDisjoint(with: engine.tournamentOpponents), "les boss du Tournoi restent au Tournoi")
        XCTAssertFalse(pool.contains("le_baron"), "pas le boss final")
        XCTAssertFalse(pool.contains("pigeon_lille"))
        XCTAssertFalse(pool.contains("hater_anonyme"), "pas les figurants du terrain vague")
        XCTAssertTrue(pool.contains("scalpel"))
    }

    func testOneAttemptADayAndTheStreak() {
        let d = days(5)
        var record = DailyRecord()
        XCTAssertTrue(record.canPlay(on: d[0]))
        record.start(on: d[0])
        XCTAssertFalse(record.canPlay(on: d[0]), "un seul essai par jour")
        record.finish(on: d[0], won: true, yesterday: "2026-09-30")
        XCTAssertEqual(record.streak, 1)
        record.start(on: d[1])
        record.finish(on: d[1], won: true, yesterday: d[0])
        XCTAssertEqual(record.streak, 2)
        XCTAssertEqual(record.currentStreak(today: d[2], yesterday: d[1]), 2, "la série tient jusqu'au lendemain")
        XCTAssertEqual(record.currentStreak(today: d[3], yesterday: d[2]), 0, "un jour sauté casse la série")
        record.start(on: d[3])
        record.finish(on: d[3], won: true, yesterday: d[2])
        XCTAssertEqual(record.streak, 1)
        record.start(on: d[4])
        record.finish(on: d[4], won: false, yesterday: d[3])
        XCTAssertEqual(record.streak, 0)
        XCTAssertEqual(record.lastResultWon, false)
        XCTAssertEqual(record.best, 2)
        XCTAssertEqual(record.wins, 3)
    }

    func testOldProfilesLoad() throws {
        let old = try JSONDecoder().decode(TrophyCase.self, from: Data(#"{"achievements":{}}"#.utf8))
        XCTAssertEqual(old.daily, DailyRecord())
        var profile = TrophyCase()
        profile.daily.start(on: "2026-10-08")
        let back = try JSONDecoder().decode(TrophyCase.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(back.daily.lastPlayed, "2026-10-08")
    }

    func testTheDailyGameIsTheSameForEveryone() throws {
        let challenge = try XCTUnwrap(DailyClash.challenge(for: "2026-10-08", cast: world.cast, excluding: engine.tournamentOpponents))
        let game = engine.dailyGame(challenge, rapper: Rapper(name: "A", city: .lyon, style: .trap))
        XCTAssertTrue(Skill.allCases.allSatisfy { game.skills.level($0) == DailyClash.playerLevel })
        XCTAssertEqual(game.clash?.opponentId, challenge.opponentId)
        XCTAssertEqual(game.clash?.crowdFavorite, challenge.crowd)
        XCTAssertEqual(game.district, challenge.district)
        XCTAssertNil(game.pendingCinematic)
    }

    func testTacticsWinTheDailyClash() throws {
        var rng = SeededGenerator(seed: 808)
        func winRate(smart: Bool) throws -> Double {
            var wins = 0, total = 0
            for (index, day) in days(60).enumerated() {
                let challenge = try XCTUnwrap(DailyClash.challenge(for: day, cast: world.cast, excluding: engine.tournamentOpponents))
                let profile = try XCTUnwrap(engine.castMember(challenge.opponentId)?.clash)
                for run in 0..<10 {
                    var state = engine.dailyGame(challenge, rapper: Rapper(name: "T", city: .paris, style: Style.allCases[(index + run) % 4]))
                    while !(state.clash?.isOver ?? true) {
                        let clash = state.clash!
                        if smart && clash.playerSecretReady {
                            _ = try engine.clashSecret(in: &state, using: &rng)
                            continue
                        }
                        let move: ClashMove
                        if smart {
                            move = ClashTactics.telegraphed(clash)?.counter ?? profile.weakness ?? challenge.crowd
                        } else {
                            move = ClashMove.allCases.randomElement(using: &rng)!
                        }
                        _ = try engine.clashMove(move, in: &state, using: &rng)
                    }
                    total += 1
                    if state.clash!.playerWon { wins += 1 }
                }
            }
            return Double(wins) / Double(total)
        }
        let smart = try winRate(smart: true)
        let random = try winRate(smart: false)
        print("Clash du jour — tactique : \(smart), hasard : \(random)")
        XCTAssertGreaterThan(smart, 0.6, "le clash du jour doit se gagner en jouant bien")
        XCTAssertLessThan(smart, 0.95, "et rester un défi")
        XCTAssertLessThan(random, 0.45, "au hasard, on perd le plus souvent")
    }
}
