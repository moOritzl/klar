import XCTest
@testable import KlarCore

final class QuotaReadingTests: XCTestCase {
    func testUnderTheLimitCountsWhatWasUsed() {
        let reading = QuotaReading(limit: 3, remaining: 2)
        XCTAssertEqual(reading.count, 1)
        XCTAssertEqual(reading.text, "1 von max. 3")
    }

    func testOnTheLimitCountsUpToIt() {
        let reading = QuotaReading(limit: 2, remaining: 0)
        XCTAssertEqual(reading.count, 2)
        XCTAssertEqual(reading.text, "2 von max. 2")
    }

    /// The numeral keeps counting past the limit — it never switches to what is left — so the
    /// month's real number is always the one on screen.
    func testPastTheLimitKeepsCounting() {
        let reading = QuotaReading(limit: 2, remaining: -2)
        XCTAssertEqual(reading.count, 4)
        XCTAssertEqual(reading.text, "4 von max. 2")
    }

    func testAnEmptyMonthStartsAtZero() {
        let reading = QuotaReading(limit: 4, remaining: 4)
        XCTAssertEqual(reading.count, 0)
        XCTAssertEqual(reading.text, "0 von max. 4")
    }
}
