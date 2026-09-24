import SwiftUI
import SwiftData
import KlarCore

/// Tab „Grenzen". The limits each substance runs under, the switch that decides whether
/// „Der Morgen danach" asks about it (added with the card), and the way to the substitutions
/// the Craving-SOS offers.
struct LimitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var substances: [Substance]
    @Query private var goalPeriods: [GoalPeriod]

    @State private var isManagingSubstances = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            KlarScreen(title: "Grenzen") {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 12) {
                        ForEach(activeSubstances) { substance in
                            GoalCard(substance: substance, store: store)
                        }
                    }

                    KlarDashedButton(title: "Substanzen verwalten", systemImage: "slider.horizontal.3") {
                        isManagingSubstances = true
                    }
                    .padding(.top, 12)

                    KlarCard(padding: 0) {
                        NavigationLink {
                            SubstitutionActionsView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Klar.textSecondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Ersatzhandlungen")
                                        .font(Klar.TypeScale.body)
                                        .foregroundStyle(Klar.text)
                                    Text("Genutzt im Craving-SOS")
                                        .font(Klar.TypeScale.caption)
                                        .foregroundStyle(Klar.textTertiary)
                                }
                                Spacer()
                                KlarDisclosureChevron()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .klarRowButtonStyle()
                        .accessibilityIdentifier("limits.substitutionsLink")
                    }
                    .padding(.top, 24)
                }
            }
            .sheet(isPresented: $isManagingSubstances) {
                SubstancesView()
            }
        }
    }
}
