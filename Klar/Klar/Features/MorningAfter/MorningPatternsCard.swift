import SwiftUI
import KlarCore

struct MorningPatternRow: Identifiable {
    let substance: Substance
    let pattern: MorningPattern
    var id: UUID { substance.id }
}

/// The Übersicht block that gives back what the morning-after card collected: one line per
/// substance with a pattern, and the user's own note for next time under it. Absent — not
/// empty — until some substance has three answered mornings.
struct MorningPatternsCard: View {
    let rows: [MorningPatternRow]

    var body: some View {
        KlarCard {
            KlarSectionLabel(text: "Der Morgen danach")
                .padding(.bottom, 10)

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(row.substance.name) · \(MorningPatternText.summary(row.pattern))")
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                    if let nextTime = row.pattern.nextTime {
                        Text("Nächstes Mal: \(nextTime)")
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textTertiary)
                    }
                }
                if index < rows.count - 1 {
                    KlarRowDivider()
                        .padding(.vertical, 10)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.morningPatterns")
    }
}
