import Foundation
import Observation

/// Auto-lock delay after the app leaves the foreground.
enum AutoLockDelay: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .immediately: "Sofort"
        case .oneMinute: "Nach 1 Minute"
        case .fiveMinutes: "Nach 5 Minuten"
        }
    }
}

/// Every user preference in the app. Deliberately small: the design's Einstellungen screen
/// is "a deliberately boring place — things you decide once and then forget".
///
/// Backed by `UserDefaults`, not SwiftData: these are device settings, not user data, and
/// they must not end up in the export/import payload.
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.isAppLockEnabled = defaults.object(forKey: Keys.isAppLockEnabled) as? Bool ?? false
        self.isPanicGestureEnabled = defaults.object(forKey: Keys.isPanicGestureEnabled) as? Bool ?? false
        self.autoLockDelay = AutoLockDelay(
            rawValue: defaults.object(forKey: Keys.autoLockDelay) as? Int ?? 0
        ) ?? .immediately
        self.areNotificationsEnabled = defaults.bool(forKey: Keys.areNotificationsEnabled)
        self.counselingCity = defaults.string(forKey: Keys.counselingCity) ?? "Berlin"
        self.lastReviewedWeekStart = defaults.object(forKey: Keys.lastReviewedWeekStart) as? Date
        self.supportContactName = defaults.string(forKey: Keys.supportContactName)
        self.supportContactPhone = defaults.string(forKey: Keys.supportContactPhone)
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    /// Face ID / device-passcode gate. Off by default — the user opts in during onboarding (A1).
    var isAppLockEnabled: Bool {
        didSet { defaults.set(isAppLockEnabled, forKey: Keys.isAppLockEnabled) }
    }

    /// When on, a two-finger double-tap anywhere swaps the UI for the calculator façade (J2).
    var isPanicGestureEnabled: Bool {
        didSet { defaults.set(isPanicGestureEnabled, forKey: Keys.isPanicGestureEnabled) }
    }

    var autoLockDelay: AutoLockDelay {
        didSet { defaults.set(autoLockDelay.rawValue, forKey: Keys.autoLockDelay) }
    }

    var areNotificationsEnabled: Bool {
        didSet { defaults.set(areNotificationsEnabled, forKey: Keys.areNotificationsEnabled) }
    }

    var counselingCity: String {
        didSet { defaults.set(counselingCity, forKey: Keys.counselingCity) }
    }

    /// Monday of the last week the user completed a Weekly Review for. Drives whether the
    /// review is offered on launch.
    var lastReviewedWeekStart: Date? {
        didSet { defaults.set(lastReviewedWeekStart, forKey: Keys.lastReviewedWeekStart) }
    }

    /// The Craving-SOS one-tap call target. Deliberately *not* part of the SwiftData store: it is
    /// another person's phone number, and it has no business in the user's data export.
    var supportContactName: String? {
        didSet { defaults.set(supportContactName, forKey: Keys.supportContactName) }
    }

    var supportContactPhone: String? {
        didSet { defaults.set(supportContactPhone, forKey: Keys.supportContactPhone) }
    }

    func resetForOnboarding() {
        hasCompletedOnboarding = false
        lastReviewedWeekStart = nil
    }

    private enum Keys {
        static let supportContactName = "klar.supportContactName"
        static let supportContactPhone = "klar.supportContactPhone"
        static let hasCompletedOnboarding = "klar.hasCompletedOnboarding"
        static let isAppLockEnabled = "klar.isAppLockEnabled"
        static let isPanicGestureEnabled = "klar.isPanicGestureEnabled"
        static let autoLockDelay = "klar.autoLockDelay"
        static let areNotificationsEnabled = "klar.areNotificationsEnabled"
        static let counselingCity = "klar.counselingCity"
        static let lastReviewedWeekStart = "klar.lastReviewedWeekStart"
    }
}
