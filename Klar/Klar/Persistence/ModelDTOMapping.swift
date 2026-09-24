import Foundation
import KlarCore

extension Substance {
    func toDTO() -> SubstanceDTO {
        SubstanceDTO(id: id, name: name, unit: unit, colorIndex: colorIndex, costPerUnit: costPerUnit, sortOrder: sortOrder, isArchived: isArchived, asksMorningAfter: asksMorningAfter)
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

extension MorningAfter {
    func toDTO() -> MorningAfterDTO {
        MorningAfterDTO(
            id: id, dayKey: dayKey, body: body, regret: regret, again: again, note: note,
            trigger: trigger, wouldHaveHelped: wouldHaveHelped, nextTime: nextTime, recordedAt: recordedAt
        )
    }
}
