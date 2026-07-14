import SwiftUI
import SwiftData

/// G5 · Ersatzhandlungen verwalten.
///
/// Same data source as the Craving-SOS (H2) — collected calmly in onboarding (A4), used in the
/// worst moment. Behavior Substitution only works if the alternatives are the user's own
/// (concept § 4, Modul E), so nothing here is prescribed.
struct SubstitutionActionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SubstitutionAction.sortOrder) private var actions: [SubstitutionAction]

    @State private var isAdding = false
    @State private var newText = ""

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Ersatzhandlungen")
                    .font(Klar.TypeScale.title)
                    .foregroundStyle(Klar.text)
                    .padding(.bottom, 4)

                Text("Erhoben im Onboarding, genutzt im Craving-SOS.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.bottom, 18)

                // A plain List, because reordering (the grip handle in the draft) is what
                // `.onMove` gives us for free — and order is meaningful: the first action is the
                // one the SOS screen leads with.
                List {
                    ForEach(actions) { action in
                        HStack(spacing: 12) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 15))
                                .foregroundStyle(Klar.textTertiary)
                            Text(action.text)
                                .font(Klar.TypeScale.body)
                                .foregroundStyle(Klar.text)
                        }
                        .listRowBackground(Klar.surface)
                    }
                    .onMove { source, destination in
                        store.moveSubstitutionActions(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteSubstitutionAction(actions[index])
                        }
                    }

                    Button {
                        isAdding = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Neue Alternative")
                                .font(Klar.TypeScale.body)
                        }
                        .foregroundStyle(Klar.accentStrong)
                    }
                    .listRowBackground(Klar.surface)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .padding(.top, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Alternative hinzufügen", isPresented: $isAdding) {
            TextField("z. B. Jonas anrufen", text: $newText)
            Button("Abbrechen", role: .cancel) { newText = "" }
            Button("Hinzufügen") {
                let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { store.addSubstitutionAction(text: text) }
                newText = ""
            }
        }
    }
}
