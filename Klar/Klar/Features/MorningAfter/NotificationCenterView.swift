import SwiftUI
import SwiftData
import KlarCore

/// „Mitteilungen", behind the bell on Übersicht. Everything Klar has asked about collects here:
/// the mornings still open, and the ones answered or skipped while they can still be changed.
///
/// The bell carries the system's red badge while a morning is open — the only count in the app.
/// It is a notice, not a demand (P9 as amended): nothing is asked twice, and an open morning
/// simply leaves the list once it can no longer be answered (72 h).
struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Unread: they redraw the lists when an entry or an answer lands.
    @Query private var entries: [Entry]
    @Query private var morningAfters: [MorningAfter]

    @State private var openedMorning: DueMorning?

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var openDays: [String] { store.openMorningAfterDays() }
    private var answeredDays: [String] {
        let open = Set(openDays)
        return store.answerableMorningAfterDays().filter { !open.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if openDays.isEmpty && answeredDays.isEmpty {
                        ContentUnavailableView(
                            "Keine Mitteilungen",
                            systemImage: "bell",
                            description: Text("Nach einem Tag mit Einträgen fragt Klar hier, wie der Morgen war.")
                        )
                        .padding(.top, 60)
                    }

                    if !openDays.isEmpty {
                        section("Wie war der Morgen?", days: openDays, isOpen: true)
                            .padding(.bottom, 28)
                    }

                    if !answeredDays.isEmpty {
                        section("Beantwortet", days: answeredDays, isOpen: false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, Klar.Space.x2)
                .padding(.bottom, Klar.Space.x6)
            }
            .background(Klar.bgSubtle)
            .navigationTitle("Mitteilungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .sheet(item: $openedMorning) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
        }
    }

    private func section(_ title: LocalizedStringKey, days: [String], isOpen: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            KlarGroupHeader(text: title)

            KlarCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element) { index, key in
                        if index > 0 {
                            KlarRowDivider(inset: 18)
                        }
                        Button {
                            openedMorning = DueMorning(dayKey: key)
                        } label: {
                            row(key, isOpen: isOpen)
                        }
                        .klarRowButtonStyle(cornerRadius: 0)
                        .accessibilityIdentifier(isOpen ? "morning.open.\(key)" : "morning.answered.\(key)")
                    }
                }
            }
        }
    }

    /// The Settings shape: the day on the left, a grey value on the right. Within 72 hours the
    /// weekday alone is unambiguous. Open rows name the substances, because that is what the
    /// question is about; answered rows say what became of it.
    private func row(_ key: String, isOpen: Bool) -> some View {
        HStack(spacing: 12) {
            if isOpen {
                // The unread dot, as in Mail: the app tint, not red. Red is the badge's job.
                Circle()
                    .fill(Klar.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            if let day = KlarDate.date(fromDayKey: key) {
                Text(KlarDate.weekdayName(day))
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
            }
            Spacer(minLength: 8)
            Text(isOpen ? substanceNames(onDayKey: key).joined(separator: ", ") : status(of: key))
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.textSecondary)
                .lineLimit(1)
            KlarDisclosureChevron()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func status(of key: String) -> String {
        guard let record = store.morningAfter(forDayKey: key) else { return "" }
        let hasContent = MorningPatternText.hasContent(
            body: record.body, regret: record.regret, again: record.again, note: record.note,
            trigger: record.trigger, wouldHaveHelped: record.wouldHaveHelped, nextTime: record.nextTime
        )
        return hasContent ? "Beantwortet" : "Übersprungen"
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
