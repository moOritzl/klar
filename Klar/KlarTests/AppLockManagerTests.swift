import XCTest
@testable import Klar

@MainActor
final class AppLockManagerTests: XCTestCase {
    func testSuccessfulAuthenticationUnlocks() async {
        let manager = AppLockManager { .success }
        await manager.attemptUnlock()
        XCTAssertFalse(manager.isLocked)
        XCTAssertFalse(manager.didFail)
    }

    func testFailedAuthenticationStaysLockedAndReportsFailure() async {
        let manager = AppLockManager { .failure }
        await manager.attemptUnlock()
        XCTAssertTrue(manager.isLocked)
        XCTAssertTrue(manager.didFail)
    }

    /// A system cancel is what happens when the app resigns active mid-prompt. The user did
    /// nothing wrong, so the screen must not accuse them of a failed attempt.
    func testCancelledAuthenticationStaysLockedWithoutReportingFailure() async {
        let manager = AppLockManager { .cancelled }
        await manager.attemptUnlock()
        XCTAssertTrue(manager.isLocked)
        XCTAssertFalse(manager.didFail)
    }

    /// The overlay re-triggers on every foregrounding. Two evaluations racing each other put
    /// two Face ID sheets on screen, which is the "stuck" symptom.
    func testOverlappingAttemptsEvaluateOnlyOnce() async {
        var evaluations = 0
        let manager = AppLockManager {
            evaluations += 1
            try? await Task.sleep(for: .milliseconds(50))
            return .success
        }

        async let first: Void = manager.attemptUnlock()
        async let second: Void = manager.attemptUnlock()
        _ = await (first, second)

        XCTAssertEqual(evaluations, 1)
    }

    func testUnavailableAuthenticationUnlocksRatherThanLockingTheUserOut() async {
        let manager = AppLockManager { .unavailable }
        await manager.attemptUnlock()
        XCTAssertFalse(manager.isLocked)
    }

    func testScheduledLockFiresOnlyAfterTheGracePeriod() {
        let manager = AppLockManager { .success }
        manager.unlockWithoutAuthentication()

        manager.scheduleLock(after: 60)
        manager.cancelPendingLockIfStillWithinGrace(now: Date().addingTimeInterval(10))
        XCTAssertFalse(manager.isLocked)

        manager.scheduleLock(after: 60)
        manager.cancelPendingLockIfStillWithinGrace(now: Date().addingTimeInterval(120))
        XCTAssertTrue(manager.isLocked)
    }
}
