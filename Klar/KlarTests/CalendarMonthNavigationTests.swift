import XCTest
@testable import Klar

/// The swipe and the chevrons must agree on which months exist. Future months are unreachable
/// by either path.
final class CalendarMonthNavigationTests: XCTestCase {
    func testSteppingBackwardMovesOneMonth() throws {
        let june = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let stepped = try XCTUnwrap(CalendarMonthNavigation.month(after: -1, from: june, today: june))
        XCTAssertEqual(KlarDate.calendar.component(.month, from: stepped), 5)
    }

    func testSteppingForwardPastTheCurrentMonthIsRefused() throws {
        let today = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        XCTAssertNil(CalendarMonthNavigation.month(after: 1, from: today, today: today))
    }

    func testSteppingForwardFromThePastIsAllowed() throws {
        let today = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let april = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 4, day: 15)))
        let stepped = try XCTUnwrap(CalendarMonthNavigation.month(after: 1, from: april, today: today))
        XCTAssertEqual(KlarDate.calendar.component(.month, from: stepped), 5)
    }
}
