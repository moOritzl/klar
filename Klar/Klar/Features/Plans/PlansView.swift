import SwiftUI
import SwiftData
import KlarCore

/// G1/G2 · Tab „Pläne".
///
/// The workshop, not the trophy shelf. Max. 3 active plans — focus beats list. Goals live here
/// rather than in Settings, because a goal is a decision, not a configuration value.
///
/// Addition to the draft: the draft ships G4 (Ziele) and G5 (Ersatzhandlungen) as standalone
/// screens without drawing an entry point. They're linked from the bottom of this screen, which
/// is also where the concept text says goals belong.
struct PlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [Plan]
    @Query private var entries: [Entry]
    @Query private var substances: [Substance]

    @State private var editorSeed: PlanEditorSeed?

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activePlans: [Plan] { store.activePlans() }
    private var canAddPlan: Bool { activePlans.count < PlanService.maxActivePlans }

    var body: some View {
        NavigationStack {
            KlarScreen(title: "Pläne", subtitle: subtitle) {
                VStack(alignment: .leading, spacing: 0) {
                    if activePlans.isEmpty {
                        emptyState
                    } else {
                        filledState
                    }

                    navigationRows
                        .padding(.top, 24)
                }
            }
            .sheet(item: $editorSeed) { seed in
                PlanEditorView(
                    existingPlan: seed.plan,
                    prefilledSituationTag: seed.tag
                )
            }
        }
    }

    private var subtitle: LocalizedStringKey {
        activePlans.isEmpty
            ? "Noch kein Plan."
            : "Max. 3 aktive Pläne."
    }

    // MARK: - G1 · Pläne (aktiv)

    @ViewBuilder
    private var filledState: some View {
        if let goalLine {
            KlarCard(padding: 16) {
                KlarSectionLabel(text: "Ziel")
                    .padding(.bottom, 6)
                Text(goalLine)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
            }
            .padding(.bottom, 14)
        }

        VStack(spacing: 12) {
            ForEach(activePlans) { plan in
                let tally = store.checkInTally(for: plan)
                Button {
                    editorSeed = PlanEditorSeed(plan: plan, tag: nil)
                } label: {
                    KlarCard(padding: 16) {
                        HStack {
                            KlarChip(text: plan.situationTag?.name ?? "Situation", compact: true)
                            Spacer()
                            Text(tallyText(tally))
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(
                                    tally.helped == tally.total && tally.total > 0
                                        ? Klar.Palette.emerald700
                                        : Klar.textTertiary
                                )
                        }
                        .padding(.bottom, 8)

                        Text("Wenn \(PlanSentence.fragment(plan.situationText)), dann \(PlanSentence.fragment(plan.actionText))")
                            .font(Klar.TypeScale.body)
                            .foregroundStyle(Klar.text)
                            .multilineTextAlignment(.leading)
                    }
                }
                .klarRowButtonStyle()
            }
        }

        if canAddPlan {
            KlarDashedButton(title: "Neuer Plan", tint: Klar.accentStrong) {
                editorSeed = PlanEditorSeed(plan: nil, tag: nil)
            }
            .padding(.top, 12)
        }
    }

    private func tallyText(_ tally: (helped: Int, total: Int)) -> String {
        tally.total == 0 ? "Noch kein Check-in" : "\(tally.helped)/\(tally.total) geholfen"
    }

    /// "Reduktion · max. 4× / Monat, Alkohol"
    private var goalLine: String? {
        guard let substance = store.primaryQuotaSubstance() else { return nil }
        let quota = store.quota(for: substance)
        guard let limit = quota.limit else { return nil }
        return "Reduktion · max. \(limit)× / Monat, \(substance.name)"
    }

    // MARK: - G2 · Pläne (leer)

    @ViewBuilder
    private var emptyState: some View {
        if let suggestion = store.suggestedSituationTag() {
            // The app only proposes a plan once the user's own entries show something. A plan
            // needs knowledge of one's own patterns — so it can't arrive on day 1.
            KlarInverseCard {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15))
                        .foregroundStyle(Klar.accent)
                    KlarSectionLabel(
                        text: "Vorschlag aus deinen Einträgen",
                        color: Klar.textOnInverseSecondary
                    )
                }
                .padding(.bottom, 10)

                Text("\(Int((suggestion.share * 100).rounded())) % deiner Einträge tragen den Tag „\(suggestion.tag.name)“. Möchtest du dafür einen Plan?")
                    .font(Klar.TypeScale.display(20))
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)

                Button {
                    editorSeed = PlanEditorSeed(plan: nil, tag: suggestion.tag)
                } label: {
                    Text("Plan für „\(suggestion.tag.name)“ bauen")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Klar.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
        }

        VStack {
            Text("Ein guter Plan braucht Kenntnis der eigenen Muster. Er entsteht, wenn deine Einträge etwas zeigen.")
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .overlay {
            RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous)
                .strokeBorder(Klar.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }

        KlarDashedButton(title: "Plan trotzdem selbst anlegen", tint: Klar.textSecondary) {
            editorSeed = PlanEditorSeed(plan: nil, tag: nil)
        }
        .padding(.top, 12)
    }

    // MARK: - Links to G4 / G5

    private var navigationRows: some View {
        KlarCard(padding: 0) {
            NavigationLink {
                GoalsView()
            } label: {
                settingsRow(icon: "target", title: "Ziele", subtitle: "Limit anpassen, Zieltyp wechseln")
            }
            .klarRowButtonStyle()
            .accessibilityIdentifier("plans.goalsLink")

            KlarRowDivider(inset: 16)

            NavigationLink {
                SubstitutionActionsView()
            } label: {
                settingsRow(
                    icon: "arrow.triangle.swap",
                    title: "Ersatzhandlungen",
                    subtitle: "Genutzt im Craving-SOS"
                )
            }
            .klarRowButtonStyle()
            .accessibilityIdentifier("plans.substitutionsLink")
        }
    }

    private func settingsRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Klar.textSecondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
                Text(subtitle)
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Klar.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

/// Carries both "edit this plan" and "start a new plan seeded with this tag" through one
/// `sheet(item:)`.
struct PlanEditorSeed: Identifiable {
    let plan: Plan?
    let tag: ContextTag?
    let id = UUID()
}
