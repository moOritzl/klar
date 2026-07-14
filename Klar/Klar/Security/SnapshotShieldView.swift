import SwiftUI

/// What iOS captures for the app switcher. Never app content — see J1.
struct SnapshotShieldView: View {
    var body: some View {
        ZStack {
            Klar.bgInverseDeep.ignoresSafeArea()
            KlarWordmark()
        }
    }
}

/// The wordmark, letter-spaced as in the design (`letter-spacing: 0.4em`).
struct KlarWordmark: View {
    var size: CGFloat = 60

    var body: some View {
        Text("KLAR")
            .font(Klar.TypeScale.display(size))
            .tracking(size * 0.4)
            .foregroundStyle(.white)
            // `tracking` adds trailing space after the final letter; nudge back to re-center.
            .padding(.leading, size * 0.4)
    }
}

#Preview {
    SnapshotShieldView()
}
