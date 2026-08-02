import XCTest
@testable import KlarCore

final class PlanSentenceTests: XCTestCase {
    func testLowercasesLeadingWordOfATypedPhrase() {
        XCTAssertEqual(PlanSentence.fragment("Auf einer Party"), "auf einer Party")
        XCTAssertEqual(PlanSentence.fragment("Alkoholfreies Bier statt Bier"), "alkoholfreies Bier statt Bier")
        XCTAssertEqual(PlanSentence.fragment("Stress"), "stress")
    }

    func testKeepsNounsAfterTheFirstWordUntouched() {
        XCTAssertEqual(PlanSentence.fragment("Abends allein zuhause"), "abends allein zuhause")
        XCTAssertEqual(PlanSentence.fragment("Tee statt Kaffee nach 18 Uhr"), "tee statt Kaffee nach 18 Uhr")
    }

    func testLowercasesUmlauts() {
        XCTAssertEqual(PlanSentence.fragment("Überstunden machen"), "überstunden machen")
    }

    func testKeepsFragmentsWhoseFirstWordHasMoreUppercase() {
        XCTAssertEqual(PlanSentence.fragment("AA-Meeting besuchen"), "AA-Meeting besuchen")
        XCTAssertEqual(PlanSentence.fragment("WG-Party"), "WG-Party")
        XCTAssertEqual(PlanSentence.fragment("U-Bahn nach Hause"), "U-Bahn nach Hause")
        XCTAssertEqual(PlanSentence.fragment("McDonalds"), "McDonalds")
    }

    func testKeepsSingleLetterFirstWords() {
        XCTAssertEqual(PlanSentence.fragment("S Bahn nehmen"), "S Bahn nehmen")
    }

    func testKeepsFragmentsThatDoNotStartWithAnUppercaseLetter() {
        XCTAssertEqual(PlanSentence.fragment("auf einer Party"), "auf einer Party")
        XCTAssertEqual(PlanSentence.fragment("iPhone weglegen"), "iPhone weglegen")
        XCTAssertEqual(PlanSentence.fragment("3 Bier maximal"), "3 Bier maximal")
        XCTAssertEqual(PlanSentence.fragment("„Nein“ sagen"), "„Nein“ sagen")
    }

    func testHandlesEmptyAndWhitespaceOnlyText() {
        XCTAssertEqual(PlanSentence.fragment(""), "")
        XCTAssertEqual(PlanSentence.fragment("   "), "   ")
    }

    func testPreservesTheRestOfTheStringVerbatim() {
        XCTAssertEqual(
            PlanSentence.fragment("Erst ein Wasser bestellen, dann weitersehen"),
            "erst ein Wasser bestellen, dann weitersehen"
        )
        XCTAssertEqual(PlanSentence.fragment("Party,"), "party,")
    }
}
