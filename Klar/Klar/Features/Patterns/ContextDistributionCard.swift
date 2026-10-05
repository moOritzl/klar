import SwiftUI
import KlarCore

struct ContextDistributionCard: View {
    let substance: Substance
    let summary: StatsSummary
    let tags: [ContextTag]
    /// Per tag, what the days after looked like — only tags with three answered days.
    var morningPatterns: [UUID: MorningPattern] = [:]

    /// Share of the entries *with context* that carry each tag. Entries without context are left
    /// out of the base: context is optional, and counting them would make every tag look rare.
    private var distribution: [(tag: ContextTag, count: Int, share: Double)] {
        let base = summary.taggedEntryCount
        guard base > 0 else { return [] }
        return summary.contextTagDistribution
            .compactMap { tagID, count -> (ContextTag, Int, Double)? in
                guard let tag = tags.first(where: { $0.id == tagID }) else { return nil }
                return (tag, count, Double(count) / Double(base))
            }
            .sorted { $0.2 > $1.2 }
    }

    private let barColors: [Color] = [
        Klar.Palette.cyan600,
        Klar.Palette.teal400,
        Klar.Palette.teal300,
        Klar.Palette.emerald600
    ]

    var body: some View {
        KlarCard {
            KlarSectionLabel(text: "Kontextverteilung")
                .padding(.bottom, 14)

            if distribution.isEmpty {
                Text("Noch keine Kontext-Tags erfasst. Sie sind optional.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            } else {
                ForEach(Array(distribution.enumerated()), id: \.element.tag.id) { index, item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.tag.name)
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.text)
                            Spacer()
                            Text("\(Int((item.share * 100).rounded())) %")
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.textTertiary)
                        }
                        KlarShareBar(
                            fraction: item.share,
                            color: barColors[index % barColors.count]
                        )
                        if let pattern = morningPatterns[item.tag.id] {
                            Text(MorningPatternText.tally(pattern))
                                .font(Klar.TypeScale.caption)
                                .foregroundStyle(Klar.textTertiary)
                        }
                    }
                    .padding(.bottom, index == distribution.count - 1 ? 0 : 12)
                }
                Text(summary.taggedEntryCount == 1
                     ? "Basis: 1 Eintrag mit Kontext"
                     : "Basis: \(summary.taggedEntryCount) Einträge mit Kontext")
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.top, 12)
            }
        }
    }
}
