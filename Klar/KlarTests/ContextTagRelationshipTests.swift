import XCTest
import SwiftData
import KlarCore
@testable import Klar

/// A context tag is shared by every entry that carries it, which only holds because
/// `ContextTag.entries` declares the inverse explicitly. Without it SwiftData infers
/// a to-one on the tag side, and assigning a tag to a second entry silently takes it
/// off the first — the failure is invisible at the call site and only shows up later
/// as an empty Kontextverteilung, a plan suggestion that never appears, and check-ins
/// that are never due.
final class ContextTagRelationshipTests: XCTestCase {
    @MainActor
    func testOneTagCanBeSharedByManyEntries() throws {
        let context = TestModelContainer.makeInMemoryContext()

        let substance = Substance(name: "Kaffee", unit: .drink, colorIndex: 0, sortOrder: 0)
        context.insert(substance)
        let tag = ContextTag(name: "Zuhause", isBuiltIn: true)
        context.insert(tag)

        for offset in 0..<3 {
            context.insert(
                Entry(
                    substance: substance,
                    timestamp: Date(timeIntervalSince1970: 1_770_000_000 + Double(offset) * 86_400),
                    timezoneID: "Europe/Berlin",
                    amount: 1,
                    contextTags: [tag]
                )
            )
        }
        try context.save()

        let stillTagged = try context.fetch(FetchDescriptor<Entry>())
            .filter { $0.contextTags?.contains { $0.id == tag.id } == true }
        XCTAssertEqual(stillTagged.count, 3, "assigning a tag must not remove it from earlier entries")
    }

    /// The same tag also has to serve as a plan's situation while entries carry it —
    /// that overlap is exactly what makes a check-in fall due.
    @MainActor
    func testATagCanBeAPlanSituationAndAnEntryContextAtOnce() throws {
        let context = TestModelContainer.makeInMemoryContext()

        let substance = Substance(name: "Alkohol", unit: .drink, colorIndex: 0, sortOrder: 0)
        context.insert(substance)
        let tag = ContextTag(name: "Sozial", isBuiltIn: true)
        context.insert(tag)

        let entry = Entry(
            substance: substance,
            timestamp: Date(timeIntervalSince1970: 1_770_000_000),
            timezoneID: "Europe/Berlin",
            amount: 2,
            contextTags: [tag]
        )
        context.insert(entry)
        context.insert(Plan(situationTag: tag, situationText: "Auf einer Party", actionText: "Erst ein Wasser"))
        try context.save()

        let plans = try context.fetch(FetchDescriptor<Plan>())
        XCTAssertEqual(plans.first?.situationTag?.id, tag.id)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<Entry>()).first?.contextTags?.map(\.id),
            [tag.id],
            "the plan taking the tag must not strip it from the entry"
        )
    }
}
