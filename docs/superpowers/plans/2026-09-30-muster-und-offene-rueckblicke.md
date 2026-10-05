# Muster tab and open reviews Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the morning-after answers a place (tab „Muster", day detail), let a missed day be answered for 72 h ("Offen"), move limits to Übersicht and Einstellungen, and fix the context distribution and the calendar dots.

**Architecture:** Pure rules (which days are open or answerable, which days a substance shares with others, `previousDayKey`) go into `KlarCore` and are tested with `swift test`. `KlarStore` bridges them to SwiftData. The auto-presented card remembers the last day it popped up for in `AppSettings` (device state, not user data), so no model or export change is needed. The UI is rebuilt from existing components: the Trends cards move into a new `PatternsView`, the `GoalCard` limit UI becomes a reusable `LimitEditor`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Charts, XCTest, iOS 26.5 simulator, Xcode 26.6.

**Spec:** [docs/superpowers/specs/2026-09-30-muster-und-offene-rueckblicke-design.md](../specs/2026-09-30-muster-und-offene-rueckblicke-design.md)

## Global Constraints

- Every file in `Packages/KlarCore/Sources` imports `Foundation` and nothing else.
- The Xcode project uses file-system-synchronized groups: new files under `Klar/Klar/`, `Klar/KlarTests/`, `Klar/KlarUITests/` are picked up without editing `project.pbxproj`. Moving a file is a plain `git mv`.
- UI copy is German and inline. Building may update `Klar/Klar/Localizable.xcstrings`; if it changed, add it to that task's commit.
- No praise, no colour coding of answers, no green/red, no badge or counter for open days (concept P7, P9).
- Answer labels: Körper „gut / angeschlagen / verkatert", Reue „nein / ein bisschen / ja", Nochmal so „ja / anders / nein".
- Pop-up expiry stays 48 h after the day ends (`MorningAfterService.expiry`). The answer window is 72 h (`MorningAfterService.answerWindow`). A logical day ends at 05:00 the next calendar day.
- Patterns need at least 3 answered days. Übersicht and the entry sheet count the newest 5. The Muster tab counts all.
- Export `schemaVersion` stays `2`.
- Commit messages follow the repo style (imperative subject, explanatory body) and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Work happens on branch `feat/muster-offen`.

**Commands used throughout** (the simulator id is the booted iPhone 17 Pro on iOS 26.5; `xcrun simctl list devices | grep "iPhone 17 Pro"` if it changes):

```bash
# KlarCore
swift test --package-path Packages/KlarCore
# App build
xcodebuild build -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -quiet
# App unit tests
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarTests -quiet
# UI tests
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -only-testing:KlarUITests -quiet
```

In later steps `xcodebuild test …` stands for the full destination line above.

Tasks 1 and 2 are the "small PR" from spec § 0. If they should ship on their own, open a PR after Task 2 and rebase the rest on it.

---

## File map

| File | Change | Responsibility |
|---|---|---|
| `Packages/KlarCore/Sources/KlarCore/StatsCalculator.swift` | modify | `taggedEntryCount` |
| `Packages/KlarCore/Sources/KlarCore/LogicalDay.swift` | modify | `previousDayKey` |
| `Packages/KlarCore/Sources/KlarCore/MorningAfterService.swift` | modify | `answerWindow`, `answerableDayKeys`, `openDayKeys`, `sharedDays` |
| `Klar/Klar/App/AppSettings.swift` | modify | `lastPresentedMorningDayKey` |
| `Klar/Klar/App/KlarDate.swift` | modify | `dayKey(forLogicalDay:)`, `date(fromDayKey:)` |
| `Klar/Klar/App/KlarStore.swift` | modify | `loggedSubstances`, open/answerable days, distribution, context patterns, shared days, reflections |
| `Klar/Klar/App/MorningPatternText.swift` | modify | `tally`, `answerLines`, `reflectionLines`, `sharedDaysText` |
| `Klar/Klar/App/MorningAnswerLabels.swift` | create | German labels of the answer enums |
| `Klar/Klar/App/RootView.swift` | modify | tab „Muster", auto-present once per day, shared substance selection |
| `Klar/Klar/Features/MorningAfter/MorningAfterCardView.swift` | modify | wording by distance, prefill, „Später" |
| `Klar/Klar/Features/MorningAfter/OpenMorningsCard.swift` | create | „Offen" list |
| `Klar/Klar/Features/MorningAfter/MorningAfterDayBlock.swift` | create | the day's review in the day detail |
| `Klar/Klar/Features/MorningAfter/MorningPatternsCard.swift` | modify | rows become buttons |
| `Klar/Klar/Features/Patterns/PatternsView.swift` | create | tab „Muster" |
| `Klar/Klar/Features/Patterns/FrequencyCard.swift` | create | Pro Woche, Ø Abstand |
| `Klar/Klar/Features/Patterns/DoseTrendCard.swift` | create (moved) | Ø Dosis über Zeit |
| `Klar/Klar/Features/Patterns/ContextDistributionCard.swift` | create (moved) | Kontext incl. consequences |
| `Klar/Klar/Features/Patterns/MorningDistributionCard.swift` | create | the three answer distributions |
| `Klar/Klar/Features/Patterns/ReflectionsCard.swift` | create | „Deine Sätze" |
| `Klar/Klar/Features/History/TrendsSectionView.swift` | delete | |
| `Klar/Klar/Features/History/HistoryView.swift` | modify | calendar only, Offen card, dots per substance, ring, day-detail block |
| `Klar/Klar/Features/Limits/LimitEditor.swift` | create | limit UI shared by the settings page and the Übersicht sheet |
| `Klar/Klar/Features/Limits/LimitSheet.swift` | create | sheet behind a quota card |
| `Klar/Klar/Features/Limits/LimitsView.swift`, `GoalCards.swift` | delete | |
| `Klar/Klar/Features/Limits/SubstitutionActionsView.swift` | move → `Features/Settings/` | |
| `Klar/Klar/Features/Settings/SubstancesView.swift` | create (moved out of `GoalCards.swift`) | substance list, `AddSubstanceSheet` |
| `Klar/Klar/Features/Settings/SubstanceSettingsView.swift` | create | per-substance page |
| `Klar/Klar/Features/Settings/SettingsView.swift` | modify | „Substanzen", group „Craving-SOS" |
| `Klar/Klar/Features/Today/TodayView.swift` | modify | Offen card, tappable quota and pattern rows |
| `Klar/Klar/Persistence/DemoDataSeeder.swift` | modify | Cannabis, open day, reflections |
| Tests | see tasks | |
| `docs/klar-screens-implementation.md`, `docs/klar-mvp-konzept.md` | modify | |

---

### Task 1: Context distribution divides by tagged entries

**Files:**
- Modify: `Packages/KlarCore/Sources/KlarCore/StatsCalculator.swift`
- Modify: `Klar/Klar/Features/History/TrendsSectionView.swift` (`ContextDistributionCard`, lines 202–259)
- Create: `Packages/KlarCore/Tests/KlarCoreTests/StatsCalculatorContextTests.swift`

**Interfaces:**
- Produces: `StatsSummary.taggedEntryCount: Int`

- [ ] **Step 1: Write the failing test**

Create `Packages/KlarCore/Tests/KlarCoreTests/StatsCalculatorContextTests.swift`:

```swift
import XCTest
@testable import KlarCore

final class StatsCalculatorContextTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()
    private let alone = UUID()
    private let home = UUID()

    private func entry(_ tags: [UUID]?, hour: Int) -> EntryDTO {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        let when = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: hour))!
        return EntryDTO(substanceID: alcohol, timestamp: when, timezoneID: berlin, amount: nil, contextTagIDs: tags)
    }

    private func summary(_ entries: [EntryDTO]) -> StatsSummary {
        StatsCalculator.summary(entries: entries, substanceID: alcohol, referenceTimezoneID: berlin)
    }

    /// „allein + zuhause" on one entry is one entry with context, not two — each tag is at 100 %.
    func testAnEntryWithTwoTagsCountsOnceInTheBase() {
        let result = summary([entry([alone, home], hour: 20)])
        XCTAssertEqual(result.taggedEntryCount, 1)
        XCTAssertEqual(result.contextTagDistribution[alone], 1)
        XCTAssertEqual(result.contextTagDistribution[home], 1)
    }

    func testEntriesWithoutContextAreNotInTheBase() {
        let result = summary([entry([alone], hour: 18), entry(nil, hour: 19), entry([], hour: 20)])
        XCTAssertEqual(result.taggedEntryCount, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/KlarCore --filter StatsCalculatorContextTests`
Expected: compile error, `value of type 'StatsSummary' has no member 'taggedEntryCount'`.

- [ ] **Step 3: Implement**

In `StatsCalculator.swift`, add the property to `StatsSummary` after `contextTagDistribution`:

```swift
    /// Entries of the substance with at least one context tag — the base the context
    /// distribution divides by. An entry with two tags counts once here and once per tag in
    /// `contextTagDistribution`, so the shares are per entry and need not add up to 100 %.
    public let taggedEntryCount: Int
```

In `summary(…)`, after the `tagCounts` loop:

```swift
        let taggedEntryCount = relevant.filter { !($0.contextTagIDs ?? []).isEmpty }.count
```

and pass it in the initializer, after `contextTagDistribution: tagCounts,`:

```swift
            taggedEntryCount: taggedEntryCount,
```

- [ ] **Step 4: Run the KlarCore tests**

Run: `swift test --package-path Packages/KlarCore`
Expected: all pass.

- [ ] **Step 5: Use the new base in the card**

In `TrendsSectionView.swift`, `ContextDistributionCard.distribution` becomes:

```swift
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
```

In `body`, after the `ForEach` inside the `else` branch, add:

```swift
                Text(summary.taggedEntryCount == 1
                     ? "Basis: 1 Eintrag mit Kontext"
                     : "Basis: \(summary.taggedEntryCount) Einträge mit Kontext")
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.top, 12)
```

- [ ] **Step 6: Build**

Run: the app build command.
Expected: `** BUILD SUCCEEDED **` (with `-quiet`, no error output).

- [ ] **Step 7: Commit**

```bash
git add Packages/KlarCore/Sources/KlarCore/StatsCalculator.swift Packages/KlarCore/Tests/KlarCoreTests/StatsCalculatorContextTests.swift Klar/Klar/Features/History/TrendsSectionView.swift
git commit -m "Divide the context distribution by entries with context

An entry tagged allein + zuhause counted twice in the base, so both tags
showed 50 %. The base is now the number of entries with at least one tag.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: One calendar dot per substance

**Files:**
- Modify: `Klar/Klar/App/KlarStore.swift:70-86` (`loggedDays`)
- Modify: `Klar/Klar/Features/History/HistoryView.swift` (`CalendarSectionView`)
- Test: `Klar/KlarTests/KlarStoreLogicalDayLookupTests.swift`

**Interfaces:**
- Produces: `KlarStore.loggedSubstances(inMonthOf: Date) -> [Date: [Substance]]`. `loggedDays(inMonthOf:)` keeps its signature.

- [ ] **Step 1: Write the failing test**

Append to `KlarStoreLogicalDayLookupTests`:

```swift
    func testLoggedSubstancesListsEachSubstanceOnceInSortOrder() throws {
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)   // sortOrder 0
        let cannabis = store.addSubstance(name: "Cannabis", unit: .g)     // sortOrder 1
        store.addEntry(substance: cannabis, timestamp: try date(2026, 8, 3, 20))
        store.addEntry(substance: alcohol, timestamp: try date(2026, 8, 3, 21))
        store.addEntry(substance: alcohol, timestamp: try date(2026, 8, 3, 23))

        let anchor = try date(2026, 8, 1, 0)
        let day = KlarDate.logicalDay(for: try date(2026, 8, 3, 21))
        XCTAssertEqual(store.loggedSubstances(inMonthOf: anchor)[day]?.map(\.name), ["Alkohol", "Cannabis"])
        XCTAssertEqual(store.loggedDays(inMonthOf: anchor), [day])
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test … -only-testing:KlarTests/KlarStoreLogicalDayLookupTests -quiet`
Expected: compile error, `value of type 'KlarStore' has no member 'loggedSubstances'`.

- [ ] **Step 3: Implement in the store**

Replace `loggedDays(inMonthOf:)` in `KlarStore.swift` with:

```swift
    /// Each logical day in `month` with an entry, and the substances logged on it — each once, in
    /// `sortOrder`. A day whose entries have no substance maps to an empty list. The calendar
    /// dots (E1).
    ///
    /// `date` is a month anchor from the calendar grid, so its calendar month is taken as given.
    /// Reading it through `monthComponents` instead would push a 00:00 anchor on the 1st back into
    /// the previous month, and the dots would then describe a different month than the grid drew.
    func loggedSubstances(inMonthOf date: Date) -> [Date: [Substance]] {
        let anchor = KlarDate.calendar.dateComponents([.year, .month], from: date)
        guard let year = anchor.year, let month = anchor.month else { return [:] }
        var byDay: [Date: [Substance]] = [:]
        for entry in allEntries() {
            let day = KlarDate.logicalDay(for: entry.timestamp, timezoneID: entry.timezoneID)
            let components = KlarDate.calendar.dateComponents([.year, .month], from: day)
            guard components.year == year && components.month == month else { continue }
            var substances = byDay[day, default: []]
            if let substance = entry.substance, !substances.contains(where: { $0.id == substance.id }) {
                substances.append(substance)
            }
            byDay[day] = substances
        }
        return byDay.mapValues { $0.sorted { $0.sortOrder < $1.sortOrder } }
    }

    /// The logical days in `month` that carry at least one entry.
    func loggedDays(inMonthOf date: Date) -> Set<Date> {
        Set(loggedSubstances(inMonthOf: date).keys)
    }
