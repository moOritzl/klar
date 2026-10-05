import XCTest
import SwiftData
import KlarCore
@testable import Klar

/// Reopening a reflected day must show the three sentences that are already stored — saving writes
/// all three fields, so starting empty would erase the ones the user did not touch.
@MainActor
final class MorningReflectionPrefillTests: XCTestCase {
    func testNoRecordStartsWithThreeEmptyFields() {
        let fields = MorningReflectionView.initialFields(for: nil)
        XCTAssertEqual(fields.trigger, "")
        XCTAssertEqual(fields.wouldHaveHelped, "")
        XCTAssertEqual(fields.nextTime, "")
    }

    func testStoredSentencesComeBackAndMissingOnesAreEmpty() throws {
        let store = KlarStore(context: TestModelContainer.makeInMemoryContext())
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let entry = store.addEntry(substance: alcohol, timestamp: Date())
        let key = LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID)
        store.recordMorningAfter(dayKey: key, body: nil, regret: .yes, again: nil, note: nil)
        store.recordReflection(dayKey: key, trigger: "Gruppendruck", wouldHaveHelped: "", nextTime: "Früher heim")

        let fields = MorningReflectionView.initialFields(for: store.morningAfter(forDayKey: key))

        XCTAssertEqual(fields.trigger, "Gruppendruck")
        XCTAssertEqual(fields.wouldHaveHelped, "")
        XCTAssertEqual(fields.nextTime, "Früher heim")
    }
}
