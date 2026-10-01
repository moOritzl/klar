import XCTest
@testable import Klar

final class KlarDateDayKeyTests: XCTestCase {
    /// A normalized logical day is 00:00. Going through `LogicalDay.dayKey(for:)` would apply the
    /// 05:00 cutoff to it and land on the day before.
    func testALogicalDayKeepsItsDate() throws {
        let day = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 9, day: 19)))
        XCTAssertEqual(KlarDate.dayKey(forLogicalDay: day), "2026-09-19")
    }

    func testAKeyRoundTrips() throws {
        let day = try XCTUnwrap(KlarDate.date(fromDayKey: "2026-02-28"))
        XCTAssertEqual(KlarDate.dayKey(forLogicalDay: day), "2026-02-28")
        XCTAssertNil(KlarDate.date(fromDayKey: "nope"))
    }
}
