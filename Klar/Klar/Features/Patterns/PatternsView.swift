import SwiftUI
import SwiftData
import KlarCore

/// Tab „Muster". Per substance: how often, what the day after was like, where it happens, how
/// much, and the user's own words — in that order. The only reference point is the user's own
/// history (P4, P7).
struct PatternsView: View {
    /// Shared with `MainTabView`, so a row on Übersicht can open this tab on its substance.
    @Binding var selectedSubstanceID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query private var substances: [Substance]
    // Unread, like the calendar's: they redraw the cards when an entry or an answer lands.
    @Query private var entries: [Entry]
    @Query private var morningAfters: [MorningAfter]

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var selectedSubstance: Substance? {
        activeSubstances.first { $0.id == selectedSubstanceID } ?? activeSubstances.first
    }

    var body: some View {
        NavigationStack {
            KlarScreen(title: "Muster") {
                VStack(alignment: .leading, spacing: 0) {
                    if activeSubstances.isEmpty {
                        emptyState
                    } else {
                        substanceFilter
                            .padding(.bottom, 16)

                        if let substance = selectedSubstance {
                            cards(for: substance)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cards(for substance: Substance) -> some View {
        let summary = store.stats(for: substance)
        let reflections = store.reflections(for: substance)
        VStack(spacing: 12) {
            FrequencyCard(summary: summary)
            if substance.asksMorningAfter {
                MorningDistributionCard(
                    distribution: store.morningDistribution(for: substance),
                    shared: store.sharedMorningDays(for: substance).map { (name: $0.substance.name, days: $0.days) }
                )
            }
            ContextDistributionCard(
                substance: substance,
                summary: summary,
                tags: store.allContextTags(),
                morningPatterns: store.morningPatternsByContext(for: substance)
            )
            DoseTrendCard(substance: substance, summary: summary)
            if !reflections.isEmpty {
                ReflectionsCard(records: reflections)
            }
        }
    }

    private var substanceFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(activeSubstances) { substance in
                    Button {
                        selectedSubstanceID = substance.id
                    } label: {
                        KlarOutlineChip(
                            text: substance.name,
                            isSelected: selectedSubstance?.id == substance.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("patterns.substance.\(substance.name)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        Text("Noch keine Substanzen. Sobald du etwas erfasst, entstehen hier Muster.")
            .font(Klar.TypeScale.bodySmall)
            .foregroundStyle(Klar.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 40)
    }
}
