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

        async let first: AuthenticationOutcome = manager.attemptUnlock()
        async let second: AuthenticationOutcome = manager.attemptUnlock()
        _ = await (first, second)

        XCTAssertEqual(evaluations, 1)
    }

    func testUnavailableAuthenticationUnlocksRatherThanLockingTheUserOut() async {
        let manager = AppLockManager { .unavailable }
        await manager.attemptUnlock()
        XCTAssertFalse(manager.isLocked)
    }

    /// The anti-wedge property. The guard above is only correct if it also *releases*: if a
    /// settled attempt left it stuck, the user could never unlock again by any route.
    func testAttemptAfterAnEarlierOneSettledEvaluatesAgain() async {
        var evaluations = 0
        let manager = AppLockManager {
            evaluations += 1
            return evaluations == 1 ? .cancelled : .success
        }

        let firstOutcome = await manager.attemptUnlock()
        XCTAssertTrue(manager.isLocked)

        let secondOutcome = await manager.attemptUnlock()
        XCTAssertEqual(evaluations, 2)
        XCTAssertFalse(manager.isLocked)

        // The outcome is the return value, not something callers have to infer from state.
        if case .cancelled = firstOutcome {} else { XCTFail("expected .cancelled, got \(firstOutcome)") }
        if case .success = secondOutcome {} else { XCTFail("expected .success, got \(secondOutcome)") }
    }

    /// "Erneut versuchen" must describe the attempt the user is looking at, not one they have
    /// already moved past.
    func testFailureLabelClearsOnceAnAttemptSucceeds() async {
        var shouldFail = true
        let manager = AppLockManager {
            defer { shouldFail = false }
            return shouldFail ? .failure : .success
        }

        await manager.attemptUnlock()
        XCTAssertTrue(manager.didFail)

        await manager.attemptUnlock()
        XCTAssertFalse(manager.didFail)
        XCTAssertFalse(manager.isLocked)
    }

    /// The stuck-screen regression. Foregrounding re-triggers the unlock while the evaluation
    /// started during backgrounding is still parked; iOS then cancels that stale prompt. If the
    /// re-request were merely dropped, nothing would be on screen and nobody would ask again.
    func testRequestArrivingMidAttemptIsHonouredOnceTheStaleOneIsCancelled() async {
        let stub = ParkingAuthenticator()
        let manager = AppLockManager { await stub.authenticate() }

        let inFlight = Task { await manager.attemptUnlock() }
        await stub.waitForEvaluations(atLeast: 1)

        // The foregrounding re-trigger, arriving while the first prompt is still up.
        await manager.attemptUnlock()
        XCTAssertEqual(stub.evaluations, 1, "the re-request must not stack a second prompt")

        stub.resume(with: .cancelled)
        await stub.waitForEvaluations(atLeast: 2)
        XCTAssertEqual(stub.evaluations, 2, "the remembered request must produce a fresh prompt")

        stub.resume(with: .success)
        await inFlight.value
        XCTAssertFalse(manager.isLocked)
        XCTAssertFalse(manager.isAuthenticating)
    }

    /// "Sofort" is the default auto-lock delay, so this is the path almost every user takes.
    func testImmediateDelayLocksAsSoonAsTheAppBackgrounds() {
        let manager = AppLockManager { .success }
        manager.unlockWithoutAuthentication()

        manager.scheduleLock(after: 0)
        XCTAssertTrue(manager.isLocked)
    }

    /// Foregrounding without a preceding backgrounding (a resigned-active blip, say) must not
    /// invent a lock the user never asked for.
    func testForegroundingWithNoScheduledLockLeavesTheAppOpen() {
        let manager = AppLockManager { .success }
        manager.unlockWithoutAuthentication()

        manager.cancelPendingLockIfStillWithinGrace(now: Date().addingTimeInterval(3600))
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

/// Stands in for `LAContext.evaluatePolicy`, which suspends until the user (or iOS) settles the
/// prompt. Every evaluation parks until the test resumes it, which is the only way to observe a
/// request that arrives *during* an attempt rather than between two.
@MainActor
private final class ParkingAuthenticator {
    private(set) var evaluations = 0
    private var prompt: CheckedContinuation<AuthenticationOutcome, Never>?

    func authenticate() async -> AuthenticationOutcome {
        evaluations += 1
        return await withCheckedContinuation { prompt = $0 }
    }

    /// Lets the test wait for an evaluation to actually be in flight instead of guessing with a
    /// sleep. Bounded, so a regression that stops the next evaluation from ever starting fails
    /// the assertion that follows rather than wedging the whole suite.
    func waitForEvaluations(atLeast count: Int, timeout: Duration = .seconds(2)) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while evaluations < count && ContinuousClock.now < deadline {
            await Task.yield()
        }
    }

    func resume(with outcome: AuthenticationOutcome) {
        let parked = prompt
        prompt = nil
        parked?.resume(returning: outcome)
    }
}
