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
                .accessibilityLabel("Mit Face ID entsperren")

                Text(lockManager.didFail ? "Erneut versuchen" : "Mit Face ID entsperren")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
            .padding(.bottom, 70)
        }
        .task {
            await lockManager.attemptUnlock()
        }
        // `.task` fires once per view identity. When the app backgrounds while already locked,
        // the overlay never leaves the hierarchy, so without this the user comes back to a dead
        // wordmark screen and no prompt.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, lockManager.isLocked else { return }
            Task { await lockManager.attemptUnlock() }
        }
    }
}
