import Foundation
import LocalAuthentication
import Observation

/// What a single authentication attempt came back with. A *cancel* is deliberately not a
/// failure: iOS cancels the prompt whenever the app resigns active, and the user never saw it.
enum AuthenticationOutcome {
    case success
    case failure
    case cancelled
    /// Neither biometrics nor a device passcode is configured. Locking here would lock the user
    /// out of their own app over a device setting they may not control.
    case unavailable
}

@MainActor
@Observable
final class AppLockManager {
    private(set) var isLocked: Bool = true
    private(set) var didFail: Bool = false
    private(set) var isAuthenticating: Bool = false

    /// Set when the app backgrounds with a non-zero auto-lock delay. On the next foregrounding
    /// we lock only if this moment has already passed — that's what makes "Nach 1 Minute"
    /// different from "Sofort".
    private var lockDeadline: Date?

    /// Someone asked to unlock while an evaluation was already in flight. Remembered rather than
    /// dropped — see `attemptUnlock()`.
    private var isRequestPending = false

    private let authenticate: () async -> AuthenticationOutcome

    init(authenticate: @escaping () async -> AuthenticationOutcome = AppLockManager.systemAuthenticate) {
        self.authenticate = authenticate
    }

    var requiresUnlock: Bool { isLocked }

    func lock() {
        isLocked = true
        lockDeadline = nil
    }

    /// Called when the app enters the background.
    func scheduleLock(after delay: TimeInterval) {
        guard delay > 0 else {
            lock()
            return
        }
        lockDeadline = Date().addingTimeInterval(delay)
    }

    /// Called when the app becomes active again. Locks only if the grace period elapsed while
    /// we were away. `now` is injectable so the grace window is testable without sleeping.
    func cancelPendingLockIfStillWithinGrace(now: Date = Date()) {
        defer { lockDeadline = nil }
        guard let lockDeadline else { return }
        if now >= lockDeadline {
            isLocked = true
        }
    }

    /// Used when the user has the Face ID lock switched off — the gate must not stand in the way.
    func unlockWithoutAuthentication() {
        isLocked = false
        didFail = false
        lockDeadline = nil
    }

    /// Re-entrant by design: the overlay calls this on every foregrounding, and a second call
    /// while a prompt is already up would stack two Face ID sheets.
    ///
    /// A request that arrives mid-flight is *remembered*, not dropped. Dropping it is what left
    /// users on a dead wordmark screen: the app foregrounds, we ignore the re-request because an
    /// evaluation is already running, and then iOS delivers that evaluation's `systemCancel`
    /// (it was started while we were backgrounded, so it was doomed). Nothing is on screen and
    /// nobody is going to ask again. Looping instead means the stale attempt's cancel is
    /// immediately followed by a fresh prompt.
    ///
    /// Returns the outcome of the last evaluation this call performed. A call that was folded
    /// into an in-flight attempt evaluated nothing and reports `.cancelled`.
    @discardableResult
    func attemptUnlock() async -> AuthenticationOutcome {
        guard !isAuthenticating else {
            isRequestPending = true
            return .cancelled
        }
        isAuthenticating = true
        defer { isAuthenticating = false }

        var outcome: AuthenticationOutcome
        repeat {
            isRequestPending = false
            // The label belongs to the attempt in progress, not to one the user has moved past.
            didFail = false

            outcome = await authenticate()
            switch outcome {
            case .success:
                isLocked = false
            case .failure:
                didFail = true
            case .cancelled:
                break
            case .unavailable:
                isLocked = false
            }
            // Only ever opens the gate: an "attempt unlock" that closed it would be a bug, and
            // the caller is unreachable unless we are locked already.
        } while isRequestPending && isLocked

        return outcome
    }

    /// Errors that mean "no attempt happened", so the lock screen must not accuse the user of a
    /// failed one. `userCancel` is the user tapping "Abbrechen"; `notInteractive` is us asking
    /// while no prompt can be shown; the two `*Cancel`s are iOS pulling the sheet, typically
    /// because the app resigned active. `biometryLockout` is deliberately absent: under
    /// `.deviceOwnerAuthentication` iOS falls back to the passcode itself, so it never surfaces.
    private static let cancelCodes: Set<LAError.Code> = [
        .systemCancel, .appCancel, .userCancel, .notInteractive
    ]

    private static func systemAuthenticate() async -> AuthenticationOutcome {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return .unavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Entsperre Klar, um fortzufahren")
            )
            return success ? .success : .failure
        } catch let error as LAError where Self.cancelCodes.contains(error.code) {
            return .cancelled
        } catch {
            return .failure
        }
    }

    /// Whether the device can actually gate on Face ID / passcode — drives whether the
    /// onboarding privacy step (A1) offers to switch the lock on.
    static func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
}
