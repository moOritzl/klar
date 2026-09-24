import XCTest
@testable import KlarCore

final class MorningAfterDTOTests: XCTestCase {
    func testARecordWithoutAnswersIsASkip() {
        XCTAssertFalse(MorningAfterDTO(dayKey: "2026-09-19").isAnswered)
        XCTAssertFalse(MorningAfterDTO(dayKey: "2026-09-19", note: "nur eine Notiz").isAnswered)
    }

    func testAnyOneAnswerCountsAsAnswered() {
        XCTAssertTrue(MorningAfterDTO(dayKey: "2026-09-19", body: .hungover).isAnswered)
        XCTAssertTrue(MorningAfterDTO(dayKey: "2026-09-19", regret: .slightly).isAnswered)
        XCTAssertTrue(MorningAfterDTO(dayKey: "2026-09-19", again: .differently).isAnswered)
    }

    func testRoundTripsThroughTheExportCoder() throws {
        let record = MorningAfterDTO(
            dayKey: "2026-09-19", body: .rough, regret: .no, again: .yes,
            note: "Früh gegangen", trigger: nil, wouldHaveHelped: nil, nextTime: "Wasser dazwischen",
            recordedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        let data = try KlarExportCoding.makeEncoder().encode(record)
        XCTAssertEqual(try KlarExportCoding.makeDecoder().decode(MorningAfterDTO.self, from: data), record)
    }
}