```

- [ ] **Step 4: Run the test**

Run: `xcodebuild test … -only-testing:KlarTests/KlarStoreLogicalDayLookupTests -quiet`
Expected: PASS.

- [ ] **Step 5: Draw the dots**

In `HistoryView.swift`, `CalendarSectionView`:

1. Remove `private var loggedDays: Set<Date> { … }`.
2. Add below `@Query private var entries: [Entry]`:

```swift
    @Query private var substances: [Substance]

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }
```

3. Replace `dayGrid`, `dayCell`, `accessibilityLabel` and `legend` with:

```swift
    private var dayGrid: some View {
        // Read once per render, not once per cell: every cell used to rescan all entries.
        let logged = store.loggedSubstances(inMonthOf: visibleMonth)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(cells) { cell in
                if let day = cell.day {
                    dayCell(day, logged: logged)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
    }

    private func dayCell(_ day: Int, logged: [Date: [Substance]]) -> some View {
        let date = dayDate(day)
        let substances = date.flatMap { logged[$0] }
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
        .accessibilityLabel(accessibilityLabel(day: day, substances: substances))
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 5, height: 5)
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
```

- [ ] **Step 6: Build and run the unit tests**

Run: the app build command, then `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: build succeeds, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Klar/Klar/App/KlarStore.swift Klar/Klar/Features/History/HistoryView.swift Klar/KlarTests/KlarStoreLogicalDayLookupTests.swift
git commit -m "Show one calendar dot per substance

A day with Alkohol and Cannabis showed the same single dot as a day with
one coffee. Each substance now gets a dot in its own colour, at most
three, and the legend names them.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Open days, answerable days and shared days in KlarCore

**Files:**
- Modify: `Packages/KlarCore/Sources/KlarCore/LogicalDay.swift`
- Modify: `Packages/KlarCore/Sources/KlarCore/MorningAfterService.swift`
- Create: `Packages/KlarCore/Tests/KlarCoreTests/PreviousDayKeyTests.swift`
- Create: `Packages/KlarCore/Tests/KlarCoreTests/OpenMorningDaysTests.swift`
- Create: `Packages/KlarCore/Tests/KlarCoreTests/SharedMorningDaysTests.swift`

**Interfaces:**
- Produces:
  - `LogicalDay.previousDayKey(_ key: String) -> String?`
  - `MorningAfterService.answerWindow: TimeInterval` (72 h)
  - `MorningAfterService.answerableDayKeys(entries: [EntryDTO], askingSubstanceIDs: Set<UUID>, now: Date, nowTimezoneID: String) -> Set<String>`
  - `MorningAfterService.openDayKeys(entries: [EntryDTO], askingSubstanceIDs: Set<UUID>, records: [MorningAfterDTO], now: Date, nowTimezoneID: String) -> [String]` (newest first)
  - `MorningAfterService.sharedDays(substanceID: UUID, askingSubstanceIDs: Set<UUID>, entries: [EntryDTO], records: [MorningAfterDTO]) -> [UUID: Int]`

- [ ] **Step 1: Write the failing tests**

`PreviousDayKeyTests.swift`:

```swift
import XCTest
@testable import KlarCore

final class PreviousDayKeyTests: XCTestCase {
    func testWithinAMonth() {
        XCTAssertEqual(LogicalDay.previousDayKey("2026-09-20"), "2026-09-19")
    }

    func testAcrossMonthAndYearBoundaries() {
        XCTAssertEqual(LogicalDay.previousDayKey("2026-03-01"), "2026-02-28")
        XCTAssertEqual(LogicalDay.previousDayKey("2028-03-01"), "2028-02-29")
        XCTAssertEqual(LogicalDay.previousDayKey("2026-01-01"), "2025-12-31")
    }

    func testRejectsSomethingThatIsNotAKey() {
        XCTAssertNil(LogicalDay.previousDayKey("gestern"))
    }
}
```

`OpenMorningDaysTests.swift`:

```swift
import XCTest
@testable import KlarCore

final class OpenMorningDaysTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()
    private let nicotine = UUID()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func entry(_ substance: UUID, _ when: Date) -> EntryDTO {
        EntryDTO(substanceID: substance, timestamp: when, timezoneID: berlin, amount: nil)
    }

    private func open(_ entries: [EntryDTO], records: [MorningAfterDTO] = [], now: Date) -> [String] {
        MorningAfterService.openDayKeys(
            entries: entries, askingSubstanceIDs: [alcohol], records: records, now: now, nowTimezoneID: berlin
        )
    }

    private func answerable(_ entries: [EntryDTO], now: Date) -> Set<String> {
        MorningAfterService.answerableDayKeys(
            entries: entries, askingSubstanceIDs: [alcohol], now: now, nowTimezoneID: berlin
        )
    }

    func testOpenUntilSeventyTwoHoursAfterTheDayEnds() {
        let entries = [entry(alcohol, date(2026, 9, 19, 22))] // day ends 2026-09-20 05:00
        XCTAssertEqual(open(entries, now: date(2026, 9, 23, 4, 59)), ["2026-09-19"])
        XCTAssertEqual(open(entries, now: date(2026, 9, 23, 5, 0)), [])
    }

    func testTodayIsNeverOpen() {
        XCTAssertEqual(open([entry(alcohol, date(2026, 9, 20, 9))], now: date(2026, 9, 20, 10)), [])
    }

    func testASwitchedOffSubstanceDoesNotCount() {
        XCTAssertEqual(open([entry(nicotine, date(2026, 9, 19, 21))], now: date(2026, 9, 20, 10)), [])
    }

    /// „Überspringen" takes the day off the list; the day detail can still answer it.
    func testASkipClosesTheDayButKeepsItAnswerable() {
        let entries = [entry(alcohol, date(2026, 9, 19, 21))]
        let skip = MorningAfterDTO(dayKey: "2026-09-19")
        XCTAssertEqual(open(entries, records: [skip], now: date(2026, 9, 20, 10)), [])
        XCTAssertEqual(answerable(entries, now: date(2026, 9, 20, 10)), ["2026-09-19"])
    }

    func testAnAnswerClosesTheDay() {
        let entries = [entry(alcohol, date(2026, 9, 19, 21))]
        let answer = MorningAfterDTO(dayKey: "2026-09-19", body: .fine)
        XCTAssertEqual(open(entries, records: [answer], now: date(2026, 9, 20, 10)), [])
    }

    /// Unlike `dueDayKey`, a newer day does not hide an older one here.
    func testSeveralOpenDaysComeNewestFirst() {
        let entries = [entry(alcohol, date(2026, 9, 18, 21)), entry(alcohol, date(2026, 9, 19, 21))]
        XCTAssertEqual(open(entries, now: date(2026, 9, 20, 10)), ["2026-09-19", "2026-09-18"])
    }

    func testAnEntryAtHalfPastTwoBelongsToThePreviousDay() {
        XCTAssertEqual(open([entry(alcohol, date(2026, 9, 20, 2, 30))], now: date(2026, 9, 20, 10)), ["2026-09-19"])
    }
}
```

`SharedMorningDaysTests.swift`:

```swift
import XCTest
@testable import KlarCore

final class SharedMorningDaysTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()
    private let cannabis = UUID()
    private let coffee = UUID()

    private func entry(_ substance: UUID, day: Int) -> EntryDTO {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        let when = calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 21))!
        return EntryDTO(substanceID: substance, timestamp: when, timezoneID: berlin, amount: nil)
    }

    private func key(_ day: Int) -> String { String(format: "2026-09-%02d", day) }

    func testCountsAnsweredDaysWithOtherAskingSubstancesOnly() {
        let entries = [
            entry(alcohol, day: 1), entry(cannabis, day: 1),   // answered, shared
            entry(alcohol, day: 2), entry(coffee, day: 2),     // answered, coffee does not ask
            entry(alcohol, day: 3), entry(cannabis, day: 3),   // skipped
            entry(cannabis, day: 4)                            // no alcohol
        ]
        let records = [
            MorningAfterDTO(dayKey: key(1), body: .rough),
            MorningAfterDTO(dayKey: key(2), body: .fine),
            MorningAfterDTO(dayKey: key(3)),
            MorningAfterDTO(dayKey: key(4), body: .fine)
        ]

        let shared = MorningAfterService.sharedDays(
            substanceID: alcohol, askingSubstanceIDs: [alcohol, cannabis], entries: entries, records: records
        )

        XCTAssertEqual(shared, [cannabis: 1])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KlarCore`
Expected: compile errors for `previousDayKey`, `openDayKeys`, `answerableDayKeys`, `sharedDays`.

- [ ] **Step 3: Implement `previousDayKey`**

In `LogicalDay.swift`, after `end(ofDayKey:timezoneID:)`:

```swift
    /// The key of the calendar day before `key`. Pure date arithmetic in UTC, so no DST shift can
    /// land it on the wrong day.
    public static func previousDayKey(_ key: String) -> String? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let calendar = calendar(for: "UTC")
        guard let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let previous = calendar.date(byAdding: .day, value: -1, to: day)
        else { return nil }
        let components = calendar.dateComponents([.year, .month, .day], from: previous)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
```

- [ ] **Step 4: Implement the service functions**

In `MorningAfterService.swift`, below `expiry`:

```swift
    /// How long after a logical day ends it can still be answered — from „Offen" or the day
    /// detail. Longer than `expiry`, which only governs the card popping up by itself.
    public static let answerWindow: TimeInterval = 72 * 60 * 60
```

Replace the entry loop in `dueDayKey` with a call to a shared helper. The function becomes:

```swift
    public static func dueDayKey(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        records: [MorningAfterDTO],
        now: Date,
        nowTimezoneID: String
    ) -> String? {
        let todayKey = LogicalDay.dayKey(for: now, timezoneID: nowTimezoneID)
        let latestEntryByDay = latestAskingEntryByDay(entries: entries, askingSubstanceIDs: askingSubstanceIDs, before: todayKey)

        guard let candidate = latestEntryByDay.keys.max(),
              let latest = latestEntryByDay[candidate],
              !records.contains(where: { $0.dayKey == candidate }),
              let end = LogicalDay.end(ofDayKey: candidate, timezoneID: latest.timezoneID),
              now < end.addingTimeInterval(expiry)
        else { return nil }

        return candidate
    }

    /// Days before today with an entry of an asking substance that ended less than
    /// `answerWindow` ago — with or without a record.
    public static func answerableDayKeys(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        now: Date,
        nowTimezoneID: String
    ) -> Set<String> {
        let todayKey = LogicalDay.dayKey(for: now, timezoneID: nowTimezoneID)
        let latestEntryByDay = latestAskingEntryByDay(entries: entries, askingSubstanceIDs: askingSubstanceIDs, before: todayKey)
        return Set(latestEntryByDay.compactMap { key, latest -> String? in
            guard let end = LogicalDay.end(ofDayKey: key, timezoneID: latest.timezoneID),
                  now < end.addingTimeInterval(answerWindow)
            else { return nil }
            return key
        })
    }

    /// „Offen": answerable days with no record at all, newest first. A skip record takes a day
    /// off this list; a newer day does not.
    public static func openDayKeys(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        records: [MorningAfterDTO],
        now: Date,
        nowTimezoneID: String
    ) -> [String] {
        let recorded = Set(records.map(\.dayKey))
        return answerableDayKeys(entries: entries, askingSubstanceIDs: askingSubstanceIDs, now: now, nowTimezoneID: nowTimezoneID)
            .subtracting(recorded)
            .sorted(by: >)
    }

    /// For the answered days of `substanceID`: how many of them also carry an entry of each other
    /// asking substance. Substances that don't ask are left out — the user said they have
    /// nothing to do with the day after.
    public static func sharedDays(
        substanceID: UUID,
        askingSubstanceIDs: Set<UUID>,
        entries: [EntryDTO],
        records: [MorningAfterDTO]
    ) -> [UUID: Int] {
        var substancesByDay: [String: Set<UUID>] = [:]
        for entry in entries {
            guard let id = entry.substanceID else { continue }
            substancesByDay[LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID), default: []].insert(id)
        }

        var counts: [UUID: Int] = [:]
        for record in records where record.isAnswered {
            guard let present = substancesByDay[record.dayKey], present.contains(substanceID) else { continue }
            for other in present where other != substanceID && askingSubstanceIDs.contains(other) {
                counts[other, default: 0] += 1
            }
        }
        return counts
    }

    /// The latest entry of an asking substance on each logical day before `todayKey`. Its
    /// timezone decides when that day ends.
    private static func latestAskingEntryByDay(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        before todayKey: String
    ) -> [String: EntryDTO] {
        var latest: [String: EntryDTO] = [:]
        for entry in entries {
            guard let substanceID = entry.substanceID, askingSubstanceIDs.contains(substanceID) else { continue }
            let key = LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID)
            guard key < todayKey else { continue }
            if let known = latest[key], known.timestamp >= entry.timestamp { continue }
            latest[key] = entry
        }
        return latest
    }
```

- [ ] **Step 5: Run the KlarCore tests**

Run: `swift test --package-path Packages/KlarCore`
Expected: all pass, including the existing `MorningAfterDueDayTests` (the refactor must not change `dueDayKey`).

- [ ] **Step 6: Commit**

```bash
git add Packages/KlarCore
git commit -m "Add open, answerable and shared morning-after days to KlarCore

A day stays answerable for 72 h after it ends. Open days are those
without any record, newest first; a newer day no longer hides an older
one there. sharedDays counts, per answered day, the other asking
substances logged that day.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Store the open days and the last auto-presented day

**Files:**
- Modify: `Klar/Klar/App/AppSettings.swift`
- Modify: `Klar/Klar/App/KlarStore.swift` (section „Der Morgen danach", lines 155–245)
- Modify: `Klar/Klar/App/KlarDate.swift`
- Test: `Klar/KlarTests/KlarStoreMorningAfterTests.swift`
- Create: `Klar/KlarTests/AppSettingsTests.swift`
- Create: `Klar/KlarTests/KlarDateDayKeyTests.swift`

**Interfaces:**
- Consumes: `MorningAfterService.openDayKeys`, `answerableDayKeys` (Task 3)
- Produces:
  - `AppSettings.lastPresentedMorningDayKey: String?`
  - `KlarStore.openMorningAfterDays(now: Date = Date()) -> [String]`
  - `KlarStore.canAnswerMorningAfter(dayKey: String, now: Date = Date()) -> Bool`
  - `KlarDate.dayKey(forLogicalDay: Date) -> String`
  - `KlarDate.date(fromDayKey: String) -> Date?`

- [ ] **Step 1: Write the failing tests**

Append to `KlarStoreMorningAfterTests` (it already has `makeStore()` and `yesterdayEvening()`):

```swift
    private func evening(daysAgo: Int) -> Date {
        let today = KlarDate.logicalDay(for: Date())
        let day = KlarDate.calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return KlarDate.calendar.date(bySettingHour: 21, minute: 0, second: 0, of: day)!
    }

    func testYesterdayStaysOpenUntilItHasARecord() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let entry = store.addEntry(substance: alcohol, timestamp: yesterdayEvening())
        let key = LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID)

        XCTAssertEqual(store.openMorningAfterDays(), [key])

        store.skipMorningAfter(dayKey: key)
        XCTAssertEqual(store.openMorningAfterDays(), [])
        XCTAssertTrue(store.canAnswerMorningAfter(dayKey: key), "a skipped day can still be answered from the day detail")
    }

    func testAnsweringASkippedDayTurnsTheSkipIntoAnAnswer() throws {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let entry = store.addEntry(substance: alcohol, timestamp: yesterdayEvening())
        let key = LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID)

        store.skipMorningAfter(dayKey: key)
        store.recordMorningAfter(dayKey: key, body: .rough, regret: nil, again: nil, note: nil)

        XCTAssertEqual(store.allMorningAfters().count, 1)
        XCTAssertEqual(try XCTUnwrap(store.morningAfter(forDayKey: key)).body, .rough)
    }

    func testADayFiveDaysAgoCanNoLongerBeAnswered() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let entry = store.addEntry(substance: alcohol, timestamp: evening(daysAgo: 5))
        let key = LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID)

        XCTAssertFalse(store.canAnswerMorningAfter(dayKey: key))
        XCTAssertEqual(store.openMorningAfterDays(), [])
    }
