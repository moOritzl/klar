import SwiftUI
import SwiftData
import KlarCore

/// F1–F3 · Flow „Weekly Review".
///
/// The one moment per week the app speaks unprompted. Three cards, under a minute, and it always
/// ends in a *decision by the user* — the app evaluates, the human decides. Without this feedback
/// layer, logging alone is behaviourally inert (concept § 2.1, Buu et al. 2020).
struct WeeklyReviewFlowView: View {
    var weekStart: Date = WeeklyReviewSummary.dueWeekStart()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var step = 0
    @State private var decision: ReviewPlanDecision = .keep
    @State private var isEditingPlan = false

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var summary: WeeklyReviewSummary {
        WeeklyReviewSummary.build(weekStart: weekStart, store: store)
    }

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                KlarProgressRail(count: 3, current: step)
                    .padding(.bottom, 20)

                switch step {
                case 0:
                    WhatHappenedStep(summary: summary) { step = 1 }
                case 1:
                    GoalAndPlanStep(summary: summary) { step = 2 }
                default:
                    LookAheadStep(
                        summary: summary,
                        decision: $decision,
                        onAdjust: { isEditingPlan = true },
                        onFinish: finish
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .sheet(isPresented: $isEditingPlan) {
            if let plan = store.activePlans().first {
                PlanEditorView(existingPlan: plan)
            }
        }
    }

    private func finish() {
        applyDecision()
        store.recordReviewDecision(weekStart: weekStart, decision: decision)
        settings.lastReviewedWeekStart = weekStart
        dismiss()
    }

    /// The decision isn't just recorded — "pausieren" actually pauses the plan. A review that
    /// changed nothing would be theatre.
    private func applyDecision() {
        guard decision == .pause else { return }
        for plan in store.activePlans() {
            store.setPlanStatus(plan, .paused)
        }
    }
}

// MARK: - F1 · Was war

struct WhatHappenedStep: View {
    let summary: WeeklyReviewSummary
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KlarSectionLabel(text: "\(KlarDate.weekRangeLong(summary.weekStart))")
                .padding(.bottom, 6)

            Text("Was war.")
                .font(Klar.TypeScale.display(26))
                .foregroundStyle(Klar.text)
                .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 12) {
                    statRow(label: "Einträge", value: "\(summary.entryCount)", isNumeral: true)

                    ForEach(summary.trends) { trend in
                        statRow(
                            label: "Ø Dosis \(trend.name)",
                            value: doseText(trend),
                            direction: trend.direction
                        )
                    }

                    if let gap = summary.lastGapDays {
                        statRow(
                            label: "Letzter Abstand",
                            value: gap == 1 ? "1 Tag" : "\(gap) Tage"
                        )
                    }

                    if summary.entryCount == 0 {
                        KlarCard(padding: 16) {
                            Text("Eine eintragsfreie Woche.")
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.textTertiary)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            KlarPrimaryButton(title: "Weiter", action: onContinue)
                .padding(.top, 12)
        }
    }

    private func doseText(_ trend: WeeklyReviewSummary.SubstanceTrend) -> String {
        guard let amount = trend.averageAmount else { return "—" }
        return "\(amount.klarFormatted) \(trend.unit.shortLabel)"
    }

    private func statRow(
        label: String,
        value: String,
        isNumeral: Bool = false,
        direction: WeeklyReviewSummary.SubstanceTrend.Direction? = nil
    ) -> some View {
        KlarCard(padding: 16) {
            HStack {
                Text(label)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Text(value)
                        .font(isNumeral ? Klar.TypeScale.numeral : Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                    if let direction {
                        // Down is drawn in emerald, but so is up — the color marks *movement*,
                        // not moral worth. No red anywhere in this app.
                        Text(direction.symbol)
                            .font(Klar.TypeScale.body)
                            .foregroundStyle(Klar.Palette.emerald700)
                    }
                }
            }
        }
    }
}

// MARK: - F2 · Ziel & Plan

