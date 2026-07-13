import Foundation

public struct QuotaResult: Sendable, Equatable {
    public let limit: Int?
    public let occasions: Int
    public let remaining: Int?
    public let goalType: GoalType?
}

public enum QuotaCalculator {
    public static func quota(
        entries: [EntryDTO],
        substanceID: UUID,
        goalPeriods: [GoalPeriodDTO],
        year: Int,
        month: Int,
        timezoneID: String
    ) -> QuotaResult {
        let monthStart = LogicalDay.date(from: DateComponents(year: year, month: month, day: 1), timezoneID: timezoneID)
        let nextMonth = month == 12 ? (year + 1, 1) : (year, month + 1)
        let monthEnd = LogicalDay.date(from: DateComponents(year: nextMonth.0, month: nextMonth.1, day: 1), timezoneID: timezoneID)

        let activeGoal = goalPeriods
            .filter { $0.substanceID == substanceID }
            .first { $0.validFrom <= monthStart && ($0.validUntil == nil || $0.validUntil! > monthStart) }

        let matchingEntries = entries.filter { entry in
            guard entry.substanceID == substanceID else { return false }
            let logicalComponents = LogicalDay.components(for: entry.timestamp, timezoneID: entry.timezoneID)
            let logicalDate = LogicalDay.date(from: logicalComponents, timezoneID: entry.timezoneID)
            return logicalDate >= monthStart && logicalDate < monthEnd
        }

        let occasionKeys = Set(matchingEntries.map { LogicalDay.components(for: $0.timestamp, timezoneID: $0.timezoneID) })
        let occasions = occasionKeys.count

        let limit = (activeGoal?.type == .reduction) ? activeGoal?.monthlyLimit : nil
        let remaining = limit.map { $0 - occasions }

        return QuotaResult(limit: limit, occasions: occasions, remaining: remaining, goalType: activeGoal?.type)
    }
}