```

`Klar/KlarTests/AppSettingsTests.swift`:

```swift
import XCTest
@testable import Klar

@MainActor
final class AppSettingsTests: XCTestCase {
    func testTheLastPresentedMorningDaySurvivesARelaunch() throws {
        let suite = "klar.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertNil(settings.lastPresentedMorningDayKey)

        settings.lastPresentedMorningDayKey = "2026-09-19"
        XCTAssertEqual(AppSettings(defaults: defaults).lastPresentedMorningDayKey, "2026-09-19")
    }
}
```

`Klar/KlarTests/KlarDateDayKeyTests.swift`:

```swift
import XCTest
@testable import Klar

final class KlarDateDayKeyTests: XCTestCase {
    /// A normalized logical day is 00:00. Going through `LogicalDay.dayKey(for:)` would apply the
    /// 05:00 cutoff to it and land on the day before.
    func testALogicalDayKeepsItsDate() throws {
        let day = try XCTUnwrap(KlarDate.calendar.date(from: DateComponents(year: 2026, month: 9, day: 19)))
        XCTAssertEqual(KlarDate.dayKey(forLogicalDay: day), "2026-09-19")
    }

    func testAKeyRoundTrips() throws {
        let day = try XCTUnwrap(KlarDate.date(fromDayKey: "2026-02-28"))
        XCTAssertEqual(KlarDate.dayKey(forLogicalDay: day), "2026-02-28")
        XCTAssertNil(KlarDate.date(fromDayKey: "nope"))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: compile errors for `openMorningAfterDays`, `canAnswerMorningAfter`, `lastPresentedMorningDayKey`, `dayKey(forLogicalDay:)`, `date(fromDayKey:)`.

- [ ] **Step 3: Implement `AppSettings`**

In `init`, after `supportContactPhone`:

```swift
        self.lastPresentedMorningDayKey = defaults.string(forKey: Keys.lastPresentedMorningDayKey)
```

After `supportContactPhone`'s property:

```swift
    /// The last day „Der Morgen danach" presented itself for. The card pops up once per day;
    /// after that the day is reachable from „Offen" and the day detail only. Device state: after
    /// an import on a new phone the card may pop up once more, which is harmless.
    var lastPresentedMorningDayKey: String? {
        didSet { defaults.set(lastPresentedMorningDayKey, forKey: Keys.lastPresentedMorningDayKey) }
    }
```

In `Keys`:

```swift
        static let lastPresentedMorningDayKey = "klar.lastPresentedMorningDayKey"
```

- [ ] **Step 4: Implement `KlarDate` helpers**

In `KlarDate.swift`, after `logicalDay(for:timezoneID:)`:

```swift
    /// The morning-after key of a normalized logical day (00:00), as the calendar grid and the
    /// day detail hold it. Not `LogicalDay.dayKey(for:)`, which would apply the cutoff again.
    static func dayKey(forLogicalDay day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// The normalized logical day a morning-after key names.
    static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
```

- [ ] **Step 5: Implement the store**

In `KlarStore.swift`, section „Der Morgen danach", add above `dueMorningAfterDay`:

```swift
    /// Substances whose days the card asks about. Archived substances still count: their
    /// entries happened.
    private var askingSubstanceIDs: Set<UUID> {
        Set(allSubstances(includeArchived: true).filter(\.asksMorningAfter).map(\.id))
    }
```

In `dueMorningAfterDay`, replace the local `asking` with `askingSubstanceIDs`. Then add after it:

```swift
    /// „Offen": days that can still be answered and have no record, newest first.
    func openMorningAfterDays(now: Date = Date()) -> [String] {
        MorningAfterService.openDayKeys(
            entries: allEntries().map { $0.toDTO() },
            askingSubstanceIDs: askingSubstanceIDs,
            records: allMorningAfters().map { $0.toDTO() },
            now: now,
            nowTimezoneID: KlarDate.timezoneID
        )
    }

    /// Whether the day detail may answer or edit `dayKey` — skipped days included.
    func canAnswerMorningAfter(dayKey: String, now: Date = Date()) -> Bool {
        MorningAfterService.answerableDayKeys(
            entries: allEntries().map { $0.toDTO() },
            askingSubstanceIDs: askingSubstanceIDs,
            now: now,
            nowTimezoneID: KlarDate.timezoneID
        ).contains(dayKey)
    }
```

- [ ] **Step 6: Run the unit tests**

Run: `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Klar/Klar/App/AppSettings.swift Klar/Klar/App/KlarStore.swift Klar/Klar/App/KlarDate.swift Klar/KlarTests/KlarStoreMorningAfterTests.swift Klar/KlarTests/AppSettingsTests.swift Klar/KlarTests/KlarDateDayKeyTests.swift
git commit -m "Expose open and answerable morning-after days from the store

Adds the device setting that remembers which day the card last popped up
for, and day-key helpers for normalized logical days.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The card pops up once, offers „Später" and speaks about the right day

**Files:**
- Create: `Klar/Klar/App/MorningAnswerLabels.swift`
- Modify: `Klar/Klar/Features/MorningAfter/MorningAfterCardView.swift`
- Modify: `Klar/Klar/App/RootView.swift` (`MainTabView`)
- Test: `Klar/KlarTests/MainTabViewMorningGuardTests.swift`
- Create: `Klar/KlarTests/MorningAfterCardWordingTests.swift`
- Test: `Klar/KlarUITests/MorningAfterUITests.swift`

**Interfaces:**
- Consumes: `LogicalDay.previousDayKey` (Task 3), `AppSettings.lastPresentedMorningDayKey` (Task 4)
- Produces:
  - `MorningBody.label`, `MorningRegret.label`, `MorningAgain.label: String`
  - `MorningAfterCardView.Wording(dayKey:now:timezoneID:)` with `isAboutYesterday`, `bodyQuestion`, `regretQuestion`, `static againQuestion`
  - `MainTabView.shouldPresentMorning(isLocked:isEntrySheetPresented:dueMorning:dueKey:lastPresentedKey:) -> Bool`
  - `DueMorning` (unchanged, reused by Tasks 9 and 10 to present the card manually)

- [ ] **Step 1: Write the failing tests**

Add `lastPresentedKey: nil` to every existing call in the guard tests:

```bash
sed -i '' -E 's/(dueKey: ("[0-9-]+"|nil))$/\1, lastPresentedKey: nil/' Klar/KlarTests/MainTabViewMorningGuardTests.swift
```

Then append to `MainTabViewMorningGuardTests`:

```swift
    /// The card pops up by itself once per day; after „Später" it waits in „Offen".
    func testDoesNotPresentTheSameDayTwice() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-20", lastPresentedKey: "2026-09-20"
        ))
    }

    func testPresentsANewDayAfterAnOlderOneWasShown() {
        XCTAssertTrue(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-20", lastPresentedKey: "2026-09-19"
        ))
    }
```

`Klar/KlarTests/MorningAfterCardWordingTests.swift`:

```swift
import XCTest
@testable import Klar

final class MorningAfterCardWordingTests: XCTestCase {
    private let berlin = "Europe/Berlin"

    private func date(_ d: Int, _ h: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: d, hour: h))!
    }

    func testTheMorningAfterSaysTodayAndYesterday() {
        let wording = MorningAfterCardView.Wording(dayKey: "2026-09-19", now: date(20, 10), timezoneID: berlin)
        XCTAssertTrue(wording.isAboutYesterday)
        XCTAssertEqual(wording.bodyQuestion, "Wie geht's dir heute körperlich?")
        XCTAssertEqual(wording.regretQuestion, "Bereust du etwas von gestern?")
    }

    func testALaterAnswerSpeaksOfTheDayAfter() {
        let wording = MorningAfterCardView.Wording(dayKey: "2026-09-18", now: date(20, 10), timezoneID: berlin)
        XCTAssertFalse(wording.isAboutYesterday)
        XCTAssertEqual(wording.bodyQuestion, "Wie ging's dir am Tag danach körperlich?")
        XCTAssertEqual(wording.regretQuestion, "Bereust du etwas von dem Tag?")
    }

    /// At 03:00 on the 20th it is still logically the 19th, so the 18th is „gestern".
    func testBeforeTheCutoffYesterdayIsTheDayBeforeTheLogicalToday() {
        XCTAssertTrue(MorningAfterCardView.Wording(dayKey: "2026-09-18", now: date(20, 3), timezoneID: berlin).isAboutYesterday)
    }
}
```

Append to `MorningAfterUITests`:

```swift
    /// „Später" leaves the day open, and the card does not pop up again by itself.
    @MainActor
    func testLaterKeepsTheCardFromPoppingUpAgain() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--klar-uitest-seed-yesterday"]
        app.launch()

        XCTAssertTrue(app.staticTexts["morningAfter.header"].waitForExistence(timeout: 10))
        app.buttons["Später"].tap()
        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5))

        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["Übersicht"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.staticTexts["morningAfter.header"].waitForExistence(timeout: 3))
    }
```

- [ ] **Step 2: Run the unit tests to verify they fail**

Run: `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: compile errors, `extra argument 'lastPresentedKey'` and `type 'MorningAfterCardView' has no member 'Wording'`.

- [ ] **Step 3: Add the answer labels**

`Klar/Klar/App/MorningAnswerLabels.swift`:

```swift
import KlarCore

// The words each answer is shown with — on the card, in the Muster tab and in the day detail.
// Kept in one place so a label can never read differently in two spots.

extension MorningBody {
    var label: String {
        switch self {
        case .fine: "gut"
        case .rough: "angeschlagen"
        case .hungover: "verkatert"
        }
    }
}

extension MorningRegret {
    var label: String {
        switch self {
        case .no: "nein"
        case .slightly: "ein bisschen"
        case .yes: "ja"
        }
    }
}

extension MorningAgain {
    var label: String {
        switch self {
        case .yes: "ja"
        case .differently: "anders"
        case .no: "nein"
        }
    }
}
```

- [ ] **Step 4: Rewrite the card**

Replace `Klar/Klar/Features/MorningAfter/MorningAfterCardView.swift` with:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// „Der Morgen danach" (concept v3, module C).
///
/// Asks about one logical day. It pops up by itself once (see `MainTabView`); after that the
/// same card opens from „Offen" and the day detail, for up to 72 h after the day ended, and shows
/// what was already answered. Everything is optional and nothing is judged: no option is
/// coloured, a good morning is not praised and a bad one is not commented on (P7, P8).
struct MorningAfterCardView: View {
    let dayKey: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var bodyAnswer: MorningBody?
    @State private var regretAnswer: MorningRegret?
    @State private var againAnswer: MorningAgain?
    @State private var note = ""
    @State private var isNoteOpen = false
    @State private var isReflecting = false
    /// The record is read once. Reading it again when the reflection cover closes would throw
    /// away whatever was tapped in the meantime.
    @State private var hasLoaded = false

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var dayEntries: [Entry] { store.entries(onDayKey: dayKey) }
    private var wording: Wording { Wording(dayKey: dayKey, now: Date(), timezoneID: KlarDate.timezoneID) }

