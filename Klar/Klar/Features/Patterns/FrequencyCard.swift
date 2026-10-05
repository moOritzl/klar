import SwiftUI
import KlarCore

/// How often, measured against the user's own history only: consumption days per week and the
/// average gap between them.
struct FrequencyCard: View {
    let summary: StatsSummary

    private var perWeekText: String {
        summary.occasionFrequencyPerWeek.formatted(
            .number.precision(.fractionLength(1)).locale(Locale(identifier: "de_DE"))
        )
    }

    private var gapText: String {
        guard let gap = summary.averageGapDays else { return "—" }
        return String(format: "%.0f", gap)
    }

    var body: some View {
        KlarCard {
            KlarSectionLabel(text: "Häufigkeit")
                .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 24) {
                tile(label: "Pro Woche", value: perWeekText, unit: "Tage")
                tile(label: "Ø Abstand", value: gapText, unit: summary.averageGapDays == nil ? nil : "Tage")
                Spacer()
            }
        }
    }

    private func tile(label: LocalizedStringKey, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Klar.TypeScale.caption)
                .foregroundStyle(Klar.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Klar.TypeScale.numeral)
                    .foregroundStyle(Klar.text)
                if let unit {
                    Text(unit)
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.text)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
