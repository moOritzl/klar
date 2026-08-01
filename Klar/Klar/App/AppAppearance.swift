import SwiftUI

/// Follows the system by default. An app that hides in a privacy-conscious pocket should not be
/// the one window that stays bright at night.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    /// `nil` hands the decision back to iOS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
