import SwiftUI
import KlarCore

/// The day's „Der Morgen danach" inside the day detail: the answers, the note, the reflection.
/// While the day is answerable (72 h) it can be filled in or edited; afterwards it is read-only.
struct MorningAfterDayBlock: View {
    let record: MorningAfter?
    let canAnswer: Bool
    let onOpen: () -> Void

    /// Answers, note or reflection — not answers alone, so a day saved with only a note is shown.
    private var hasContent: Bool {
        record.map {
            MorningPatternText.hasContent(
                body: $0.body, regret: $0.regret, again: $0.again,
                note: $0.note, trigger: $0.trigger, wouldHaveHelped: $0.wouldHaveHelped, nextTime: $0.nextTime
            )
        } ?? false
    }

    var body: some View {
        KlarCard(padding: 16) {
            KlarSectionLabel(text: "Der Morgen danach")
                .padding(.bottom, 10)

            if let record, hasContent {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(MorningPatternText.answerLines(body: record.body, regret: record.regret, again: record.again), id: \.self) { line in
                        Text(line)
                            .font(Klar.TypeScale.body)
                            .foregroundStyle(Klar.text)
                    }
                    if let note = record.note {
                        Text(note)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textTertiary)
                            .padding(.top, 6)
                    }
                    ForEach(
                        MorningPatternText.reflectionLines(trigger: record.trigger, wouldHaveHelped: record.wouldHaveHelped, nextTime: record.nextTime),
                        id: \.self
                    ) { line in
                        Text(line)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textSecondary)
                    }
                }
                if canAnswer {
                    KlarInlineButton(title: "Bearbeiten", systemImage: "pencil", tint: Klar.textSecondary, action: onOpen)
                        .padding(.top, 12)
                        .accessibilityIdentifier("dayDetail.morning")
                }
            } else {
                if record != nil {
                    Text("Übersprungen.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                        .padding(.bottom, canAnswer ? 10 : 0)
                }
                if canAnswer {
                    KlarDashedButton(title: "Rückblick nachtragen", action: onOpen)
                        .accessibilityIdentifier("dayDetail.morning")
                }
            }
        }
    }
}
