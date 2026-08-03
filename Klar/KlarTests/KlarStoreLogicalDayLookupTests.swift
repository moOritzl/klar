import XCTest
import SwiftData
@testable import Klar

/// The calendar's currency is the *normalized* logical day (00:00 of the day), not a wall-clock
/// instant. Feeding such a date back through the 05:00 cutoff shifts it to the previous day, which
/// is how a tapped day could show "0 Einträge" while its dot said otherwise.
@MainActor
final class KlarStoreLogicalDayLookupTests: XCTestCase {
    private var store: KlarStore!

    override func setUp() {
        super.setUp()
        store = KlarStore(context: TestModelContainer.makeInMemoryContext())
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try XCTUnwrap(KlarDate.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        ))
    }

    func testEveningEntryIsFoundOnTheLogicalDayTheCalendarTapped() throws {
        let evening = try date(2026, 8, 3, 21, 30)
        store.addEntry(substance: nil, timestamp: evening)

        // What the calendar hands to the day detail: midnight on the tapped cell.
        let tappedDay = KlarDate.logicalDay(for: evening)
        XCTAssertEqual(store.entries(onLogicalDay: tappedDay).count, 1)
    }

    func testAfterMidnightEntryIsFoundOnThePreviousLogicalDay() throws {
        let afterMidnight = try date(2026, 8, 4, 2, 30)
        store.addEntry(substance: nil, timestamp: afterMidnight)

        let nightBefore = try date(2026, 8, 3, 12)
        XCTAssertEqual(store.entries(onLogicalDay: KlarDate.logicalDay(for: nightBefore)).count, 1)

        let theDayItself = try date(2026, 8, 4, 12)
        XCTAssertTrue(store.entries(onLogicalDay: KlarDate.logicalDay(for: theDayItself)).isEmpty)
    }

    func testWallClockLookupStillHonoursTheCutoff() throws {
        let evening = try date(2026, 8, 3, 21, 30)
        store.addEntry(substance: nil, timestamp: evening)

        // Today's screen asks with "now" — at 02:00 the night before's entries are still today's.
        XCTAssertEqual(store.entries(onLogicalDayOf: try date(2026, 8, 4, 2)).count, 1)
        XCTAssertEqual(store.entries(onLogicalDayOf: try date(2026, 8, 3, 23)).count, 1)
        XCTAssertTrue(store.entries(onLogicalDayOf: try date(2026, 8, 4, 6)).isEmpty)
    }

    /// Between 00:00 and 05:00 on the 1st, the logical month is still the previous one. The grid is
    /// drawn from the month anchor, so the dots have to come from that same anchor rather than from
    /// re-normalizing it.
    func testLoggedDaysUsesTheAnchorsCalendarMonth() throws {
        let firstOfAugust = try date(2026, 8, 1, 21, 30)
        store.addEntry(substance: nil, timestamp: firstOfAugust)

        let augustAnchor = try date(2026, 8, 1, 0)
        let logged = store.loggedDays(inMonthOf: augustAnchor)
        XCTAssertEqual(logged, [KlarDate.logicalDay(for: firstOfAugust)])
    }
}
