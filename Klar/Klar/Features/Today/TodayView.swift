import SwiftUI
import SwiftData
import KlarCore

/// B1–B3 · Tab „Heute".
///
/// The hierarchy of the screen is the hierarchy of the message: goal and plan on top, what was
/// actually logged underneath. The screen's job is to keep the *intention* present, not the
/// consumption. Its best state is its quietest.
struct TodayView: View {
    @Binding var selectedTab: KlarTab

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var substances: [Substance]

    @State private var isEntrySheetPresented = false
    @State private var isSettingsPresented = false
    @State private var planBeingEdited: Plan?
    @State private var entryBeingEdited: Entry?

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var today: Date { Date() }
    private var todaysEntries: [Entry] { store.entries(onLogicalDayOf: today) }
    private var activePlan: Plan? { store.activePlans().first }
    private var quotaSubstance: Substance? { store.primaryQuotaSubstance() }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Klar.bgSubtle.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, 16)

                    // B3 · Only on the 1st. The quota resets, and the app says so out loud —
                    // "Jeder Monat beginnt bei null." Absolution, built into the calendar.
                    if KlarDate.isFirstOfMonth(today), let substance = quotaSubstance {
                        NewMonthCard(limit: store.quota(for: substance).limit ?? 0)
                            .padding(.bottom, 14)
                    }

                    if let substance = quotaSubstance {
                        QuotaCard(
                            substance: substance,
                            quota: store.quota(for: substance),
                            daysSinceLast: store.stats(for: substance).daysSinceLastOccasion
                        )
                        .padding(.bottom, 12)
                    }

                    if let activePlan {
                        PlanSummaryCard(plan: activePlan) {
                            planBeingEdited = activePlan
                        }
                        .padding(.bottom, 18)
                    } else if !substances.isEmpty {
                        // No plan yet: point at where one gets built, without nagging.
                        Button {
                            selectedTab = .plans
                        } label: {
                            KlarCard {
                                Text("Noch kein Plan.")
                                    .font(Klar.TypeScale.headline)
                                    .foregroundStyle(Klar.text)
                                    .padding(.bottom, 4)
                                Text("Ein Plan entsteht aus deinen Mustern — nicht am Tag 1.")
                                    .font(Klar.TypeScale.bodySmall)
                                    .foregroundStyle(Klar.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 18)
                    }

                    if todaysEntries.isEmpty {
                        // B2 · The empty day. No "Noch nichts geloggt!" — an entry-free day is
                        // the calm baseline, not a gap to be filled.
                        Text("Ein ruhiger Tag.")
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textTertiary)
                            .opacity(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        KlarSectionLabel(text: "Heute erfasst")
                            .accessibilityIdentifier("today.loggedSection")
                            .padding(.bottom, 10)

                        VStack(spacing: 10) {
                            ForEach(todaysEntries) { entry in
                                Button {
                                    entryBeingEdited = entry
                                } label: {
                                    EntryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100) // clear the FAB
            }
            .scrollIndicators(.hidden)

            addButton
                .padding(.trailing, 18)
                .padding(.bottom, 18)
        }
        .sheet(isPresented: $isEntrySheetPresented) {
            EntrySheetView()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .sheet(item: $planBeingEdited) { plan in
            PlanEditorView(existingPlan: plan)
        }
        .sheet(item: $entryBeingEdited) { entry in
            EntryDetailSheet(entry: entry)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("Heute")
                .font(Klar.TypeScale.title)
                .foregroundStyle(Klar.text)
            Spacer()
            Text(KlarDate.shortWeekdayDate(today))
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textTertiary)
            KlarIconButton(systemImage: "gearshape", accessibilityLabel: "Einstellungen") {
                isSettingsPresented = true
            }
        }
    }

    private var addButton: some View {
        Button {
            isEntrySheetPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Klar.accent, in: Circle())
                .klarShadow(Klar.Shadow.md)
        }
        .accessibilityLabel("Eintrag erfassen")
    }
}

// MARK: - Quota card

/// The design's core inversion: the headline counts what *remains*, and the bar drains rather
/// than fills. "Noch 2 von 4" is a budget, not a scorecard.
struct QuotaCard: View {
    let substance: Substance
    let quota: QuotaResult
    let daysSinceLast: Int?

