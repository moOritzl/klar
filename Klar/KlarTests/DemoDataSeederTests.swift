import XCTest
import SwiftData
import KlarCore
@testable import Klar

/// The seeder inserts entries and then, in the same unsaved context, fetches them back to build
/// morning-after records. If `context.fetch` did not see those pending inserts, this would
/// silently insert zero `MorningAfter` records — the demo would show no pattern and the entry
/// sheet would look untouched. This test exists to catch exactly that regression.
@MainActor
final class DemoDataSeederTests: XCTestCase {
    func testSeedLeavesTheNewestAlcoholEveningOpenAndAnswersTheRest() throws {
        let context = TestModelContainer.makeInMemoryContext()

        try DemoDataSeeder.seed(context: context)

        let mornings = try context.fetch(FetchDescriptor<MorningAfter>())
        XCTAssertFalse(mornings.isEmpty, "the seeder must leave at least one morning-after record")

        let substances = try context.fetch(FetchDescriptor<Substance>())
        let coffee = try XCTUnwrap(substances.first { $0.name == "Kaffee" })
        let nicotine = try XCTUnwrap(substances.first { $0.name == "Nikotin" })
        XCTAssertFalse(coffee.asksMorningAfter)
        XCTAssertFalse(nicotine.asksMorningAfter)

        let alcohol = try XCTUnwrap(substances.first { $0.name == "Alkohol" })
        let entries = try context.fetch(FetchDescriptor<Entry>())
        let alcoholDayKeys = Set(
            entries
                .filter { $0.substance?.id == alcohol.id }
                .map { LogicalDay.dayKey(for: $0.timestamp, timezoneID: $0.timezoneID) }
        )
        let newestAlcoholDay = try XCTUnwrap(alcoholDayKeys.max())
        let recordedDayKeys = Set(mornings.map(\.dayKey))

        XCTAssertFalse(
            recordedDayKeys.contains(newestAlcoholDay),
            "the newest alcohol evening must stay open, so it is the card the demo shows on launch"
        )
    }
}
