import SwiftUI
import SwiftData
import KlarCore

/// G4 · Ziele je Substanz.
///
/// Every change here *versions* the goal rather than overwriting it (see `KlarStore.setGoal`), so
/// a past month keeps the limit that was actually in force at the time. Editing a goal must never
/// retroactively rewrite whether the user met it.
struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var substances: [Substance]
    @Query private var goalPeriods: [GoalPeriod]

    @State private var isManagingSubstances = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ziele")
                        .font(Klar.TypeScale.title)
                        .foregroundStyle(Klar.text)
                        .padding(.bottom, 16)

                    VStack(spacing: 12) {
                        ForEach(activeSubstances) { substance in
                            GoalCard(substance: substance, store: store)
                        }
                    }

                    KlarDashedButton(title: "Substanzen verwalten", systemImage: "slider.horizontal.3") {
                        isManagingSubstances = true
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Klar.bgSubtle, for: .navigationBar)
        .sheet(isPresented: $isManagingSubstances) {
            SubstancesView()
        }
    }
}

struct GoalCard: View {
    let substance: Substance
    let store: KlarStore

    @State private var monthlyLimit: Int = 4

    private var goal: GoalPeriod? { store.currentGoal(for: substance) }
    private var isPaused: Bool { store.isGoalPaused(for: substance) }

    var body: some View {
        KlarCard(padding: 16) {
            HStack {
                Text(substance.name)
                    .font(Klar.TypeScale.headline)
                    .foregroundStyle(Klar.text)
                Spacer()
                statusBadge
            }
            .padding(.bottom, goal?.type == .reduction ? 12 : 6)

            switch (isPaused, goal?.type) {
            case (true, _):
                Text("Zieltyp wechseln oder fortsetzen.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)

            case (false, .reduction):
                KlarStepper(label: "Limit / Monat", value: $monthlyLimit, range: 1...30)
                    .onChange(of: monthlyLimit) { _, newValue in
                        store.setGoal(for: substance, type: .reduction, monthlyLimit: newValue)
                    }

            case (false, .abstinence):
                Text("Abstinenz. Einträge werden weiterhin ohne Wertung erfasst.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)

            default:
                Text("Kein Limit gesetzt.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }

            Divider()
                .overlay(Klar.borderSubtle)
                .padding(.vertical, 14)

            KlarSegmentedControl(
                options: [
                    (GoalType.reduction, "Reduktion"),
                    (GoalType.abstinence, "Abstinenz"),
                    (GoalType.observe, "Beobachten")
                ],
                selection: Binding(
                    get: { goal?.type ?? .observe },
                    set: { newType in
                        store.setGoal(
                            for: substance,
                            type: newType,
                            monthlyLimit: newType == .reduction ? monthlyLimit : nil
                        )
                    }
                )
            )

            if !isPaused, goal != nil {
                Button("Ziel pausieren") {
                    store.pauseGoal(for: substance)
                }
                .font(Klar.TypeScale.bodySmall.weight(.semibold))
                .foregroundStyle(Klar.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            }
        }
        .task {
            monthlyLimit = goal?.monthlyLimit ?? 4
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isPaused {
            Text("Pausiert")
                .font(Klar.TypeScale.caption)
                .foregroundStyle(Klar.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Klar.surfaceTint, in: Capsule())
        } else if let type = goal?.type {
            Text(type.germanLabel)
                .font(Klar.TypeScale.caption)
                .foregroundStyle(type == .reduction ? Klar.accentStrong : Klar.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(type == .reduction ? Klar.accentTint : Klar.surfaceTint, in: Capsule())
        }
    }
}

// MARK: - Substanzen verwalten

/// Reached from G4's "Substanzen verwalten" and from Settings ("Substanzen & Kosten").
/// The cost basis feeds the money-saved estimate the concept calls for (§ 4, Modul D).
struct SubstancesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var substances: [Substance]

    @State private var isAdding = false
    @State private var newName = ""
    @State private var newUnit: SubstanceUnit = .mg

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Klar.bgSubtle.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        KlarScreenHeader(title: "Substanzen & Kosten") { dismiss() }
                            .padding(.bottom, 6)

                        Text("Die Kostenbasis ist deine eigene Schätzung. Sie speist die „Geld gespart“-Rechnung.")
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textTertiary)
                            .padding(.bottom, 18)

                        VStack(spacing: 10) {
                            ForEach(activeSubstances) { substance in
                                SubstanceRow(substance: substance, store: store)
                            }
                        }

                        KlarDashedButton(title: "Substanz hinzufügen", tint: Klar.accentStrong) {
                            isAdding = true
                        }
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isAdding) {
            AddSubstanceSheet { name, unit in
                store.addSubstance(name: name, unit: unit)
            }
        }
    }
}

struct SubstanceRow: View {
    let substance: Substance
    let store: KlarStore

    @State private var costText = ""
    @State private var isConfirmingArchive = false

    var body: some View {
        KlarCard(padding: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Klar.substanceColor(substance.colorIndex))
                    .frame(width: 10, height: 10)
                Text(substance.name)
                    .font(Klar.TypeScale.headline)
                    .foregroundStyle(Klar.text)
                Spacer()
                Text(substance.unit.shortLabel)
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                Button {
                    isConfirmingArchive = true
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 13))
                        .foregroundStyle(Klar.textTertiary)
                }
                .accessibilityLabel("\(substance.name) archivieren")
            }
            .padding(.bottom, 12)

            HStack {
                Text("Kosten je \(substance.unit.shortLabel)")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textSecondary)
                Spacer()
                TextField("—", text: $costText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Klar.TypeScale.bodySmall)
                    .frame(width: 70)
                    .onChange(of: costText) { _, newValue in
                        let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                        substance.costPerUnit = normalized.isEmpty ? nil : Decimal(string: normalized)
                    }
                Text("€")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
        }
        .confirmationDialog(
            "„\(substance.name)“ archivieren?",
            isPresented: $isConfirmingArchive,
            titleVisibility: .visible
        ) {
            Button("Archivieren") { store.archiveSubstance(substance) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Bestehende Einträge bleiben erhalten. Die Substanz verschwindet nur aus der Auswahl.")
        }
        .task {
            costText = substance.costPerUnit?.klarFormatted ?? ""
        }
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
