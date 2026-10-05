import SwiftUI
import SwiftData
import KlarCore

/// „Offen": consumption days that can still be answered and have no record. At most three by
/// construction (72 h). No badge, no count in the tab bar, no colour — it simply isn't there
/// when nothing is open (P9).
struct OpenMorningsCard: View {
    let dayKeys: [String]
    let onOpen: (String) -> Void

    @Environment(\.modelContext) private var modelContext

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        KlarCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(dayKeys.enumerated()), id: \.element) { index, key in
                    if index > 0 {
                        KlarRowDivider(inset: 18)
                    }
                    Button {
                        onOpen(key)
                    } label: {
                        row(key)
                    }
                    .klarRowButtonStyle()
                    .accessibilityIdentifier("morning.open.\(key)")
                }
            }
        } header: {
            KlarSectionLabel(text: "Offen")
        }
    }

    private func row(_ key: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let day = KlarDate.date(fromDayKey: key) {
                    Text(KlarDate.longWeekdayDate(day))
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                }
                KlarFlowLayout(spacing: 6) {
                    ForEach(substanceNames(onDayKey: key), id: \.self) { name in
                        KlarChip(text: name, compact: true)
                    }
                }
            }
            Spacer()
            KlarDisclosureChevron()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// The day's asking substances, each once, in the order they were logged.
    private func substanceNames(onDayKey key: String) -> [String] {
        var seen: Set<String> = []
        return store.entries(onDayKey: key)
            .compactMap(\.substance)
            .filter(\.asksMorningAfter)
            .map(\.name)
            .filter { seen.insert($0).inserted }
    }
}
