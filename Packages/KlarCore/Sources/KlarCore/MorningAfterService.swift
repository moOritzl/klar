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

    /// How long after a logical day ends it can still be answered — from „Offen" or the day
    /// detail. Longer than `expiry`, which only governs the card popping up by itself.
    public static let answerWindow: TimeInterval = 72 * 60 * 60

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
        let latestEntryByDay = latestAskingEntryByDay(entries: entries, askingSubstanceIDs: askingSubstanceIDs, before: todayKey)

        guard let candidate = latestEntryByDay.keys.max(),
              let latest = latestEntryByDay[candidate],
              !records.contains(where: { $0.dayKey == candidate }),
              let end = LogicalDay.end(ofDayKey: candidate, timezoneID: latest.timezoneID),
              now < end.addingTimeInterval(expiry)
        else { return nil }

        return candidate
    }

    /// Days before today with an entry of an asking substance that ended less than
    /// `answerWindow` ago — with or without a record.
    public static func answerableDayKeys(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        now: Date,
        nowTimezoneID: String
    ) -> Set<String> {
        let todayKey = LogicalDay.dayKey(for: now, timezoneID: nowTimezoneID)
        let latestEntryByDay = latestAskingEntryByDay(entries: entries, askingSubstanceIDs: askingSubstanceIDs, before: todayKey)
        return Set(latestEntryByDay.compactMap { key, latest -> String? in
            guard let end = LogicalDay.end(ofDayKey: key, timezoneID: latest.timezoneID),
                  now < end.addingTimeInterval(answerWindow)
            else { return nil }
            return key
        })
    }

    /// „Offen": answerable days with no record at all, newest first. A skip record takes a day
    /// off this list; a newer day does not.
    public static func openDayKeys(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        records: [MorningAfterDTO],
        now: Date,
        nowTimezoneID: String
    ) -> [String] {
        let recorded = Set(records.map(\.dayKey))
        return answerableDayKeys(entries: entries, askingSubstanceIDs: askingSubstanceIDs, now: now, nowTimezoneID: nowTimezoneID)
            .subtracting(recorded)
            .sorted(by: >)
    }

    /// For the answered days of `substanceID`: how many of them also carry an entry of each other
    /// asking substance. Substances that don't ask are left out — the user said they have
    /// nothing to do with the day after.
    public static func sharedDays(
        substanceID: UUID,
        askingSubstanceIDs: Set<UUID>,
        entries: [EntryDTO],
        records: [MorningAfterDTO]
    ) -> [UUID: Int] {
        var substancesByDay: [String: Set<UUID>] = [:]
        for entry in entries {
            guard let id = entry.substanceID else { continue }
            substancesByDay[LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID), default: []].insert(id)
        }

        var counts: [UUID: Int] = [:]
        for record in records where record.isAnswered {
            guard let present = substancesByDay[record.dayKey], present.contains(substanceID) else { continue }
            for other in present where other != substanceID && askingSubstanceIDs.contains(other) {
                counts[other, default: 0] += 1
            }
        }
        return counts
    }

    /// The latest entry of an asking substance on each logical day before `todayKey`. Its
    /// timezone decides when that day ends.
    private static func latestAskingEntryByDay(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        before todayKey: String
    ) -> [String: EntryDTO] {
        var latest: [String: EntryDTO] = [:]
        for entry in entries {
            guard let substanceID = entry.substanceID, askingSubstanceIDs.contains(substanceID) else { continue }
            let key = LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID)
            guard key < todayKey else { continue }
            if let known = latest[key], known.timestamp >= entry.timestamp { continue }
            latest[key] = entry
        }
        return latest
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
