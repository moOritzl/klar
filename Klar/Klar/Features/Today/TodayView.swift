import SwiftUI
import SwiftData
import KlarCore

/// B1–B3 + E1–E2 · Tab „Übersicht". It also carries what used to be the tab „Verlauf".
///
/// The hierarchy of the screen is the hierarchy of the message: the month's limits on top, then
/// the calendar, whose selected day — today unless another is tapped — lists its entries under the
/// grid. Open mornings are not on the page; they wait behind the bell („Mitteilungen"), whose
/// badge says when one is there. The month block exists only for reduction limits; without one the
/// screen starts at the calendar. How often, over time, is Muster's job (`FrequencyCard`).
struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var entries: [Entry]
    @Query private var morningAfters: [MorningAfter]

    @State private var isSettingsPresented = false
    @State private var limitSubstance: Substance?
    @State private var isNotificationsPresented = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    /// Re-read when the app comes forward, not on every render.
    ///
    /// The month header names the month of this moment, so it is refreshed when the app comes
    /// forward rather than read on every render.
    @State private var today = Date()
    private var quotaSubstances: [SubstanceQuota] {
        store.quotaSubstances()
    }
    private var openMorningDays: [String] { store.openMorningAfterDays() }

    var body: some View {
        NavigationStack {
            todayScroll
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .sheet(item: $limitSubstance) { LimitSheet(substance: $0) }
        .sheet(isPresented: $isNotificationsPresented) {
            NotificationCenterView()
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
                    // No new-month banner on the 1st. It repeated the limits printed directly under
                    // it, louder than the card itself; the bars standing full again say the same.
                    //
                    // The month is a header above the card, like every other section here, not an
                    // uppercase label inside it — and only when there is a limit to put under it.
                    if !quotaSubstances.isEmpty {
                        KlarGroupHeader(text: "\(KlarDate.monthName(today))")
                            .padding(.bottom, 10)
                    }

                    // One substance keeps the original large card; several share one combined
                    // card — every limit visible at a glance, tightest first.
                    if quotaSubstances.count == 1, let single = quotaSubstances.first {
                        Button {
                            limitSubstance = single.substance
                        } label: {
                            QuotaCard(
                                substance: single.substance,
                                quota: single.quota,
                                daysSinceLast: store.stats(for: single.substance).daysSinceLastOccasion,
                                month: today
                            )
                        }
                        .klarRowButtonStyle()
                        .accessibilityIdentifier("today.quota.\(single.substance.name)")
                        .padding(.bottom, 28)
                    } else if quotaSubstances.count > 1 {
                        MultiQuotaCard(quotas: quotaSubstances, onSelect: { limitSubstance = $0 })
                            .padding(.bottom, 28)
                    }

                    // E1–E2 · The calendar, with today selected: today's entries are listed under
                    // its grid, and nothing at all when there are none.
                    CalendarSectionView()
                }
                .padding(.horizontal, 16)
                .padding(.top, Klar.Space.x4)
                .padding(.bottom, Klar.Space.x6)
            }
            // Same two reasons as `KlarScreen`: the background belongs to the scroll view so the
            // content travels under the bar, and the default bounce stays so a quiet day can
            // still be dragged — that drag is what collapses the title.
            .background(Klar.bgSubtle)
            // Not „Heute". The screen leads with a *monthly* quota, and only the second block is
            // actually about today — so a title that promised one day forced the quota card to
            // correct it („Diesen Monat") just to be read right. A scope-neutral title lets both
            // blocks name their own timeframe, which is why Health's tab is „Übersicht" and not
            // „Heute" either.
            .navigationTitle("Übersicht")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mitteilungen", systemImage: "bell") {
                        isNotificationsPresented = true
                    }
                    // The system badge: red, with the count of open mornings, gone at zero.
                    .badge(openMorningDays.count)
                    .accessibilityIdentifier("today.notifications")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Einstellungen", systemImage: "gearshape") {
                        isSettingsPresented = true
                    }
                }
            }
        }
    }
}

// MARK: - Quota card

/// The headline is the month's real count, „2 von max. 4", so the one number people come for is
/// always on screen. The bar is the budget and drains rather than fills: filled segments are
/// what *remains*, and past the limit it simply stays empty. No switch in meaning, no red.
struct QuotaCard: View {
    let substance: Substance
    let quota: QuotaResult
    let daysSinceLast: Int?
    /// Only spoken: VoiceOver reads the card as one sentence, without the header above it.
    var month: Date = Date()

