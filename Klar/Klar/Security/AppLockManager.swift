import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLockManager {
    private(set) var isLocked: Bool = true

    /// Set when the app backgrounds with a non-zero auto-lock delay. On the next foregrounding
    /// we lock only if this moment has already passed — that's what makes "Nach 1 Minute"
    /// different from "Sofort".
    private var lockDeadline: Date?

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
    /// we were away.
    func cancelPendingLockIfStillWithinGrace() {
        defer { lockDeadline = nil }
        guard let lockDeadline else { return }
        if Date() >= lockDeadline {
            isLocked = true
        }
    }

    /// Used when the user has the Face ID lock switched off — the gate must not stand in the way.
    func unlockWithoutAuthentication() {
        isLocked = false
        lockDeadline = nil
    }

    @discardableResult
    func attemptUnlock(context: LAContext = LAContext()) async -> Bool {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics/passcode configured on this device: don't lock the user out
            // of their own app over a device-level setting they may not control.
            isLocked = false
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Entsperre Klar, um fortzufahren")
            )
            isLocked = !success
            return success
        } catch {
            isLocked = true
            return false
        }
    }

    /// Whether the device can actually gate on Face ID / passcode — drives whether the
    /// onboarding privacy step (A1) offers to switch the lock on.
    static func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
}
