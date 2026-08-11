import SwiftUI
import SwiftData
import KlarCore

/// E1–E4 · Tab „Verlauf".
///
/// Making patterns visible is the mechanism — not keeping a chronicle. Every number here answers
/// a question the user could act on, and the only reference point is their own baseline (never a
/// norm; see concept § 3, P4/P7).
///
/// Deviation from the draft: the draft's segmented control has two segments (Kalender /
/// Rückblick) but ships a third screen, "Trends" (E3), with no entry point drawn. A third
/// segment is the smallest change that makes every designed screen reachable.
struct HistoryView: View {
    enum Section: Hashable, CaseIterable {
        case calendar, trends, review
    }

    @State private var section: Section = .calendar
    /// Which way the next section change slides. Set before the change so the animation follows
    /// the swipe instead of always entering from the same side.
    @State private var isAdvancing = true

    var body: some View {
        NavigationStack {
            KlarScreen(title: title) {
                VStack(alignment: .leading, spacing: 0) {
                    KlarSegmentedControl(
                        options: [
                            (Section.calendar, "Kalender"),
                            (Section.trends, "Trends"),
                            (Section.review, "Rückblick")
                        ],
                        selection: Binding(get: { section }, set: { select($0) })
                    )
                    .padding(.bottom, Klar.Space.x5)

                    sectionContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(section)
                        .transition(.asymmetric(
                            insertion: .move(edge: isAdvancing ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: isAdvancing ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
            }
            // Swiping anywhere the content does not claim — which on a short month is most of the
            // screen — moves between the three sections. The segments stay because a bare gesture
            // is undiscoverable and unreachable with VoiceOver; this is the shortcut, not the only
            // way.
            //
            // `simultaneousGesture`, not `gesture`: the direction test only runs in `onEnded`, so
            // an exclusive gesture claims every drag — including vertical ones — for the whole
            // time the finger is down, and the scroll view never sees them. The page simply did
            // not scroll. It also sits inside the `NavigationStack` so it cannot cover the bar.
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        shiftSection(value.translation.width < 0 ? 1 : -1)
                    }
            )
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .calendar: CalendarSectionView()
        case .trends: TrendsSectionView()
        case .review: ReviewArchiveSectionView()
        }
    }

    private func select(_ next: Section) {
        guard next != section,
              let from = Section.allCases.firstIndex(of: section),
              let to = Section.allCases.firstIndex(of: next)
        else { return }
        isAdvancing = to > from
        withAnimation(.easeInOut(duration: 0.25)) { section = next }
    }

    /// Refuses to wrap around: swiping past the last section does nothing, so the ends of the
    /// range stay felt rather than looping the user back to the start.
    private func shiftSection(_ delta: Int) {
        let all = Section.allCases
        guard let index = all.firstIndex(of: section) else { return }
        let target = index + delta
        guard all.indices.contains(target) else { return }
        select(all[target])
    }

    private var title: LocalizedStringKey {
        switch section {
        case .calendar, .trends: "Verlauf"
        case .review: "Wochenrückblicke"
        }
    }
}

/// The month's two numbers. Pure output, and the first thing on the section — the user singled
/// these out as the one part of the restructure that worked.
struct CalendarStatsView: View {
    let visibleMonth: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [Entry]

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var calendar: Calendar { KlarDate.calendar }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30
    }

    private var entryCount: Int {
        entries.filter {
            let day = KlarDate.logicalDay(for: $0.timestamp, timezoneID: $0.timezoneID)
            return calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        }.count
    }

    private var entryFreeDays: Int {
        daysInMonth - store.loggedDays(inMonthOf: visibleMonth).count
    }

    var body: some View {
        HStack(spacing: 12) {
            tile(label: "Einträge", value: "\(entryCount)", color: Klar.text)
            tile(label: "Eintragsfrei", value: "\(entryFreeDays)", color: Klar.Palette.emerald700)
        }
    }

    private func tile(label: LocalizedStringKey, value: String, color: Color) -> some View {
        KlarCard(padding: 14) {
            Text(label)
                .font(Klar.TypeScale.caption)
                .foregroundStyle(Klar.textTertiary)
            Text(value)
                .font(Klar.TypeScale.numeral)
                .foregroundStyle(color)
        }
    }
}

// MARK: - E1 · Monatskalender

/// Month stepping, pulled out of the view so the chevrons and the swipe cannot drift apart and
/// so the "no future months" rule is testable.
enum CalendarMonthNavigation {
    static func month(after delta: Int, from visibleMonth: Date, today: Date = Date()) -> Date? {
        let calendar = KlarDate.calendar
        guard let shifted = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else {
            return nil
        }
        guard shifted <= today || calendar.isDate(shifted, equalTo: today, toGranularity: .month) else {
            return nil
        }
        return shifted
    }
}

struct CalendarSectionView: View {
    @Environment(\.modelContext) private var modelContext
    /// Unread on purpose. The counts moved to `CalendarStatsView`, but this is what still
    /// invalidates the grid when an entry is added, so the day dots stay current. Deleting it
    /// silently stops the calendar updating.
    @Query private var entries: [Entry]

