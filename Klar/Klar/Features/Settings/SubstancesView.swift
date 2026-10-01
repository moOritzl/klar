import SwiftUI
import SwiftData
import KlarCore

/// Einstellungen › Substanzen. One row per active substance, each leading to its page — limit,
/// the morning-after switch, cost basis, archiving.
struct SubstancesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var substances: [Substance]
    /// Unread, like the calendar's entries query: it redraws the subtitles when a limit changes
    /// on a pushed page.
    @Query private var goalPeriods: [GoalPeriod]

    @State private var isAdding = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsGroup {
                        ForEach(Array(activeSubstances.enumerated()), id: \.element.id) { index, substance in
                            if index > 0 { KlarRowDivider() }
                            NavigationLink {
                                SubstanceSettingsView(substance: substance)
                            } label: {
                                row(substance)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.substance.\(substance.name)")
                        }
                    }

                    KlarDashedButton(title: "Substanz hinzufügen", tint: Klar.accentStrong) {
                        isAdding = true
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, Klar.Space.x2)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Klar.bgSubtle)
            .navigationTitle("Substanzen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            AddSubstanceSheet { name, unit in
                store.addSubstance(name: name, unit: unit)
            }
        }
    }

    private func row(_ substance: Substance) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Klar.substanceColor(substance.colorIndex))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(substance.name)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
                Text(Self.subtitle(for: substance, store: store))
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

    /// „max. 4 / Monat · Morgen danach" — the limit, then whether the card asks about this one.
    static func subtitle(for substance: Substance, store: KlarStore) -> String {
        var parts: [String] = []
        if store.isGoalPaused(for: substance) {
            parts.append("Pausiert")
        } else {
            let goal = store.currentGoal(for: substance)
            switch goal?.type {
            case .reduction: parts.append("max. \(goal?.monthlyLimit ?? 0) / Monat")
            case .abstinence: parts.append("Abstinenz")
            case .observe, nil: parts.append("Beobachten")
            }
        }
        if substance.asksMorningAfter { parts.append("Morgen danach") }
        return parts.joined(separator: " · ")
    }
}

struct AddSubstanceSheet: View {
    let onAdd: (String, SubstanceUnit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var unit: SubstanceUnit = .mg

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Einheit", selection: $unit) {
                    ForEach(SubstanceUnit.allCases, id: \.self) { unit in
                        Text(unit.shortLabel).tag(unit)
                    }
                }
            }
            .navigationTitle("Substanz hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed, unit)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
