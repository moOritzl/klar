import SwiftUI
import KlarCore

/// The day's „Der Morgen danach" inside the day detail: the answers, the note, the reflection.
/// While the day is answerable (72 h) it can be filled in or edited; afterwards it is read-only.
struct MorningAfterDayBlock: View {
    let record: MorningAfter?
    let canAnswer: Bool
    let onOpen: () -> Void

    private var isAnswered: Bool {
        record.map { $0.body != nil || $0.regret != nil || $0.again != nil } ?? false
    }

    var body: some View {
        KlarCard(padding: 16) {
            KlarSectionLabel(text: "Der Morgen danach")
                .padding(.bottom, 10)

            if let record, isAnswered {
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
