import Foundation
import SwiftData
import KlarCore

/// Everything the Weekly Review (F1–F3) and the review archive (E4) display for one week.
///
/// Deliberately descriptive: counts, the user's own previous week as the only reference point,
/// and what their own plan did. No norms, no comparison to anyone else (concept § 3, P4/P7).
struct WeeklyReviewSummary {
    struct SubstanceTrend: Identifiable {
        let substanceID: UUID
        let name: String
        let unit: SubstanceUnit
        let averageAmount: Decimal?
        let previousAverageAmount: Decimal?
        let occasionCount: Int

        var id: UUID { substanceID }

        /// Down / up / flat against *this user's* previous week. nil when there's nothing to
        /// compare against yet.
        var direction: Direction? {
            guard let averageAmount, let previousAverageAmount, previousAverageAmount != 0 else {
                return nil
            }
            if averageAmount < previousAverageAmount { return .down }
            if averageAmount > previousAverageAmount { return .up }
            return .flat
        }

        enum Direction {
            case down, up, flat

            var symbol: String {
                switch self {
                case .down: "↓"
                case .up: "↑"
                case .flat: "→"
                }
            }
        }
    }

    struct PlanTally: Identifiable {
        let planID: UUID
        let situationText: String
        let actionText: String
        let helped: Int
        let total: Int

        var id: UUID { planID }
        var summary: String { "\(helped)/\(total)" }
    }

    let weekStart: Date
    let entryCount: Int
    let trends: [SubstanceTrend]
    let lastGapDays: Int?
    let planTallies: [PlanTally]
    let quotaSubstanceName: String?
    let quotaLimit: Int?
    let quotaRemaining: Int?

    var hasQuota: Bool { quotaLimit != nil && quotaRemaining != nil }

    /// The one-line archive subtitle: "2 Einträge · Ø Dosis ↓ · Plan 3/3 geholfen".
    var archiveSubtitle: String {
        var parts: [String] = []
        parts.append(entryCount == 1 ? "1 Eintrag" : "\(entryCount) Einträge")

        if entryCount == 0 {
            parts.append("eintragsfreie Woche")
        } else if let trend = trends.first(where: { $0.direction != nil }),
                  let direction = trend.direction {
            parts.append(direction == .flat ? "Ø Dosis stabil" : "Ø Dosis \(direction.symbol)")
        }

        let totals = planTallies.reduce(into: (helped: 0, total: 0)) {
            $0.helped += $1.helped
            $0.total += $1.total
        }
        if totals.total > 0 {
            parts.append("Plan \(totals.helped)/\(totals.total) geholfen")
        }

        return parts.joined(separator: " · ")
    }
}

// MARK: - Building

extension WeeklyReviewSummary {

    @MainActor
    static func build(weekStart: Date, store: KlarStore) -> WeeklyReviewSummary {
        let calendar = KlarDate.calendar
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart

        let allEntries = store.allEntries()
        let entriesThisWeek = allEntries.filter {
            let day = KlarDate.logicalDay(for: $0.timestamp, timezoneID: $0.timezoneID)
            return day >= weekStart && day < weekEnd
        }

        // Per-substance average dose this week vs. last week, and how many occasions.
        var trends: [SubstanceTrend] = []
        for substance in store.allSubstances() {
            let summary = store.stats(for: substance, referenceDate: weekEnd)
            let thisWeek = summary.weeklyAverages.first { $0.weekStart == weekStart }
            let lastWeek = summary.weeklyAverages.first { $0.weekStart == previousWeekStart }
            guard let thisWeek, thisWeek.occasionCount > 0 else { continue }

            trends.append(
                SubstanceTrend(
                    substanceID: substance.id,
                    name: substance.name,
                    unit: substance.unit,
                    averageAmount: thisWeek.averageAmount,
                    previousAverageAmount: lastWeek?.averageAmount,
                    occasionCount: thisWeek.occasionCount
                )
            )
        }

        // "Letzter Abstand": days between the two most recent occasions overall.
        let occasionDays = Set(
            allEntries
                .filter { KlarDate.logicalDay(for: $0.timestamp, timezoneID: $0.timezoneID) < weekEnd }
                .map { KlarDate.logicalDay(for: $0.timestamp, timezoneID: $0.timezoneID) }
        ).sorted()
        var lastGapDays: Int?
        if occasionDays.count >= 2 {
            let last = occasionDays[occasionDays.count - 1]
            let previous = occasionDays[occasionDays.count - 2]
            lastGapDays = calendar.dateComponents([.day], from: previous, to: last).day
        }

        let planTallies = store.activePlans().map { plan in
            let tally = store.checkInTally(for: plan, weekStart: weekStart)
            return PlanTally(
                planID: plan.id,
                situationText: plan.situationText,
                actionText: plan.actionText,
                helped: tally.helped,
                total: tally.total
            )
        }

        let quotaSubstance = store.primaryQuotaSubstance()
        let quota = quotaSubstance.map { store.quota(for: $0, on: weekStart) }

        return WeeklyReviewSummary(
            weekStart: weekStart,
            entryCount: entriesThisWeek.count,
            trends: trends,
            lastGapDays: lastGapDays,
            planTallies: planTallies,
            quotaSubstanceName: quotaSubstance?.name,
            quotaLimit: quota?.limit,
            quotaRemaining: quota?.remaining
        )
    }

    /// Every completed week that has passed since the user's first entry, newest first — the
    /// archive list (E4).
    @MainActor
    static func archivedWeekStarts(store: KlarStore, now: Date = Date(), limit: Int = 12) -> [Date] {
        let entries = store.allEntries()
        guard let earliest = entries.map(\.timestamp).min() else { return [] }

        let calendar = KlarDate.calendar
        let firstWeek = KlarDate.weekStart(for: earliest)
        let currentWeek = KlarDate.weekStart(for: now)

        var weeks: [Date] = []
        var cursor = calendar.date(byAdding: .day, value: -7, to: currentWeek) ?? currentWeek
        while cursor >= firstWeek && weeks.count < limit {
            weeks.append(cursor)
            guard let previous = calendar.date(byAdding: .day, value: -7, to: cursor) else { break }
            cursor = previous
        }
        return weeks
    }

    /// The review covers the week that just *ended*. It becomes due once we're in a new week and
    /// the user hasn't seen that week's review yet — and never before they've logged anything,
    /// because a review of nothing is noise, not feedback.
    static func isReviewDue(
        lastReviewedWeekStart: Date?,
        hasAnyEntries: Bool,
        now: Date = Date()
    ) -> Bool {
        guard hasAnyEntries else { return false }
        let calendar = KlarDate.calendar
        let currentWeek = KlarDate.weekStart(for: now)
        guard let lastCompletedWeek = calendar.date(byAdding: .day, value: -7, to: currentWeek) else {
            return false
        }
        guard let lastReviewedWeekStart else { return true }
        return KlarDate.weekStart(for: lastReviewedWeekStart) < lastCompletedWeek
    }

    /// The week the review flow should show right now: the one that just ended.
    static func dueWeekStart(now: Date = Date()) -> Date {
        let currentWeek = KlarDate.weekStart(for: now)
        return KlarDate.calendar.date(byAdding: .day, value: -7, to: currentWeek) ?? currentWeek
    }
}
