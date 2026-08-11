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
    @Environment(\.scenePhase) private var scenePhase
    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var substances: [Substance]

    @State private var isSettingsPresented = false
    @State private var planBeingEdited: Plan?
    @State private var entryBeingEdited: Entry?

    private var store: KlarStore { KlarStore(context: modelContext) }

    /// Re-read when the app comes forward, not on every render.
    ///
    /// The header now states which logical day it is listing, and „bis 5 Uhr" is a claim that stops
    /// being true at 05:00. A computed `Date()` would be correct but only by accident — it updates
    /// whenever something else happens to invalidate the view. Refreshing on `.active` covers the
    /// case that actually occurs (phone put down at 04:50, picked up at 07:00); an app left open
    /// across the boundary keeps the value it had, and no timer runs to prevent that.
    @State private var today = Date()
    /// Newest first — the opposite of `entries(onLogicalDay:)`, which the day detail keeps.
    ///
    /// The two lists answer different questions. The day detail is a record read end to end, so
    /// it runs forwards: morning coffee, the cigarette at work, the drinks that evening. This
    /// list is the thing you just tapped, checked against what the app now shows, so the entry
    /// you are looking for is the last one made — and on a heavy day it would otherwise be the
    /// one furthest down.
    private var todaysEntries: [Entry] {
        store.entries(onLogicalDayOf: today).sorted { $0.timestamp > $1.timestamp }
    }
    private var activePlan: Plan? { store.activePlans().first }
    private var quotaSubstances: [SubstanceQuota] {
        store.quotaSubstances()
    }

    var body: some View {
        NavigationStack {
            todayScroll
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            today = Date()
        }
    }

    private var todayScroll: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // B3 · Only on the 1st. The quota resets, and the card says so — the number
                    // and nothing else.
                    if KlarDate.isFirstOfMonth(today), !quotaSubstances.isEmpty {
                        NewMonthCard(
                            quotas: quotaSubstances.map { (name: $0.substance.name, limit: $0.quota.limit ?? 0) }
                        )
                        .padding(.bottom, 14)
                    }

                    // One substance keeps the original large card; several share one combined
                    // card — every limit visible at a glance, tightest first.
                    if quotaSubstances.count == 1, let single = quotaSubstances.first {
                        QuotaCard(
                            substance: single.substance,
                            quota: single.quota,
                            daysSinceLast: store.stats(for: single.substance).daysSinceLastOccasion,
                            month: today
                        )
                        .padding(.bottom, 12)
                    } else if quotaSubstances.count > 1 {
                        MultiQuotaCard(quotas: quotaSubstances, month: today)
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
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Noch kein Plan.")
                                            .font(Klar.TypeScale.headline)
                                            .foregroundStyle(Klar.text)
                                        Text("Ein Plan entsteht aus deinen Mustern.")
                                            .font(Klar.TypeScale.bodySmall)
                                            .foregroundStyle(Klar.textTertiary)
                                    }
                                    Spacer(minLength: 0)
                                    KlarDisclosureChevron()
                                        .padding(.top, 3)
                                }
                            }
                        }
                        .klarRowButtonStyle()
                        .padding(.bottom, 18)
                    }

                    if todaysEntries.isEmpty {
                        // B2 · The empty day. No "Noch nichts geloggt!" — an entry-free day is
                        // the calm baseline, not a gap to be filled.
                        VStack(spacing: 6) {
                            Text("Ein ruhiger Tag.")
                            // There is no entry list to label here, so the date would be
                            // decoration — except between midnight and 05:00, where it changes
                            // what the next tap will do. Same rule as everywhere else: the hint
                            // appears only where the shown day contradicts the phone.
                            if KlarDate.isBeforeCutoff(today) {
                                Text(dayLabel)
                            }
                        }
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                        .opacity(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        KlarGroupHeader(text: "Heute erfasst") {
                            Text(dayLabel)
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.textTertiary)
                        }
                        .accessibilityIdentifier("today.loggedSection")
                        .padding(.bottom, 10)

                        VStack(spacing: 10) {
                            ForEach(todaysEntries) { entry in
                                Button {
                                    entryBeingEdited = entry
                                } label: {
                                    EntryRow(entry: entry)
                                }
                                .klarRowButtonStyle()
                                // The only way to delete an entry used to be to open it first.
                                // A long press is where iOS puts this, and it keeps the
                                // destructive action one deliberate step away from a tap.
                                .contextMenu {
                                    Button {
                                        entryBeingEdited = entry
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        store.deleteEntry(entry)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, Klar.Space.x4)
                // No longer 100pt to clear a floating button. The bottom accessory takes part in
                // the safe area, so iOS insets the scroll content for it and the last entry is
                // reachable without a hand-tuned gap.
                .padding(.bottom, Klar.Space.x6)
            }
            // Same two reasons as `KlarScreen`: the background belongs to the scroll view so the
            // content travels under the bar, and the default bounce stays so a quiet day can
            // still be dragged — that drag is what collapses the title.
            .background(Klar.bgSubtle)
            // Not „Heute". The screen leads with a *monthly* quota and carries a standing plan
            // underneath it, and only the third block is actually about today — so a title that
            // promised one day forced the quota card to correct it („Diesen Monat") just to be
            // read right. A scope-neutral title lets the three blocks name their own timeframe,
            // which is why Health's tab is „Übersicht" and not „Heute" either.
            .navigationTitle("Übersicht")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
        }
    }

    // MARK: - Pieces

    /// The logical day, not the wall clock: between midnight and 05:00 those disagree, and this
    /// line labels the entries listed under it, so it has to follow them. The „bis 5 Uhr" hint
    /// appears only inside that window, because only there does the date contradict the phone.
    ///
    /// It sits on the „Heute erfasst" header rather than on the screen, because that is what it
    /// labels — the screen also carries a monthly quota and a standing plan, and neither of those
    /// is dated today.
    private var dayLabel: String {
        let day = KlarDate.logicalDayLabel(now: today)
        return KlarDate.isBeforeCutoff(today) ? "\(day) · bis 5 Uhr" : day
    }

}