    private var header: String {
        guard let first = dayEntries.first else { return "Der Morgen danach" }
        let day = KlarDate.logicalDay(for: first.timestamp, timezoneID: first.timezoneID)
        let label = wording.isAboutYesterday ? KlarDate.weekdayName(day) : KlarDate.shortWeekdayDate(day)
        return "Der Morgen danach · \(label)"
    }

    /// The day's substances, then its context tags, each once, in the order they were logged.
    private var chips: [String] {
        var seen: Set<String> = []
        let names = dayEntries.compactMap { $0.substance?.name }
            + dayEntries.flatMap { ($0.contextTags ?? []).map(\.name) }
        return names.filter { seen.insert($0).inserted }
    }

    var body: some View {
        ZStack {
            Color(hex: 0x15272B).opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text(header)
                    .font(Klar.TypeScale.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Klar.textTertiary)
                    .accessibilityIdentifier("morningAfter.header")
                    .padding(.bottom, 10)

                if !chips.isEmpty {
                    KlarFlowLayout(spacing: 6) {
                        ForEach(chips, id: \.self) { KlarChip(text: $0, compact: true) }
                    }
                    .padding(.bottom, 18)
                }

                VStack(alignment: .leading, spacing: 16) {
                    AnswerRow(
                        question: wording.bodyQuestion,
                        options: MorningBody.allCases.map { ($0, $0.label) },
                        selection: $bodyAnswer
                    )
                    AnswerRow(
                        question: wording.regretQuestion,
                        options: MorningRegret.allCases.map { ($0, $0.label) },
                        selection: $regretAnswer
                    )
                    AnswerRow(
                        question: Wording.againQuestion,
                        options: MorningAgain.allCases.map { ($0, $0.label) },
                        selection: $againAnswer
                    )
                }

                if regretAnswer == .yes {
                    KlarInlineButton(title: "Kurz drüber nachdenken", systemImage: "lightbulb") {
                        save()
                        isReflecting = true
                    }
                    .padding(.top, 14)
                }

                if isNoteOpen {
                    TextField("Notiz (optional)", text: $note, axis: .vertical)
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(Klar.bgSubtle, in: RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                        .padding(.top, 16)
                } else {
                    KlarInlineButton(title: "Notiz hinzufügen", systemImage: "plus", tint: Klar.textSecondary) {
                        isNoteOpen = true
                    }
                    .padding(.top, 14)
                }

                VStack(spacing: 10) {
                    KlarPrimaryButton(title: "Fertig") {
                        save()
                        dismiss()
                    }
                    // „Später" writes nothing: the day stays in „Offen". „Überspringen" takes it
                    // off that list; the day detail can still answer it.
                    HStack(spacing: 10) {
                        KlarQuietButton(title: "Später") {
                            dismiss()
                        }
                        KlarQuietButton(title: "Überspringen") {
                            store.skipMorningAfter(dayKey: dayKey)
                            dismiss()
                        }
                    }
                }
                .padding(.top, 22)
            }
            .padding(24)
            .background(Klar.surface)
            .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.xl, style: .continuous))
            .klarShadow(Klar.Shadow.lg)
            .padding(22)
        }
        .presentationBackground(.clear)
        .sensoryFeedback(.selection, trigger: [bodyAnswer?.rawValue, regretAnswer?.rawValue, againAnswer?.rawValue])
        .onAppear(perform: loadExistingAnswers)
        .fullScreenCover(isPresented: $isReflecting) {
            MorningReflectionView(dayKey: dayKey) { dismiss() }
        }
    }

    private func loadExistingAnswers() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let record = store.morningAfter(forDayKey: dayKey) else { return }
        bodyAnswer = record.body
        regretAnswer = record.regret
        againAnswer = record.again
        note = record.note ?? ""
        isNoteOpen = !note.isEmpty
    }

    private func save() {
        store.recordMorningAfter(dayKey: dayKey, body: bodyAnswer, regret: regretAnswer, again: againAnswer, note: note)
    }
}

extension MorningAfterCardView {
    /// „heute" and „gestern" only when it really is the morning after. Answered later — from
    /// „Offen" or the day detail — the questions speak of „dem Tag danach".
    struct Wording: Equatable {
        let isAboutYesterday: Bool

        init(dayKey: String, now: Date, timezoneID: String) {
            isAboutYesterday = LogicalDay.previousDayKey(LogicalDay.dayKey(for: now, timezoneID: timezoneID)) == dayKey
        }

        var bodyQuestion: String {
            isAboutYesterday ? "Wie geht's dir heute körperlich?" : "Wie ging's dir am Tag danach körperlich?"
        }

        var regretQuestion: String {
            isAboutYesterday ? "Bereust du etwas von gestern?" : "Bereust du etwas von dem Tag?"
        }

        static let againQuestion = "Würdest du es wieder so machen?"
    }
}

/// A question over a three-way control with nothing preselected. Tapping the selected option
/// again clears it, the same rule as the mood control in the entry sheet.
private struct AnswerRow<Value: Hashable>: View {
    let question: String
    let options: [(value: Value, label: String)]
    @Binding var selection: Value?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textSecondary)
            KlarSegmentedControl(
                options: options.map { (value: Optional($0.value), label: $0.label) },
                selection: Binding(
                    get: { selection },
                    set: { selection = ($0 == selection) ? nil : $0 }
                )
            )
        }
    }
}
```

- [ ] **Step 5: Pop up once per day**

In `RootView.swift`, `MainTabView`:

1. Delete `@State private var presentedMorningKey: String?` and its doc comment.
2. Replace the morning `.sheet` with:

```swift
        // Dismissing writes nothing: swiping the card away is „Später", and the day waits in
        // „Offen". Only the card's own „Überspringen" records a skip.
        .sheet(item: $dueMorning) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
        }
```

3. Replace `presentDueMorning()` and `shouldPresentMorning` with:

```swift
    private func presentDueMorning() {
        // Never above the lock screen: a `.sheet` draws in its own window, in front of
        // `RootView`'s `.overlay`, so presenting here while locked would make the card readable
        // without unlocking. (Pre-existing, out of scope: a sheet already open when the app
        // backgrounds sits above the lock too — that needs a window-level lock, not this guard.)
        let dueKey = store.dueMorningAfterDay()
        guard Self.shouldPresentMorning(
            isLocked: isLocked,
            isEntrySheetPresented: isEntrySheetPresented,
            dueMorning: dueMorning,
            dueKey: dueKey,
            lastPresentedKey: settings.lastPresentedMorningDayKey
        ) else { return }
        settings.lastPresentedMorningDayKey = dueKey
        dueMorning = dueKey.map(DueMorning.init)
    }

    /// Pulled out of `presentDueMorning()` so the guard is testable without `AppLockManager`'s
    /// Face ID plumbing or a real `TabView`. A day the card already popped up for is not
    /// presented again — P9: every question is asked by itself once.
    static func shouldPresentMorning(
        isLocked: Bool,
        isEntrySheetPresented: Bool,
        dueMorning: DueMorning?,
        dueKey: String?,
        lastPresentedKey: String?
    ) -> Bool {
        !isLocked && dueMorning == nil && !isEntrySheetPresented && dueKey != nil && dueKey != lastPresentedKey
    }
```

- [ ] **Step 6: Run unit and morning UI tests**

Run: `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: all pass.

Run: `xcodebuild test … -only-testing:KlarUITests/MorningAfterUITests -quiet`
Expected: all three tests pass.

- [ ] **Step 7: Commit**

```bash
git add Klar/Klar/App/MorningAnswerLabels.swift Klar/Klar/Features/MorningAfter/MorningAfterCardView.swift Klar/Klar/App/RootView.swift Klar/KlarTests/MainTabViewMorningGuardTests.swift Klar/KlarTests/MorningAfterCardWordingTests.swift Klar/KlarUITests/MorningAfterUITests.swift
git commit -m "Let the morning-after card wait instead of losing the day

Swiping the card away used to skip the day for good. It now means
„Später": the card does not pop up again by itself, and the day stays
answerable. The card prefills existing answers and speaks of „dem Tag
danach" when it is answered later than the next morning.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Limits and substances in Einstellungen

**Files:**
- Create: `Klar/Klar/Features/Limits/LimitEditor.swift`
- Modify: `Klar/Klar/Features/Limits/GoalCards.swift` (GoalCard uses `LimitEditor`; `SubstancesView`, `SubstanceRow`, `AddSubstanceSheet` move out)
- Create: `Klar/Klar/Features/Settings/SubstancesView.swift`
- Create: `Klar/Klar/Features/Settings/SubstanceSettingsView.swift`
- Move: `Klar/Klar/Features/Limits/SubstitutionActionsView.swift` → `Klar/Klar/Features/Settings/SubstitutionActionsView.swift`
- Modify: `Klar/Klar/Features/Settings/SettingsView.swift`
- Create: `Klar/KlarTests/SubstanceSubtitleTests.swift`

**Interfaces:**
- Consumes: `KlarStore.currentGoal(for:)`, `isGoalPaused(for:)`, `setGoal(for:type:monthlyLimit:)`, `pauseGoal(for:)`, `setAsksMorningAfter(_:for:)`, `archiveSubstance(_:)`
- Produces:
  - `LimitEditor(substance: Substance, store: KlarStore)`: a view without its own card
  - `SubstanceSettingsView(substance: Substance)`
  - `SubstancesView.subtitle(for: Substance, store: KlarStore) -> String`
  - Accessibility identifiers `settings.substances`, `settings.substance.<name>`, `settings.substitutions`, `settings.asksMorningAfter.<name>`

- [ ] **Step 1: Write the failing test**

`Klar/KlarTests/SubstanceSubtitleTests.swift`:

```swift
import XCTest
@testable import Klar

@MainActor
final class SubstanceSubtitleTests: XCTestCase {
    private func makeStore() -> KlarStore {
        KlarStore(context: TestModelContainer.makeInMemoryContext())
    }

    func testReductionShowsTheLimitAndTheMorningSwitch() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.setGoal(for: alcohol, type: .reduction, monthlyLimit: 4)
        XCTAssertEqual(SubstancesView.subtitle(for: alcohol, store: store), "max. 4 / Monat · Morgen danach")
    }

    func testNoGoalReadsAsObservingAndNicotineDoesNotAsk() {
        let store = makeStore()
        let nicotine = store.addSubstance(name: "Nikotin", unit: .piece)
        XCTAssertEqual(SubstancesView.subtitle(for: nicotine, store: store), "Beobachten")
    }

    func testAPausedGoalSaysSo() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.setGoal(for: alcohol, type: .abstinence, monthlyLimit: nil)
        store.pauseGoal(for: alcohol)
        XCTAssertEqual(SubstancesView.subtitle(for: alcohol, store: store), "Pausiert · Morgen danach")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test … -only-testing:KlarTests/SubstanceSubtitleTests -quiet`
Expected: compile error, `type 'SubstancesView' has no member 'subtitle'`.

- [ ] **Step 3: Extract `LimitEditor`**

Create `Klar/Klar/Features/Limits/LimitEditor.swift`. The body is `GoalCard`'s body from `switch (isPaused, goal?.type)` through the „Ziel pausieren" button, moved verbatim. The name row becomes a „Grenze" label with the badge, and the card and the morning toggle are left out:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// One substance's limit: Reduktion with a monthly stepper, Abstinenz or Beobachten, and pausing.
/// No card of its own — the substance page in Einstellungen and the sheet behind a quota card on
/// Übersicht each put it in one.
///
/// Every change *versions* the goal rather than overwriting it (see `KlarStore.setGoal`), so a
/// past month keeps the limit that was actually in force at the time. The store is not
/// observable: the view hosting this must `@Query` the goal periods, or it will not redraw.
struct LimitEditor: View {
    let substance: Substance
    let store: KlarStore

    @State private var monthlyLimit: Int = 4

    private var goal: GoalPeriod? { store.currentGoal(for: substance) }
    private var isPaused: Bool { store.isGoalPaused(for: substance) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                KlarSectionLabel(text: "Grenze")
                Spacer()
                statusBadge
            }
            .padding(.bottom, goal?.type == .reduction ? 12 : 6)

            switch (isPaused, goal?.type) {
            case (true, _):
                Text("Zieltyp wechseln oder fortsetzen.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)

            case (false, .reduction):
                KlarStepper(label: "Limit / Monat", value: $monthlyLimit, range: 1...30)
                    .onChange(of: monthlyLimit) { _, newValue in
                        store.setGoal(for: substance, type: .reduction, monthlyLimit: newValue)
                    }

            case (false, .abstinence):
                Text("Abstinenz. Einträge werden weiterhin ohne Wertung erfasst.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)

            default:
                Text("Kein Limit gesetzt.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }

            Divider()
                .overlay(Klar.borderSubtle)
                .padding(.vertical, 14)

            KlarSegmentedControl(
                options: [
                    (GoalType.reduction, "Reduktion"),
                    (GoalType.abstinence, "Abstinenz"),
                    (GoalType.observe, "Beobachten")
                ],
                selection: Binding(
                    get: { goal?.type ?? .observe },
                    set: { newType in
                        store.setGoal(
                            for: substance,
                            type: newType,
                            monthlyLimit: newType == .reduction ? monthlyLimit : nil
                        )
                    }
                )
            )

            if !isPaused, goal != nil {
                Button("Ziel pausieren") {
                    store.pauseGoal(for: substance)
                }
                .font(Klar.TypeScale.bodySmall.weight(.semibold))
                .foregroundStyle(Klar.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            }
        }
        .task {
            monthlyLimit = goal?.monthlyLimit ?? 4
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isPaused {
            Text("Pausiert")
                .font(Klar.TypeScale.caption)
                .foregroundStyle(Klar.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Klar.surfaceTint, in: Capsule())
        } else if let type = goal?.type {
            Text(type.germanLabel)
                .font(Klar.TypeScale.caption)
                .foregroundStyle(type == .reduction ? Klar.accentStrong : Klar.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(type == .reduction ? Klar.accentTint : Klar.surfaceTint, in: Capsule())
        }
    }
}
```

