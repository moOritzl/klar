import SwiftUI
import Charts
import KlarCore

struct DoseTrendCard: View {
    let substance: Substance
    let summary: StatsSummary

    /// The last 8 weeks that actually have occasions — an empty stretch shouldn't stretch the axis.
    private var points: [WeeklyAverage] {
        Array(summary.weeklyAverages.suffix(8))
    }

    private var thisWeek: WeeklyAverage? { points.last }

    private var previousWeek: WeeklyAverage? {
        points.count >= 2 ? points[points.count - 2] : nil
    }

    var body: some View {
        KlarCard {
            KlarSectionLabel(text: "Ø Dosis über Zeit")
                .padding(.bottom, 12)

            if points.count < 2 {
                Text("Zu wenig Einträge für einen Verlauf. Ab zwei Wochen mit Einträgen zeigt sich hier eine Linie.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.bottom, 12)
            } else {
                chart
                    .frame(height: 88)
                    .padding(.bottom, 14)
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diese Woche")
                        .font(Klar.TypeScale.caption)
                        .foregroundStyle(Klar.textTertiary)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(thisWeek?.averageAmount?.klarFormatted ?? "—")
                            .font(Klar.TypeScale.numeral)
                            .foregroundStyle(Klar.text)
                        if thisWeek?.averageAmount != nil {
                            Text(substance.unit.shortLabel)
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.text)
                        }
                    }

                    if let delta = deltaText {
                        Text(delta)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.Palette.emerald700)
                    }
                }

                Spacer()
            }
        }
    }

    private var chart: some View {
        Chart(points, id: \.weekStart) { point in
            LineMark(
                x: .value("Woche", point.weekStart),
                y: .value("Ø Dosis", doubleValue(point.averageAmount))
            )
            .foregroundStyle(Klar.Palette.teal600)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)

            if point.weekStart == points.last?.weekStart {
                PointMark(
                    x: .value("Woche", point.weekStart),
                    y: .value("Ø Dosis", doubleValue(point.averageAmount))
                )
                .foregroundStyle(Klar.Palette.teal600)
                .symbolSize(60)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func doubleValue(_ decimal: Decimal?) -> Double {
        (decimal as NSDecimalNumber?)?.doubleValue ?? 0
    }

    /// "↓ von 95 mg" — the user's own previous week, never a norm.
    private var deltaText: String? {
        guard let current = thisWeek?.averageAmount,
              let previous = previousWeek?.averageAmount,
              current != previous
        else { return nil }
        let arrow = current < previous ? "↓" : "↑"
        return "\(arrow) von \(previous.klarFormatted) \(substance.unit.shortLabel)"
    }
}