    /// The 1st of the visible month at 00:00, never a wall-clock moment: every derived number here
    /// (the dots, the two tiles, the cell dates) reads its calendar month off this anchor, and they
    /// can only agree if it carries no time of day to normalize away. `startOfMonth` also means that
    /// between 00:00 and 05:00 the calendar opens on the month the *logical* today lives in.
    @State private var visibleMonth = KlarDate.startOfMonth()
    @State private var selectedDay: Date?

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var calendar: Calendar { KlarDate.calendar }

    private var loggedDays: Set<Date> { store.loggedDays(inMonthOf: visibleMonth) }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30
    }

    /// Blank cells before the 1st, so the grid lines up under M/D/M/D/F/S/S.
    private var leadingBlanks: Int {
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth))
        else { return 0 }
        // `weekday` is 1=Sunday; the grid starts on Monday.
        let weekday = calendar.component(.weekday, from: first)
        return (weekday + 5) % 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CalendarStatsView(visibleMonth: visibleMonth)
                .padding(.bottom, 16)

            KlarCard(padding: 16) {
                monthHeader
                    .padding(.bottom, 12)

                weekdayHeader
                    .padding(.bottom, 6)

                dayGrid
            }
            // No swipe-to-change-month. The card used to claim horizontal drags with a
            // `highPriorityGesture`, which meant three gesture recognisers were arguing over the
            // same card — the month swipe, the section swipe around it, and the scroll view —
            // and the day cells had to win a race just to register a tap. The chevrons in
            // `monthHeader` are the way to move between months; they always were.

            legend
                .padding(.top, 14)
        }
        .sheet(item: Binding(
            get: { selectedDay.map { IdentifiableDate(date: $0) } },
            set: { selectedDay = $0?.date }
        )) { wrapper in
            DayDetailView(day: wrapper.date)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Klar.textTertiary)
            }
            .accessibilityLabel("Vorheriger Monat")

            Spacer()

            Text(KlarDate.monthName(visibleMonth))
                .font(Klar.TypeScale.headline)
                .foregroundStyle(Klar.text)
            Text(String(calendar.component(.year, from: visibleMonth)))
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textTertiary)

            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? Klar.borderStrong : Klar.textTertiary)
            }
            .disabled(isCurrentMonth)
            .accessibilityLabel("Nächster Monat")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            // Keyed by position, not by the letter: Montag/Mittwoch both give "M", as do
            // Dienstag/Donnerstag and Samstag/Sonntag. `id: \.self` collapsed those into three
            // duplicate IDs, which SwiftUI reports as undefined behaviour at runtime.
            ForEach(Array(["M", "D", "M", "D", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// One cell per grid slot. Leading blanks and real days must live in a *single* identified
    /// collection: two sibling `ForEach`es keyed `id: \.self` over `Int` flatten into one identity
    /// space inside `LazyVGrid`, so the blanks' ids (0, 1, …) collide with the day numbers and
    /// silently swallow the 1st of any month that starts on a Tuesday or later.
    private struct DayCell: Identifiable {
        let id: Int
        let day: Int?
    }

    private var cells: [DayCell] {
        let blanks = (0..<leadingBlanks).map { DayCell(id: $0, day: nil) }
        let days = (1...daysInMonth).map { DayCell(id: leadingBlanks + $0, day: $0) }
        return blanks + days
    }

    private var dayGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(cells) { cell in
                if let day = cell.day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let date = dayDate(day)
        let hasEntries = date.map { loggedDays.contains($0) } ?? false
        let isToday = date.map { $0 == KlarDate.logicalDay(for: Date()) } ?? false
        let isFuture = date.map { $0 > KlarDate.logicalDay(for: Date()) } ?? false

        return Button {
            if let date, !isFuture { selectedDay = date }
        } label: {
            ZStack {
                if isToday {
                    Circle().fill(Klar.text)
                }
                Text("\(day)")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(dayColor(isToday: isToday, isFuture: isFuture))

                if hasEntries {
                    Circle()
                        .fill(isToday ? Klar.bg : Klar.Palette.cyan600)
                        .frame(width: 5, height: 5)
                        .offset(y: 11)
                }
            }
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityLabel(day: day, hasEntries: hasEntries))
    }

    private func dayColor(isToday: Bool, isFuture: Bool) -> Color {
        // The today pill is filled with `Klar.text`, which flips with the scheme, so its
        // contents have to be the page colour rather than a literal white.
        if isToday { return Klar.bg }
        return isFuture ? Klar.borderStrong : Klar.text
    }

    private func accessibilityLabel(day: Int, hasEntries: Bool) -> String {
        "\(day). \(KlarDate.monthName(visibleMonth))" + (hasEntries ? ", erfasst" : ", eintragsfrei")
    }

    private var legend: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Klar.borderStrong)
                    .frame(width: 10, height: 10)
                Text("Eintragsfrei")
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(Klar.Palette.cyan600)
                    .frame(width: 10, height: 10)
                Text("Erfasst")
            }
        }
        .font(Klar.TypeScale.bodySmall)
        .foregroundStyle(Klar.textTertiary)
    }

    // MARK: - Month math

    private var isCurrentMonth: Bool {
        calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        guard let shifted = CalendarMonthNavigation.month(after: delta, from: visibleMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = shifted
        }
    }

    private func dayDate(_ day: Int) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: visibleMonth)
        components.day = day
        return calendar.date(from: components)
    }
}