// MARK: - Quota card

/// The design's core inversion: the headline counts what *remains*, and the bar drains rather
/// than fills. "Noch 2 von 4" is a budget, not a scorecard.
struct QuotaCard: View {
    let substance: Substance
    let quota: QuotaResult
    let daysSinceLast: Int?
    /// Named, not "diesen Monat". A month name is unmistakably a month, so the card no longer
    /// has to talk its way out of the screen title it sits under.
    var month: Date = Date()

    var body: some View {
        KlarCard {
            HStack(spacing: 8) {
                Circle()
                    .fill(Klar.substanceColor(substance.colorIndex))
                    .frame(width: 8, height: 8)
                Text(substance.name)
                    .font(Klar.TypeScale.bodySmall.weight(.semibold))
                    .foregroundStyle(Klar.textSecondary)
            }
            .padding(.bottom, 8)

            QuotaCount(quota: quota)

            if let limit = quota.limit, let remaining = quota.remaining {
                KlarQuotaBar(limit: limit, remaining: remaining)
                    .padding(.vertical, 12)
            } else {
                Spacer().frame(height: 12)
            }

            Text(subline)
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textTertiary)
        } header: {
            KlarSectionLabel(text: "\(KlarDate.monthName(month))")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(substance.name), \(QuotaCount.spokenText(for: quota)) im \(KlarDate.monthName(month)). \(subline)")
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

/// B1 with several limits: one calm card, one row per substance, tightest remaining on top.
/// Same drain-not-fill bar as the single card — just every budget visible at a glance.
///
/// Laid out like a grouped-list section rather than a box of stacked text: a label row, a
/// hairline across the full card, then one separated row per substance. The count is the
/// biggest thing in each row, because it is the only thing on this screen anyone actually
/// comes to read.
struct MultiQuotaCard: View {
    let quotas: [SubstanceQuota]
    var month: Date = Date()

    var body: some View {
        KlarCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(quotas.enumerated()), id: \.element.id) { index, pair in
                    if index > 0 {
                        KlarRowDivider(inset: 18)
                    }
                    MultiQuotaRow(substance: pair.substance, quota: pair.quota)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                }
            }
        } header: {
            KlarSectionLabel(text: "\(KlarDate.monthName(month))")
        }
    }
}

struct MultiQuotaRow: View {
    let substance: Substance
    let quota: QuotaResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Klar.substanceColor(substance.colorIndex))
                    .frame(width: 8, height: 8)
                Text(substance.name)
                    .font(Klar.TypeScale.bodySmall.weight(.semibold))
                    .foregroundStyle(Klar.textSecondary)
            }

            QuotaCount(quota: quota)

            if let limit = quota.limit, let remaining = quota.remaining {
                KlarQuotaBar(limit: limit, remaining: remaining)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(substance.name), \(QuotaCount.spokenText(for: quota))")
    }
}

/// „Noch **4** von 6" — the count carried by the numeral, the words kept small around it.
///
/// The wording is unchanged and still comes from the same two rules: over the limit it drops
/// the „Noch" and states the plain fact, and there is no red and no exclamation anywhere in it.
/// Only the weighting is new, and it is the Health „**1.313** Schritte" treatment: one number
/// big enough to read without looking, its unit small enough to stay out of the way.
struct QuotaCount: View {
    let quota: QuotaResult

    var body: some View {
        if let limit = quota.limit, let remaining = quota.remaining {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if remaining > 0 {
                    Text("Noch")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textSecondary)
                }
                Text("\(remaining > 0 ? remaining : quota.occasions)")
                    .font(Klar.TypeScale.numeral)
                    .foregroundStyle(Klar.text)
                    .contentTransition(.numericText())
                Text("von \(limit)")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textSecondary)
            }
            .animation(.snappy, value: remaining)
        } else {
            Text("Nur beobachten")
                .font(Klar.TypeScale.headline)
                .foregroundStyle(Klar.text)
        }
    }

    /// VoiceOver reads the row as one sentence; the visual split into three `Text`s would
    /// otherwise come out as three separate stops.
    static func spokenText(for quota: QuotaResult) -> String {
        guard let limit = quota.limit, let remaining = quota.remaining else {
            return "Nur beobachten"
        }
        if remaining <= 0 {
            return "\(quota.occasions) von \(limit)"
        }
        return "Noch \(remaining) von \(limit)"
    }
}

// MARK: - New month card (B3)

struct NewMonthCard: View {
    let quotas: [(name: String, limit: Int)]

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

            Text(quotaLine)
                .font(Klar.TypeScale.display(24))
                .foregroundStyle(.white)
        }
    }

    private var quotaLine: String {
        if quotas.count == 1, let single = quotas.first {
            return "Kontingent: \(single.limit)."
        }
        return "Kontingente: " + quotas.map { "\($0.name) \($0.limit)" }.joined(separator: " · ") + "."
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

                KlarDisclosureChevron()
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
