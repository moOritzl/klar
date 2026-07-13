import Foundation

public enum PlanServiceError: Error, Sendable, Equatable {
    case activePlanLimitReached
}

public enum PlanService {
    public static let maxActivePlans = 3

    /// Versions a plan: archives `existingPlan` (if any) with `supersededBy` pointing at the
    /// freshly created plan, which starts a new `committedAt`. Enforces the active-plan limit
    /// here in the service layer, not in the model.
    @discardableResult
    public static func createVersion(
        of existingPlan: PlanDTO?,
        situationTagID: UUID?,
        situationText: String,
        actionText: String,
        newStatus: PlanStatus = .active,
        existingPlans: [PlanDTO],
        now: Date = Date()
    ) throws -> (updatedOld: PlanDTO?, newPlan: PlanDTO) {
        if newStatus == .active {
            let activeCountExcludingReplaced = existingPlans
                .filter { $0.status == .active && $0.id != existingPlan?.id }
                .count
            guard activeCountExcludingReplaced < maxActivePlans else {
                throw PlanServiceError.activePlanLimitReached
            }
        }

        let newPlan = PlanDTO(
            situationTagID: situationTagID,
            situationText: situationText,
            actionText: actionText,
            committedAt: now,
            status: newStatus,
            supersededBy: nil
        )

        guard var updatedOld = existingPlan else {
            return (nil, newPlan)
        }
        updatedOld.status = .archived
        updatedOld.supersededBy = newPlan.id
        return (updatedOld, newPlan)
    }

    /// A check-in is due when an entry's context tags match an active plan's situation tag,
    /// the entry's logical day is strictly before "now"'s logical day, and no check-in exists
    /// for that entry yet.
    public static func pendingCheckIns(
        entries: [EntryDTO],
        plans: [PlanDTO],
        existingCheckIns: [PlanCheckInDTO],
        now: Date,
        nowTimezoneID: String
    ) -> [(plan: PlanDTO, entry: EntryDTO)] {
        let activePlans = plans.filter { $0.status == .active }
        let checkedInEntryIDs = Set(existingCheckIns.compactMap { $0.entryID })

        var results: [(PlanDTO, EntryDTO)] = []
        for plan in activePlans {
            guard let situationTagID = plan.situationTagID else { continue }
            for entry in entries {
                guard entry.contextTagIDs?.contains(situationTagID) == true else { continue }
                guard !checkedInEntryIDs.contains(entry.id) else { continue }
                guard LogicalDay.isLogicalDayBefore(entry.timestamp, entry.timezoneID, now, nowTimezoneID) else { continue }
                results.append((plan, entry))
            }
        }
        return results
    }
}
