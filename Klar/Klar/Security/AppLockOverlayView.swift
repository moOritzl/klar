import SwiftUI

/// J1 · Sperrbildschirm — a neutral screen. Wordmark only, nothing that hints at what the
/// app is for.
struct AppLockOverlayView: View {
    @Bindable var lockManager: AppLockManager
    @State private var didFail = false

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            KlarWordmark()

            VStack(spacing: 12) {
                Spacer()
                Button {
                    Task { await unlock() }
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

                Text(didFail ? "Erneut versuchen" : "Mit Face ID entsperren")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
            .padding(.bottom, 70)
        }
        .task {
            await unlock()
        }
    }

    private func unlock() async {
        let success = await lockManager.attemptUnlock()
        didFail = !success
    }
}