    var body: some View {
        KlarCard {
            Text(headline)
                .font(Klar.TypeScale.headline)
                .foregroundStyle(Klar.text)

            if let limit = quota.limit, let remaining = quota.remaining {
                KlarQuotaBar(limit: limit, remaining: remaining)
                    .padding(.vertical, 12)
            } else {
                Spacer().frame(height: 12)
            }

            Text(subline)
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textTertiary)
        }
    }

    private var headline: String {
        guard let limit = quota.limit, let remaining = quota.remaining else {
            return "\(substance.name) · nur beobachten"
        }
        // Over the limit we state the fact and stop. No red, no exclamation, no appeal.
        if remaining <= 0 {
            return "\(quota.occasions) von \(limit) diesen Monat"
        }
        return "Noch \(remaining) von \(limit) diesen Monat"
    }

    private var subline: String {
        var parts: [String] = []
        parts.append("Ziel: \(quota.goalType?.germanLabel ?? "—")")
        if let daysSinceLast {
            parts.append(
                daysSinceLast == 1
                    ? "1 Tag seit dem letzten Eintrag"
                    : "\(daysSinceLast) Tage seit dem letzten Eintrag"
            )
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - New month card (B3)

struct NewMonthCard: View {
    let limit: Int

    var body: some View {
        KlarInverseCard {
            HStack(spacing: 10) {
                Image(systemName: "sunrise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Klar.accent)
                Text("Neuer Monat")
                    .font(Klar.TypeScale.headline)
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 8)

            Text("Kontingent: \(limit).")
                .font(Klar.TypeScale.display(24))
                .foregroundStyle(.white)
                .padding(.bottom, 6)

            Text("Jeder Monat beginnt bei null. Kein Rückblick auf den letzten, kein Vorwurf.")
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textOnInverseSecondary)
        }
    }
}

// MARK: - Plan card

struct PlanSummaryCard: View {
    let plan: Plan
    let onEdit: () -> Void

    var body: some View {
        KlarCard {
            HStack(alignment: .top, spacing: 10) {
                Text("WENN")
                    .font(Klar.TypeScale.caption.weight(.semibold))
                    .foregroundStyle(Klar.textTertiary)
                    .frame(width: 42, alignment: .leading)
                    .padding(.top, 2)
                Text(plan.situationText)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
            }
            .padding(.bottom, 6)

            HStack(alignment: .top, spacing: 10) {
                Text("DANN")
                    .font(Klar.TypeScale.caption.weight(.semibold))
                    .foregroundStyle(Klar.textTertiary)
                    .frame(width: 42, alignment: .leading)
                    .padding(.top, 2)
                Text(plan.actionText)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
            }
            .padding(.bottom, 14)

            HStack {
                Text("Vorgenommen am \(KlarDate.dayAndMonth(plan.committedAt))")
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                Spacer()
                KlarIconButton(
                    systemImage: "pencil",
                    size: 28,
                    accessibilityLabel: "Plan bearbeiten",
                    action: onEdit
                )
            }
        }
    }
}

// MARK: - Entry row

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        KlarCard(padding: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Klar.substanceColor(entry.substance?.colorIndex ?? 0))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.substance?.name ?? "Ohne Substanz")
                        .font(Klar.TypeScale.headline)
                        .foregroundStyle(Klar.text)
                    Text(detailLine)
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                }

                Spacer()

                if let tag = entry.contextTags?.first {
                    KlarChip(text: tag.name)
                }
            }
        }
    }

    private var detailLine: String {
        var parts: [String] = []
        if let amount = entry.amount, let unit = entry.substance?.unit {
            parts.append("\(amount.klarFormatted) \(unit.label(for: amount))")
        }
        parts.append(KlarDate.time(entry.timestamp))
        return parts.joined(separator: " · ")
    }
}

// MARK: - Goal label

extension GoalType {
    var germanLabel: String {
        switch self {
        case .reduction: "Reduktion"
        case .abstinence: "Abstinenz"
        case .observe: "Nur beobachten"
        }
    }
}
