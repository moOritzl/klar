import XCTest
import SwiftData
import KlarCore
@testable import Klar

@MainActor
final class KlarStoreMorningAfterTests: XCTestCase {
    private func makeStore() -> KlarStore {
        KlarStore(context: TestModelContainer.makeInMemoryContext())
    }

    private func yesterdayEvening() -> Date {
        let today = KlarDate.logicalDay(for: Date())
        let yesterday = KlarDate.calendar.date(byAdding: .day, value: -1, to: today)!
        return KlarDate.calendar.date(bySettingHour: 21, minute: 0, second: 0, of: yesterday)!
    }

    func testNikotinDoesNotAskByDefaultAndEverythingElseDoes() {
        let store = makeStore()
        XCTAssertFalse(store.addSubstance(name: "Nikotin", unit: .piece).asksMorningAfter)
        XCTAssertTrue(store.addSubstance(name: "Alkohol", unit: .drink).asksMorningAfter)
        XCTAssertTrue(store.addSubstance(name: "Mate", unit: .drink).asksMorningAfter)
    }

    func testYesterdaysEntryMakesYesterdayDue() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let entry = store.addEntry(substance: alcohol, timestamp: yesterdayEvening())
        XCTAssertEqual(store.dueMorningAfterDay(), LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID))
    }

    func testRecordingAnswersClearsTheDueDay() throws {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.addEntry(substance: alcohol, timestamp: yesterdayEvening())
        let key = try XCTUnwrap(store.dueMorningAfterDay())

        store.recordMorningAfter(dayKey: key, body: .hungover, regret: .yes, again: nil, note: "  ")

        XCTAssertNil(store.dueMorningAfterDay())
        let record = try XCTUnwrap(store.morningAfter(forDayKey: key))
        XCTAssertEqual(record.body, .hungover)
        XCTAssertEqual(record.regret, .yes)
        XCTAssertNil(record.note, "a blank note is stored as no note")
    }

    func testSkippingIsRememberedAndDoesNotOverwriteAnswers() throws {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.addEntry(substance: alcohol, timestamp: yesterdayEvening())
        let key = try XCTUnwrap(store.dueMorningAfterDay())

        store.recordMorningAfter(dayKey: key, body: .fine, regret: nil, again: nil, note: nil)
        store.skipMorningAfter(dayKey: key)

        XCTAssertEqual(store.allMorningAfters().count, 1)
        XCTAssertEqual(store.morningAfter(forDayKey: key)?.body, .fine)
    }

    func testReflectionLandsOnTheSameRecord() throws {
        let store = makeStore()
        store.recordMorningAfter(dayKey: "2026-09-19", body: nil, regret: .yes, again: nil, note: nil)
        store.recordReflection(dayKey: "2026-09-19", trigger: "Gruppendruck", wouldHaveHelped: "", nextTime: "Früher heim")

        XCTAssertEqual(store.allMorningAfters().count, 1)
        let record = try XCTUnwrap(store.morningAfter(forDayKey: "2026-09-19"))
        XCTAssertEqual(record.regret, .yes)
        XCTAssertEqual(record.trigger, "Gruppendruck")
        XCTAssertNil(record.wouldHaveHelped)
        XCTAssertEqual(record.nextTime, "Früher heim")
    }

    func testSwitchingASubstanceOffStopsItsCard() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.addEntry(substance: alcohol, timestamp: yesterdayEvening())

        store.setAsksMorningAfter(false, for: alcohol)

        XCTAssertNil(store.dueMorningAfterDay())
    }
}
