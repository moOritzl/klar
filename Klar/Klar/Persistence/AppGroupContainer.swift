import Foundation

enum AppGroupContainer {
    static let identifier = "group.de.lenhard.klar"

    /// Resolves the directory the SwiftData store should live in. Prefers the App Group
    /// container so widgets/App Intents can read the same store later; falls back to the
    /// app's own Application Support directory if the App Group isn't provisioned (e.g. on
    /// a free Apple Developer account, where App Groups require a paid membership).
    static func storeDirectory(fileManager: FileManager = .default) -> URL {
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return groupURL
        }
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Klar", isDirectory: true)
    }
}
