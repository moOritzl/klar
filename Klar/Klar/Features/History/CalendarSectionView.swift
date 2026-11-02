import SwiftUI
import SwiftData
import KlarCore

// E1–E2 · The calendar and what each day held, at the bottom of „Übersicht" (`TodayView`).
//
// Built like the iOS Calendar month view: the grid on top, the selected day's entries in the same
// card below it. Today is selected by default, so this is also where today's entries live — and
// an entry-free today shows nothing under the grid at all. A past day additionally offers „Eintrag
// nachtragen" and, below the card, its „Der Morgen danach". There is no tab „Verlauf" and no
// day-detail sheet any more; how often over time is what Muster's `FrequencyCard` shows.

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
    /// Unread on purpose: this is what invalidates the grid when an entry is added, so the day
    /// dots stay current. Deleting it silently stops the calendar updating.
    @Query private var entries: [Entry]
    @Query private var substances: [Substance]
    // Unread: redraws the open-day rings when a day is answered.
    @Query private var morningAfters: [MorningAfter]

    /// The 1st of the visible month at 00:00, never a wall-clock moment: every derived number here
    /// (the dots, the cell dates) reads its calendar month off this anchor, and they
    /// can only agree if it carries no time of day to normalize away. `startOfMonth` also means that
    /// between 00:00 and 05:00 the calendar opens on the month the *logical* today lives in.
    @State private var visibleMonth = KlarDate.startOfMonth()
    /// `nil` means today. Kept as „today" rather than a date so the selection follows the day
    /// across 05:00 instead of staying on yesterday.
    @State private var selectedDay: Date?
    @State private var entryBeingEdited: Entry?
    @State private var isAddingEntry = false
    @State private var openedMorning: DueMorning?

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var calendar: Calendar { KlarDate.calendar }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

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

    /// The logical today, normalized to 00:00 like the grid's dates.
    private var today: Date { KlarDate.logicalDay(for: Date()) }
    private var shownDay: Date { selectedDay ?? today }
    private var isShowingToday: Bool { shownDay == today }
    private var isShownDayVisible: Bool {
        calendar.isDate(shownDay, equalTo: visibleMonth, toGranularity: .month)
    }
    /// A past day reads oldest first, as a record: morning coffee, the cigarette at work, the
    /// evening. Today runs newest first, because there the list is checked against what was just
    /// tapped, and on a heavy day that entry would otherwise be the one furthest down.
    private var shownEntries: [Entry] {
        let entries = store.entries(onLogicalDay: shownDay)
        return isShowingToday ? entries.reversed() : entries
    }

    /// Not `LogicalDay.dayKey(for: day)`: `shownDay` is already normalized to 00:00, and the
    /// cutoff would move it to the day before.
    private var shownDayKey: String { KlarDate.dayKey(forLogicalDay: shownDay) }
    private var morningRecord: MorningAfter? { store.morningAfter(forDayKey: shownDayKey) }
    private var canAnswerMorning: Bool { store.canAnswerMorningAfter(dayKey: shownDayKey) }

    /// Today without entries shows nothing under the grid: an entry-free day is the calm
    /// baseline, not a gap to point at. A past day always shows its section, because back-filling
    /// it is the reason to tap it.
    private var showsDaySection: Bool {
        isShownDayVisible && (!isShowingToday || !shownEntries.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KlarCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    monthHeader
                        .padding(.bottom, 12)

                    weekdayHeader
                        .padding(.bottom, 6)

                    dayGrid
                }
                .padding(16)

                if showsDaySection {
                    KlarRowDivider()
                    daySection
                }
            }
            // No swipe-to-change-month. The card used to claim horizontal drags with a
            // `highPriorityGesture`, which meant three gesture recognisers were arguing over the
            // same card — the month swipe, the section swipe around it, and the scroll view —
            // and the day cells had to win a race just to register a tap. The chevrons in
            // `monthHeader` are the way to move between months; they always were.

            legend
                .padding(.top, 14)

            if isShownDayVisible, !isShowingToday, morningRecord != nil || canAnswerMorning {
                MorningAfterDayBlock(record: morningRecord, canAnswer: canAnswerMorning) {
                    openedMorning = DueMorning(dayKey: shownDayKey)
                }
                .padding(.top, 20)
            }
        }
        .sheet(item: $entryBeingEdited) { entry in
            EntryDetailSheet(entry: entry)
        }
        .sheet(isPresented: $isAddingEntry) {
            // Back-filling a past day: keep the day, default the time to noon of that day.
            EntrySheetView(timestamp: backfillTimestamp)
        }
        .sheet(item: $openedMorning) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
        }
    }

    // MARK: - E2 · The selected day

    /// The day's name, then one row per entry, then — for a past day — „Eintrag nachtragen".
    /// Rows in the Settings shape, separated by inset hairlines, so the list reads as part of
    /// the calendar card rather than a second card under it.
    private var daySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(dayTitle)
                .font(Klar.TypeScale.bodySmall.weight(.semibold))
                .foregroundStyle(Klar.textSecondary)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(isShowingToday ? "today.loggedSection" : "calendar.dayTitle")

            ForEach(Array(shownEntries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    KlarRowDivider(inset: 18)
                }
                Button {
                    entryBeingEdited = entry
                } label: {
                    EntryRow(entry: entry)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                }
                .klarRowButtonStyle(cornerRadius: 0)
                // A long press is where iOS puts this, and it keeps the destructive action one
                // deliberate step away from a tap.
                .contextMenu {
                    Button {
                        entryBeingEdited = entry
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        store.deleteEntry(entry)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }

            if !isShowingToday {
                if !shownEntries.isEmpty {
                    KlarRowDivider(inset: 18)
                }
                Button {
                    isAddingEntry = true
                } label: {
                    Label("Eintrag nachtragen", systemImage: "plus")
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.accentStrong)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .klarRowButtonStyle(cornerRadius: 0)
                .accessibilityIdentifier("calendar.backfill")
            }
        }
        .padding(.bottom, 4)
    }

    /// „Heute", or the date for any other day. Between midnight and 05:00 today's title names the
    /// logical day, because there it contradicts the phone and changes what the next entry does.
    private var dayTitle: String {
        if isShowingToday {
            return KlarDate.isBeforeCutoff() ? "\(KlarDate.shortWeekdayDate(today)) · bis 5 Uhr" : "Heute"
        }
        return KlarDate.longWeekdayDate(shownDay)
    }

    /// A back-filled entry lands at noon on the chosen day — safely inside the logical day, and
    /// obviously a placeholder the user can correct in the detail form.
    private var backfillTimestamp: Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: shownDay) ?? shownDay
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
        // Read once per render, not once per cell: every cell used to rescan all entries.
        let logged = store.loggedSubstances(inMonthOf: visibleMonth)
        let open = Set(store.openMorningAfterDays().compactMap(KlarDate.date(fromDayKey:)))
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(cells) { cell in
                if let day = cell.day {
                    dayCell(day, logged: logged, open: open)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
    }

    private func dayCell(_ day: Int, logged: [Date: [Substance]], open: Set<Date>) -> some View {
        let date = dayDate(day)
        let substances = date.flatMap { logged[$0] }
        let isToday = date.map { $0 == KlarDate.logicalDay(for: Date()) } ?? false
        let isFuture = date.map { $0 > KlarDate.logicalDay(for: Date()) } ?? false
        let isOpen = date.map { open.contains($0) } ?? false
        let isSelected = !isToday && date == selectedDay

        return Button {
            guard let date, !isFuture else { return }
            withAnimation(.snappy(duration: 0.2)) {
                selectedDay = date == today ? nil : date
            }
        } label: {
            ZStack {
                if isToday {
                    Circle().fill(Klar.text)
                }
                if isSelected {
                    // Another day picked: the app tint, like the selected day in Calendar.
                    Circle().fill(Klar.accent.opacity(0.22))
                    Circle().strokeBorder(Klar.accent, lineWidth: 1.5)
                } else if isOpen {
                    // Today is never open, so the ring cannot collide with the today pill.
                    Circle().strokeBorder(Klar.borderStrong, lineWidth: 1)
                }
                Text("\(day)")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(dayColor(isToday: isToday, isFuture: isFuture))

                if let substances {
                    // One dot per substance, at most three — the cell is 38 pt tall. On the today
                    // pill the colours would vanish into `Klar.text`, so they take the page colour.
                    HStack(spacing: 2) {
                        if substances.isEmpty {
                            dot(isToday ? Klar.bg : Klar.Palette.cyan600)
                        }
                        ForEach(Array(substances.prefix(3))) { substance in
                            dot(isToday ? Klar.bg : Klar.substanceColor(substance.colorIndex))
                        }
                    }
                    .offset(y: 11)
                }
            }
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityLabel(day: day, substances: substances) + (isOpen ? ", Rückblick offen" : ""))
        .accessibilityAddTraits(isSelected || (isToday && selectedDay == nil) ? .isSelected : [])
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 5, height: 5)
    }

    private func dayColor(isToday: Bool, isFuture: Bool) -> Color {
        // The today pill is filled with `Klar.text`, which flips with the scheme, so its
        // contents have to be the page colour rather than a literal white.
        if isToday { return Klar.bg }
        // Quieter than the past, but still readable. These used to be in the border colour,
        // which in dark mode all but vanished and left most of the month looking broken.
        return isFuture ? Klar.textTertiary : Klar.text
    }

    private func accessibilityLabel(day: Int, substances: [Substance]?) -> String {
        let base = "\(day). \(KlarDate.monthName(visibleMonth))"
        guard let substances else { return base + ", eintragsfrei" }
        let names = substances.map(\.name)
        return base + (names.isEmpty ? ", erfasst" : ", " + names.joined(separator: ", "))
    }

    private var legend: some View {
        KlarFlowLayout(spacing: 14) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Klar.borderStrong)
                    .frame(width: 10, height: 10)
                Text("Eintragsfrei")
            }
            ForEach(activeSubstances) { substance in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Klar.substanceColor(substance.colorIndex))
                        .frame(width: 10, height: 10)
                    Text(substance.name)
                }
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