struct GoalAndPlanStep: View {
    let summary: WeeklyReviewSummary
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ziel & Plan.")
                .font(Klar.TypeScale.display(26))
                .foregroundStyle(Klar.text)
                .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 12) {
                    if let limit = summary.quotaLimit, let remaining = summary.quotaRemaining {
                        KlarCard {
                            KlarSectionLabel(text: "Kontingent")
                                .padding(.bottom, 8)
                            Text(
                                remaining > 0
                                    ? "Noch \(remaining) von \(limit) diesen Monat"
                                    : "\(limit - remaining) von \(limit) diesen Monat"
                            )
                            .font(Klar.TypeScale.headline)
                            .foregroundStyle(Klar.text)
                            .padding(.bottom, 10)

                            KlarQuotaBar(limit: limit, remaining: remaining)
                        }
                    }

                    KlarCard {
                        KlarSectionLabel(text: "Plan-Bilanz der Woche")
                            .padding(.bottom, 12)

                        if summary.planTallies.isEmpty {
                            Text("Noch kein aktiver Plan. Die Bilanz erscheint, sobald einer läuft.")
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.textTertiary)
                        } else {
                            ForEach(summary.planTallies) { tally in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("„Wenn \(tally.situationText), dann \(tally.actionText).“")
                                        .font(Klar.TypeScale.bodySmall)
                                        .foregroundStyle(Klar.text)
                                    Spacer(minLength: 8)
                                    Text(tally.summary)
                                        .font(Klar.TypeScale.bodySmall.weight(.semibold))
                                        .foregroundStyle(
                                            tally.total > 0 ? Klar.Palette.emerald700 : Klar.textTertiary
                                        )
                                        .fixedSize()
                                }
                                .padding(.bottom, 8)
                            }
                        }

                        Text("Kein Vergleich, keine Norm. Nur, was dein Plan diese Woche getan hat.")
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textTertiary)
                            .padding(.top, 4)
                    }
                }
            }
            .scrollIndicators(.hidden)

            KlarPrimaryButton(title: "Weiter", action: onContinue)
                .padding(.top, 12)
        }
    }
}

// MARK: - F3 · Eine Frage nach vorn

struct LookAheadStep: View {
    let summary: WeeklyReviewSummary
    @Binding var decision: ReviewPlanDecision
    let onAdjust: () -> Void
    let onFinish: () -> Void

    private let options: [(value: ReviewPlanDecision, label: String, icon: String)] = [
        (.keep, "Plan behalten", "checkmark"),
        (.adjust, "Plan anpassen", "pencil"),
        (.pause, "Plan pausieren", "pause")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Eine Frage nach vorn.")
                .font(Klar.TypeScale.display(26))
                .foregroundStyle(Klar.text)
                .padding(.bottom, 8)

            Text("Dein Plan für nächste Woche.")
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textSecondary)
                .padding(.bottom, 24)

            VStack(spacing: 12) {
                ForEach(options, id: \.value) { option in
                    Button {
                        decision = option.value
                        if option.value == .adjust { onAdjust() }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    decision == option.value ? Klar.accentStrong : Klar.textSecondary
                                )
                            Text(option.label)
                                .font(Klar.TypeScale.body)
                                .foregroundStyle(Klar.text)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .background(decision == option.value ? Klar.accentTint : Klar.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous)
                                .strokeBorder(
                                    decision == option.value ? Klar.accent : Klar.border,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button(action: onFinish) {
                Text("Rückblick abschließen")
                    .font(.system(size: 16, weight: .semibold))
                    // The button is filled with `Klar.text`, which flips with the scheme, so its
                    // label has to be the page colour rather than a literal white.
                    .foregroundStyle(Klar.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Klar.text)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Archived review (read-only)

/// Opening a past week from the archive (E4) shows the same two descriptive cards, without the
/// forward-looking decision — that decision was made at the time and isn't up for revision.
struct ArchivedReviewView: View {
    let weekStart: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        let summary = WeeklyReviewSummary.build(weekStart: weekStart, store: store)

        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    KlarScreenHeader(title: KlarDate.weekRange(weekStart)) { dismiss() }
                        .padding(.bottom, 18)

                    VStack(spacing: 12) {
                        KlarCard(padding: 16) {
                            HStack {
                                Text("Einträge")
                                    .font(Klar.TypeScale.body)
                                    .foregroundStyle(Klar.textSecondary)
                                Spacer()
                                Text("\(summary.entryCount)")
                                    .font(Klar.TypeScale.numeral)
                                    .foregroundStyle(Klar.text)
                            }
                        }

                        ForEach(summary.trends) { trend in
                            KlarCard(padding: 16) {
                                HStack {
                                    Text("Ø Dosis \(trend.name)")
                                        .font(Klar.TypeScale.body)
                                        .foregroundStyle(Klar.textSecondary)
                                    Spacer()
                                    Text(
                                        trend.averageAmount.map {
                                            "\($0.klarFormatted) \(trend.unit.shortLabel)"
                                        } ?? "—"
                                    )
                                    .font(Klar.TypeScale.body)
                                    .foregroundStyle(Klar.text)
                                }
                            }
                        }

                        if !summary.planTallies.isEmpty {
                            KlarCard {
                                KlarSectionLabel(text: "Plan-Bilanz der Woche")
                                    .padding(.bottom, 12)
                                ForEach(summary.planTallies) { tally in
                                    HStack(alignment: .top) {
                                        Text("„Wenn \(tally.situationText), dann \(tally.actionText).“")
                                            .font(Klar.TypeScale.bodySmall)
                                            .foregroundStyle(Klar.text)
                                        Spacer(minLength: 8)
                                        Text(tally.summary)
                                            .font(Klar.TypeScale.bodySmall.weight(.semibold))
                                            .foregroundStyle(Klar.Palette.emerald700)
                                            .fixedSize()
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }
}
