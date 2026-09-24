import Foundation

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
}
