import Foundation
import Observation
import UserNotifications

/// The one push notification Klar sends: „Wie war der Morgen?", the morning after a day with
/// entries.
///
/// Local only — scheduled on the device, no server, nothing leaves the phone. The rules come from
/// P9 as amended: at most one reminder per day, never for a day the card already asked about by
/// itself, never repeated when ignored, and no substance on the lock screen.
///
/// Scheduling is a pure prediction over the current data (`nextReminder`), redone whenever the app
/// comes forward or leaves: one pending request at a time, replaced every time. A new entry, an
/// answer or a changed setting is therefore picked up the next time the app is left.
@Observable
final class MorningReminder: NSObject, UNUserNotificationCenterDelegate {
    static let shared = MorningReminder()
    static let requestIdentifier = "klar.morningAfter"
    private static let dayKeyInfo = "dayKey"

    /// The day of a reminder the user tapped, waiting for `MainTabView` to open its card. Kept
    /// until it can be shown — the app lock may still be in front when the tap arrives.
    var tappedDayKey: String?

    private var center: UNUserNotificationCenter { .current() }

    /// UI tests drive the morning card themselves; a system permission alert in the middle of
    /// their taps would break every one of them.
    private var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--klar-uitest") }
    }

    /// Must run before the app finishes launching, or a tap that cold-starts the app is lost.
    func install() {
        center.delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Asked once, after the first morning card — the moment the reminder means something —
    /// rather than during onboarding.
    func requestAuthorizationIfUndetermined() async {
        guard !isRunningUITests, await authorizationStatus() == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func reschedule(store: KlarStore, settings: AppSettings, now: Date = Date()) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        guard settings.isMorningReminderEnabled else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        guard let next = Self.nextReminder(
            now: now,
            minuteOfDay: settings.morningReminderMinuteOfDay,
            lastPresentedKey: settings.lastPresentedMorningDayKey,
            dueKeyAt: { store.dueMorningAfterDay(now: $0) }
        ) else { return }

        let content = UNMutableNotificationContent()
        // No substance, no count: this is what shows on a lock screen other people can see.
        content.body = String(localized: "Wie war der Morgen?")
        content.sound = .default
        content.userInfo = [Self.dayKeyInfo: next.dayKey]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: next.fireDate)
        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    /// The first reminder time today or tomorrow at which a morning would be due, for a day the
    /// card has not asked about yet. `dueKeyAt` answers „which day would be due at this moment",
    /// so expiry and „already answered" stay in `MorningAfterService`, where the card reads them.
    static func nextReminder(
        now: Date,
        minuteOfDay: Int,
        lastPresentedKey: String?,
        calendar: Calendar = .current,
        dueKeyAt: (Date) -> String?
    ) -> (fireDate: Date, dayKey: String)? {
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(
                      bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: day
                  ),
                  fireDate > now,
                  let dayKey = dueKeyAt(fireDate)
            else { continue }
            // Day keys sort as strings. A day the card already popped up for was asked once.
            if let lastPresentedKey, dayKey <= lastPresentedKey { continue }
            return (fireDate, dayKey)
        }
        return nil
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let dayKey = response.notification.request.content.userInfo[Self.dayKeyInfo] as? String
        await MainActor.run { self.tappedDayKey = dayKey }
    }

    /// With the app open the card appears by itself, so a banner on top of it would only repeat it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
