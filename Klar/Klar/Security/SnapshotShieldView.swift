import SwiftUI

struct SnapshotShieldView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Text("Klar")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    SnapshotShieldView()
}
