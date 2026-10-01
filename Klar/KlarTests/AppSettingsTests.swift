import XCTest
@testable import Klar

@MainActor
final class AppSettingsTests: XCTestCase {
    func testTheLastPresentedMorningDaySurvivesARelaunch() throws {
        let suite = "klar.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertNil(settings.lastPresentedMorningDayKey)

        settings.lastPresentedMorningDayKey = "2026-09-19"
        XCTAssertEqual(AppSettings(defaults: defaults).lastPresentedMorningDayKey, "2026-09-19")
    }
}
