import XCTest
import SwiftData
import KlarCore
@testable import Klar

final class ExportImportTests: XCTestCase {
    func testJSONRoundTripRestoresIdenticalDatabase() throws {
        let sourceContext = TestModelContainer.makeInMemoryContext()

        let substance = Substance(name: "Kaffee", unit: .drink, colorIndex: 2, costPerUnit: Decimal(string: "2.50"), sortOrder: 0)
        sourceContext.insert(substance)

        let tag = ContextTag(name: "Zuhause", isBuiltIn: true)
        sourceContext.insert(tag)

        let entry = Entry(
            substance: substance,
            timestamp: Date(timeIntervalSince1970: 1_770_000_000),
            timezoneID: "Europe/Berlin",
            amount: Decimal(string: "1.5"),
            contextTags: [tag],
            mood: 4,
            note: "Testeintrag"
        )
        sourceContext.insert(entry)

        let goal = GoalPeriod(substance: substance, type: .reduction, monthlyLimit: 20, validFrom: Date(timeIntervalSince1970: 1_760_000_000))
        sourceContext.insert(goal)

        let plan = Plan(situationTag: tag, situationText: "Alleine zuhause", actionText: "Tee statt Kaffee")
        sourceContext.insert(plan)

        let checkIn = PlanCheckIn(plan: plan, entry: entry, date: Date(timeIntervalSince1970: 1_770_100_000), outcome: .helped)
        sourceContext.insert(checkIn)

        let substitution = SubstitutionAction(text: "Wasser trinken", sortOrder: 0)
        sourceContext.insert(substitution)

        let whyNote = WhyNote(text: "Mehr Energie ohne Koffein-Crash")
        sourceContext.insert(whyNote)

        let reviewDecision = ReviewDecision(weekStart: Date(timeIntervalSince1970: 1_769_900_000), planDecision: .keep)
        sourceContext.insert(reviewDecision)

        try sourceContext.save()

        let jsonData = try ExportImportService.exportJSON(context: sourceContext)

        let destinationContext = TestModelContainer.makeInMemoryContext()
        try ExportImportService.importJSON(jsonData, context: destinationContext)

        let importedSubstances = try destinationContext.fetch(FetchDescriptor<Substance>())
        XCTAssertEqual(importedSubstances.count, 1)
        let importedSubstance = try XCTUnwrap(importedSubstances.first)
        XCTAssertEqual(importedSubstance.id, substance.id)
        XCTAssertEqual(importedSubstance.name, "Kaffee")
        XCTAssertEqual(importedSubstance.unit, .drink)
        XCTAssertEqual(importedSubstance.costPerUnit, Decimal(string: "2.50"))

        let importedEntries = try destinationContext.fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(importedEntries.count, 1)
        let importedEntry = try XCTUnwrap(importedEntries.first)
        XCTAssertEqual(importedEntry.id, entry.id)
        XCTAssertEqual(importedEntry.substance?.id, substance.id)
        XCTAssertEqual(importedEntry.amount, Decimal(string: "1.5"))
        XCTAssertEqual(importedEntry.timezoneID, "Europe/Berlin")
        XCTAssertEqual(importedEntry.mood, 4)
        XCTAssertEqual(importedEntry.note, "Testeintrag")
        XCTAssertEqual(importedEntry.contextTags?.map(\.id), [tag.id])

        let importedPlans = try destinationContext.fetch(FetchDescriptor<Plan>())
        XCTAssertEqual(importedPlans.count, 1)
        XCTAssertEqual(importedPlans.first?.situationTag?.id, tag.id)

        let importedCheckIns = try destinationContext.fetch(FetchDescriptor<PlanCheckIn>())
        XCTAssertEqual(importedCheckIns.count, 1)
        XCTAssertEqual(importedCheckIns.first?.plan?.id, plan.id)
        XCTAssertEqual(importedCheckIns.first?.entry?.id, entry.id)
        XCTAssertEqual(importedCheckIns.first?.outcome, .helped)

        let importedGoals = try destinationContext.fetch(FetchDescriptor<GoalPeriod>())
        XCTAssertEqual(importedGoals.count, 1)
        XCTAssertEqual(importedGoals.first?.monthlyLimit, 20)

        let importedSubstitutions = try destinationContext.fetch(FetchDescriptor<SubstitutionAction>())
        XCTAssertEqual(importedSubstitutions.count, 1)

        let importedWhyNotes = try destinationContext.fetch(FetchDescriptor<WhyNote>())
        XCTAssertEqual(importedWhyNotes.count, 1)

        let importedReviewDecisions = try destinationContext.fetch(FetchDescriptor<ReviewDecision>())
        XCTAssertEqual(importedReviewDecisions.count, 1)
        XCTAssertEqual(importedReviewDecisions.first?.planDecision, .keep)
    }

