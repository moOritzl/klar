import XCTest
@testable import KlarCore

final class LogicalDayTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, timezoneID: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezoneID)!
        let components = DateComponents(year: y, month: m, day: d, hour: h, minute: min)
        return calendar.date(from: components)!
    }

    func testEarlyMorningEntryBelongsToPreviousDay() {
        let entry = date(2026, 7, 15, 2, 30, timezoneID: "Europe/Berlin")
        let day = LogicalDay.components(for: entry, timezoneID: "Europe/Berlin")
        XCTAssertEqual(day.year, 2026)
        XCTAssertEqual(day.month, 7)
        XCTAssertEqual(day.day, 14)
    }

    func testFiveAMBoundaryIsInclusiveToNewDay() {
        let atCutoff = date(2026, 7, 15, 5, 0, timezoneID: "Europe/Berlin")
        let dayAtCutoff = LogicalDay.components(for: atCutoff, timezoneID: "Europe/Berlin")
        XCTAssertEqual(dayAtCutoff.day, 15)

        let justBeforeCutoff = date(2026, 7, 15, 4, 59, timezoneID: "Europe/Berlin")
        let dayBeforeCutoff = LogicalDay.components(for: justBeforeCutoff, timezoneID: "Europe/Berlin")
        XCTAssertEqual(dayBeforeCutoff.day, 14)
    }

    /// The predicate the UI needs to explain itself: is the logical day still the previous
    /// calendar day, so that a shown date contradicts the phone's clock?
    func testIsBeforeCutoffIsTrueOnlyBetweenMidnightAndFive() {
        XCTAssertTrue(LogicalDay.isBeforeCutoff(date(2026, 8, 4, 0, 1, timezoneID: "Europe/Berlin"), timezoneID: "Europe/Berlin"))
        XCTAssertTrue(LogicalDay.isBeforeCutoff(date(2026, 8, 4, 2, 30, timezoneID: "Europe/Berlin"), timezoneID: "Europe/Berlin"))
        XCTAssertTrue(LogicalDay.isBeforeCutoff(date(2026, 8, 4, 4, 59, timezoneID: "Europe/Berlin"), timezoneID: "Europe/Berlin"))

        XCTAssertFalse(LogicalDay.isBeforeCutoff(date(2026, 8, 4, 5, 0, timezoneID: "Europe/Berlin"), timezoneID: "Europe/Berlin"))
        XCTAssertFalse(LogicalDay.isBeforeCutoff(date(2026, 8, 4, 21, 30, timezoneID: "Europe/Berlin"), timezoneID: "Europe/Berlin"))
    }

    /// The window is wall-clock local, so it has to follow the timezone it is asked about.
    func testIsBeforeCutoffFollowsTheGivenTimezone() {
        // 02:30 in Berlin is 20:30 the previous evening in New York: inside the window there,
        // outside it here.
        let berlinNight = date(2026, 8, 4, 2, 30, timezoneID: "Europe/Berlin")
        XCTAssertTrue(LogicalDay.isBeforeCutoff(berlinNight, timezoneID: "Europe/Berlin"))
        XCTAssertFalse(LogicalDay.isBeforeCutoff(berlinNight, timezoneID: "America/New_York"))
    }

    func testEntryInDifferentTimezoneUsesThatTimezonesWallClock() {
        // 23:30 in New York is still the same evening (after cutoff) -> same day
        let nyEntry = date(2026, 7, 15, 23, 30, timezoneID: "America/New_York")
        let nyDay = LogicalDay.components(for: nyEntry, timezoneID: "America/New_York")
        XCTAssertEqual(nyDay.day, 15)

        // The exact same absolute instant, read through Tokyo's clock, is a different wall-clock day
        let tokyoDay = LogicalDay.components(for: nyEntry, timezoneID: "Asia/Tokyo")
        XCTAssertNotEqual(tokyoDay.day, nyDay.day)
    }

    func testDSTSpringForwardDoesNotSkipOrDuplicateDays() throws {
        try assertMonotonicAcrossTransition(startingFrom: date(2026, 1, 1, 0, 0, timezoneID: "Europe/Berlin"))
    }

    func testDSTFallBackDoesNotSkipOrDuplicateDays() throws {
        let tz = TimeZone(identifier: "Europe/Berlin")!
        let springTransition = try XCTUnwrap(tz.nextDaylightSavingTimeTransition(after: date(2026, 1, 1, 0, 0, timezoneID: "Europe/Berlin")))
        try assertMonotonicAcrossTransition(startingFrom: springTransition.addingTimeInterval(3600))
    }

    private func assertMonotonicAcrossTransition(startingFrom searchStart: Date) throws {
        let tz = TimeZone(identifier: "Europe/Berlin")!
        let transition = try XCTUnwrap(tz.nextDaylightSavingTimeTransition(after: searchStart))

        var previousDayValue: Int?
        var cursor = transition.addingTimeInterval(-6 * 3600)
        let end = transition.addingTimeInterval(6 * 3600)
        while cursor < end {
            let components = LogicalDay.components(for: cursor, timezoneID: "Europe/Berlin")
            let day = try XCTUnwrap(components.day)
            if let previous = previousDayValue {
                XCTAssertTrue(day == previous || day == previous + 1 || (previous == 31 && day == 1) || (previous >= 28 && day == 1),
                               "logical day jumped unexpectedly from \(previous) to \(day) at \(cursor) across DST transition")
            }
            previousDayValue = day
            cursor = cursor.addingTimeInterval(15 * 60)
        }
    }
}
