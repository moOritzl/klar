import Foundation
import LocalAuthentication
import Observation

@Observable
final class AppLockManager {
    private(set) var isLocked: Bool = true

    var requiresUnlock: Bool { isLocked }

    func lock() {
        isLocked = true
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
}
