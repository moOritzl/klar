import XCTest
@testable import KlarCore

final class PreviousDayKeyTests: XCTestCase {
    func testWithinAMonth() {
        XCTAssertEqual(LogicalDay.previousDayKey("2026-09-20"), "2026-09-19")
    }

    func testAcrossMonthAndYearBoundaries() {
        XCTAssertEqual(LogicalDay.previousDayKey("2026-03-01"), "2026-02-28")
        XCTAssertEqual(LogicalDay.previousDayKey("2028-03-01"), "2028-02-29")
        XCTAssertEqual(LogicalDay.previousDayKey("2026-01-01"), "2025-12-31")
    }

    func testRejectsSomethingThatIsNotAKey() {
        XCTAssertNil(LogicalDay.previousDayKey("gestern"))
    }
}
