import SwiftUI
import SwiftData
import Charts
import KlarCore

/// E3 · Trends je Substanz.
///
/// The context distribution is the bridge into Modul C: once "70 % deiner MDMA-Einträge tragen
/// den Tag ‚Club'" is on screen, the plan practically writes itself — so the card ends by
/// offering to build exactly that plan.
struct TrendsSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var substances: [Substance]
    @Query private var entries: [Entry]

    @State private var selectedSubstanceID: UUID?
    @State private var planTagSeed: ContextTag?

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var selectedSubstance: Substance? {
        activeSubstances.first { $0.id == selectedSubstanceID } ?? activeSubstances.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if activeSubstances.isEmpty {
                    emptyState
                } else {
                    substanceFilter
                        .padding(.bottom, 16)

                    if let substance = selectedSubstance {
                        let summary = store.stats(for: substance)

                        DoseTrendCard(substance: substance, summary: summary)
                            .padding(.bottom, 12)

                        ContextDistributionCard(
                            substance: substance,
                            summary: summary,
                            tags: store.allContextTags()
                        ) { tag in
                            planTagSeed = tag
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $planTagSeed) { tag in
            PlanEditorView(existingPlan: nil, prefilledSituationTag: tag)
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

// MARK: - Ø Dosis über Zeit

struct DoseTrendCard: View {
    let substance: Substance
    let summary: StatsSummary

    /// The last 8 weeks that actually have occasions — an empty stretch shouldn't stretch the axis.
    private var points: [WeeklyAverage] {
        Array(summary.weeklyAverages.suffix(8))
    }

    private var thisWeek: WeeklyAverage? { points.last }

    private var previousWeek: WeeklyAverage? {
        points.count >= 2 ? points[points.count - 2] : nil
    }

    var body: some View {
        KlarCard {
            KlarSectionLabel(text: "Ø Dosis über Zeit")
                .padding(.bottom, 12)

            if points.count < 2 {
                Text("Zu wenig Einträge für einen Verlauf. Ab zwei Wochen mit Einträgen zeigt sich hier eine Linie.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.bottom, 12)
            } else {
                chart
                    .frame(height: 88)
                    .padding(.bottom, 14)
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diese Woche")
                        .font(Klar.TypeScale.caption)
                        .foregroundStyle(Klar.textTertiary)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(thisWeek?.averageAmount?.klarFormatted ?? "—")
                            .font(Klar.TypeScale.numeral)
                            .foregroundStyle(Klar.text)
                        if thisWeek?.averageAmount != nil {
                            Text(substance.unit.shortLabel)
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.text)
                        }
                    }

                    if let delta = deltaText {
                        Text(delta)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.Palette.emerald700)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ø Abstand")
                        .font(Klar.TypeScale.caption)
                        .foregroundStyle(Klar.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(averageGapText)
                            .font(Klar.TypeScale.numeral)
                            .foregroundStyle(Klar.text)
                        if summary.averageGapDays != nil {
                            Text("Tage")
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.text)
                        }
                    }
                }

                Spacer()
            }
        }
    }

    private var chart: some View {
        Chart(points, id: \.weekStart) { point in
            LineMark(
                x: .value("Woche", point.weekStart),
                y: .value("Ø Dosis", doubleValue(point.averageAmount))
            )
            .foregroundStyle(Klar.Palette.teal600)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)

            if point.weekStart == points.last?.weekStart {
                PointMark(
                    x: .value("Woche", point.weekStart),
                    y: .value("Ø Dosis", doubleValue(point.averageAmount))
                )
                .foregroundStyle(Klar.Palette.teal600)
                .symbolSize(60)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func doubleValue(_ decimal: Decimal?) -> Double {
        (decimal as NSDecimalNumber?)?.doubleValue ?? 0
    }

    /// "↓ von 95 mg" — the user's own previous week, never a norm.
    private var deltaText: String? {
        guard let current = thisWeek?.averageAmount,
              let previous = previousWeek?.averageAmount,
              current != previous
        else { return nil }
        let arrow = current < previous ? "↓" : "↑"
        return "\(arrow) von \(previous.klarFormatted) \(substance.unit.shortLabel)"
    }

    private var averageGapText: String {
        guard let gap = summary.averageGapDays else { return "—" }
        return String(format: "%.0f", gap)
    }
}

// MARK: - Kontextverteilung

struct ContextDistributionCard: View {
    let substance: Substance
    let summary: StatsSummary
    let tags: [ContextTag]
    let onBuildPlan: (ContextTag) -> Void

    private var distribution: [(tag: ContextTag, count: Int, share: Double)] {
        let total = summary.contextTagDistribution.values.reduce(0, +)
        guard total > 0 else { return [] }
        return summary.contextTagDistribution
            .compactMap { tagID, count -> (ContextTag, Int, Double)? in
                guard let tag = tags.first(where: { $0.id == tagID }) else { return nil }
                return (tag, count, Double(count) / Double(total))
            }
            .sorted { $0.2 > $1.2 }
    }

    private var dominant: (tag: ContextTag, count: Int, share: Double)? {
        // Only surface a plan suggestion once one context clearly dominates.
        distribution.first.flatMap { $0.share >= 0.5 ? $0 : nil }
    }

    private let barColors: [Color] = [
        Klar.Palette.cyan600,
        Klar.Palette.teal400,
        Klar.Palette.teal300,
        Klar.Palette.emerald600
    ]

    var body: some View {
        KlarCard {
            KlarSectionLabel(text: "Kontextverteilung")
                .padding(.bottom, 14)

            if distribution.isEmpty {
                Text("Noch keine Kontext-Tags erfasst. Sie sind optional und der Rohstoff für deine Pläne.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            } else {
                ForEach(Array(distribution.enumerated()), id: \.element.tag.id) { index, item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.tag.name)
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.text)
                            Spacer()
                            Text("\(Int((item.share * 100).rounded())) %")
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.textTertiary)
                        }
                        KlarShareBar(
                            fraction: item.share,
                            color: barColors[index % barColors.count]
                        )
                    }
                    .padding(.bottom, index == distribution.count - 1 ? 0 : 12)
                }

                if let dominant {
                    Divider()
                        .overlay(Klar.borderSubtle)
                        .padding(.top, 14)

                    Button {
                        onBuildPlan(dominant.tag)
                    } label: {
                        Text("\(Int((dominant.share * 100).rounded())) % deiner \(substance.name)-Einträge tragen den Tag „\(dominant.tag.name)“. Plan dafür bauen?")
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - E4 · Weekly-Review-Archiv

struct ReviewArchiveSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [Entry]

    @State private var selectedWeek: IdentifiableWeek?

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var weeks: [Date] {
        WeeklyReviewSummary.archivedWeekStarts(store: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Dein Archiv.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.bottom, 18)

                if weeks.isEmpty {
                    Text("Noch keine abgeschlossene Woche. Der erste Rückblick kommt, sobald eine Woche mit Einträgen vorbei ist.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(weeks, id: \.self) { weekStart in
                            let summary = WeeklyReviewSummary.build(weekStart: weekStart, store: store)
                            Button {
                                selectedWeek = IdentifiableWeek(weekStart: weekStart)
                            } label: {
                                KlarCard(padding: 16) {
                                    HStack {
                                        Text(KlarDate.weekRange(weekStart))
                                            .font(Klar.TypeScale.headline)
                                            .foregroundStyle(Klar.text)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Klar.textTertiary)
                                    }
                                    .padding(.bottom, 6)

                                    Text(summary.archiveSubtitle)
                                        .font(Klar.TypeScale.bodySmall)
                                        .foregroundStyle(Klar.textTertiary)
                                }
                            }
                            .klarRowButtonStyle()
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selectedWeek) { week in
            ArchivedReviewView(weekStart: week.weekStart)
        }
    }
}

struct IdentifiableWeek: Identifiable {
    let weekStart: Date
    var id: TimeInterval { weekStart.timeIntervalSince1970 }
}
