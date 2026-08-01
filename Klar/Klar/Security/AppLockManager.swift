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
    func attemptUnlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        switch await authenticate() {
        case .success:
            isLocked = false
            didFail = false
        case .failure:
            isLocked = true
            didFail = true
        case .cancelled:
            isLocked = true
        case .unavailable:
            isLocked = false
            didFail = false
        }
    }

    private static func systemAuthenticate() async -> AuthenticationOutcome {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Entsperre Klar, um fortzufahren")
            )
            return success ? .success : .failure
        } catch let error as LAError where error.code == .systemCancel || error.code == .appCancel {
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
