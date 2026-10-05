import XCTest
@testable import KlarCore

/// `occasionFrequencyPerWeek` counts consumption days inside a window that ends at the logical
/// day of the reference date and is at most 56 days long. Every case passes an explicit
/// reference date, so none of these depend on the real clock.
final class StatsCalculatorFrequencyTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        return calendar
    }

    /// `hour` o'clock on the day `offset` days after 1 July 2026.
    private func moment(day offset: Int, hour: Int) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: hour))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    private func perWeek(days: [Int], reference: Int) -> Double {
        let entries = days.map {
            EntryDTO(substanceID: alcohol, timestamp: moment(day: $0, hour: 20), timezoneID: berlin, amount: nil, contextTagIDs: nil)
        }
        return StatsCalculator.summary(
            entries: entries,
            substanceID: alcohol,
            referenceDate: moment(day: reference, hour: 21),
            referenceTimezoneID: berlin
        ).occasionFrequencyPerWeek
    }

    func testNoOccasionsIsZero() {
        XCTAssertEqual(perWeek(days: [], reference: 10), 0, accuracy: 0.001)
    }

    func testOneOccasionIsOne() {
        XCTAssertEqual(perWeek(days: [3], reference: 3), 1.0, accuracy: 0.001)
    }

    func testTwoConsecutiveDaysIsTwoNotFourteen() {
        XCTAssertEqual(perWeek(days: [3, 4], reference: 4), 2.0, accuracy: 0.001)
    }

    func testEveryDayForNineDaysIsSeven() {
        XCTAssertEqual(perWeek(days: Array(0...8), reference: 8), 7.0, accuracy: 0.001)
    }

    func testTwelveOccasionsOverExactlyFourWeeksIsThree() {
        // First occasion on day 0, last and reference on day 27: a window of exactly 28 days.
        let days = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 27]
        XCTAssertEqual(perWeek(days: days, reference: 27), 3.0, accuracy: 0.001)
    }

    func testStoppingForEightWeeksReadsZero() {
        // Three days a week for four weeks, then nothing: the reference is 56 days after the
        // last occasion, so no occasion lies inside the last 56 days.
        let days = (0..<4).flatMap { week in [0, 2, 4].map { week * 7 + $0 } }
        let last = days.max()!
        XCTAssertEqual(perWeek(days: days, reference: last + 56), 0.0, accuracy: 0.001)
    }

    func testRateFallsWhileTheUserHasStopped() {
        // Two occasions, then a reference 20 days later: window is 22 days wide from the first.
        XCTAssertEqual(perWeek(days: [0, 1], reference: 21), 2.0 / (22.0 / 7.0), accuracy: 0.001)
    }
}
