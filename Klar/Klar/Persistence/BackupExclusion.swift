import Foundation

enum BackupExclusion {
    /// Marks `url` as excluded from iCloud/iTunes backup. Must be re-applied on every launch:
    /// the flag is a filesystem attribute, not persisted app state, and can be lost across a
    /// device restore.
    @discardableResult
    static func apply(to url: URL) -> Bool {
        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try mutableURL.setResourceValues(resourceValues)
            return true
        } catch {
            return false
        }
    }

    static func isExcluded(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup ?? false
    }
}