In `GoalCards.swift`, keep only `GoalCard`, rewritten on top of `LimitEditor`. It lives until Task 7 deletes the tab:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// One substance on the Grenzen tab. Goes with the tab in the next commit.
struct GoalCard: View {
    let substance: Substance
    let store: KlarStore

    var body: some View {
        KlarCard(padding: 16) {
            Text(substance.name)
                .font(Klar.TypeScale.headline)
                .foregroundStyle(Klar.text)
                .padding(.bottom, 10)

            LimitEditor(substance: substance, store: store)

            Divider()
                .overlay(Klar.borderSubtle)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Toggle(isOn: Binding(
                get: { substance.asksMorningAfter },
                set: { store.setAsksMorningAfter($0, for: substance) }
            )) {
                Text("Morgen danach fragen")
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
            }
            .tint(Klar.accent)
        }
    }
}
```

- [ ] **Step 4: Move the substances list and add the substance page**

```bash
git mv Klar/Klar/Features/Limits/SubstitutionActionsView.swift Klar/Klar/Features/Settings/SubstitutionActionsView.swift
```

Create `Klar/Klar/Features/Settings/SubstancesView.swift`. `AddSubstanceSheet` is moved verbatim from `GoalCards.swift`. `SubstanceRow` is replaced by navigation rows:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// Einstellungen › Substanzen. One row per active substance, each leading to its page — limit,
/// the morning-after switch, cost basis, archiving.
struct SubstancesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var substances: [Substance]
    /// Unread, like the calendar's entries query: it redraws the subtitles when a limit changes
    /// on a pushed page.
    @Query private var goalPeriods: [GoalPeriod]

    @State private var isAdding = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsGroup {
                        ForEach(Array(activeSubstances.enumerated()), id: \.element.id) { index, substance in
                            if index > 0 { KlarRowDivider() }
                            NavigationLink {
                                SubstanceSettingsView(substance: substance)
                            } label: {
                                row(substance)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.substance.\(substance.name)")
                        }
                    }

                    KlarDashedButton(title: "Substanz hinzufügen", tint: Klar.accentStrong) {
                        isAdding = true
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, Klar.Space.x2)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Klar.bgSubtle)
            .navigationTitle("Substanzen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            AddSubstanceSheet { name, unit in
                store.addSubstance(name: name, unit: unit)
            }
        }
    }

    private func row(_ substance: Substance) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Klar.substanceColor(substance.colorIndex))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(substance.name)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
                Text(Self.subtitle(for: substance, store: store))
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
            }
            Spacer()
            KlarDisclosureChevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    /// „max. 4 / Monat · Morgen danach" — the limit, then whether the card asks about this one.
    static func subtitle(for substance: Substance, store: KlarStore) -> String {
        var parts: [String] = []
        if store.isGoalPaused(for: substance) {
            parts.append("Pausiert")
        } else {
            let goal = store.currentGoal(for: substance)
            switch goal?.type {
            case .reduction: parts.append("max. \(goal?.monthlyLimit ?? 0) / Monat")
            case .abstinence: parts.append("Abstinenz")
            case .observe, nil: parts.append("Beobachten")
            }
        }
        if substance.asksMorningAfter { parts.append("Morgen danach") }
        return parts.joined(separator: " · ")
    }
}

// AddSubstanceSheet: moved here unchanged from GoalCards.swift.
```

(Paste `AddSubstanceSheet` from `GoalCards.swift` below that comment, then delete the comment line. Delete `SubstancesView`, `SubstanceRow` and `AddSubstanceSheet` from `GoalCards.swift`.)

Create `Klar/Klar/Features/Settings/SubstanceSettingsView.swift`:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// Einstellungen › Substanzen › one substance. Everything decided once per substance, in one
/// place: its limit, whether „Der Morgen danach" asks about it, its cost basis, archiving.
struct SubstanceSettingsView: View {
    let substance: Substance

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Unread: redraws `LimitEditor` when a goal is versioned. See its doc comment.
    @Query private var goalPeriods: [GoalPeriod]

    @State private var costText = ""
    @State private var isConfirmingArchive = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KlarCard(padding: 16) {
                    LimitEditor(substance: substance, store: store)
                }

                SettingsGroup {
                    SettingsToggleRow(
                        icon: "sunrise",
                        title: "Morgen danach fragen",
                        subtitle: "Eine kurze Karte am Morgen nach einem Tag mit Einträgen",
                        isOn: Binding(
                            get: { substance.asksMorningAfter },
                            set: { store.setAsksMorningAfter($0, for: substance) }
                        )
                    )
                    .accessibilityIdentifier("settings.asksMorningAfter.\(substance.name)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    SettingsGroup {
                        HStack(spacing: 12) {
                            Image(systemName: "eurosign")
                                .font(.system(size: 15))
                                .foregroundStyle(Klar.textSecondary)
                                .frame(width: 18)
                            Text("Kosten je \(substance.unit.shortLabel)")
                                .font(Klar.TypeScale.body)
                                .foregroundStyle(Klar.text)
                            Spacer()
                            TextField("—", text: $costText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(Klar.TypeScale.body)
                                .frame(width: 70)
                                .onChange(of: costText) { _, newValue in
                                    let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                                    substance.costPerUnit = normalized.isEmpty ? nil : Decimal(string: normalized)
                                }
                            Text("€")
                                .font(Klar.TypeScale.body)
                                .foregroundStyle(Klar.textTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    Text("Die Kostenbasis ist deine eigene Schätzung. Sie speist die „Geld gespart“-Rechnung.")
                        .font(Klar.TypeScale.caption)
                        .foregroundStyle(Klar.textTertiary)
                        .padding(.horizontal, 4)
                }

                KlarQuietButton(title: "Archivieren") {
                    isConfirmingArchive = true
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, Klar.Space.x2)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Klar.bgSubtle)
        .navigationTitle(substance.name)
        .confirmationDialog(
            "„\(substance.name)“ archivieren?",
            isPresented: $isConfirmingArchive,
            titleVisibility: .visible
        ) {
            Button("Archivieren") {
                store.archiveSubstance(substance)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Bestehende Einträge bleiben erhalten. Die Substanz verschwindet nur aus der Auswahl.")
        }
        .task {
            costText = substance.costPerUnit?.klarFormatted ?? ""
        }
    }
}
```

- [ ] **Step 5: Regroup Einstellungen**

In `SettingsView.swift`:

1. Add `@State private var isEditingSubstitutions = false` next to the other sheet flags.
2. Replace the „Deine Daten" group (from `KlarGroupHeader(text: "Deine Daten")` through its `.padding(.bottom, 16)`) with:

```swift
                        KlarGroupHeader(text: "Deine Daten")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsNavigationRow(
                                icon: "list.bullet",
                                title: "Substanzen",
                                subtitle: "Grenzen, Morgen danach, Kosten"
                            ) { isManagingSubstances = true }
                            .accessibilityIdentifier("settings.substances")

                            KlarRowDivider()

                            SettingsNavigationRow(
                                icon: "square.and.arrow.down",
                                title: "Daten"
                            ) { isShowingDataScreen = true }
                        }
                        .padding(.bottom, 16)

                        KlarGroupHeader(text: "Craving-SOS")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsNavigationRow(
                                icon: "arrow.triangle.swap",
                                title: "Ersatzhandlungen"
                            ) { isEditingSubstitutions = true }
                            .accessibilityIdentifier("settings.substitutions")

                            KlarRowDivider()

                            SettingsNavigationRow(
                                icon: "quote.opening",
                                title: "Dein „Warum“",
                                subtitle: whySubtitle
                            ) { isEditingWhy = true }

                            KlarRowDivider()

                            SettingsNavigationRow(
                                icon: "person.crop.circle",
                                title: "Vertrauensperson",
                                subtitle: settings.supportContactName ?? "Für den Ein-Tap-Anruf im SOS"
                            ) { isEditingContact = true }
                        }
                        .padding(.bottom, 16)
```

3. Next to the other `.sheet`s:

```swift
        .sheet(isPresented: $isEditingSubstitutions) {
            NavigationStack {
                SubstitutionActionsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { isEditingSubstitutions = false }
                        }
                    }
            }
        }
```

- [ ] **Step 6: Build and run the unit tests**

Run: the app build command, then `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: build succeeds, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add -A Klar/Klar/Features/Limits Klar/Klar/Features/Settings Klar/KlarTests/SubstanceSubtitleTests.swift
git commit -m "Give every substance its own page in Einstellungen

The limit UI becomes LimitEditor, shared by the new substance page and
(next) the quota cards. The page also carries the morning-after switch,
the cost basis and archiving. Ersatzhandlungen, „Warum“ and the
Vertrauensperson move into a Craving-SOS group.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Tab „Muster" replaces „Grenzen"; Verlauf is the calendar

**Files:**
- Create: `Klar/Klar/Features/Patterns/PatternsView.swift`
- Create: `Klar/Klar/Features/Patterns/FrequencyCard.swift`
- Create: `Klar/Klar/Features/Patterns/DoseTrendCard.swift` (moved out of `TrendsSectionView.swift`)
- Create: `Klar/Klar/Features/Patterns/ContextDistributionCard.swift` (moved out of `TrendsSectionView.swift`)
- Delete: `Klar/Klar/Features/History/TrendsSectionView.swift`, `Klar/Klar/Features/Limits/LimitsView.swift`, `Klar/Klar/Features/Limits/GoalCards.swift`
- Modify: `Klar/Klar/App/RootView.swift`
- Modify: `Klar/Klar/Features/History/HistoryView.swift` (`HistoryView` only)
- Test: `Klar/KlarUITests/KlarUITests.swift`, `Klar/KlarUITests/ScreenshotTests.swift`

**Interfaces:**
- Consumes: `StatsSummary.taggedEntryCount` (Task 1), `SubstanceSettingsView` identifiers (Task 6)
- Produces:
  - `KlarTab.patterns` (replaces `.limits`)
  - `PatternsView(selectedSubstanceID: Binding<UUID?>)`
  - `MainTabView` state `patternsSubstanceID: UUID?` (Task 10 writes it)
  - identifiers `patterns.substance.<name>`

- [ ] **Step 1: Update the UI tests to the new tabs (failing)**

In `KlarUITests.testTabsAreReachableAfterOnboarding`, replace everything from `app.tabBars.buttons["Verlauf"].tap()` to the end of the function with:

```swift
        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.buttons["Vorheriger Monat"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Muster"].tap()
        XCTAssertTrue(app.buttons["patterns.substance.Alkohol"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Hilfe"].tap()
        XCTAssertTrue(app.buttons["help.sos"].waitForExistence(timeout: 5))

        // Ersatzhandlungen live in Einstellungen now.
        app.tabBars.buttons["Übersicht"].tap()
        app.buttons["Einstellungen"].tap()
        app.buttons["settings.substitutions"].tap()
        XCTAssertTrue(app.navigationBars["Ersatzhandlungen"].waitForExistence(timeout: 5))
    }
```

In `ScreenshotTests.testCaptureAllScreens`, replace the block from `// E1 · Verlauf · Kalender` through `capture(app, "G-Grenzen")` with:

```swift
        // E1 · Verlauf · Kalender
        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.buttons["Vorheriger Monat"].waitForExistence(timeout: 5))
        capture(app, "E1-Kalender")

        // M · Muster
        app.tabBars.buttons["Muster"].tap()
        XCTAssertTrue(app.buttons["patterns.substance.MDMA"].waitForExistence(timeout: 5))
        capture(app, "M-Muster")
```

and after `capture(app, "I1-Einstellungen")` add:

```swift

        // I2 · Substanzen, I3 · eine Substanz
        app.buttons["settings.substances"].tap()
        XCTAssertTrue(app.buttons["settings.substance.MDMA"].waitForExistence(timeout: 5))
        capture(app, "I2-Substanzen")
        app.buttons["settings.substance.MDMA"].tap()
        XCTAssertTrue(app.staticTexts["Morgen danach fragen"].waitForExistence(timeout: 5))
        capture(app, "I3-Substanz")
```

- [ ] **Step 2: Run the tab test to verify it fails**

Run: `xcodebuild test … -only-testing:KlarUITests/KlarUITests/testTabsAreReachableAfterOnboarding -quiet`
Expected: FAIL, `Vorheriger Monat` or `Muster` not found.

- [ ] **Step 3: Move the two Trends cards**

```bash
mkdir -p Klar/Klar/Features/Patterns
```

Create `Klar/Klar/Features/Patterns/DoseTrendCard.swift` with `import SwiftUI`, `import Charts`, `import KlarCore` and the `DoseTrendCard` struct from `TrendsSectionView.swift` (the `// MARK: - Ø Dosis über Zeit` section), with the „Ø Abstand" column removed. Its `HStack(alignment: .top, spacing: 24)` then holds only the „Diese Woche" `VStack` and the `Spacer()`. Delete `averageGapText`.

Create `Klar/Klar/Features/Patterns/ContextDistributionCard.swift` with `import SwiftUI`, `import KlarCore` and the `ContextDistributionCard` struct from the `// MARK: - Kontextverteilung` section, unchanged. Task 8 extends it.

Create `Klar/Klar/Features/Patterns/FrequencyCard.swift`:

