import SwiftUI
import SwiftData
import KlarCore

/// „Der Morgen danach" (concept v3, module C).
///
/// Asks about one logical day. It pops up by itself once (see `MainTabView`); after that the
/// same card opens from „Offen" and the day detail, for up to 72 h after the day ended, and shows
/// what was already answered. Everything is optional and nothing is judged: no option is
/// coloured, a good morning is not praised and a bad one is not commented on (P7, P8).
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
    /// The record is read once. Reading it again when the reflection cover closes would throw
    /// away whatever was tapped in the meantime.
    @State private var hasLoaded = false

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var dayEntries: [Entry] { store.entries(onDayKey: dayKey) }
    private var wording: Wording { Wording(dayKey: dayKey, now: Date(), timezoneID: KlarDate.timezoneID) }

    private var header: String {
        guard let first = dayEntries.first else { return "Der Morgen danach" }
        let day = KlarDate.logicalDay(for: first.timestamp, timezoneID: first.timezoneID)
        let label = wording.isAboutYesterday ? KlarDate.weekdayName(day) : KlarDate.shortWeekdayDate(day)
        return "Der Morgen danach · \(label)"
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
                        question: wording.bodyQuestion,
                        options: MorningBody.allCases.map { ($0, $0.label) },
                        selection: $bodyAnswer
                    )
                    AnswerRow(
                        question: wording.regretQuestion,
                        options: MorningRegret.allCases.map { ($0, $0.label) },
                        selection: $regretAnswer
                    )
                    AnswerRow(
                        question: Wording.againQuestion,
                        options: MorningAgain.allCases.map { ($0, $0.label) },
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
                    // „Später" writes nothing: the day stays in „Offen". „Überspringen" takes it
                    // off that list; the day detail can still answer it.
                    HStack(spacing: 10) {
                        KlarQuietButton(title: "Später") {
                            dismiss()
                        }
                        KlarQuietButton(title: "Überspringen") {
                            store.skipMorningAfter(dayKey: dayKey)
                            dismiss()
                        }
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
        .onAppear(perform: loadExistingAnswers)
        .fullScreenCover(isPresented: $isReflecting) {
            MorningReflectionView(dayKey: dayKey) { dismiss() }
        }
    }

    private func loadExistingAnswers() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let record = store.morningAfter(forDayKey: dayKey) else { return }
        bodyAnswer = record.body
        regretAnswer = record.regret
        againAnswer = record.again
        note = record.note ?? ""
        isNoteOpen = !note.isEmpty
    }

    private func save() {
        store.recordMorningAfter(dayKey: dayKey, body: bodyAnswer, regret: regretAnswer, again: againAnswer, note: note)
    }
}

extension MorningAfterCardView {
    /// „heute" and „gestern" only when it really is the morning after. Answered later — from
    /// „Offen" or the day detail — the questions speak of „dem Tag danach".
    struct Wording: Equatable {
        let isAboutYesterday: Bool

        init(dayKey: String, now: Date, timezoneID: String) {
            isAboutYesterday = LogicalDay.previousDayKey(LogicalDay.dayKey(for: now, timezoneID: timezoneID)) == dayKey
        }

        var bodyQuestion: String {
            isAboutYesterday ? "Wie geht's dir heute körperlich?" : "Wie ging's dir am Tag danach körperlich?"
        }

        var regretQuestion: String {
            isAboutYesterday ? "Bereust du etwas von gestern?" : "Bereust du etwas von dem Tag?"
        }

        static let againQuestion = "Würdest du es wieder so machen?"
    }
}

/// A question over a three-way control with nothing preselected. Tapping the selected option
/// again clears it, the same rule as the mood control in the entry sheet.
private struct AnswerRow<Value: Hashable>: View {
    let question: String
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
