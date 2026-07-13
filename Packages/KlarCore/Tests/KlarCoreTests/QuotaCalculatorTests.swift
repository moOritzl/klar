import XCTest
@testable import KlarCore

final class QuotaCalculatorTests: XCTestCase {
    private let substanceID = UUID()
    private let tz = "Europe/Berlin"

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: tz)!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func entry(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> EntryDTO {
        EntryDTO(substanceID: substanceID, timestamp: date(y, m, d, h, min), timezoneID: tz, amount: 1)
    }

    func testPastMonthUsesGoalThatWasValidThen() {
        let oldGoal = GoalPeriodDTO(substanceID: substanceID, type: .reduction, monthlyLimit: 10,
                                     validFrom: date(2026, 1, 1, 0, 0), validUntil: date(2026, 4, 1, 0, 0))
        let newGoal = GoalPeriodDTO(substanceID: substanceID, type: .reduction, monthlyLimit: 5,
                                     validFrom: date(2026, 4, 1, 0, 0), validUntil: nil)
        let entries = [entry(2026, 2, 10, 20, 0), entry(2026, 2, 20, 20, 0)]

        let februaryResult = QuotaCalculator.quota(
            entries: entries, substanceID: substanceID, goalPeriods: [oldGoal, newGoal],
            year: 2026, month: 2, timezoneID: tz
        )
        XCTAssertEqual(februaryResult.limit, 10)
        XCTAssertEqual(februaryResult.occasions, 2)
        XCTAssertEqual(februaryResult.remaining, 8)

        let mayResult = QuotaCalculator.quota(
            entries: [], substanceID: substanceID, goalPeriods: [oldGoal, newGoal],
            year: 2026, month: 5, timezoneID: tz
        )
        XCTAssertEqual(mayResult.limit, 5)
        XCTAssertEqual(mayResult.remaining, 5)
    }

    func testSameNightMultipleEntriesCountAsOneOccasion() {
        let goal = GoalPeriodDTO(substanceID: substanceID, type: .reduction, monthlyLimit: 10,
                                  validFrom: date(2026, 1, 1, 0, 0), validUntil: nil)
        // 23:00 on the 10th and 01:30 on the 11th are the same logical day (cutoff 05:00)
        let entries = [entry(2026, 3, 10, 23, 0), entry(2026, 3, 11, 1, 30), entry(2026, 3, 15, 20, 0)]

        let result = QuotaCalculator.quota(
            entries: entries, substanceID: substanceID, goalPeriods: [goal],
            year: 2026, month: 3, timezoneID: tz
        )
        XCTAssertEqual(result.occasions, 2)
        XCTAssertEqual(result.remaining, 8)
    }

    func testAbstinenceTypeHasNoNumericLimit() {
        let goal = GoalPeriodDTO(substanceID: substanceID, type: .abstinence, monthlyLimit: nil,
                                  validFrom: date(2026, 6, 1, 0, 0), validUntil: nil)
        let entries = [entry(2026, 6, 5, 20, 0)]

        let result = QuotaCalculator.quota(
            entries: entries, substanceID: substanceID, goalPeriods: [goal],
            year: 2026, month: 6, timezoneID: tz
        )
        XCTAssertNil(result.limit)
        XCTAssertNil(result.remaining)
        XCTAssertEqual(result.occasions, 1)
        XCTAssertEqual(result.goalType, .abstinence)
    }

    func testObserveTypeHasNoNumericLimit() {
        let goal = GoalPeriodDTO(substanceID: substanceID, type: .observe, monthlyLimit: nil,
                                  validFrom: date(2026, 6, 1, 0, 0), validUntil: nil)
        let entries = [entry(2026, 6, 5, 20, 0), entry(2026, 6, 6, 20, 0)]

        let result = QuotaCalculator.quota(
            entries: entries, substanceID: substanceID, goalPeriods: [goal],
            year: 2026, month: 6, timezoneID: tz
        )
        XCTAssertNil(result.limit)
        XCTAssertNil(result.remaining)
        XCTAssertEqual(result.occasions, 2)
        XCTAssertEqual(result.goalType, .observe)
    }
}
