import XCTest
@testable import Klar

final class MorningAfterCardWordingTests: XCTestCase {
    private let berlin = "Europe/Berlin"

    private func date(_ d: Int, _ h: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: d, hour: h))!
    }

    func testTheMorningAfterSaysTodayAndYesterday() {
        let wording = MorningAfterCardView.Wording(dayKey: "2026-09-19", now: date(20, 10), timezoneID: berlin)
        XCTAssertTrue(wording.isAboutYesterday)
        XCTAssertEqual(wording.bodyQuestion, "Wie geht's dir heute körperlich?")
        XCTAssertEqual(wording.regretQuestion, "Bereust du etwas von gestern?")
    }

    func testALaterAnswerSpeaksOfTheDayAfter() {
        let wording = MorningAfterCardView.Wording(dayKey: "2026-09-18", now: date(20, 10), timezoneID: berlin)
        XCTAssertFalse(wording.isAboutYesterday)
        XCTAssertEqual(wording.bodyQuestion, "Wie ging's dir am Tag danach körperlich?")
        XCTAssertEqual(wording.regretQuestion, "Bereust du etwas von dem Tag?")
    }

    /// At 03:00 on the 20th it is still logically the 19th, so the 18th is „gestern".
    func testBeforeTheCutoffYesterdayIsTheDayBeforeTheLogicalToday() {
        XCTAssertTrue(MorningAfterCardView.Wording(dayKey: "2026-09-18", now: date(20, 3), timezoneID: berlin).isAboutYesterday)
    }
}
