import Foundation

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
}
