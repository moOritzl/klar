import SwiftUI
import SwiftData
import KlarCore

/// D1 · Plan-Check-in.
///
/// Deliberately time-shifted: never right after the entry, always at least one logical day
/// later (enforced in `PlanService.pendingCheckIns`). A day later, reflection is *evaluation*,
/// not confrontation. "Nein" is information about the plan, never about the person — which is
/// why the copy asks whether the plan helped, not whether the user succeeded.
struct PlanCheckInView: View {
    let plan: Plan
    let entry: Entry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isReflecting = false
    @State private var isEditingPlan = false
    /// The same tick for all three answers. Which one was chosen is not the phone's opinion.
    @State private var answerCount = 0

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ZStack {
            Color(hex: 0x15272B).opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                KlarSectionLabel(text: situationLabel)
                    .padding(.bottom, 12)

                Text("Hat dein Plan geholfen?")
                    .font(Klar.TypeScale.display(22))
                    .foregroundStyle(Klar.text)
                    .padding(.bottom, 8)

                Text("„Wenn \(PlanSentence.fragment(plan.situationText)), dann \(PlanSentence.fragment(plan.actionText))“")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textSecondary)
                    .padding(.bottom, 22)

                VStack(spacing: 10) {
                    KlarPrimaryButton(title: "Ja, hat geholfen") {
                        store.recordCheckIn(plan: plan, entry: entry, outcome: .helped)
                        answerCount += 1
                        dismiss()
                    }

                    KlarSecondaryButton(title: "Nein") {
                        // "Nein" doesn't just get recorded — it opens the Problem-Solving flow,
                        // because an unhelpful plan is a plan that needs reworking.
                        store.recordCheckIn(plan: plan, entry: entry, outcome: .notHelped)
                        answerCount += 1
                        isReflecting = true
                    }

                    Button("Plan anpassen") {
                        store.recordCheckIn(plan: plan, entry: entry, outcome: .adjusted)
                        answerCount += 1
                        isEditingPlan = true
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Klar.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
            }
            .padding(24)
            .background(Klar.surface)
            .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.xl, style: .continuous))
            .klarShadow(Klar.Shadow.lg)
            .padding(22)
        }
        .presentationBackground(.clear)
        .sensoryFeedback(.selection, trigger: answerCount)
        .fullScreenCover(isPresented: $isReflecting) {
            ReflectionView(plan: plan, entry: entry) { dismiss() }
        }
        .sheet(isPresented: $isEditingPlan) {
            PlanEditorView(existingPlan: plan)
        }
        .onChange(of: isEditingPlan) { _, isPresented in
            if !isPresented { dismiss() }
        }
    }

    private var situationLabel: LocalizedStringKey {
        if let tag = plan.situationTag {
            return "Dein Plan für „\(tag.name)“"
        }
        return "Dein Plan"
    }
}

// MARK: - D2 · Reflexion

/// The Problem-Solving module (concept § 4, Modul E). Three questions, and the third one is the
/// hand-off: whatever the user writes becomes the starting text of the reworked plan, so the
/// reflection *ends in a changed plan* rather than in a feeling.
struct ReflectionView: View {
    let plan: Plan
    let entry: Entry
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var trigger = ""
    @State private var whatWouldHaveHelped = ""
    @State private var planChange = ""
    @State private var isEditingPlan = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 15))
                        .foregroundStyle(Klar.Palette.cyan600)
                    KlarSectionLabel(text: "Kurz nachdenken")
                    Spacer()
                    Button("Später") { finish() }
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                }
                .padding(.bottom, 6)

                Text("Was war los?")
                    .font(Klar.TypeScale.display(24))
                    .foregroundStyle(Klar.text)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 14) {
                        questionCard(
                            number: 1,
                            label: "Was war der Auslöser?",
                            placeholder: "z. B. Gruppendruck, alle haben mitgemacht.",
                            text: $trigger
                        )
                        questionCard(
                            number: 2,
                            label: "Was hätte geholfen?",
                            placeholder: "z. B. Früher gehen, bevor es kippt.",
                            text: $whatWouldHaveHelped
                        )
                        questionCard(
                            number: 3,
                            label: "Was änderst du am Plan?",
                            placeholder: "Antwort tippen …",
                            text: $planChange
                        )
                    }
                }
                .scrollIndicators(.hidden)

                KlarPrimaryButton(title: "Plan anpassen", systemImage: "arrow.right") {
                    saveReflection()
                    isEditingPlan = true
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $isEditingPlan) {
            // The plan editor opens pre-filled with the user's own answer to question 3.
            PlanEditorView(existingPlan: plan, prefilledActionText: trimmed(planChange))
        }
        .onChange(of: isEditingPlan) { _, isPresented in
            if !isPresented { finish() }
        }
    }

    private func questionCard(
        number: Int,
        label: LocalizedStringKey,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        KlarCard(padding: 16) {
            HStack(spacing: 0) {
                Text("\(number) · ")
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                Text(label)
                    .font(Klar.TypeScale.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(Klar.textTertiary)
            }
            .padding(.bottom, 8)

            TextField(placeholder, text: text, axis: .vertical)
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.text)
                .lineLimit(1...4)
        }
    }

    /// Answers 1 and 2 are context for *this entry*, so they're stored on the entry's note —
    /// they'll show up again in the day detail. Answer 3 goes into the plan itself.
    private func saveReflection() {
        var lines: [String] = []
        if !trimmed(trigger).isEmpty { lines.append("Auslöser: \(trimmed(trigger))") }
        if !trimmed(whatWouldHaveHelped).isEmpty {
            lines.append("Hätte geholfen: \(trimmed(whatWouldHaveHelped))")
        }
        guard !lines.isEmpty else { return }

        let existing = entry.note.map { $0 + "\n" } ?? ""
        store.updateEntry(entry, note: .some(existing + lines.joined(separator: "\n")))
    }

    private func finish() {
        dismiss()
        onFinish()
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
