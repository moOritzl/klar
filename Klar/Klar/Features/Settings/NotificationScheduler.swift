import Foundation
import UserNotifications

/// Notification copy is **generic by contract**. A substance name on a lock screen is exactly the
/// leak the whole app is built to prevent — so no notification text here may ever name a
/// substance, a dose, or an entry. "Dein Wochenrückblick ist da." and nothing more.
enum NotificationScheduler {
    private static let weeklyReviewID = "klar.weeklyReview"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Monday morning — the review covers the week that just ended.
    static func scheduleWeeklyReviewReminder() async {
        let content = UNMutableNotificationContent()
        content.title = "Klar"
        content.body = String(localized: "Dein Wochenrückblick ist da.")
        content.sound = .default

        var components = DateComponents()
        components.weekday = 2 // Monday
        components.hour = 10

        let request = UNNotificationRequest(
            identifier: weeklyReviewID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [weeklyReviewID])
    }
}