```swift
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
```

- [ ] **Step 4: Create the tab**

`Klar/Klar/Features/Patterns/PatternsView.swift`:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// Tab „Muster". Per substance: how often, what the day after was like, where it happens, how
/// much, and the user's own words — in that order. The only reference point is the user's own
/// history (P4, P7).
struct PatternsView: View {
    /// Shared with `MainTabView`, so a row on Übersicht can open this tab on its substance.
    @Binding var selectedSubstanceID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query private var substances: [Substance]
    // Unread, like the calendar's: they redraw the cards when an entry or an answer lands.
    @Query private var entries: [Entry]
    @Query private var morningAfters: [MorningAfter]

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var selectedSubstance: Substance? {
        activeSubstances.first { $0.id == selectedSubstanceID } ?? activeSubstances.first
    }

    var body: some View {
        NavigationStack {
            KlarScreen(title: "Muster") {
                VStack(alignment: .leading, spacing: 0) {
                    if activeSubstances.isEmpty {
                        emptyState
                    } else {
                        substanceFilter
                            .padding(.bottom, 16)

                        if let substance = selectedSubstance {
                            cards(for: substance)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cards(for substance: Substance) -> some View {
        let summary = store.stats(for: substance)
        VStack(spacing: 12) {
            FrequencyCard(summary: summary)
            ContextDistributionCard(substance: substance, summary: summary, tags: store.allContextTags())
            DoseTrendCard(substance: substance, summary: summary)
        }
    }

    private var substanceFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(activeSubstances) { substance in
                    Button {
                        selectedSubstanceID = substance.id
                    } label: {
                        KlarOutlineChip(
                            text: substance.name,
                            isSelected: selectedSubstance?.id == substance.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("patterns.substance.\(substance.name)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        Text("Noch keine Substanzen. Sobald du etwas erfasst, entstehen hier Muster.")
            .font(Klar.TypeScale.bodySmall)
            .foregroundStyle(Klar.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 40)
    }
}
```

- [ ] **Step 5: Delete the old screens and wire the tab**

```bash
git rm Klar/Klar/Features/History/TrendsSectionView.swift Klar/Klar/Features/Limits/LimitsView.swift Klar/Klar/Features/Limits/GoalCards.swift
```

In `RootView.swift`:

1. `enum KlarTab` becomes `case today, history, patterns, help`.
2. In `MainTabView`, add `@State private var patternsSubstanceID: UUID?` below `isEntrySheetPresented`.
3. Replace the `LimitsView()` tab item with:

```swift
            PatternsView(selectedSubstanceID: $patternsSubstanceID)
                .tabItem { Label("Muster", systemImage: "chart.xyaxis.line") }
                .tag(KlarTab.patterns)
```

4. In the `tabBarMinimizeBehavior` comment, replace „Verlauf, Grenzen and Hilfe" with „Verlauf, Muster and Hilfe".

In `HistoryView.swift`, replace `struct HistoryView` (the whole struct, from its doc comment to its closing brace) with:

```swift
/// E1–E2 · Tab „Verlauf": the calendar, and what each day held.
///
/// Trends moved into the tab „Muster" with the morning-after evaluation. What is left here is
/// the record itself, so the segmented control and the section swipe went with them.
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            KlarScreen(title: "Verlauf") {
                CalendarSectionView()
            }
        }
    }
}
```

- [ ] **Step 6: Build and run the tests**

Run: the app build command.
Expected: build succeeds. Any leftover reference to `GoalCard`, `LimitsView`, `TrendsSectionView` or `KlarTab.limits` is a compile error. Fix it by pointing it at the new types.

Run: `xcodebuild test … -only-testing:KlarTests -quiet`, then `xcodebuild test … -only-testing:KlarUITests -quiet`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add -A Klar/Klar Klar/KlarUITests
git commit -m "Replace the Grenzen tab with Muster

Trends move into a tab of their own, which the morning-after evaluation
joins next. Limits are set on the substance page; Verlauf keeps only the
calendar.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The morning-after evaluation in Muster

**Files:**
- Modify: `Klar/Klar/App/KlarStore.swift`
- Modify: `Klar/Klar/App/MorningPatternText.swift`
- Create: `Klar/Klar/Features/Patterns/MorningDistributionCard.swift`
- Create: `Klar/Klar/Features/Patterns/ReflectionsCard.swift`
- Modify: `Klar/Klar/Features/Patterns/ContextDistributionCard.swift`
- Modify: `Klar/Klar/Features/Patterns/PatternsView.swift`
- Test: `Klar/KlarTests/KlarStoreMorningAfterTests.swift`, `Klar/KlarTests/MorningPatternTextTests.swift`

**Interfaces:**
- Consumes: `MorningAfterService.pattern(…, limit:)`, `sharedDays` (Task 3), answer labels (Task 5)
- Produces:
  - `KlarStore.morningDistribution(for: Substance) -> MorningPattern?`
  - `KlarStore.morningPatternsByContext(for: Substance) -> [UUID: MorningPattern]`
  - `KlarStore.sharedMorningDays(for: Substance) -> [(substance: Substance, days: Int)]`
  - `KlarStore.reflections(for: Substance, limit: Int = 5) -> [MorningAfter]`
  - `MorningPatternText.tally(_:) -> String`
  - `MorningPatternText.sharedDaysText(_ shared: [(name: String, days: Int)]) -> String`
  - `MorningPatternText.reflectionLines(trigger:wouldHaveHelped:nextTime:) -> [String]` (Task 9 reuses it)

- [ ] **Step 1: Write the failing text tests**

Append to `MorningPatternTextTests`:

```swift
    func testTheTallyNamesTheDaysCounted() {
        XCTAssertEqual(MorningPatternText.tally(pattern(days: 5, body: [.hungover: 4, .fine: 1], regret: [.yes: 1])), "5 Tage: 4× verkatert, 1× bereut")
        XCTAssertEqual(MorningPatternText.tally(pattern(days: 3, body: [.fine: 3], regret: [.no: 3])), "3 Tage: kein Kater, nichts bereut")
    }

    func testSharedDaysNameTheOtherSubstances() {
        XCTAssertEqual(MorningPatternText.sharedDaysText([("Cannabis", 3), ("Alkohol", 1)]), "Davon 3 Tage zusammen mit Cannabis, 1 mit Alkohol")
        XCTAssertEqual(MorningPatternText.sharedDaysText([("Cannabis", 1)]), "Davon 1 Tag zusammen mit Cannabis")
    }

    func testReflectionLinesLeaveOutWhatWasNotWritten() {
        XCTAssertEqual(
            MorningPatternText.reflectionLines(trigger: "Stress", wouldHaveHelped: nil, nextTime: "Wasser"),
            ["Auslöser: Stress", "Nächstes Mal: Wasser"]
        )
    }
```

- [ ] **Step 2: Write the failing store tests**

Append to `KlarStoreMorningAfterTests` (uses `evening(daysAgo:)` from Task 4):

```swift
    /// The Muster tab counts every answered day, not the newest five.
    func testTheDistributionCountsAllAnsweredDays() throws {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        for daysAgo in 10...16 {
            let entry = store.addEntry(substance: alcohol, timestamp: evening(daysAgo: daysAgo))
            store.recordMorningAfter(dayKey: LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID), body: .rough, regret: nil, again: nil, note: nil)
        }
        XCTAssertEqual(try XCTUnwrap(store.morningDistribution(for: alcohol)).days, 7)

        store.setAsksMorningAfter(false, for: alcohol)
        XCTAssertNil(store.morningDistribution(for: alcohol))
    }

    func testSharedDaysNameTheOtherAskingSubstance() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let cannabis = store.addSubstance(name: "Cannabis", unit: .g)
        let entry = store.addEntry(substance: alcohol, timestamp: evening(daysAgo: 10))
        store.addEntry(substance: cannabis, timestamp: evening(daysAgo: 10))
        store.recordMorningAfter(dayKey: LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID), body: .hungover, regret: nil, again: nil, note: nil)

        let shared = store.sharedMorningDays(for: alcohol)
        XCTAssertEqual(shared.map(\.substance.name), ["Cannabis"])
        XCTAssertEqual(shared.map(\.days), [1])
    }

    func testReflectionsAreTheSubstancesDaysWithWrittenAnswersNewestFirst() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let coffee = store.addSubstance(name: "Kaffee", unit: .drink)
        let old = store.addEntry(substance: alcohol, timestamp: evening(daysAgo: 12))
        let new = store.addEntry(substance: alcohol, timestamp: evening(daysAgo: 10))
        let silent = store.addEntry(substance: alcohol, timestamp: evening(daysAgo: 11))
        let other = store.addEntry(substance: coffee, timestamp: evening(daysAgo: 9))
        func key(_ entry: Entry) -> String { LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID) }

        store.recordReflection(dayKey: key(old), trigger: "Stress", wouldHaveHelped: nil, nextTime: nil)
        store.recordReflection(dayKey: key(new), trigger: nil, wouldHaveHelped: nil, nextTime: "Wasser")
        store.recordMorningAfter(dayKey: key(silent), body: .fine, regret: nil, again: nil, note: nil)
        store.recordReflection(dayKey: key(other), trigger: "Müde", wouldHaveHelped: nil, nextTime: nil)

        XCTAssertEqual(store.reflections(for: alcohol).map(\.dayKey), [key(new), key(old)])
    }
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: compile errors for `tally`, `sharedDaysText`, `reflectionLines`, `morningDistribution`, `sharedMorningDays`, `reflections`.

- [ ] **Step 4: Implement the text helpers**

In `MorningPatternText.swift`, replace `summary(_:)` with a shared fragment builder and add the new functions:

```swift
    /// "letzte 5: 3× verkatert, 1× bereut" — Übersicht and the entry sheet, newest five days.
    static func summary(_ pattern: MorningPattern) -> String {
        "letzte \(pattern.days): \(fragments(pattern))"
    }

    /// "5 Tage: 4× verkatert, 1× bereut" — the Muster tab, which counts every answered day.
    static func tally(_ pattern: MorningPattern) -> String {
        "\(pattern.days) Tage: \(fragments(pattern))"
    }

    /// "Davon 3 Tage zusammen mit Cannabis, 1 mit Alkohol". A day's answers belong to every
    /// substance of that day, so the evaluation says which days were shared.
    static func sharedDaysText(_ shared: [(name: String, days: Int)]) -> String {
        guard let first = shared.first else { return "" }
        let head = "Davon \(first.days) \(first.days == 1 ? "Tag" : "Tage") zusammen mit \(first.name)"
        let rest = shared.dropFirst().map { "\($0.days) mit \($0.name)" }
        return ([head] + rest).joined(separator: ", ")
    }

    /// The problem-solving answers of one day, each labelled, empty ones left out.
    static func reflectionLines(trigger: String?, wouldHaveHelped: String?, nextTime: String?) -> [String] {
        [("Auslöser", trigger), ("Hätte geholfen", wouldHaveHelped), ("Nächstes Mal", nextTime)]
            .compactMap { label, text in
                guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                return "\(label): \(text)"
            }
    }

    private static func fragments(_ pattern: MorningPattern) -> String {
        var parts: [String] = []
        if let count = pattern.body[.hungover], count > 0 { parts.append("\(count)× verkatert") }
        if let count = pattern.body[.rough], count > 0 { parts.append("\(count)× angeschlagen") }
        if let count = pattern.regret[.yes], count > 0 { parts.append("\(count)× bereut") }
        if let count = pattern.regret[.slightly], count > 0 { parts.append("\(count)× ein bisschen bereut") }

        if !parts.isEmpty { return parts.joined(separator: ", ") }
        if pattern.body.isEmpty && pattern.regret.isEmpty { return "ohne Angaben zu Kater und Reue" }
        return "kein Kater, nichts bereut"
    }
```

- [ ] **Step 5: Implement the store functions**

In `KlarStore.swift`, after `morningPattern(for:contextTag:)`:

```swift
    /// All answered days of the substance, not only the newest five — the Muster tab.
    func morningDistribution(for substance: Substance) -> MorningPattern? {
        guard substance.asksMorningAfter else { return nil }
        return MorningAfterService.pattern(
            substanceID: substance.id,
            contextTagID: nil,
            entries: allEntries().map { $0.toDTO() },
            records: allMorningAfters().map { $0.toDTO() },
            limit: .max
        )
    }

    /// Per context tag, the pattern over all answered days with that tag — only tags with at
    /// least three.
    func morningPatternsByContext(for substance: Substance) -> [UUID: MorningPattern] {
        guard substance.asksMorningAfter else { return [:] }
        let entries = allEntries().map { $0.toDTO() }
        let records = allMorningAfters().map { $0.toDTO() }
        var result: [UUID: MorningPattern] = [:]
        for tag in allContextTags() {
            if let pattern = MorningAfterService.pattern(
                substanceID: substance.id, contextTagID: tag.id, entries: entries, records: records, limit: .max
            ) {
                result[tag.id] = pattern
            }
        }
        return result
    }

    /// The other asking substances logged on this substance's answered days, most shared first.
    func sharedMorningDays(for substance: Substance) -> [(substance: Substance, days: Int)] {
        guard substance.asksMorningAfter else { return [] }
        let all = allSubstances(includeArchived: true)
        let counts = MorningAfterService.sharedDays(
            substanceID: substance.id,
            askingSubstanceIDs: askingSubstanceIDs,
            entries: allEntries().map { $0.toDTO() },
            records: allMorningAfters().map { $0.toDTO() }
        )
        return counts
            .compactMap { id, days in all.first { $0.id == id }.map { (substance: $0, days: days) } }
            .sorted { $0.days != $1.days ? $0.days > $1.days : $0.substance.sortOrder < $1.substance.sortOrder }
    }

    /// Records of this substance's days that carry at least one written reflection, newest first.
    func reflections(for substance: Substance, limit: Int = 5) -> [MorningAfter] {
        guard substance.asksMorningAfter else { return [] }
        let days = Set(
            allEntries()
                .filter { $0.substance?.id == substance.id }
                .map { LogicalDay.dayKey(for: $0.timestamp, timezoneID: $0.timezoneID) }
        )
        return Array(
            allMorningAfters()
                .filter { days.contains($0.dayKey) }
                .filter {
                    !MorningPatternText.reflectionLines(trigger: $0.trigger, wouldHaveHelped: $0.wouldHaveHelped, nextTime: $0.nextTime).isEmpty
                }
                .sorted { $0.dayKey > $1.dayKey }
                .prefix(limit)
        )
    }
```

- [ ] **Step 6: Run the unit tests**

Run: `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: all pass.

- [ ] **Step 7: Build the cards**

`Klar/Klar/Features/Patterns/MorningDistributionCard.swift`:

```swift
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
```

`Klar/Klar/Features/Patterns/ReflectionsCard.swift`:

```swift
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
```

In `ContextDistributionCard.swift`, add a property after `tags`:

```swift
    /// Per tag, what the days after looked like — only tags with three answered days.
    var morningPatterns: [UUID: MorningPattern] = [:]
```

and inside the row's `VStack(alignment: .leading, spacing: 5)`, after `KlarShareBar(…)`:

```swift
                        if let pattern = morningPatterns[item.tag.id] {
                            Text(MorningPatternText.tally(pattern))
                                .font(Klar.TypeScale.caption)
                                .foregroundStyle(Klar.textTertiary)
                        }
```

In `PatternsView.cards(for:)`, replace the `VStack` with:

```swift
        let reflections = store.reflections(for: substance)
        VStack(spacing: 12) {
            FrequencyCard(summary: summary)
            if substance.asksMorningAfter {
                MorningDistributionCard(
                    distribution: store.morningDistribution(for: substance),
                    shared: store.sharedMorningDays(for: substance).map { (name: $0.substance.name, days: $0.days) }
                )
            }
            ContextDistributionCard(
                substance: substance,
                summary: summary,
                tags: store.allContextTags(),
                morningPatterns: store.morningPatternsByContext(for: substance)
            )
            DoseTrendCard(substance: substance, summary: summary)
            if !reflections.isEmpty {
                ReflectionsCard(records: reflections)
            }
        }
```

- [ ] **Step 8: Build and run the tests**

Run: the app build command, then `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: build succeeds, all tests pass.

- [ ] **Step 9: Commit**

```bash
git add Klar/Klar/App/KlarStore.swift Klar/Klar/App/MorningPatternText.swift Klar/Klar/Features/Patterns Klar/KlarTests/KlarStoreMorningAfterTests.swift Klar/KlarTests/MorningPatternTextTests.swift
git commit -m "Show the morning-after answers in Muster

Per substance: the three answers over every answered day, the days
shared with other substances, the consequences per context next to the
context share, and the user's own reflections.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: „Offen", the calendar ring and the day's review

**Files:**
- Create: `Klar/Klar/Features/MorningAfter/OpenMorningsCard.swift`
- Create: `Klar/Klar/Features/MorningAfter/MorningAfterDayBlock.swift`
- Modify: `Klar/Klar/App/MorningPatternText.swift`
- Modify: `Klar/Klar/Features/History/HistoryView.swift` (`HistoryView`, `CalendarSectionView`, `DayDetailView`)
- Modify: `Klar/Klar/Features/Today/TodayView.swift`
- Test: `Klar/KlarTests/MorningPatternTextTests.swift`, `Klar/KlarUITests/MorningAfterUITests.swift`, `Klar/KlarUITests/ScreenshotTests.swift`

**Interfaces:**
- Consumes: `KlarStore.openMorningAfterDays`, `canAnswerMorningAfter` (Task 4), `KlarDate.dayKey(forLogicalDay:)`, `date(fromDayKey:)` (Task 4), `DueMorning` (Task 5), `MorningPatternText.reflectionLines` (Task 8)
- Produces:
  - `OpenMorningsCard(dayKeys: [String], onOpen: (String) -> Void)`
  - `MorningAfterDayBlock(record: MorningAfter?, canAnswer: Bool, onOpen: () -> Void)`
  - `MorningPatternText.answerLines(body:regret:again:) -> [String]`
  - identifiers `morning.open.<dayKey>`, `dayDetail.morning`

- [ ] **Step 1: Write the failing tests**

Append to `MorningPatternTextTests`:

```swift
    func testAnswerLinesNameEachAnsweredQuestion() {
        XCTAssertEqual(
            MorningPatternText.answerLines(body: .hungover, regret: nil, again: .differently),
            ["Körper: verkatert", "Nochmal so: anders"]
        )
    }
```

In `MorningAfterUITests.testLaterKeepsTheCardFromPoppingUpAgain`, append after the last assertion:

```swift

