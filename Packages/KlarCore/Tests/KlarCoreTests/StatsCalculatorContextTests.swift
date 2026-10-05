import XCTest
@testable import KlarCore

final class StatsCalculatorContextTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()
    private let alone = UUID()
    private let home = UUID()

    private func entry(_ tags: [UUID]?, hour: Int) -> EntryDTO {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        let when = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: hour))!
        return EntryDTO(substanceID: alcohol, timestamp: when, timezoneID: berlin, amount: nil, contextTagIDs: tags)
    }

    private func summary(_ entries: [EntryDTO]) -> StatsSummary {
        StatsCalculator.summary(entries: entries, substanceID: alcohol, referenceTimezoneID: berlin)
    }

    /// „allein + zuhause" on one entry is one entry with context, not two — each tag is at 100 %.
    func testAnEntryWithTwoTagsCountsOnceInTheBase() {
        let result = summary([entry([alone, home], hour: 20)])
        XCTAssertEqual(result.taggedEntryCount, 1)
        XCTAssertEqual(result.contextTagDistribution[alone], 1)
        XCTAssertEqual(result.contextTagDistribution[home], 1)
    }

    func testEntriesWithoutContextAreNotInTheBase() {
        let result = summary([entry([alone], hour: 18), entry(nil, hour: 19), entry([], hour: 20)])
        XCTAssertEqual(result.taggedEntryCount, 1)
    }
}
