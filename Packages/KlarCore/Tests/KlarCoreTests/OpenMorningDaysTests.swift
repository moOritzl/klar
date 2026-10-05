import XCTest
@testable import KlarCore

final class OpenMorningDaysTests: XCTestCase {
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

    private func open(_ entries: [EntryDTO], records: [MorningAfterDTO] = [], now: Date) -> [String] {
        MorningAfterService.openDayKeys(
            entries: entries, askingSubstanceIDs: [alcohol], records: records, now: now, nowTimezoneID: berlin
        )
    }

    private func answerable(_ entries: [EntryDTO], now: Date) -> Set<String> {
        MorningAfterService.answerableDayKeys(
            entries: entries, askingSubstanceIDs: [alcohol], now: now, nowTimezoneID: berlin
        )
    }

    func testOpenUntilSeventyTwoHoursAfterTheDayEnds() {
        let entries = [entry(alcohol, date(2026, 9, 19, 22))] // day ends 2026-09-20 05:00
        XCTAssertEqual(open(entries, now: date(2026, 9, 23, 4, 59)), ["2026-09-19"])
        XCTAssertEqual(open(entries, now: date(2026, 9, 23, 5, 0)), [])
    }

    func testTodayIsNeverOpen() {
        XCTAssertEqual(open([entry(alcohol, date(2026, 9, 20, 9))], now: date(2026, 9, 20, 10)), [])
    }

    func testASwitchedOffSubstanceDoesNotCount() {
        XCTAssertEqual(open([entry(nicotine, date(2026, 9, 19, 21))], now: date(2026, 9, 20, 10)), [])
    }

    /// „Überspringen" takes the day off the list; the day detail can still answer it.
    func testASkipClosesTheDayButKeepsItAnswerable() {
        let entries = [entry(alcohol, date(2026, 9, 19, 21))]
        let skip = MorningAfterDTO(dayKey: "2026-09-19")
        XCTAssertEqual(open(entries, records: [skip], now: date(2026, 9, 20, 10)), [])
        XCTAssertEqual(answerable(entries, now: date(2026, 9, 20, 10)), ["2026-09-19"])
    }

    func testAnAnswerClosesTheDay() {
        let entries = [entry(alcohol, date(2026, 9, 19, 21))]
        let answer = MorningAfterDTO(dayKey: "2026-09-19", body: .fine)
        XCTAssertEqual(open(entries, records: [answer], now: date(2026, 9, 20, 10)), [])
    }

    /// Unlike `dueDayKey`, a newer day does not hide an older one here.
    func testSeveralOpenDaysComeNewestFirst() {
        let entries = [entry(alcohol, date(2026, 9, 18, 21)), entry(alcohol, date(2026, 9, 19, 21))]
        XCTAssertEqual(open(entries, now: date(2026, 9, 20, 10)), ["2026-09-19", "2026-09-18"])
    }

    func testAnEntryAtHalfPastTwoBelongsToThePreviousDay() {
        XCTAssertEqual(open([entry(alcohol, date(2026, 9, 20, 2, 30))], now: date(2026, 9, 20, 10)), ["2026-09-19"])
    }
}