        // The day waits in „Offen" on Übersicht, and answering it there takes it off the list.
        let openRow = relaunched.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "morning.open.")).firstMatch
        XCTAssertTrue(openRow.waitForExistence(timeout: 5))
        openRow.tap()
        XCTAssertTrue(relaunched.staticTexts["morningAfter.header"].waitForExistence(timeout: 5))
        relaunched.buttons["verkatert"].tap()
        relaunched.buttons["Fertig"].tap()
        XCTAssertFalse(openRow.waitForExistence(timeout: 3))
```

In `testSkippingAlsoEndsTheQuestion`, append:

```swift
        XCTAssertFalse(
            relaunched.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "morning.open.")).firstMatch.exists,
            "a skipped day is not listed as open"
        )
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test … -only-testing:KlarTests/MorningPatternTextTests -quiet`
Expected: compile error, `answerLines` missing.

- [ ] **Step 3: Implement `answerLines`**

In `MorningPatternText.swift`:

```swift
    /// "Körper: verkatert" — one line per answered question, for the day detail.
    static func answerLines(body: MorningBody?, regret: MorningRegret?, again: MorningAgain?) -> [String] {
        var lines: [String] = []
        if let body { lines.append("Körper: \(body.label)") }
        if let regret { lines.append("Reue: \(regret.label)") }
        if let again { lines.append("Nochmal so: \(again.label)") }
        return lines
    }
```

- [ ] **Step 4: Create the Offen card**

`Klar/Klar/Features/MorningAfter/OpenMorningsCard.swift`:

```swift
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
```

- [ ] **Step 5: Create the day-detail block**

`Klar/Klar/Features/MorningAfter/MorningAfterDayBlock.swift`:

```swift
import SwiftUI
import KlarCore

/// The day's „Der Morgen danach" inside the day detail: the answers, the note, the reflection.
/// While the day is answerable (72 h) it can be filled in or edited; afterwards it is read-only.
struct MorningAfterDayBlock: View {
    let record: MorningAfter?
    let canAnswer: Bool
    let onOpen: () -> Void

    private var isAnswered: Bool {
        record.map { $0.body != nil || $0.regret != nil || $0.again != nil } ?? false
    }

    var body: some View {
        KlarCard(padding: 16) {
            KlarSectionLabel(text: "Der Morgen danach")
                .padding(.bottom, 10)

            if let record, isAnswered {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(MorningPatternText.answerLines(body: record.body, regret: record.regret, again: record.again), id: \.self) { line in
                        Text(line)
                            .font(Klar.TypeScale.body)
                            .foregroundStyle(Klar.text)
                    }
                    if let note = record.note {
                        Text(note)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textTertiary)
                            .padding(.top, 6)
                    }
                    ForEach(
                        MorningPatternText.reflectionLines(trigger: record.trigger, wouldHaveHelped: record.wouldHaveHelped, nextTime: record.nextTime),
                        id: \.self
                    ) { line in
                        Text(line)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textSecondary)
                    }
                }
                if canAnswer {
                    KlarInlineButton(title: "Bearbeiten", systemImage: "pencil", tint: Klar.textSecondary, action: onOpen)
                        .padding(.top, 12)
                        .accessibilityIdentifier("dayDetail.morning")
                }
            } else {
                if record != nil {
                    Text("Übersprungen.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                        .padding(.bottom, canAnswer ? 10 : 0)
                }
                if canAnswer {
                    KlarDashedButton(title: "Rückblick nachtragen", action: onOpen)
                        .accessibilityIdentifier("dayDetail.morning")
                }
            }
        }
    }
}
```

- [ ] **Step 6: Wire Verlauf, the calendar and the day detail**

In `HistoryView.swift`:

1. Replace `HistoryView` with:

```swift
/// E1–E2 · Tab „Verlauf": open reviews, the calendar, and what each day held.
///
/// Trends moved into the tab „Muster" with the morning-after evaluation. What is left here is
/// the record itself, so the segmented control and the section swipe went with them.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    // Unread: they redraw „Offen" when an entry or an answer lands.
    @Query private var entries: [Entry]
    @Query private var morningAfters: [MorningAfter]

    @State private var openedMorning: DueMorning?

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            KlarScreen(title: "Verlauf") {
                VStack(alignment: .leading, spacing: 0) {
                    let openDays = store.openMorningAfterDays()
                    if !openDays.isEmpty {
                        OpenMorningsCard(dayKeys: openDays) { openedMorning = DueMorning(dayKey: $0) }
                            .padding(.bottom, 16)
                    }
                    CalendarSectionView()
                }
            }
        }
        .sheet(item: $openedMorning) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
        }
    }
}
```

2. In `CalendarSectionView`:
   - Add `@Query private var morningAfters: [MorningAfter]` below the substances query, with the comment `// Unread: redraws the open-day rings when a day is answered.`
   - In `dayGrid`, next to `let logged = …`, add `let open = Set(store.openMorningAfterDays().compactMap(KlarDate.date(fromDayKey:)))`, and pass it on: `dayCell(day, logged: logged, open: open)`.
   - Change the signature to `private func dayCell(_ day: Int, logged: [Date: [Substance]], open: Set<Date>) -> some View`. After `let isFuture = …` add `let isOpen = date.map { open.contains($0) } ?? false`. Inside the `ZStack`, right after the `if isToday { … }` block, add:

```swift
                if isOpen {
                    // Today is never open, so the ring cannot collide with the today pill.
                    Circle().strokeBorder(Klar.borderStrong, lineWidth: 1)
                }
```

   - The accessibility label becomes `accessibilityLabel(day: day, substances: substances) + (isOpen ? ", Rückblick offen" : "")`.

3. In `DayDetailView`:
   - Add `@Query private var morningAfters: [MorningAfter]` below `allEntries` and `@State private var openedMorning: DueMorning?` below `isAddingEntry`.
   - Add:

```swift
    /// Not `LogicalDay.dayKey(for: day)`: `day` is already normalized to 00:00, and the cutoff
    /// would move it to the day before.
    private var dayKey: String { KlarDate.dayKey(forLogicalDay: day) }
    private var morningRecord: MorningAfter? { store.morningAfter(forDayKey: dayKey) }
    private var canAnswerMorning: Bool { store.canAnswerMorningAfter(dayKey: dayKey) }
```

   - After `KlarDashedButton(title: "Eintrag nachtragen") { … }.padding(.top, 12)`, add:

```swift
                    if morningRecord != nil || canAnswerMorning {
                        MorningAfterDayBlock(record: morningRecord, canAnswer: canAnswerMorning) {
                            openedMorning = DueMorning(dayKey: dayKey)
                        }
                        .padding(.top, 20)
                    }
```

   - Next to the other `.sheet`s:

```swift
        .sheet(item: $openedMorning) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
        }
```

- [ ] **Step 7: Wire Übersicht**

In `TodayView.swift`:
- Add `@State private var openedMorning: DueMorning?` next to `entryBeingEdited`.
- Add `private var openMorningDays: [String] { store.openMorningAfterDays() }`.
- Between the quota block and `if !morningRows.isEmpty`, insert:

```swift
                    if !openMorningDays.isEmpty {
                        OpenMorningsCard(dayKeys: openMorningDays) { openedMorning = DueMorning(dayKey: $0) }
                            .padding(.bottom, 12)
                    }
```

- Next to the other `.sheet`s:

```swift
        .sheet(item: $openedMorning) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
        }
```

`TodayView` already queries `morningAfters`, so the card disappears once the day is answered.

- [ ] **Step 8: Extend the screenshot walk**

In `ScreenshotTests.testCaptureMorningAfter`, append:

```swift

        // B · Offen, E1 with the ring, E2 with „Rückblick nachtragen"
        app.buttons["Später"].tap()
        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5))
        capture(app, "B-Offen")
        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.buttons["Vorheriger Monat"].waitForExistence(timeout: 5))
        capture(app, "E1-Kalender-offen")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Rückblick offen")).firstMatch.tap()
        XCTAssertTrue(app.buttons["dayDetail.morning"].waitForExistence(timeout: 5))
        capture(app, "E2-Tagesdetail-offen")
```

Before that block, the test taps „ja" on the regret row, which only sets a selection. „Später" writes nothing, so the day stays open.

- [ ] **Step 9: Run all tests**

Run: `xcodebuild test … -only-testing:KlarTests -quiet`, then `xcodebuild test … -only-testing:KlarUITests -quiet`
Expected: all pass.

- [ ] **Step 10: Commit**

