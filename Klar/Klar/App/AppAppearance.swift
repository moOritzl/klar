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

    /// `.unspecified` hands the decision back to iOS.
    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Overriding the window rather than using `preferredColorScheme`, which restyles the SwiftUI
/// content but leaves the hosting window on the system style — sheets and the tab bar chrome kept
/// following iOS instead of the user's choice, and it pinned an open sheet to the previous scheme
/// when the choice went back to System. The window is the one thing every presentation, SwiftUI or
/// UIKit, inherits its traits from.
struct WindowAppearance: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ view: UIView, context: Context) {
        // The view is not in a window yet on the first update pass.
        DispatchQueue.main.async {
            view.window?.overrideUserInterfaceStyle = style
        }
    }
}
