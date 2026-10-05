import XCTest
@testable import KlarCore

/// `occasionFrequencyPerWeek` is consumption days per week over the inclusive span first to last
/// day, with the span floored at one week — so it can never read above 7.
final class StatsCalculatorFrequencyTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()

    /// An entry at 20:00 on `day` of October 2026.
    private func entry(day: Int) -> EntryDTO {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        let when = calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 20))!
        return EntryDTO(substanceID: alcohol, timestamp: when, timezoneID: berlin, amount: nil, contextTagIDs: nil)
    }

    private func perWeek(days: [Int]) -> Double {
        StatsCalculator.summary(
            entries: days.map { entry(day: $0) },
            substanceID: alcohol,
            referenceTimezoneID: berlin
        ).occasionFrequencyPerWeek
    }

    func testNoOccasionsIsZero() {
        XCTAssertEqual(perWeek(days: []), 0, accuracy: 0.001)
    }

    func testOneOccasionIsOne() {
        XCTAssertEqual(perWeek(days: [3]), 1.0, accuracy: 0.001)
    }

    func testTwoConsecutiveDaysIsTwoNotFourteen() {
        XCTAssertEqual(perWeek(days: [3, 4]), 2.0, accuracy: 0.001)
    }

    func testEveryDayForNineDaysIsSeven() {
        XCTAssertEqual(perWeek(days: Array(1...9)), 7.0, accuracy: 0.001)
    }

    func testTwoOccasionsFourteenDaysApartSpanFifteenDays() {
        XCTAssertEqual(perWeek(days: [1, 15]), 2.0 / (15.0 / 7.0), accuracy: 0.001)
    }
}
