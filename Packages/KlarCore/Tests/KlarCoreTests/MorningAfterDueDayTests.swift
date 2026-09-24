import XCTest
@testable import KlarCore

final class MorningAfterDueDayTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()
    private let nicotine = UUID()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func entry(_ substance: UUID, _ when: Date) -> EntryDTO {
        EntryDTO(substanceID: substance, timestamp: when, timezoneID: berlin, amount: nil)
    }

    private func due(_ entries: [EntryDTO], records: [MorningAfterDTO] = [], asking: Set<UUID>? = nil, now: Date) -> String? {
        MorningAfterService.dueDayKey(
            entries: entries,
            askingSubstanceIDs: asking ?? [alcohol],
            records: records,
            now: now,
            nowTimezoneID: berlin
        )
    }

    func testAnEntryAtHalfPastTwoMakesThePreviousEveningDue() {
        XCTAssertEqual(due([entry(alcohol, date(2026, 9, 20, 2, 30))], now: date(2026, 9, 20, 10)), "2026-09-19")
    }

    func testASwitchedOffSubstanceNeverTriggers() {
        XCTAssertNil(due([entry(nicotine, date(2026, 9, 19, 21))], now: date(2026, 9, 20, 10)))
    }

    func testDueUntilFortyEightHoursAfterTheDayEnds() {
        let entries = [entry(alcohol, date(2026, 9, 19, 22))] // day ends 2026-09-20 05:00
        XCTAssertEqual(due(entries, now: date(2026, 9, 22, 4, 59)), "2026-09-19")
        XCTAssertNil(due(entries, now: date(2026, 9, 22, 5, 0)))
    }

    func testANewerDayHidesAnOlderUnansweredOne() {
        let entries = [entry(alcohol, date(2026, 9, 17, 21)), entry(alcohol, date(2026, 9, 19, 21))]
        XCTAssertEqual(due(entries, now: date(2026, 9, 20, 10)), "2026-09-19")
    }

    /// Once the newest day has a record, older unanswered days stay unasked.
    func testAnAnsweredNewestDayDoesNotFallBackToAnOlderOne() {
        let entries = [entry(alcohol, date(2026, 9, 17, 21)), entry(alcohol, date(2026, 9, 19, 21))]
        let records = [MorningAfterDTO(dayKey: "2026-09-19", body: .fine)]
        XCTAssertNil(due(entries, records: records, now: date(2026, 9, 20, 10)))
    }

    func testASkipStopsTheQuestion() {
        let entries = [entry(alcohol, date(2026, 9, 19, 21))]
        XCTAssertNil(due(entries, records: [MorningAfterDTO(dayKey: "2026-09-19")], now: date(2026, 9, 20, 10)))
    }

    func testNoEntriesMeansNothingIsDue() {
        XCTAssertNil(due([], now: date(2026, 9, 20, 10)))
    }

    func testTodaysEntriesAloneAreNotDue() {
        XCTAssertNil(due([entry(alcohol, date(2026, 9, 20, 9))], now: date(2026, 9, 20, 10)))
    }

    /// A morning cigarette must not cancel last night's card (spec § 1.3).
    func testAnEntryTodayDoesNotExpireYesterday() {
        let entries = [entry(alcohol, date(2026, 9, 19, 21)), entry(alcohol, date(2026, 9, 20, 9))]
        XCTAssertEqual(due(entries, now: date(2026, 9, 20, 10)), "2026-09-19")
    }
}
