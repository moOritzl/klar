import Foundation

/// What the newest answered mornings after a substance looked like. Plain counts, no score.
public struct MorningPattern: Sendable, Equatable {
    /// Answered days counted, between `minimum` and `limit`.
    public let days: Int
    public let body: [MorningBody: Int]
    public let regret: [MorningRegret: Int]
    public let again: [MorningAgain: Int]
    /// The latest non-empty „Was machst du nächstes Mal anders?" among those days.
    public let nextTime: String?

    public init(days: Int, body: [MorningBody: Int], regret: [MorningRegret: Int], again: [MorningAgain: Int], nextTime: String?) {
        self.days = days
        self.body = body
        self.regret = regret
        self.again = again
        self.nextTime = nextTime
    }
}

public enum MorningAfterService {
    /// How long after a logical day ends its card may still appear.
    public static let expiry: TimeInterval = 48 * 60 * 60

    /// The logical day „Der Morgen danach" should ask about now, if any.
    ///
    /// Only the newest day before today with an entry of an asking substance is ever a
    /// candidate. If it already has a record — answered or skipped — nothing is due, and older
    /// days are never asked about. It expires 48 h after the day ends (05:00 the next calendar
    /// day, in the timezone of that day's latest entry).
    public static func dueDayKey(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        records: [MorningAfterDTO],
        now: Date,
        nowTimezoneID: String
    ) -> String? {
        let todayKey = LogicalDay.dayKey(for: now, timezoneID: nowTimezoneID)

        var latestEntryByDay: [String: EntryDTO] = [:]
        for entry in entries {
            guard let substanceID = entry.substanceID, askingSubstanceIDs.contains(substanceID) else { continue }
            let key = LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID)
            guard key < todayKey else { continue }
            if let known = latestEntryByDay[key], known.timestamp >= entry.timestamp { continue }
            latestEntryByDay[key] = entry
        }

        guard let candidate = latestEntryByDay.keys.max(),
              let latest = latestEntryByDay[candidate],
              !records.contains(where: { $0.dayKey == candidate }),
              let end = LogicalDay.end(ofDayKey: candidate, timezoneID: latest.timezoneID),
              now < end.addingTimeInterval(expiry)
        else { return nil }

        return candidate
    }

    /// The pattern for one substance, optionally narrowed to days whose entries of that
    /// substance carry `contextTagID`. `nil` below `minimum` answered days.
    public static func pattern(
        substanceID: UUID,
        contextTagID: UUID?,
        entries: [EntryDTO],
        records: [MorningAfterDTO],
        limit: Int = 5,
        minimum: Int = 3
    ) -> MorningPattern? {
        var matchingDays: Set<String> = []
        for entry in entries where entry.substanceID == substanceID {
            if let contextTagID, entry.contextTagIDs?.contains(contextTagID) != true { continue }
            matchingDays.insert(LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID))
        }

        let counted = records
            .filter { $0.isAnswered && matchingDays.contains($0.dayKey) }
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(limit)
        guard counted.count >= minimum else { return nil }

        var body: [MorningBody: Int] = [:]
        var regret: [MorningRegret: Int] = [:]
        var again: [MorningAgain: Int] = [:]
        for record in counted {
            if let answer = record.body { body[answer, default: 0] += 1 }
            if let answer = record.regret { regret[answer, default: 0] += 1 }
            if let answer = record.again { again[answer, default: 0] += 1 }
        }
        let nextTime = counted.lazy
            .compactMap { $0.nextTime?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return MorningPattern(days: counted.count, body: body, regret: regret, again: again, nextTime: nextTime)
    }
}
