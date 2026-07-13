import XCTest
@testable import Klar

final class BackupExclusionTests: XCTestCase {
    func testStoreDirectoryHasExclusionResourceValueSetAfterInit() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KlarBackupExclusionTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        XCTAssertFalse(BackupExclusion.isExcluded(tempDirectory))

        let applied = BackupExclusion.apply(to: tempDirectory)
        XCTAssertTrue(applied)
        XCTAssertTrue(BackupExclusion.isExcluded(tempDirectory))
    }
}