```bash
git add Klar/Klar Klar/KlarTests Klar/KlarUITests
git commit -m "List open reviews and show each day's review in the day detail

Open days appear on Übersicht and Verlauf and get a ring in the
calendar. The day detail shows the answers, the note and the reflection,
and offers to fill them in while the day is still answerable.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Übersicht leads into limits and patterns

**Files:**
- Create: `Klar/Klar/Features/Limits/LimitSheet.swift`
- Modify: `Klar/Klar/Features/Today/TodayView.swift` (`TodayView`, `MultiQuotaCard`)
- Modify: `Klar/Klar/Features/MorningAfter/MorningPatternsCard.swift`
- Modify: `Klar/Klar/App/RootView.swift`

**Interfaces:**
- Consumes: `LimitEditor` (Task 6), `MainTabView.patternsSubstanceID`, `KlarTab.patterns` (Task 7)
- Produces:
  - `LimitSheet(substance: Substance)`
  - `TodayView(onShowPatterns: (Substance) -> Void)`
  - `MultiQuotaCard.onSelect`
  - `MorningPatternsCard.onSelect`
  - identifiers `today.quota.<name>`, `today.morningPattern.<name>`

- [ ] **Step 1: Create the limit sheet**

`Klar/Klar/Features/Limits/LimitSheet.swift`:

```swift
import SwiftUI
import SwiftData

/// The limit behind a quota card on Übersicht — the same editor as on the substance page, one
/// tap from where the number is read.
struct LimitSheet: View {
    let substance: Substance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Unread: redraws `LimitEditor` when a goal is versioned.
    @Query private var goalPeriods: [GoalPeriod]

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            ScrollView {
                KlarCard(padding: 16) {
                    LimitEditor(substance: substance, store: store)
                }
                .padding(16)
            }
            .background(Klar.bgSubtle)
            .navigationTitle(substance.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
```

- [ ] **Step 2: Make the rows tappable**

`MultiQuotaCard`: add `var onSelect: (Substance) -> Void = { _ in }` after `month`, and wrap each row:

```swift
                    Button {
                        onSelect(pair.substance)
                    } label: {
                        MultiQuotaRow(substance: pair.substance, quota: pair.quota)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                    }
                    .klarRowButtonStyle(cornerRadius: 0)
                    .accessibilityIdentifier("today.quota.\(pair.substance.name)")
```

`MorningPatternsCard`: add `var onSelect: (Substance) -> Void = { _ in }` after `rows`. Wrap the row's `VStack(alignment: .leading, spacing: 3) { … }` in:

```swift
                Button {
                    onSelect(row.substance)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            // … the two Texts, unchanged …
                        }
                        Spacer()
                        KlarDisclosureChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today.morningPattern.\(row.substance.name)")
```

and replace `.accessibilityElement(children: .combine)` on the card with `.accessibilityElement(children: .contain)`, so each row stays its own button.

`TodayView`:
- Add `var onShowPatterns: (Substance) -> Void = { _ in }` as the first property and `@State private var limitSubstance: Substance?` next to `entryBeingEdited`.
- Wrap the single `QuotaCard(…)`:

```swift
                        Button {
                            limitSubstance = single.substance
                        } label: {
                            QuotaCard(
                                substance: single.substance,
                                quota: single.quota,
                                daysSinceLast: store.stats(for: single.substance).daysSinceLastOccasion,
                                month: today
                            )
                        }
                        .klarRowButtonStyle()
                        .accessibilityIdentifier("today.quota.\(single.substance.name)")
                        .padding(.bottom, 12)
```

- Pass `onSelect: { limitSubstance = $0 }` to `MultiQuotaCard` and `onSelect: onShowPatterns` to `MorningPatternsCard`.
- Next to the other `.sheet`s: `.sheet(item: $limitSubstance) { LimitSheet(substance: $0) }`.

In `RootView.swift`, `MainTabView`, the Übersicht tab becomes:

```swift
            TodayView(onShowPatterns: { substance in
                patternsSubstanceID = substance.id
                selectedTab = .patterns
            })
```

- [ ] **Step 3: Build and run all tests**

Run: the app build command, `xcodebuild test … -only-testing:KlarTests -quiet`, `xcodebuild test … -only-testing:KlarUITests -quiet`
Expected: all pass.

- [ ] **Step 4: Check by hand**

Install the current build on the simulator (the UI-test run in Step 3 leaves it installed), then launch the demo:

```bash
xcrun simctl launch --terminate-running-process D9360641-F9CD-4536-870B-3D66A89F6FEE de.lenhard.Klar --klar-demo-seed
```

Check:
- tapping the Alkohol quota row opens the limit sheet, and changing the limit updates the row after closing;
- tapping the Alkohol line of „Der Morgen danach" switches to Muster with Alkohol selected.

- [ ] **Step 5: Commit**

```bash
git add Klar/Klar
git commit -m "Open the limit from its quota card and the pattern from its row

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Demo data with mixed use, an open day and reflections

**Files:**
- Modify: `Klar/Klar/Persistence/DemoDataSeeder.swift`
- Test: `Klar/KlarTests/DemoDataSeederTests.swift`

**Interfaces:**
- Consumes: `KlarStore.openMorningAfterDays`, `sharedMorningDays`, `reflections`, `morningDistribution`

- [ ] **Step 1: Write the failing test**

Append to `DemoDataSeederTests`:

```swift
    /// The demo must show every new surface: an open day, mixed use and written reflections.
    func testSeedShowsAnOpenDayMixedUseAndReflections() throws {
        let context = TestModelContainer.makeInMemoryContext()
        try DemoDataSeeder.seed(context: context)
        let store = KlarStore(context: context)

        XCTAssertEqual(store.openMorningAfterDays().count, 1)
        let alcohol = try XCTUnwrap(store.allSubstances().first { $0.name == "Alkohol" })
        XCTAssertNotNil(store.morningDistribution(for: alcohol))
        XCTAssertFalse(store.sharedMorningDays(for: alcohol).isEmpty)
        XCTAssertFalse(store.reflections(for: alcohol).isEmpty)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test … -only-testing:KlarTests/DemoDataSeederTests -quiet`
Expected: FAIL. The open-day count is 0, and shared days and reflections are empty.

- [ ] **Step 3: Seed Cannabis, the open day and reflections**

In `DemoDataSeeder.seed`:

1. After `nicotine`:

```swift
        let cannabis = Substance(name: "Cannabis", unit: .g, colorIndex: 3, costPerUnit: Decimal(string: "10.00"), sortOrder: 3)
```

and insert it with the others: `for substance in [coffee, alcohol, nicotine, cannabis]`.

2. In the `while` loop, inside `if dayOffset % 9 == 0 { … }` after the alcohol entries, and as a new branch after the nicotine one:

```swift
                if dayOffset % 18 == 0 {
                    // Some club nights are mixed — the Muster tab names those days.
                    insertEntry(cannabis, day: day, hour: 23, minute: 45, tag: club)
                    entryCount += 1
                }
```

```swift
            if dayOffset % 7 == 0 {
                insertEntry(cannabis, day: day, hour: 21, tag: zuhause)
                entryCount += 1
            }
```

3. Replace the whole morning-after block (from `// Answer most past alcohol evenings` to the end of its `for` loop) with:

```swift
        // One mixed evening three logical days ago stays open. That is past the 48 h in which
        // the card pops up by itself, and inside the 72 h in which it can be answered — so the
        // demo shows „Offen" and the calendar ring without a card covering the screen at launch
        // (between 00:00 and 05:00 it still pops up once, which is fine).
        let logicalToday = LogicalDay.date(
            from: LogicalDay.components(for: now, timezoneID: "Europe/Berlin"),
            timezoneID: "Europe/Berlin"
        )
        let openDay = calendar.date(byAdding: .day, value: -3, to: logicalToday)!
        insertEntry(alcohol, day: openDay, hour: 21, tag: club)
        insertEntry(cannabis, day: openDay, hour: 22, tag: club)
        let openKey = LogicalDay.dayKey(
            for: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: openDay)!,
            timezoneID: "Europe/Berlin"
        )

        // Every older day with alcohol or cannabis is answered, so Übersicht, the entry sheet and
        // Muster all have a pattern. The last few regretted days carry a written reflection.
        let askingIDs: Set<UUID> = [alcohol.id, cannabis.id]
        let answered = Set(
            try context.fetch(FetchDescriptor<Entry>())
                .filter { $0.substance.map { askingIDs.contains($0.id) } ?? false }
                .map { LogicalDay.dayKey(for: $0.timestamp, timezoneID: $0.timezoneID) }
        )
        .filter { $0 < openKey }
        .sorted()
        for (index, key) in answered.enumerated() {
            let hungover = index % 3 != 1
            let regretted = index % 3 == 0
            let reflects = regretted && index >= answered.count - 4
            context.insert(MorningAfter(
                dayKey: key,
                body: hungover ? .hungover : .fine,
                regret: regretted ? .yes : .no,
                again: hungover ? .differently : .yes,
                trigger: reflects ? "Wollte nicht als Erste gehen" : nil,
                wouldHaveHelped: reflects ? "Vorher richtig essen" : nil,
                nextTime: reflects ? "Zwischendurch Wasser" : nil
            ))
        }
```

The existing test (newest alcohol day stays unrecorded) still holds, because that day is now the open day. Update its doc comment and failure message to say so: „the newest alcohol evening is the open day".

- [ ] **Step 4: Run the tests**

Run: `xcodebuild test … -only-testing:KlarTests -quiet`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Klar/Klar/Persistence/DemoDataSeeder.swift Klar/KlarTests/DemoDataSeederTests.swift
git commit -m "Seed demo data for mixed use, an open day and reflections

Cannabis joins the demo as a second substance the card asks about. One
mixed evening three days ago stays open, and the last regretted days
carry written reflections.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Docs and full verification

**Files:**
- Modify: `docs/klar-screens-implementation.md`
- Modify: `docs/klar-mvp-konzept.md`

- [ ] **Step 1: Update the screens doc**

In `docs/klar-screens-implementation.md`:
- **B · Übersicht:**
  - the „Offen" card between quota and patterns;
  - quota cards and pattern rows are tappable (limit sheet, tab Muster).
- **D1:** replace the sentence starting „„Fertig" saves and dismisses; „Überspringen" and swiping…" with: „„Fertig" saves. „Später" and swiping the card away write nothing — the card does not pop up again by itself (`AppSettings.lastPresentedMorningDayKey`), and the day waits in „Offen" for 72 h after it ends. „Überspringen" records a skip, which takes the day off „Offen"; the day detail can still answer it. Answered later than the next morning, the questions speak of „dem Tag danach", and an existing record is prefilled."
- **E · Verlauf:**
  - E1 is the calendar with one dot per substance (at most three), a ring on open days and the „Offen" card above it;
  - E2 gains the „Der Morgen danach" block (answers, note, reflection, „Rückblick nachtragen"/„Bearbeiten" while answerable);
  - remove E3 and the deviation note about segments.
- **Replace G with M · Muster** ([PatternsView.swift](../Klar/Klar/Features/Patterns/PatternsView.swift)): substance chips, then Häufigkeit, Der Morgen danach (all answered days, shared days), Kontext (share of entries with context plus consequences per tag), Ø Dosis über Zeit, Deine Sätze.
- **I · Einstellungen:** „Substanzen" leads to a page per substance (limit, „Morgen danach fragen", cost, archive); group „Craving-SOS" with Ersatzhandlungen, „Warum", Vertrauensperson.

- [ ] **Step 2: Update the concept**

In `docs/klar-mvp-konzept.md`, § 4:
- **Modul B:** replace the „Rückblick-Muster" bullet with: „Tab „Muster" je Substanz: Häufigkeit, Verteilung der drei Rückblick-Antworten über alle beantworteten Tage, Folgen je Kontext neben dem Kontextanteil, Mischkonsum-Tage benannt, eigene Reflexionssätze. Übersicht und Eintrag-Sheet zeigen weiter die Kurzform der letzten fünf."
- **Modul C:**
  - Replace the „Verfall" bullet with: „**Verfall:** Die Karte erscheint pro Konsumtag einmal von selbst — für den jüngsten Konsumtag, bis 48 Stunden nach seinem Ende. „Später" oder Wegwischen lässt den Tag offen. Offene Tage stehen bis 72 Stunden nach ihrem Ende unter „Offen" (Übersicht, Verlauf) und sind im Tagesdetail nachtragbar; „Überspringen" nimmt einen Tag nur aus dieser Liste."
  - Change „(„Morgen danach fragen" im Tab Grenzen)" to „(„Morgen danach fragen" in Einstellungen › Substanzen)".
- **Modul D:** add: „Der Stand jeder Grenze steht in der Übersicht und öffnet per Tippen die Grenze; gesetzt wird sie pro Substanz in Einstellungen › Substanzen."

- [ ] **Step 3: Full verification**

Run, in order:

```bash
swift test --package-path Packages/KlarCore
xcodebuild test -project Klar/Klar.xcodeproj -scheme Klar -destination 'platform=iOS Simulator,id=D9360641-F9CD-4536-870B-3D66A89F6FEE' -quiet
```

Expected: every KlarCore, KlarTests and KlarUITests test passes. Read the output. Do not claim success without it.

- [ ] **Step 4: Check by hand in the simulator**

Launch the demo (`--klar-demo-seed`) on iPhone 17 Pro (iOS 26.5), in light and dark. Take screenshots of:
- Übersicht with „Offen";
- Verlauf with the ring and dots;
- the day detail of the open day and of an answered day;
- Muster for Alkohol, scrolled through all cards;
- Einstellungen › Substanzen › Alkohol.

Check in particular:
- no answer is coloured green or red;
- the „Offen" card disappears after answering;
- the tab bar shows no badge.

- [ ] **Step 5: Commit**

```bash
git add docs/klar-screens-implementation.md docs/klar-mvp-konzept.md
git commit -m "Document the Muster tab and open reviews

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
