import XCTest
@testable import Klar

/// The 05:00 boundary is only honest if the UI says which day it means. These are the labels the
/// Heute header and the entry confirmation build, pinned at a wall-clock moment inside and outside
/// the night window. 3 August 2026 is a Monday.
final class DayBoundaryLabelTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try XCTUnwrap(KlarDate.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        ))
    }

    /// 02:15 on Tuesday still belongs to Monday, and the header has to say Monday — the phone's
    /// clock says otherwise, which is exactly what needs explaining.
    func testHeaderLabelNamesTheLogicalDayDuringTheNight() throws {
        let label = KlarDate.logicalDayLabel(now: try date(2026, 8, 4, 2, 15))
        XCTAssertEqual(label, "Mo., 3. Aug.")
    }

    func testHeaderLabelMatchesTheWallClockDayOutsideTheNight() throws {
        XCTAssertEqual(KlarDate.logicalDayLabel(now: try date(2026, 8, 3, 21, 30)), "Mo., 3. Aug.")
        XCTAssertEqual(KlarDate.logicalDayLabel(now: try date(2026, 8, 4, 5, 0)), "Di., 4. Aug.")
    }

    func testTheHintAppearsOnlyWhileTheShownDayContradictsTheClock() throws {
        XCTAssertTrue(KlarDate.isBeforeCutoff(try date(2026, 8, 4, 2, 15)))
        XCTAssertFalse(KlarDate.isBeforeCutoff(try date(2026, 8, 4, 5, 0)))
        XCTAssertFalse(KlarDate.isBeforeCutoff(try date(2026, 8, 3, 21, 30)))
    }

    /// The entry confirmation names the day in words, so it needs the weekday of the *logical*
    /// day rather than of the timestamp.
    func testWeekdayNameOfTheLogicalDayOfANightTimeEntry() throws {
        let entry = try date(2026, 8, 4, 2, 15)
        XCTAssertEqual(KlarDate.weekdayName(KlarDate.logicalDay(for: entry)), "Montag")
    }

    func testWeekdayNameOfAnEveningEntryIsThatEvening() throws {
        let entry = try date(2026, 8, 4, 21, 30)
        XCTAssertEqual(KlarDate.weekdayName(KlarDate.logicalDay(for: entry)), "Dienstag")
    }
}
