import SwiftUI
import SwiftData

/// The limit behind a quota card on Übersicht — the same editor as on the substance page, one
/// tap from where the number is read.
struct LimitSheet: View {
    let substance: Substance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Unread: redraws `LimitEditor` when a goal is versioned.
    @Query private var goalPeriods: [GoalPeriod]

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            ScrollView {
                KlarCard(padding: 16) {
                    LimitEditor(substance: substance, store: store)
                }
                .padding(16)
            }
            .background(Klar.bgSubtle)
            .navigationTitle(substance.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
