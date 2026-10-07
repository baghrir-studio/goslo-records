import XCTest
@testable import GosloRecords

/// Rappeur or rappeuse: every text agrees, and none is left half-written.
final class GenderTests: XCTestCase {
    func testAgreementPicksTheRightForm() {
        let him = Rapper(name: "Kéké", city: .lille, style: .trap)
        let her = Rapper(name: "Kéka", city: .lille, style: .trap, gender: .rappeuse)
        let text = "{Monsieur|Madame} {nom}, merci d'être {venu|venue}. Reviens quand tu seras {prêt|prête}, {frère|ma sœur}."
        XCTAssertEqual(TextTemplate.render(text, for: him), "Monsieur Kéké, merci d'être venu. Reviens quand tu seras prêt, frère.")
        XCTAssertEqual(TextTemplate.render(text, for: her), "Madame Kéka, merci d'être venue. Reviens quand tu seras prête, ma sœur.")
        XCTAssertEqual(TextTemplate.render("Rien à accorder.", for: her), "Rien à accorder.")
    }

    func testOldSavesAreRappeurs() throws {
        let old = try JSONDecoder().decode(Rapper.self, from: Data(#"{"name": "T", "city": "Lyon", "style": "Trap", "skinTone": 2}"#.utf8))
        XCTAssertEqual(old.gender, .rappeur)
        XCTAssertFalse(old.look.feminine)
        let her = Rapper(name: "T", city: .lyon, style: .boomBap, gender: .rappeuse)
        XCTAssertTrue(her.look.feminine)
        XCTAssertFalse(her.look.beard)
        XCTAssertEqual(try JSONDecoder().decode(Rapper.self, from: JSONEncoder().encode(her)).gender, .rappeuse)
    }

    /// Every `{a|b}` in the data is well formed: no stray braces or bars once rendered, for both.
    func testEveryTextRendersCleanlyForBoth() throws {
        let bundle = Bundle(for: AppModel.self)
        for name in ["story", "events", "quests", "cast"] {
            let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"), name)
            let raw = try String(contentsOf: url, encoding: .utf8)
            for gender in Gender.allCases {
                let rendered = TextTemplate.agree(raw, gender)
                XCTAssertFalse(rendered.contains("|"), "\(name) : un {a|b} mal formé (\(gender))")
                XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(rendered.utf8)), "\(name) reste du JSON valide")
            }
        }
    }
}
