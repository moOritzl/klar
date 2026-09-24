import XCTest
import KlarCore
@testable import Klar

final class MorningPatternTextTests: XCTestCase {
    private func pattern(days: Int = 5, body: [MorningBody: Int] = [:], regret: [MorningRegret: Int] = [:]) -> MorningPattern {
        MorningPattern(days: days, body: body, regret: regret, again: [:], nextTime: nil)
    }

    func testListsTheCountsInAFixedOrder() {
        let text = MorningPatternText.summary(pattern(body: [.hungover: 3, .rough: 1, .fine: 1], regret: [.yes: 1, .slightly: 2]))
        XCTAssertEqual(text, "letzte 5: 3× verkatert, 1× angeschlagen, 1× bereut, 2× ein bisschen bereut")
    }

    func testLeavesOutWhatNeverHappened() {
        XCTAssertEqual(MorningPatternText.summary(pattern(days: 4, body: [.hungover: 2, .fine: 2])), "letzte 4: 2× verkatert")
    }

    func testSaysSoPlainlyWhenNothingWentWrong() {
        XCTAssertEqual(MorningPatternText.summary(pattern(days: 3, body: [.fine: 3], regret: [.no: 2])), "letzte 3: kein Kater, nichts bereut")
    }

    /// „kein Kater" would be a claim the answers never made.
    func testDoesNotClaimAnythingWhenOnlyTheLastQuestionWasAnswered() {
        XCTAssertEqual(MorningPatternText.summary(pattern(days: 3)), "letzte 3: ohne Angaben zu Kater und Reue")
    }

    func testTheContextualLineNamesTheTag() {
        XCTAssertEqual(MorningPatternText.contextual(pattern(days: 4, body: [.hungover: 3, .fine: 1]), tagName: "Club"), "Mit Club · letzte 4: 3× verkatert")
    }
}
