import XCTest
@testable import KlarCore

final class SharedMorningDaysTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()
    private let cannabis = UUID()
    private let coffee = UUID()

    private func entry(_ substance: UUID, day: Int) -> EntryDTO {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        let when = calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 21))!
        return EntryDTO(substanceID: substance, timestamp: when, timezoneID: berlin, amount: nil)
    }

    private func key(_ day: Int) -> String { String(format: "2026-09-%02d", day) }

    func testCountsAnsweredDaysWithOtherAskingSubstancesOnly() {
        let entries = [
            entry(alcohol, day: 1), entry(cannabis, day: 1),   // answered, shared
            entry(alcohol, day: 2), entry(coffee, day: 2),     // answered, coffee does not ask
            entry(alcohol, day: 3), entry(cannabis, day: 3),   // skipped
            entry(cannabis, day: 4)                            // no alcohol
        ]
        let records = [
            MorningAfterDTO(dayKey: key(1), body: .rough),
            MorningAfterDTO(dayKey: key(2), body: .fine),
            MorningAfterDTO(dayKey: key(3)),
            MorningAfterDTO(dayKey: key(4), body: .fine)
        ]

        let shared = MorningAfterService.sharedDays(
            substanceID: alcohol, askingSubstanceIDs: [alcohol, cannabis], entries: entries, records: records
        )

        XCTAssertEqual(shared, [cannabis: 1])
    }
}
