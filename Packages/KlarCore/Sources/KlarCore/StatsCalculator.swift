import Foundation

public struct WeeklyAverage: Sendable, Equatable {
    public let weekStart: Date
    public let averageAmount: Decimal?
    public let occasionCount: Int
}

public struct StatsSummary: Sendable, Equatable {
    public let weeklyAverages: [WeeklyAverage]
    /// Occasion days inside a window ending at the logical day of the reference date and at most
    /// 56 days long (starting no earlier than the first occasion), divided by the window in weeks
    /// floored at one — so it never exceeds 7 and it falls when the user stops.
    public let occasionFrequencyPerWeek: Double
    public let averageGapDays: Double?
    public let contextTagDistribution: [UUID: Int]
    /// Entries of the substance with at least one context tag — the base the context
    /// distribution divides by. An entry with two tags counts once here and once per tag in
    /// `contextTagDistribution`, so the shares are per entry and need not add up to 100 %.
    public let taggedEntryCount: Int
    public let daysSinceLastOccasion: Int?
}

public enum StatsCalculator {
    /// Longest window, in days, that `occasionFrequencyPerWeek` looks back over (8 weeks).
    private static let frequencyWindowDays = 56

    public static func summary(
        entries: [EntryDTO],
        substanceID: UUID,
        referenceDate: Date = Date(),
        referenceTimezoneID: String
    ) -> StatsSummary {
        let relevant = entries.filter { $0.substanceID == substanceID }

        let byLogicalDay = Dictionary(grouping: relevant) {
            LogicalDay.components(for: $0.timestamp, timezoneID: $0.timezoneID)
        }
        let occasions = byLogicalDay.map { key, dayEntries -> (date: Date, entries: [EntryDTO]) in
            let tzID = dayEntries.first?.timezoneID ?? referenceTimezoneID
            return (LogicalDay.date(from: key, timezoneID: tzID), dayEntries)
        }.sorted { $0.date < $1.date }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: referenceTimezoneID) ?? .current
        calendar.firstWeekday = 2 // Monday

        var weekBuckets: [Date: [Decimal]] = [:]
        for occasion in occasions {
            let occasionAmount = occasion.entries.compactMap(\.amount).reduce(Decimal(0), +)
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: occasion.date)?.start ?? occasion.date
            weekBuckets[weekStart, default: []].append(occasionAmount)
        }
        let weeklyAverages = weekBuckets.map { weekStart, amounts in
            WeeklyAverage(
                weekStart: weekStart,
                averageAmount: amounts.isEmpty ? nil : amounts.reduce(Decimal(0), +) / Decimal(amounts.count),
                occasionCount: amounts.count
            )
        }.sorted { $0.weekStart < $1.weekStart }

        let occasionDates = occasions.map(\.date)
        var gaps: [Double] = []
        if occasionDates.count > 1 {
            for i in 1..<occasionDates.count {
                gaps.append(occasionDates[i].timeIntervalSince(occasionDates[i - 1]) / 86400)
            }
        }
        let averageGapDays = gaps.isEmpty ? nil : gaps.reduce(0, +) / Double(gaps.count)

        let referenceLogicalDate = LogicalDay.date(
            from: LogicalDay.components(for: referenceDate, timezoneID: referenceTimezoneID),
            timezoneID: referenceTimezoneID
        )

        let frequency: Double
        if let first = occasionDates.first {
            let earliestStart = calendar.date(byAdding: .day, value: -(frequencyWindowDays - 1), to: referenceLogicalDate) ?? first
            let windowStart = max(first, earliestStart)
            let windowDays = (calendar.dateComponents([.day], from: windowStart, to: referenceLogicalDate).day ?? 0) + 1
            let inWindow = occasionDates.filter { $0 >= windowStart && $0 <= referenceLogicalDate }.count
            frequency = Double(inWindow) / max(1, Double(windowDays) / 7)
        } else {
            frequency = 0
        }

        var tagCounts: [UUID: Int] = [:]
        for entry in relevant {
            for tagID in entry.contextTagIDs ?? [] {
                tagCounts[tagID, default: 0] += 1
            }
        }

        let taggedEntryCount = relevant.filter { !($0.contextTagIDs ?? []).isEmpty }.count

        var daysSinceLast: Int?
        if let lastOccasion = occasionDates.last {
            daysSinceLast = calendar.dateComponents([.day], from: lastOccasion, to: referenceLogicalDate).day
        }

        return StatsSummary(
            weeklyAverages: weeklyAverages,
            occasionFrequencyPerWeek: frequency,
            averageGapDays: averageGapDays,
            contextTagDistribution: tagCounts,
            taggedEntryCount: taggedEntryCount,
            daysSinceLastOccasion: daysSinceLast
        )
    }
}
