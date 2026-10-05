import SwiftUI
import KlarCore

/// What the days after looked like, over every answered day. One hue in three steps, in option
/// order, the same for every question — no answer is highlighted, none is red (P7).
struct MorningDistributionCard: View {
    /// `nil` below three answered days.
    let distribution: MorningPattern?
    let shared: [(name: String, days: Int)]

    private var title: String {
        distribution.map { "Der Morgen danach · \($0.days) Tage" } ?? "Der Morgen danach"
    }

    var body: some View {
        KlarCard {
            KlarSectionLabel(text: LocalizedStringKey(title))
                .padding(.bottom, 12)

            if let distribution {
                VStack(alignment: .leading, spacing: 14) {
                    AnswerDistributionRow(
                        title: "Körper",
                        counts: MorningBody.allCases.map { ($0.label, distribution.body[$0] ?? 0) }
                    )
                    AnswerDistributionRow(
                        title: "Reue",
                        counts: MorningRegret.allCases.map { ($0.label, distribution.regret[$0] ?? 0) }
                    )
                    AnswerDistributionRow(
                        title: "Nochmal so",
                        counts: MorningAgain.allCases.map { ($0.label, distribution.again[$0] ?? 0) }
                    )
                }

                if !shared.isEmpty {
                    Text(MorningPatternText.sharedDaysText(shared))
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                        .padding(.top, 14)
                }
            } else {
                Text("Muster erscheinen nach drei Rückblicken.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
        }
        .accessibilityIdentifier("patterns.morning")
    }
}

private struct AnswerDistributionRow: View {
    let title: String
    let counts: [(label: String, count: Int)]

    private static let colors = [Klar.Palette.teal700, Klar.Palette.teal400, Klar.Palette.teal300]

    private var total: Int { counts.map(\.count).reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textSecondary)

            if total == 0 {
                Text("keine Angaben")
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
            } else {
                GeometryReader { proxy in
                    let visible = counts.filter { $0.count > 0 }.count
                    let width = proxy.size.width - CGFloat(max(visible - 1, 0)) * 2
                    HStack(spacing: 2) {
                        ForEach(Array(counts.enumerated()), id: \.offset) { index, item in
                            if item.count > 0 {
                                Rectangle()
                                    .fill(Self.colors[index])
                                    .frame(width: width * CGFloat(item.count) / CGFloat(total))
                            }
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())

                Text(counts.filter { $0.count > 0 }.map { "\($0.label) \($0.count)" }.joined(separator: " · "))
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title): " + (total == 0
                ? "keine Angaben"
                : counts.filter { $0.count > 0 }.map { "\($0.count) \($0.label)" }.joined(separator: ", "))
        )
    }
}
