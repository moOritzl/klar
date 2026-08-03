import Foundation
import SwiftData
import KlarCore

enum ExportImportService {
    static func exportJSON(context: ModelContext) throws -> Data {
        let export = try buildExport(context: context)
        return try KlarExportCoding.makeEncoder().encode(export)
    }

    /// Decodes and validates without touching the store. Split out from the import so a corrupt
    /// or wrong-version file can be rejected *before* anything is deleted.
    static func decode(_ data: Data) throws -> KlarExport {
        let export = try KlarExportCoding.makeDecoder().decode(KlarExport.self, from: data)
        guard export.schemaVersion == KlarExport.currentSchemaVersion else {
            throw ExportImportError.unknownSchemaVersion(export.schemaVersion)
        }
        return export
    }

    static func importJSON(_ data: Data, context: ModelContext) throws {
        guard try isStoreEmpty(context: context) else {
            throw ExportImportError.storeNotEmpty
        }
        try restore(decode(data), context: context)
    }

    /// What the import screen calls. Decode first, so a corrupt file is rejected while the old
    /// data is still there.
    ///
    /// Decoding is not enough on its own: `wipeAll` commits, so a file that decodes but fails
    /// half way through `restore` — a constraint violation, a full disk, a hand-edited payload —
    /// would leave the user with nothing and no undo. This is the only place in the app that can
    /// destroy data it cannot get back, so it keeps a snapshot and puts it back if the restore
    /// throws.
    /// `restoreStep` exists so a test can make the restore fail; there is no other way to reach
    /// the rollback, and an untested rollback is a promise rather than a safeguard. It takes `nil`
    /// rather than defaulting to `restore` because a default argument expression is evaluated
    /// outside the enclosing declaration's isolation, and `restore` is main-actor isolated like
    /// everything else in this target.
    static func replaceAll(
        with data: Data,
        context: ModelContext,
        restoreStep: (@MainActor (KlarExport, ModelContext) throws -> Void)? = nil
    ) throws {
        let export = try decode(data)
        let snapshot = try exportJSON(context: context)

        try wipeAll(context: context)
        do {
            if let restoreStep {
                try restoreStep(export, context)
            } else {
                try restore(export, context: context)
            }
        } catch {
            try? wipeAll(context: context)
            try? restore(decode(snapshot), context: context)
            throw error
        }
    }

    static func wipeAll(context: ModelContext) throws {
        try context.delete(model: Entry.self)
        try context.delete(model: PlanCheckIn.self)
        try context.delete(model: Plan.self)
        try context.delete(model: GoalPeriod.self)
        try context.delete(model: Substance.self)
        try context.delete(model: ContextTag.self)
        try context.delete(model: SubstitutionAction.self)
        try context.delete(model: WhyNote.self)
        try context.delete(model: ReviewDecision.self)
        try context.save()
    }

    /// Writes a decoded export into a store. Callers are responsible for the store being empty
    /// first — `importJSON` checks, `replaceAll` wipes.
    static func restore(_ export: KlarExport, context: ModelContext) throws {
        try insert(export, into: context)
    }

    // MARK: - Private

    private static func isStoreEmpty(context: ModelContext) throws -> Bool {
        let substanceCount = try context.fetchCount(FetchDescriptor<Substance>())
        let entryCount = try context.fetchCount(FetchDescriptor<Entry>())
        return substanceCount == 0 && entryCount == 0
    }

    private static func buildExport(context: ModelContext) throws -> KlarExport {
        KlarExport(
            exportedAt: Date(),
            substances: try context.fetch(FetchDescriptor<Substance>()).map { $0.toDTO() },
            entries: try context.fetch(FetchDescriptor<Entry>()).map { $0.toDTO() },
            contextTags: try context.fetch(FetchDescriptor<ContextTag>()).map { $0.toDTO() },
            goalPeriods: try context.fetch(FetchDescriptor<GoalPeriod>()).map { $0.toDTO() },
            plans: try context.fetch(FetchDescriptor<Plan>()).map { $0.toDTO() },
            planCheckIns: try context.fetch(FetchDescriptor<PlanCheckIn>()).map { $0.toDTO() },
            substitutionActions: try context.fetch(FetchDescriptor<SubstitutionAction>()).map { $0.toDTO() },
            whyNotes: try context.fetch(FetchDescriptor<WhyNote>()).map { $0.toDTO() },
            reviewDecisions: try context.fetch(FetchDescriptor<ReviewDecision>()).map { $0.toDTO() }
        )
    }

    private static func insert(_ export: KlarExport, into context: ModelContext) throws {
        var substanceByID: [UUID: Substance] = [:]
        for dto in export.substances {
            let substance = Substance(id: dto.id, name: dto.name, unit: dto.unit, colorIndex: dto.colorIndex, costPerUnit: dto.costPerUnit, sortOrder: dto.sortOrder, isArchived: dto.isArchived)
            context.insert(substance)
            substanceByID[dto.id] = substance
        }

        var tagByID: [UUID: ContextTag] = [:]
        for dto in export.contextTags {
            let tag = ContextTag(id: dto.id, name: dto.name, isBuiltIn: dto.isBuiltIn)
            context.insert(tag)
            tagByID[dto.id] = tag
        }

        var entryByID: [UUID: Entry] = [:]
        for dto in export.entries {
            let entry = Entry(
                id: dto.id,
                substance: dto.substanceID.flatMap { substanceByID[$0] },
                timestamp: dto.timestamp,
                timezoneID: dto.timezoneID,
                amount: dto.amount,
                unitOverride: dto.unitOverride,
                contextTags: dto.contextTagIDs?.compactMap { tagByID[$0] },
                mood: dto.mood,
                note: dto.note,
                createdAt: dto.createdAt,
                editedAt: dto.editedAt
            )
            context.insert(entry)
            entryByID[dto.id] = entry
        }

        for dto in export.goalPeriods {
            let goal = GoalPeriod(id: dto.id, substance: dto.substanceID.flatMap { substanceByID[$0] }, type: dto.type, monthlyLimit: dto.monthlyLimit, validFrom: dto.validFrom, validUntil: dto.validUntil)
            context.insert(goal)
        }

        var planByID: [UUID: Plan] = [:]
        for dto in export.plans {
            let plan = Plan(id: dto.id, situationTag: dto.situationTagID.flatMap { tagByID[$0] }, situationText: dto.situationText, actionText: dto.actionText, committedAt: dto.committedAt, status: dto.status, supersededBy: dto.supersededBy)
            context.insert(plan)
            planByID[dto.id] = plan
        }

        for dto in export.planCheckIns {
            let checkIn = PlanCheckIn(id: dto.id, plan: dto.planID.flatMap { planByID[$0] }, entry: dto.entryID.flatMap { entryByID[$0] }, date: dto.date, outcome: dto.outcome)
            context.insert(checkIn)
        }

        for dto in export.substitutionActions {
            context.insert(SubstitutionAction(id: dto.id, text: dto.text, sortOrder: dto.sortOrder))
        }

        for dto in export.whyNotes {
            context.insert(WhyNote(id: dto.id, text: dto.text, createdAt: dto.createdAt))
        }

        for dto in export.reviewDecisions {
            context.insert(ReviewDecision(id: dto.id, weekStart: dto.weekStart, planDecision: dto.planDecision))
        }

        try context.save()
    }
}
