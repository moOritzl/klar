import SwiftUI
import KlarCore

/// „Deine Sätze": what the user wrote when they thought a day over, newest first. Their own
/// words are the one kind of feedback that cannot be normative.
struct ReflectionsCard: View {
    let records: [MorningAfter]

    var body: some View {
        KlarCard {
            KlarSectionLabel(text: "Deine Sätze")
                .padding(.bottom, 10)

            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                VStack(alignment: .leading, spacing: 3) {
                    if let day = KlarDate.date(fromDayKey: record.dayKey) {
                        Text(KlarDate.shortWeekdayDate(day))
                            .font(Klar.TypeScale.caption)
                            .foregroundStyle(Klar.textTertiary)
                    }
                    ForEach(
                        MorningPatternText.reflectionLines(trigger: record.trigger, wouldHaveHelped: record.wouldHaveHelped, nextTime: record.nextTime),
                        id: \.self
                    ) { line in
                        Text(line)
                            .font(Klar.TypeScale.body)
                            .foregroundStyle(Klar.text)
                    }
                }
                if index < records.count - 1 {
                    KlarRowDivider()
                        .padding(.vertical, 10)
                }
            }
        }
    }
}
