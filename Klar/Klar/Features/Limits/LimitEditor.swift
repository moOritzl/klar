import SwiftUI
import SwiftData
import KlarCore

/// One substance's limit: Reduktion with a monthly stepper, Abstinenz or Beobachten, and pausing.
/// No card of its own — the substance page in Einstellungen and the sheet behind a quota card on
/// Übersicht each put it in one.
///
/// Every change *versions* the goal rather than overwriting it (see `KlarStore.setGoal`), so a
/// past month keeps the limit that was actually in force at the time. The store is not
/// observable: the view hosting this must `@Query` the goal periods, or it will not redraw.
struct LimitEditor: View {
    let substance: Substance
    let store: KlarStore

    @State private var monthlyLimit: Int = 4

    private var goal: GoalPeriod? { store.currentGoal(for: substance) }
    private var isPaused: Bool { store.isGoalPaused(for: substance) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                KlarSectionLabel(text: "Grenze")
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
