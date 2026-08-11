import SwiftUI
import SwiftData
import KlarCore

/// G3 · Plan-Editor.
///
/// An if-then plan (Gollwitzer's implementation intentions; concept § 2.4) assembled from the
/// user's *own* context tags rather than from a generic library. Templates are offered as a
/// starting point and are freely editable — a plan the user didn't phrase isn't their plan.
///
/// Addition to the draft: the draft shows only tag chips under "WENN", but the model (and the
/// resulting "Wenn …, dann …" sentence) needs a situation *phrase* too. Picking a tag pre-fills
/// that phrase from a template; the field stays editable.
struct PlanEditorView: View {
    let existingPlan: Plan?
    var prefilledSituationTag: ContextTag?
    var prefilledActionText: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var contextTags: [ContextTag]

    @State private var selectedTagID: UUID?
    @State private var situationText = ""
    @State private var actionText = ""
    @State private var limitReached = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var sortedTags: [ContextTag] {
        contextTags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedTag: ContextTag? {
        sortedTags.first { $0.id == selectedTagID }
    }

    private var canSave: Bool {
        !situationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !actionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    KlarSectionLabel(text: "Wenn … (Situation aus deinen Tags)")
                        .padding(.bottom, 8)

                    KlarFlowLayout(spacing: 8) {
                        ForEach(sortedTags) { tag in
                            Button {
                                select(tag)
                            } label: {
                                KlarOutlineChip(text: tag.name, isSelected: selectedTagID == tag.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)

                    TextField("Situation beschreiben …", text: $situationText, axis: .vertical)
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                        .lineLimit(1...3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Klar.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                                .strokeBorder(Klar.border, lineWidth: 1)
                        }
                        .padding(.bottom, 20)

                    KlarSectionLabel(text: "Dann … (Handlung: Vorlage, frei editierbar)")
                        .padding(.bottom, 8)

                    TextField("Handlung beschreiben …", text: $actionText, axis: .vertical)
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                        .lineLimit(1...3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Klar.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                                .strokeBorder(Klar.accent, lineWidth: 1)
                        }
                        .padding(.bottom, 10)

                    VStack(spacing: 8) {
                        ForEach(PlanTemplates.actions.filter { $0 != actionText }, id: \.self) { template in
                            Button {
                                actionText = template
                            } label: {
                                Text(template)
                                    .font(Klar.TypeScale.bodySmall)
                                    .foregroundStyle(Klar.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Klar.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                            }
                            .klarRowButtonStyle(cornerRadius: Klar.Radius.md)
                        }
                    }
                    .padding(.bottom, 20)

                    HStack {
                        Text("Vorgenommen am")
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textSecondary)
                        Spacer()
                        Text(commitmentDateText)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.text)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Klar.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                            .strokeBorder(Klar.border, lineWidth: 1)
                    }
                    .padding(.bottom, 20)

                    KlarPrimaryButton(title: "Plan festlegen", isEnabled: canSave) {
                        commit()
                    }

                    if existingPlan != nil {
                        Button("Plan pausieren") {
                            if let existingPlan {
                                store.setPlanStatus(existingPlan, .paused)
                            }
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Klar.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, Klar.Space.x2)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            // Background on the scroll view rather than a `ZStack` sibling, so the content
            // travels under the bar and iOS can apply the scroll-edge effect.
            .background(Klar.bgSubtle)
            .navigationTitle(existingPlan == nil ? "Neuer Plan" : "Plan anpassen")
            // „Abbrechen", not „Fertig": nothing here is written until „Plan festlegen", so
            // leaving discards. The hand-built ✕ in a tinted circle that used to sit here said
            // the same thing in a dialect only this screen spoke.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Schon 3 aktive Pläne", isPresented: $limitReached) {
            Button("Verstanden", role: .cancel) {}
        } message: {
            Text("Max. 3 aktive Pläne. Pausiere einen bestehenden Plan, um Platz zu schaffen.")
        }
        .task {
            loadInitialState()
        }
    }


    /// An edited plan is a *new version* with a fresh commitment date — that's the point of
    /// versioning it rather than mutating it in place.
    private var commitmentDateText: String {
        "Heute, \(KlarDate.dayAndMonth(Date()))"
    }

    private func loadInitialState() {
        if let existingPlan {
            selectedTagID = existingPlan.situationTag?.id
            situationText = existingPlan.situationText
            actionText = prefilledActionText ?? existingPlan.actionText
        } else if let prefilledSituationTag {
            select(prefilledSituationTag)
            actionText = prefilledActionText ?? ""
        } else if let prefilledActionText {
            actionText = prefilledActionText
        }
    }

    private func select(_ tag: ContextTag) {
        selectedTagID = tag.id
        // Only pre-fill an *empty* field — never overwrite something the user typed.
        if situationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            situationText = PlanTemplates.situation(for: tag.name)
        }
    }

    private func commit() {
        do {
            try store.commitPlan(
                replacing: existingPlan,
                situationTag: selectedTag,
                situationText: situationText.trimmingCharacters(in: .whitespacesAndNewlines),
                actionText: actionText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch PlanServiceError.activePlanLimitReached {
            limitReached = true
        } catch {
            limitReached = true
        }
    }
}

// MARK: - Templates

enum PlanTemplates {
    /// The three plan shapes the concept names (§ 4, Modul C): situation, craving, quantity.
    static let actions = [
        "sage ich: „Heute nicht.“",
        "gehe ich zuerst 10 Minuten raus",
        "trinke ich ein Wasser und warte",
        "starte ich den 20-Minuten-Timer und gehe eine Runde",
        "nehme ich höchstens die Hälfte der letzten Dosis"
    ]

    /// A starting phrase for the "Wenn …" half, derived from the tag the user picked.
    static func situation(for tagName: String) -> String {
        switch tagName.lowercased() {
        case "club": "mir im Club etwas angeboten wird"
        case "sozial": "mir in einer Runde etwas angeboten wird"
        case "allein": "ich abends allein zuhause bin"
        case "zuhause": "ich zuhause zur Ruhe kommen will"
        case "stress": "der Stress zu viel wird"
        default: "die Situation „\(tagName)“ eintritt"
        }
    }
}
