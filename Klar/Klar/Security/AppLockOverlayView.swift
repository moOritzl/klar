import SwiftUI

struct AppLockOverlayView: View {
    @Bindable var lockManager: AppLockManager

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Klar")
                    .font(.largeTitle.weight(.semibold))
                Button("Entsperren") {
                    Task { await lockManager.attemptUnlock() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            await lockManager.attemptUnlock()
        }
    }
}
