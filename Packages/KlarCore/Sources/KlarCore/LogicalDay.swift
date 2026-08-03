import Foundation

public enum LogicalDay: Sendable {
    public static let cutoffHour = 5

    public static func components(for date: Date, timezoneID: String) -> DateComponents {
        let calendar = calendar(for: timezoneID)
        let wallClock = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        guard let hour = wallClock.hour, let dayStart = calendar.date(from: wallClock) else {
            return wallClock
        }
        if hour < cutoffHour {
            let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
            return calendar.dateComponents([.year, .month, .day], from: previousDay)
        }
        return calendar.dateComponents([.year, .month, .day], from: dayStart)
    }

    /// True while `date`'s logical day is still the *previous* calendar day — the hours between
    /// midnight and the cutoff.
    ///
    /// This is the window in which any date the UI shows contradicts the phone's clock, so it is
    /// also the only window in which the UI owes the user an explanation.
    public static func isBeforeCutoff(_ date: Date, timezoneID: String) -> Bool {
        let hour = calendar(for: timezoneID).component(.hour, from: date)
        return hour < cutoffHour
    }

    public static func date(from components: DateComponents, timezoneID: String) -> Date {
        let calendar = calendar(for: timezoneID)
        return calendar.date(from: components) ?? Date()
    }

    public static func isSameLogicalDay(_ a: Date, _ aTimezoneID: String, _ b: Date, _ bTimezoneID: String) -> Bool {
        components(for: a, timezoneID: aTimezoneID) == components(for: b, timezoneID: bTimezoneID)
    }

    public static func isLogicalDayBefore(_ a: Date, _ aTimezoneID: String, _ b: Date, _ bTimezoneID: String) -> Bool {
        let dateA = date(from: components(for: a, timezoneID: aTimezoneID), timezoneID: aTimezoneID)
        let dateB = date(from: components(for: b, timezoneID: bTimezoneID), timezoneID: bTimezoneID)
        return dateA < dateB
    }

    private static func calendar(for timezoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezoneID) ?? .current
        return calendar
    }
}
