import Foundation
import SwiftData

#if DEBUG
/// Boots the app straight into a populated, already-onboarded state.
///
/// Marketing and documentation screenshots need screens that only exist once
/// there is history behind them — the weekly review spans months, which is not
/// something you can tap in by hand. Passing `--klar-demo-seed` wipes the
/// store, seeds `DemoDataSeeder`'s neutral sample data (Kaffee, Alkohol,
/// Nikotin) and skips onboarding.
enum DemoModeSupport {
    static let argument = "--klar-demo-seed"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    /// Must run before `AppSettings` is constructed — it reads UserDefaults in
    /// its initializer, so writing afterwards would not be picked up.
    /// Mirrors `AppSettings.Keys.hasCompletedOnboarding`, which is private.
    static func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: "klar.hasCompletedOnboarding")
    }

    static func seed(container: ModelContainer) {
        try? DemoDataSeeder.seed(context: ModelContext(container))
    }
}
#endif
