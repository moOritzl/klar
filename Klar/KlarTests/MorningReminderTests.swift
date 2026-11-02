import XCTest
@testable import Klar

/// `MorningReminder.nextReminder` decides when the one push goes out. `dueKeyAt` stands in for
/// `MorningAfterService.dueDayKey`, so these tests only pin the timing and the „asked once" rule.
final class MorningReminderTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testEveningEntrySchedulesTheNextMorning() {
        // Logged on the evening of the 2nd; the 2nd becomes due once its logical day ends.
        let next = MorningReminder.nextReminder(
            now: date(2, 22), minuteOfDay: 10 * 60, lastPresentedKey: nil, calendar: calendar,
            dueKeyAt: { $0 >= self.date(3, 5) ? "2026-11-02" : nil }
        )
        XCTAssertEqual(next?.fireDate, date(3, 10))
        XCTAssertEqual(next?.dayKey, "2026-11-02")
    }

    func testADayAlreadyDueThisMorningIsRemindedToday() {
        let next = MorningReminder.nextReminder(
            now: date(3, 7), minuteOfDay: 10 * 60, lastPresentedKey: nil, calendar: calendar,
            dueKeyAt: { _ in "2026-11-02" }
        )
        XCTAssertEqual(next?.fireDate, date(3, 10))
    }

    func testNoReminderForADayTheCardAlreadyAskedAbout() {
        // The app was opened at 08:00, the card popped up and was put off: asked once is enough.
        let next = MorningReminder.nextReminder(
            now: date(3, 8), minuteOfDay: 10 * 60, lastPresentedKey: "2026-11-02", calendar: calendar,
            dueKeyAt: { _ in "2026-11-02" }
        )
        XCTAssertNil(next)
    }

    func testPastReminderTimeWaitsForTheNextDueDay() {
        // After 10:00 today's reminder time has passed; tomorrow nothing would be due.
        let next = MorningReminder.nextReminder(
            now: date(3, 11), minuteOfDay: 10 * 60, lastPresentedKey: nil, calendar: calendar,
            dueKeyAt: { $0 < self.date(3, 12) ? "2026-11-02" : nil }
        )
        XCTAssertNil(next)
    }

    func testNothingDueMeansNoReminder() {
        let next = MorningReminder.nextReminder(
            now: date(3, 7), minuteOfDay: 10 * 60, lastPresentedKey: nil, calendar: calendar,
            dueKeyAt: { _ in nil }
        )
        XCTAssertNil(next)
    }

    func testCustomTimeIsHonoured() {
        let next = MorningReminder.nextReminder(
            now: date(3, 7), minuteOfDay: 8 * 60 + 30, lastPresentedKey: nil, calendar: calendar,
            dueKeyAt: { _ in "2026-11-02" }
        )
        XCTAssertEqual(next?.fireDate, date(3, 8, 30))
    }
}
