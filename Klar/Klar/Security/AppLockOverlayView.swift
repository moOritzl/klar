import SwiftUI

/// J1 · Sperrbildschirm — a neutral screen. Wordmark only, nothing that hints at what the
/// app is for.
struct AppLockOverlayView: View {
    @Bindable var lockManager: AppLockManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            KlarWordmark()

            VStack(spacing: 12) {
                Spacer()
                Button {
                    Task { await lockManager.attemptUnlock() }
                } label: {
                    Image(systemName: "faceid")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Klar.textSecondary)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Circle().strokeBorder(Klar.borderStrong, lineWidth: 2)
                        }
                }
                // A tap during an in-flight evaluation is coalesced, not acted on, so the button
                // must not look live. Matches how A1 disables its own button while authenticating.
                .disabled(lockManager.isAuthenticating)
                .accessibilityLabel("Mit Face ID entsperren")

                Text(lockManager.didFail ? "Erneut versuchen" : "Mit Face ID entsperren")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
            .padding(.bottom, 70)
        }
        // Keyed on the scene phase, so this is both the initial trigger and the re-trigger on
        // every foregrounding — the overlay stays in the hierarchy while backgrounded, so a plain
        // `.task` would fire once and leave the user on a dead wordmark screen on the way back.
        //
        // The `.active` guard is what keeps us out of the default "Sofort" trap: backgrounding
        // locks immediately, mounting this view while the app is *not* active, and an evaluation
        // started there is either doomed to be cancelled or comes back `.notInteractive` — the
        // user's first sight of the lock screen would read "Erneut versuchen" for an attempt they
        // never made.
        .task(id: scenePhase) {
            guard scenePhase == .active, lockManager.isLocked else { return }
            await lockManager.attemptUnlock()
        }
    }
}
