import XCTest
@testable import KlarCore

final class MorningPatternTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()
    private let coffee = UUID()
    private let club = UUID()

    private func evening(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 21))!
    }

    private func key(_ day: Int) -> String { String(format: "2026-09-%02d", day) }

    private func entry(_ substance: UUID, day: Int, tags: [UUID]? = nil) -> EntryDTO {
        EntryDTO(substanceID: substance, timestamp: evening(day), timezoneID: berlin, amount: nil, contextTagIDs: tags)
    }

    private func pattern(_ entries: [EntryDTO], _ records: [MorningAfterDTO], tag: UUID? = nil) -> MorningPattern? {
        MorningAfterService.pattern(substanceID: alcohol, contextTagID: tag, entries: entries, records: records)
    }

    func testFewerThanThreeAnsweredDaysIsNoPattern() {
        let entries = [entry(alcohol, day: 1), entry(alcohol, day: 2)]
        let records = [MorningAfterDTO(dayKey: key(1), body: .hungover), MorningAfterDTO(dayKey: key(2), body: .fine)]
        XCTAssertNil(pattern(entries, records))
    }

    func testCountsEachAnswerOfTheMatchingDays() throws {
        let entries = (1...4).map { entry(alcohol, day: $0) }
        let records = [
            MorningAfterDTO(dayKey: key(1), body: .hungover, regret: .yes),
            MorningAfterDTO(dayKey: key(2), body: .hungover, regret: .no),
            MorningAfterDTO(dayKey: key(3), body: .fine, again: .yes),
            MorningAfterDTO(dayKey: key(4), body: .rough, regret: .slightly, again: .differently)
        ]
        let result = try XCTUnwrap(pattern(entries, records))
        XCTAssertEqual(result.days, 4)
        XCTAssertEqual(result.body, [.hungover: 2, .fine: 1, .rough: 1])
        XCTAssertEqual(result.regret, [.yes: 1, .no: 1, .slightly: 1])
        XCTAssertEqual(result.again, [.yes: 1, .differently: 1])
    }

    func testTheContextFilterKeepsOnlyDaysWithThatTag() throws {
        let entries = [
            entry(alcohol, day: 1, tags: [club]), entry(alcohol, day: 2, tags: [club]), entry(alcohol, day: 3, tags: [club]),
            entry(alcohol, day: 4), entry(alcohol, day: 5)
        ]
        let records = (1...5).map { MorningAfterDTO(dayKey: key($0), body: $0 <= 3 ? .hungover : .fine) }
        XCTAssertEqual(try XCTUnwrap(pattern(entries, records, tag: club)).body, [.hungover: 3])
        XCTAssertEqual(try XCTUnwrap(pattern(entries, records)).days, 5)
    }

    func testAPartialAnswerCountsAsADayButOnlyInWhatItAnswered() throws {
        let entries = (1...3).map { entry(alcohol, day: $0) }
        let records = [
            MorningAfterDTO(dayKey: key(1), body: .hungover),
            MorningAfterDTO(dayKey: key(2), body: .fine),
            MorningAfterDTO(dayKey: key(3), regret: .yes)
        ]
        let result = try XCTUnwrap(pattern(entries, records))
        XCTAssertEqual(result.days, 3)
        XCTAssertEqual(result.body, [.hungover: 1, .fine: 1])
        XCTAssertEqual(result.regret, [.yes: 1])
    }

    func testSkipsAreNotCounted() {
        let entries = (1...3).map { entry(alcohol, day: $0) }
        let records = [
            MorningAfterDTO(dayKey: key(1), body: .fine),
            MorningAfterDTO(dayKey: key(2), body: .fine),
            MorningAfterDTO(dayKey: key(3))
        ]
        XCTAssertNil(pattern(entries, records))
    }

    func testOnlyTheNewestFiveDaysAreCounted() throws {
        let entries = (1...7).map { entry(alcohol, day: $0) }
        let records = (1...7).map { MorningAfterDTO(dayKey: key($0), body: $0 <= 2 ? .hungover : .fine) }
        let result = try XCTUnwrap(pattern(entries, records))
        XCTAssertEqual(result.days, 5)
        XCTAssertEqual(result.body, [.fine: 5])
    }

    func testDaysOfAnotherSubstanceDoNotCount() {
        let entries = [entry(alcohol, day: 1), entry(coffee, day: 2), entry(coffee, day: 3)]
        let records = (1...3).map { MorningAfterDTO(dayKey: key($0), body: .fine) }
        XCTAssertNil(pattern(entries, records))
    }

    func testNextTimeIsTheLatestNonEmptyAnswer() throws {
        let entries = (1...3).map { entry(alcohol, day: $0) }
        var records = [
            MorningAfterDTO(dayKey: key(1), body: .hungover, nextTime: "Früher heim"),
            MorningAfterDTO(dayKey: key(2), body: .fine, nextTime: "   "),
            MorningAfterDTO(dayKey: key(3), body: .fine)
        ]
        XCTAssertEqual(try XCTUnwrap(pattern(entries, records)).nextTime, "Früher heim")
        records[2].nextTime = "Wasser dazwischen"
        XCTAssertEqual(try XCTUnwrap(pattern(entries, records)).nextTime, "Wasser dazwischen")
    }
}
