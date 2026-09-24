import SwiftUI
import SwiftData
import KlarCore

/// „Der Morgen danach" (concept v3, module C).
///
/// Asks about one logical day, once. Everything is optional and nothing is judged: no option is
/// coloured, a good morning is not praised and a bad one is not commented on (P7, P8). What it
/// collects comes back as a pattern, on Übersicht and in the entry sheet — the card is the
/// input, not the point.
struct MorningAfterCardView: View {
    let dayKey: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var bodyAnswer: MorningBody?
    @State private var regretAnswer: MorningRegret?
    @State private var againAnswer: MorningAgain?
    @State private var note = ""
    @State private var isNoteOpen = false
    @State private var isReflecting = false

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var dayEntries: [Entry] { store.entries(onDayKey: dayKey) }

    private var header: String {
        guard let first = dayEntries.first else { return "Der Morgen danach" }
        let day = KlarDate.logicalDay(for: first.timestamp, timezoneID: first.timezoneID)
        return "Der Morgen danach · \(KlarDate.weekdayName(day))"
    }

    /// The day's substances, then its context tags, each once, in the order they were logged.
    private var chips: [String] {
        var seen: Set<String> = []
        let names = dayEntries.compactMap { $0.substance?.name }
            + dayEntries.flatMap { ($0.contextTags ?? []).map(\.name) }
        return names.filter { seen.insert($0).inserted }
    }

    var body: some View {
        ZStack {
            Color(hex: 0x15272B).opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text(header)
                    .font(Klar.TypeScale.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Klar.textTertiary)
                    .accessibilityIdentifier("morningAfter.header")
                    .padding(.bottom, 10)

                if !chips.isEmpty {
                    KlarFlowLayout(spacing: 6) {
                        ForEach(chips, id: \.self) { KlarChip(text: $0, compact: true) }
                    }
                    .padding(.bottom, 18)
                }

                VStack(alignment: .leading, spacing: 16) {
                    AnswerRow(
                        question: "Wie geht's dir heute körperlich?",
                        options: [(.fine, "gut"), (.rough, "angeschlagen"), (.hungover, "verkatert")],
                        selection: $bodyAnswer
                    )
                    AnswerRow(
                        question: "Bereust du etwas von gestern?",
                        options: [(.no, "nein"), (.slightly, "ein bisschen"), (.yes, "ja")],
                        selection: $regretAnswer
                    )
                    AnswerRow(
                        question: "Würdest du es wieder so machen?",
                        options: [(.yes, "ja"), (.differently, "anders"), (.no, "nein")],
                        selection: $againAnswer
                    )
                }

                if regretAnswer == .yes {
                    KlarInlineButton(title: "Kurz drüber nachdenken", systemImage: "lightbulb") {
                        save()
                        isReflecting = true
                    }
                    .padding(.top, 14)
                }

                if isNoteOpen {
                    TextField("Notiz (optional)", text: $note, axis: .vertical)
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(Klar.bgSubtle, in: RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                        .padding(.top, 16)
                } else {
                    KlarInlineButton(title: "Notiz hinzufügen", systemImage: "plus", tint: Klar.textSecondary) {
                        isNoteOpen = true
                    }
                    .padding(.top, 14)
                }

                VStack(spacing: 10) {
                    KlarPrimaryButton(title: "Fertig") {
                        save()
                        dismiss()
                    }
                    KlarQuietButton(title: "Überspringen") {
                        store.skipMorningAfter(dayKey: dayKey)
                        dismiss()
                    }
                }
                .padding(.top, 22)
            }
            .padding(24)
            .background(Klar.surface)
            .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.xl, style: .continuous))
            .klarShadow(Klar.Shadow.lg)
            .padding(22)
        }
        .presentationBackground(.clear)
        .sensoryFeedback(.selection, trigger: [bodyAnswer?.rawValue, regretAnswer?.rawValue, againAnswer?.rawValue])
        .fullScreenCover(isPresented: $isReflecting) {
            MorningReflectionView(dayKey: dayKey) { dismiss() }
        }
    }

    private func save() {
        store.recordMorningAfter(dayKey: dayKey, body: bodyAnswer, regret: regretAnswer, again: againAnswer, note: note)
    }
}

/// A question over a three-way control with nothing preselected. Tapping the selected option
/// again clears it, the same rule as the mood control in the entry sheet.
private struct AnswerRow<Value: Hashable>: View {
    let question: LocalizedStringKey
    let options: [(value: Value, label: String)]
    @Binding var selection: Value?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textSecondary)
            KlarSegmentedControl(
                options: options.map { (value: Optional($0.value), label: $0.label) },
                selection: Binding(
                    get: { selection },
                    set: { selection = ($0 == selection) ? nil : $0 }
                )
            )
        }
    }
}