    var body: some View {
        // The month is the section header above the card (`TodayView`), and the substance needs
        // no colour dot: its name is right there.
        KlarCard {
            Text(substance.name)
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.text)
                .padding(.bottom, 4)

            QuotaCount(quota: quota)

            if let limit = quota.limit, let remaining = quota.remaining {
                KlarQuotaBar(limit: limit, remaining: remaining)
                    .padding(.top, 12)
            }

            if let subline {
                Text(subline)
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.top, 12)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(substance.name), \(QuotaCount.spokenText(for: quota)) im \(KlarDate.monthName(month))."
                + (subline.map { " \($0)" } ?? "")
        )
    }

    /// Only the one fact the count does not already carry. The goal type used to lead this line
    /// („Ziel: Reduktion"), but a card that shows a limit has already said that.
    private var subline: String? {
        guard let daysSinceLast else { return nil }
        return daysSinceLast == 1 ? "1 Tag seit dem letzten Eintrag" : "\(daysSinceLast) Tage seit dem letzten Eintrag"
    }
}

/// B1 with several limits: one calm card, one row per substance, tightest remaining on top.
/// Same drain-not-fill bar as the single card — just every budget visible at a glance.
///
/// Laid out like a grouped-list section: the month as a header above the card (`TodayView`),
/// then one separated row per substance. The count is the biggest thing in each row, because it
/// is the only thing on this screen anyone actually comes to read.
struct MultiQuotaCard: View {
    let quotas: [SubstanceQuota]
    var onSelect: (Substance) -> Void = { _ in }

    var body: some View {
        KlarCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(quotas.enumerated()), id: \.element.id) { index, pair in
                    if index > 0 {
                        KlarRowDivider(inset: 18)
                    }
                    Button {
                        onSelect(pair.substance)
                    } label: {
                        MultiQuotaRow(substance: pair.substance, quota: pair.quota)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                    }
                    .klarRowButtonStyle(cornerRadius: 0)
                    .accessibilityIdentifier("today.quota.\(pair.substance.name)")
                }
            }
        }
    }
}

/// Name on the left, count on the right, the bar underneath — the Settings row shape (title and
/// value on one line) rather than a label stacked over a number.
struct MultiQuotaRow: View {
    let substance: Substance
    let quota: QuotaResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(substance.name)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
                Spacer(minLength: 8)
                QuotaCount(quota: quota)
            }

            if let limit = quota.limit, let remaining = quota.remaining {
                KlarQuotaBar(limit: limit, remaining: remaining)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(substance.name), \(QuotaCount.spokenText(for: quota))")
    }
}

/// „**4** von max. 6" — the count carried by the numeral, the words kept small around it.
///
/// The numeral is always the month's real count (`QuotaReading`) and keeps counting past the
/// limit, so it never changes meaning. The weighting is the Health „**1.313** Schritte"
/// treatment: one number big enough to read without looking, its unit small enough to stay out
/// of the way.
struct QuotaCount: View {
    let quota: QuotaResult

    var body: some View {
        if let reading = Self.reading(for: quota) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(reading.count)")
                    .font(Klar.TypeScale.numeral)
                    .foregroundStyle(Klar.text)
                    .contentTransition(.numericText())
                Text("von max. \(reading.limit)")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textSecondary)
            }
            .animation(.snappy, value: reading)
        } else {
            Text("Nur beobachten")
                .font(Klar.TypeScale.headline)
                .foregroundStyle(Klar.text)
        }
    }

    static func reading(for quota: QuotaResult) -> QuotaReading? {
        guard let limit = quota.limit, let remaining = quota.remaining else { return nil }
        return QuotaReading(limit: limit, remaining: remaining)
    }

    /// VoiceOver reads the row as one sentence; the visual split into two `Text`s would
    /// otherwise come out as separate stops.
    static func spokenText(for quota: QuotaResult) -> String {
        reading(for: quota)?.text ?? "Nur beobachten"
    }
}

// MARK: - Entry row

/// One entry as a row inside the calendar card: the substance's dot (the same colour as its dot in
/// the grid above), name, amount and time, the first context tag. No card of its own — the rows
/// share the calendar's.
struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Klar.substanceColor(entry.substance?.colorIndex ?? 0))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.substance?.name ?? "Ohne Substanz")
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
                Text(detailLine)
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }

            Spacer()

            if let tag = entry.contextTags?.first {
                KlarChip(text: tag.name, compact: true)
            }

            KlarDisclosureChevron()
        }
        .contentShape(Rectangle())
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
