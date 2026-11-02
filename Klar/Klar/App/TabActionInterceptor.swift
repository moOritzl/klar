import SwiftUI
import UIKit

/// Turns one tab of the tab bar — the separate round „+" (a search-role `Tab`) — into a plain
/// action.
///
/// SwiftUI has no action tab. Refusing the selection in the `TabView` binding works, but only after
/// UIKit has already switched to the tab's empty page for a few frames: the screen flashed black.
/// UIKit asks `tabBarController(_:shouldSelect:)` *before* it switches, so this sits in front of
/// SwiftUI's own delegate, says no for that one tab and runs the action instead, and forwards every
/// other call to SwiftUI unchanged.
///
/// The tab is recognised by its title. On iOS 26 SwiftUI's phone tab view drives
/// `UITabBarController` through `viewControllers`, so UIKit asks `shouldSelect viewController`;
/// on iOS 27 it uses `UITab`s and asks `shouldSelectTab` instead. Both are answered.
struct TabActionInterceptor: UIViewControllerRepresentable {
    /// The title of the `Tab` to intercept, exactly as passed to `Tab(_:systemImage:value:)`.
    let tabTitle: String
    let action: () -> Void

    func makeCoordinator() -> Proxy { Proxy() }

    func makeUIViewController(context: Context) -> Probe {
        let probe = Probe()
        probe.proxy = context.coordinator
        return probe
    }

    func updateUIViewController(_ probe: Probe, context: Context) {
        context.coordinator.tabTitle = tabTitle
        context.coordinator.action = action
        probe.install()
    }

    /// Invisible; only here to find the tab bar controller it ends up inside.
    final class Probe: UIViewController {
        weak var proxy: Proxy?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        func install() {
            guard let proxy, let tabBarController else { return }
            proxy.attach(to: tabBarController)
        }
    }

    final class Proxy: NSObject, UITabBarControllerDelegate {
        var tabTitle = ""
        var action: () -> Void = {}
        /// SwiftUI's coordinator. Weak: the tab bar controller owns it, not us.
        private weak var original: UITabBarControllerDelegate?

        func attach(to tabBarController: UITabBarController) {
            guard tabBarController.delegate !== self else { return }
            original = tabBarController.delegate
            tabBarController.delegate = self
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
            if tab.title == tabTitle {
                action()
                return false
            }
            return original?.tabBarController?(tabBarController, shouldSelectTab: tab) ?? true
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            if viewController.tabBarItem.title == tabTitle {
                action()
                return false
            }
            return original?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
        }

        // Everything else is SwiftUI's business.
        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || (original?.responds(to: selector) ?? false)
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
        }
    }
}
