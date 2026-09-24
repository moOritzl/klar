import Foundation
import SwiftData
import KlarCore

/// Lets a UI test start from a genuinely clean install.
///
/// Passing defaults as launch arguments (`-klar.hasCompletedOnboarding NO`) doesn't work here:
/// `NSArgumentDomain` outranks the application domain, so the app could never *write* its way
/// past onboarding during the test. Wiping both domains up front is the only honest reset.
enum UITestSupport {
    static let resetArgument = "--klar-uitest-reset"

    static var isResetRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(resetArgument)
    }

    static func reset(fileManager: FileManager = .default) {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        let directory = AppGroupContainer.storeDirectory(fileManager: fileManager)
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in contents where url.lastPathComponent.hasPrefix(ModelContainerFactory.storeFileName) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Onboarding done, Alkohol, one entry at 21:00 on the previous logical day — the smallest
    /// state in which „Der Morgen danach" is due.
    static let seedYesterdayArgument = "--klar-uitest-seed-yesterday"

    static var isSeedYesterdayRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(seedYesterdayArgument)
    }

    @MainActor
    static func seedYesterday(container: ModelContainer) {
        let store = KlarStore(context: ModelContext(container))
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let today = KlarDate.logicalDay(for: Date())
        guard let yesterday = KlarDate.calendar.date(byAdding: .day, value: -1, to: today),
              let evening = KlarDate.calendar.date(bySettingHour: 21, minute: 0, second: 0, of: yesterday)
        else { return }
        store.addEntry(substance: alcohol, timestamp: evening)
    }
}
