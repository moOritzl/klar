import XCTest
import SwiftData
import KlarCore
@testable import Klar

/// A context tag is shared by every entry that carries it, which only holds because
/// `ContextTag.entries` declares the inverse explicitly. Without it SwiftData infers
/// a to-one on the tag side, and assigning a tag to a second entry silently takes it
/// off the first — the failure is invisible at the call site and only shows up later
/// as an empty Kontextverteilung.
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
}
