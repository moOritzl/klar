import Foundation

public struct WeeklyAverage: Sendable, Equatable {
    public let weekStart: Date
    public let averageAmount: Decimal?
    public let occasionCount: Int
}

public struct StatsSummary: Sendable, Equatable {
    public let weeklyAverages: [WeeklyAverage]
    /// Occasion days divided by the inclusive first-to-last span in weeks, the span floored at one
    /// week — so it never exceeds 7, and a short history reads as its own days, not an inflated rate.
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

        let frequency: Double
        if let first = occasionDates.first, let last = occasionDates.last {
            let spanDays = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
            let spanWeeks = max(1, Double(spanDays) / 7)
            frequency = Double(occasionDates.count) / spanWeeks
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
            let referenceLogicalDate = LogicalDay.date(
                from: LogicalDay.components(for: referenceDate, timezoneID: referenceTimezoneID),
                timezoneID: referenceTimezoneID
            )
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
