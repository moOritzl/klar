import Foundation
import KlarCore

extension Substance {
    func toDTO() -> SubstanceDTO {
        SubstanceDTO(id: id, name: name, unit: unit, colorIndex: colorIndex, costPerUnit: costPerUnit, sortOrder: sortOrder, isArchived: isArchived)
    }
}

extension Entry {
    func toDTO() -> EntryDTO {
        EntryDTO(
            id: id,
            substanceID: substance?.id,
            timestamp: timestamp,
            timezoneID: timezoneID,
            amount: amount,
            unitOverride: unitOverride,
            contextTagIDs: contextTags?.map(\.id),
            mood: mood,
            note: note,
            createdAt: createdAt,
            editedAt: editedAt
        )
    }
}

extension ContextTag {
    func toDTO() -> ContextTagDTO {
        ContextTagDTO(id: id, name: name, isBuiltIn: isBuiltIn)
    }
}

extension GoalPeriod {
    func toDTO() -> GoalPeriodDTO {
        GoalPeriodDTO(id: id, substanceID: substance?.id, type: type, monthlyLimit: monthlyLimit, validFrom: validFrom, validUntil: validUntil)
    }
}

extension Plan {
    func toDTO() -> PlanDTO {
        PlanDTO(id: id, situationTagID: situationTag?.id, situationText: situationText, actionText: actionText, committedAt: committedAt, status: status, supersededBy: supersededBy)
    }
}

extension PlanCheckIn {
    func toDTO() -> PlanCheckInDTO {
        PlanCheckInDTO(id: id, planID: plan?.id, entryID: entry?.id, date: date, outcome: outcome)
    }
}

extension SubstitutionAction {
    func toDTO() -> SubstitutionActionDTO {
        SubstitutionActionDTO(id: id, text: text, sortOrder: sortOrder)
    }
}

extension WhyNote {
    func toDTO() -> WhyNoteDTO {
        WhyNoteDTO(id: id, text: text, createdAt: createdAt)
    }
}

extension ReviewDecision {
    func toDTO() -> ReviewDecisionDTO {
        ReviewDecisionDTO(id: id, weekStart: weekStart, planDecision: planDecision)
    }
}