    func testImportIntoNonEmptyStoreFails() throws {
        let context = TestModelContainer.makeInMemoryContext()
        context.insert(Substance(name: "Existierend", unit: .mg, colorIndex: 0, sortOrder: 0))
        try context.save()

        let emptyExport = KlarExport()
        let data = try KlarExportCoding.makeEncoder().encode(emptyExport)

        XCTAssertThrowsError(try ExportImportService.importJSON(data, context: context)) { error in
            XCTAssertEqual(error as? ExportImportError, .storeNotEmpty)
        }
    }

    func testImportWithUnknownSchemaVersionFails() throws {
        let context = TestModelContainer.makeInMemoryContext()

        var export = KlarExport()
        export.schemaVersion = 999
        let data = try KlarExportCoding.makeEncoder().encode(export)

        XCTAssertThrowsError(try ExportImportService.importJSON(data, context: context)) { error in
            XCTAssertEqual(error as? ExportImportError, .unknownSchemaVersion(999))
        }
    }

    func testDecodeRejectsMalformedJSONWithoutTouchingTheStore() throws {
        let context = TestModelContainer.makeInMemoryContext()
        context.insert(Substance(name: "Kaffee", unit: .drink, colorIndex: 0, sortOrder: 0))
        try context.save()

        XCTAssertThrowsError(try ExportImportService.decode(Data("nicht json".utf8)))

        let survivors = try context.fetch(FetchDescriptor<Substance>())
        XCTAssertEqual(survivors.count, 1, "A rejected file must leave the store untouched")
    }

    func testDecodeRejectsAnUnknownSchemaVersion() throws {
        let payload = #"{"schemaVersion": 999, "exportedAt": "1970-01-01T00:00:00Z", "substances": [], "entries": [], "contextTags": [], "goalPeriods": [], "plans": [], "planCheckIns": [], "substitutionActions": [], "whyNotes": [], "reviewDecisions": []}"#

        XCTAssertThrowsError(try ExportImportService.decode(Data(payload.utf8))) { error in
            XCTAssertEqual(error as? ExportImportError, .unknownSchemaVersion(999))
        }
    }

    /// The import screen's real sequence: decode, then wipe, then restore. Exercised end to end
    /// because the ordering is the whole safety property.
    func testReplaceAllReplacesAPopulatedStore() throws {
        let sourceContext = TestModelContainer.makeInMemoryContext()
        let substance = Substance(name: "Kaffee", unit: .drink, colorIndex: 2, sortOrder: 0)
        sourceContext.insert(substance)
        sourceContext.insert(Entry(substance: substance, timestamp: Date(timeIntervalSince1970: 1_770_000_000), timezoneID: "Europe/Berlin", amount: nil))
        try sourceContext.save()
        let payload = try ExportImportService.exportJSON(context: sourceContext)

        let destinationContext = TestModelContainer.makeInMemoryContext()
        destinationContext.insert(Substance(name: "Bier", unit: .drink, colorIndex: 1, sortOrder: 0))
        try destinationContext.save()

        try ExportImportService.replaceAll(with: payload, context: destinationContext)

        let names = try destinationContext.fetch(FetchDescriptor<Substance>()).map(\.name)
        XCTAssertEqual(names, ["Kaffee"])
        XCTAssertEqual(try destinationContext.fetchCount(FetchDescriptor<Entry>()), 1)
    }
}
