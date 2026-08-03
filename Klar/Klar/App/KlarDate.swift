import Foundation
import KlarCore

/// Date formatting and logical-day helpers for the UI layer.
///
/// The app's day boundary is 05:00 (`LogicalDay.cutoffHour`), not midnight — an entry logged
/// at 02:30 belongs to the night before. Every "today" / "this month" question in the UI must
/// go through here so the calendar, the quota and the check-in flow all agree.
enum KlarDate {

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "de_DE")
        calendar.firstWeekday = 2 // Monday — matches the design's M/D/M/D/F/S/S header.
        return calendar
    }

    static var timezoneID: String { TimeZone.current.identifier }

    /// The logical day `date` falls into, normalized to that day's 00:00.
    static func logicalDay(for date: Date, timezoneID: String = KlarDate.timezoneID) -> Date {
        LogicalDay.date(
            from: LogicalDay.components(for: date, timezoneID: timezoneID),
            timezoneID: timezoneID
        )
    }

    static func isToday(_ date: Date, timezoneID: String, now: Date = Date()) -> Bool {
        LogicalDay.isSameLogicalDay(date, timezoneID, now, KlarDate.timezoneID)
    }

    /// True while the logical day is still the previous calendar day (00:00 until the 05:00
    /// cutoff) — the only hours in which the UI has to say which day it means.
    static func isBeforeCutoff(_ date: Date = Date(), timezoneID: String = KlarDate.timezoneID) -> Bool {
        LogicalDay.isBeforeCutoff(date, timezoneID: timezoneID)
    }

    /// Monday 00:00 of the week containing `date`.
    static func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    /// Sunday of the week containing `date`.
    static func weekEnd(for date: Date) -> Date {
        calendar.date(byAdding: .day, value: 6, to: weekStart(for: date)) ?? date
    }

    /// True when `date`'s logical day is the 1st of its month — drives the "Neuer Monat" card (B3).
    static func isFirstOfMonth(_ date: Date = Date()) -> Bool {
        calendar.component(.day, from: logicalDay(for: date)) == 1
    }

    static func monthComponents(for date: Date = Date()) -> (year: Int, month: Int) {
        let day = logicalDay(for: date)
        return (calendar.component(.year, from: day), calendar.component(.month, from: day))
    }

    /// Midnight on the 1st of `date`'s month.
    ///
    /// This is the anchor every `GoalPeriod.validFrom` uses. `QuotaCalculator` resolves a month's
    /// goal by asking which period was in force *at the start of that month*, so a goal stamped
    /// with the wall-clock moment it was created would not apply to the month it was created in.
    static func startOfMonth(for date: Date = Date()) -> Date {
        let (year, month) = monthComponents(for: date)
        return LogicalDay.date(
            from: DateComponents(year: year, month: month, day: 1),
            timezoneID: timezoneID
        )
    }

    // MARK: - Formatters

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate(format)
        return formatter
    }

    /// "Di, 14. Jul" — the Today header.
    static func shortWeekdayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EE, d. MMM"
        return formatter.string(from: date)
    }

    /// "Mo., 3. Aug." for the logical day `now` falls into — the Heute header.
    ///
    /// Deliberately not `shortWeekdayDate(now)`: at 02:15 those two disagree, and the screen is
    /// titled „Heute", so it has to name the day whose entries it lists.
    static func logicalDayLabel(now: Date = Date()) -> String {
        shortWeekdayDate(logicalDay(for: now))
    }

    /// "Montag"
    static func weekdayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// "Montag, 14. Juli" — the day-detail header.
    static func longWeekdayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, d. MMMM"
        return formatter.string(from: date)
    }

    /// "3. Juli" — plan commitment date.
    static func dayAndMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM"
        return formatter.string(from: date)
    }

    /// "22:40"
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// "Juli"
    static func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }

    /// "7. – 13. Jul" — the review week range, collapsing the month when both ends share one.
    static func weekRange(_ weekStart: Date) -> String {
        let end = weekEnd(for: weekStart)
        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "de_DE")
        dayOnly.dateFormat = "d."

        let dayMonth = DateFormatter()
        dayMonth.locale = Locale(identifier: "de_DE")
        dayMonth.dateFormat = "d. MMM"

        let sameMonth = calendar.component(.month, from: weekStart) == calendar.component(.month, from: end)
        let startText = sameMonth ? dayOnly.string(from: weekStart) : dayMonth.string(from: weekStart)
        return "\(startText) – \(dayMonth.string(from: end))"
    }

    /// "7. – 13. JULI" — the Weekly Review eyebrow.
    static func weekRangeLong(_ weekStart: Date) -> String {
        let end = weekEnd(for: weekStart)
        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "de_DE")
        dayOnly.dateFormat = "d."

        let dayMonth = DateFormatter()
        dayMonth.locale = Locale(identifier: "de_DE")
        dayMonth.dateFormat = "d. MMMM"

        return "\(dayOnly.string(from: weekStart)) – \(dayMonth.string(from: end))"
    }
}

// MARK: - Amount formatting

extension Decimal {
    /// "80" not "80.0"; "2,5" in German locale.
    var klarFormatted: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}

extension SubstanceUnit {
    /// The unit as it reads next to a number: "80 mg", "2 Getränke".
    func label(for amount: Decimal?) -> String {
        switch self {
        case .mg: "mg"
        case .g: "g"
        case .ml: "ml"
        case .piece: (amount == 1) ? "Stück" : "Stück"
        case .drink: (amount == 1) ? "Getränk" : "Getränke"
        }
    }

    var shortLabel: String {
        switch self {
        case .mg: "mg"
        case .g: "g"
        case .ml: "ml"
        case .piece: "Stück"
        case .drink: "Getränke"
        }
    }
}