/// `sheet(item:)` needs an Identifiable — `Date` isn't.
private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

// MARK: - E2 · Tagesdetail

struct DayDetailView: View {
    /// A normalized logical day (00:00), as the calendar grid produces it — not a wall-clock moment.
    let day: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [Entry]

    @State private var entryBeingEdited: Entry?
    @State private var isAddingEntry = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var entries: [Entry] {
        store.entries(onLogicalDay: day)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    KlarGroupHeader(text: entries.count == 1 ? "1 Eintrag" : "\(entries.count) Einträge")
                        .padding(.bottom, 10)

                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            dayEntryCard(entry)
                        }
                    }

                    KlarDashedButton(title: "Eintrag nachtragen") {
                        isAddingEntry = true
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, Klar.Space.x2)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Klar.bgSubtle)
            .navigationTitle(KlarDate.longWeekdayDate(day))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .sheet(item: $entryBeingEdited) { entry in
            EntryDetailSheet(entry: entry)
        }
        .sheet(isPresented: $isAddingEntry) {
            // Back-filling a past day: keep the day, default the time to now-of-that-day.
            EntrySheetView(timestamp: backfillTimestamp)
        }
    }

    private func dayEntryCard(_ entry: Entry) -> some View {
        KlarCard(padding: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Klar.substanceColor(entry.substance?.colorIndex ?? 0))
                    .frame(width: 10, height: 10)
                Text(entry.substance?.name ?? "Ohne Substanz")
                    .font(Klar.TypeScale.headline)
                    .foregroundStyle(Klar.text)
                Spacer()
                KlarIconButton(
                    systemImage: "pencil",
                    size: 26,
                    accessibilityLabel: "Eintrag bearbeiten"
                ) {
                    entryBeingEdited = entry
                }
            }
            .padding(.bottom, 10)

            KlarFlowLayout(spacing: 8) {
                if let amount = entry.amount, let unit = entry.substance?.unit {
                    KlarChip(text: "\(amount.klarFormatted) \(unit.label(for: amount))", compact: true)
                }
                KlarChip(text: KlarDate.time(entry.timestamp), compact: true)
                ForEach(entry.contextTags ?? []) { tag in
                    KlarChip(text: tag.name, compact: true)
                }
            }

            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.top, 10)
            }
        }
    }

    /// A back-filled entry lands at noon on the chosen day — safely inside the logical day, and
    /// obviously a placeholder the user can correct in the detail form.
    private var backfillTimestamp: Date {
        KlarDate.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}
