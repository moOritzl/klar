import Foundation

public struct WeeklyAverage: Sendable, Equatable {
    public let weekStart: Date
    public let averageAmount: Decimal?
    public let occasionCount: Int
}

public struct StatsSummary: Sendable, Equatable {
    public let weeklyAverages: [WeeklyAverage]
    public let occasionFrequencyPerWeek: Double
    public let averageGapDays: Double?
    public let contextTagDistribution: [UUID: Int]
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
        if let first = occasionDates.first, let last = occasionDates.last, last > first {
            let totalWeeks = last.timeIntervalSince(first) / (7 * 86400)
            frequency = totalWeeks > 0 ? Double(occasionDates.count) / totalWeeks : Double(occasionDates.count)
        } else {
            frequency = Double(occasionDates.count)
        }

        var tagCounts: [UUID: Int] = [:]
        for entry in relevant {
            for tagID in entry.contextTagIDs ?? [] {
                tagCounts[tagID, default: 0] += 1
            }
        }

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
            daysSinceLastOccasion: daysSinceLast
        )
    }
}
