# „Der Morgen danach" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace if-then plans and the weekly review in the Klar iOS app with a per-day „Der Morgen danach" check-in whose answers are shown back as patterns, and turn the „Pläne" tab into „Grenzen".

**Architecture:** Pure rules (which day is due, what a pattern counts) live in `KlarCore` and are tested with `swift test` in milliseconds. The app stores one `MorningAfter` SwiftData record per logical day, joins it to that day's entries through `KlarStore`, and renders a card, an Übersicht block and an entry-sheet line. Removal of plans and review happens before the new feature lands, so every commit builds and passes its tests.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, iOS 26.5 simulator, Xcode 26.6; Python 3 for the example-data generator.

**Spec:** [docs/superpowers/specs/2026-09-24-v3-morgen-danach-design.md](../specs/2026-09-24-v3-morgen-danach-design.md)

## Global Constraints

- Every file in `Packages/KlarCore/Sources` imports `Foundation` and nothing else.
- The Xcode project uses file-system-synchronized groups: new files under `Klar/Klar/`, `Klar/KlarTests/`, `Klar/KlarUITests/` are picked up without editing `project.pbxproj`. Moving a file is a plain `git mv`.
- UI copy is German. UI name of the feature: „Der Morgen danach". Code name: `MorningAfter`.
- Answer scales, UI labels in this order: Körper „gut / angeschlagen / verkatert", Reue „nein / ein bisschen / ja", Nochmal so „ja / anders / nein".
- **Deviation from the spec, on purpose:** the middle regret case is `slightly`, not `some` — `.some` collides with `Optional.some` wherever the value is optional.
- No praise, no colour coding, no comment on answers (concept P7, P8). No push notifications.
- `Nikotin` defaults to `asksMorningAfter = false`; every other substance, custom ones included, defaults to `true`.
- Export `schemaVersion` is `2`. Any other version is rejected before anything is deleted.
- Pattern threshold: at least 3 answered days, newest 5 counted.
- A due day expires 48 h after it ends; the logical day ends at 05:00 the next calendar day.
- Commit messages follow the repo style (imperative subject, explanatory body) and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

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

The SwiftData schema changes in Tasks 4, 5 and 6. A simulator that still holds an older store will crash on launch (`fatalError` in `ModelContainerFactory`) — delete the app from the simulator before running it by hand. UI tests are unaffected: `--klar-uitest-reset` deletes the store first.

---

## File map

| File | Change | Responsibility |
|---|---|---|
| `Packages/KlarCore/Sources/KlarCore/LogicalDay.swift` | modify | `dayKey(for:timezoneID:)`, `end(ofDayKey:timezoneID:)` |
| `Packages/KlarCore/Sources/KlarCore/MorningAfter.swift` | create | answer enums, `MorningAfterDTO` |
| `Packages/KlarCore/Sources/KlarCore/MorningAfterService.swift` | create | `dueDayKey`, `pattern`, `MorningPattern` |
| `Packages/KlarCore/Sources/KlarCore/DTOs.swift`, `Enums.swift` | modify | drop plan/review types, add `asksMorningAfter`, `morningAfters`, schema 2 |
| `Packages/KlarCore/Sources/KlarCore/PlanService.swift`, `PlanSentence.swift` | delete | |
| `Klar/Klar/Persistence/Models/MorningAfter.swift` | create | SwiftData model |
| `Klar/Klar/Persistence/Models/Plan.swift`, `PlanCheckIn.swift`, `ReviewDecision.swift` | delete | |
| `Klar/Klar/App/KlarStore.swift` | modify | drop plan/review API, add morning-after API |
| `Klar/Klar/App/MorningPatternText.swift` | create | German one-line rendering of a pattern |
| `Klar/Klar/Features/MorningAfter/MorningAfterCardView.swift` | create | the card |
| `Klar/Klar/Features/MorningAfter/MorningReflectionView.swift` | create | problem-solving flow |
| `Klar/Klar/Features/MorningAfter/MorningPatternsCard.swift` | create | Übersicht block |
| `Klar/Klar/Features/Limits/LimitsView.swift` | create | tab „Grenzen" |
| `Klar/Klar/Features/Limits/GoalCards.swift` | moved from `Features/Plans/GoalsView.swift` | `GoalCard`, `SubstancesView`, `SubstanceRow` |
| `Klar/Klar/Features/Limits/SubstitutionActionsView.swift` | moved from `Features/Plans/` | unchanged |
| `Klar/Klar/Features/Plans/PlansView.swift`, `PlanEditorView.swift`, `Features/CheckIn/PlanCheckInView.swift` | delete | |
| `Klar/Klar/Features/Review/WeeklyReviewFlowView.swift`, `App/WeeklyReviewSummary.swift`, `Features/Settings/NotificationScheduler.swift` | delete | |
| `Klar/Klar/App/RootView.swift` | modify | tab „Grenzen", card presentation |
| `Klar/Klar/Features/Today/TodayView.swift` | modify | plan block out, patterns card in |
| `Klar/Klar/Features/Entry/EntrySheetView.swift` | modify | pattern line in `EntryDetailForm` |
| `Klar/Klar/Features/History/HistoryView.swift`, `TrendsSectionView.swift` | modify | review segment and plan suggestion out |
| `Klar/Klar/Features/Settings/SettingsView.swift`, `App/AppSettings.swift` | modify | notifications and review bookkeeping out |
| `Klar/Klar/Features/Help/CravingSOSView.swift` | modify | copy |
| `Klar/Klar/Features/Onboarding/SubstanceCatalog.swift` | modify | Nikotin default |
| `Klar/Klar/App/UITestSupport.swift`, `KlarApp.swift` | modify | `--klar-uitest-seed-yesterday` |
| `Klar/Klar/Persistence/*` (`ModelContainerFactory`, `ModelDTOMapping`, `ExportImportService`, `DemoDataSeeder`), `Debug/DebugRootView.swift` | modify | schema and export |
| `tools/generate_example_data.py`, `examples/*` | modify / regenerate | schema 2 sample data |
| `docs/klar-screens-implementation.md`, `docs/klar-mvp-konzept.md` | modify | docs |

---

### Task 1: Day keys and the morning-after record in KlarCore

**Files:**
- Modify: `Packages/KlarCore/Sources/KlarCore/LogicalDay.swift`
- Create: `Packages/KlarCore/Sources/KlarCore/MorningAfter.swift`
- Test: `Packages/KlarCore/Tests/KlarCoreTests/LogicalDayTests.swift`, create `Packages/KlarCore/Tests/KlarCoreTests/MorningAfterDTOTests.swift`

**Interfaces:**
- Produces: `LogicalDay.dayKey(for: Date, timezoneID: String) -> String` („yyyy-MM-dd"), `LogicalDay.end(ofDayKey: String, timezoneID: String) -> Date?`, `enum MorningBody { fine, rough, hungover }`, `enum MorningRegret { no, slightly, yes }`, `enum MorningAgain { yes, differently, no }`, `struct MorningAfterDTO` with `isAnswered`.

- [ ] **Step 1: Write the failing tests**

Append to `LogicalDayTests` (inside the class; `date(...)` is the existing helper):

```swift
    func testDayKeyFollowsTheFiveAMCutoff() {
        XCTAssertEqual(LogicalDay.dayKey(for: date(2026, 9, 20, 2, 30, timezoneID: "Europe/Berlin"), timezoneID: "Europe/Berlin"), "2026-09-19")
        XCTAssertEqual(LogicalDay.dayKey(for: date(2026, 9, 20, 5, 0, timezoneID: "Europe/Berlin"), timezoneID: "Europe/Berlin"), "2026-09-20")
    }

    /// Keys are compared as strings everywhere, which only works with zero padding.
    func testDayKeyIsZeroPaddedSoItSortsAsAString() {
        let key = LogicalDay.dayKey(for: date(2026, 1, 5, 12, 0, timezoneID: "Europe/Berlin"), timezoneID: "Europe/Berlin")
        XCTAssertEqual(key, "2026-01-05")
        XCTAssertLessThan("2026-01-05", "2026-01-15")
    }

    func testDayKeyReadsTheInstantInTheGivenTimezone() {
        let instant = date(2026, 9, 20, 3, 0, timezoneID: "Europe/Berlin") // 21:00 the day before in New York
        XCTAssertEqual(LogicalDay.dayKey(for: instant, timezoneID: "Europe/Berlin"), "2026-09-19")
        XCTAssertEqual(LogicalDay.dayKey(for: instant, timezoneID: "America/New_York"), "2026-09-19")
        let later = date(2026, 9, 20, 12, 0, timezoneID: "Europe/Berlin") // 06:00 in New York
        XCTAssertEqual(LogicalDay.dayKey(for: later, timezoneID: "America/New_York"), "2026-09-20")
    }

    func testEndOfDayKeyIsFiveAMTheNextCalendarDay() {
        XCTAssertEqual(
            LogicalDay.end(ofDayKey: "2026-09-19", timezoneID: "Europe/Berlin"),
            date(2026, 9, 20, 5, 0, timezoneID: "Europe/Berlin")
        )
        XCTAssertNil(LogicalDay.end(ofDayKey: "kein Datum", timezoneID: "Europe/Berlin"))
    }
```

Create `MorningAfterDTOTests.swift`:

```swift
import XCTest
@testable import KlarCore

final class MorningAfterDTOTests: XCTestCase {
    func testARecordWithoutAnswersIsASkip() {
        XCTAssertFalse(MorningAfterDTO(dayKey: "2026-09-19").isAnswered)
        XCTAssertFalse(MorningAfterDTO(dayKey: "2026-09-19", note: "nur eine Notiz").isAnswered)
    }

    func testAnyOneAnswerCountsAsAnswered() {
        XCTAssertTrue(MorningAfterDTO(dayKey: "2026-09-19", body: .hungover).isAnswered)
        XCTAssertTrue(MorningAfterDTO(dayKey: "2026-09-19", regret: .slightly).isAnswered)
        XCTAssertTrue(MorningAfterDTO(dayKey: "2026-09-19", again: .differently).isAnswered)
    }

    func testRoundTripsThroughTheExportCoder() throws {
        let record = MorningAfterDTO(
            dayKey: "2026-09-19", body: .rough, regret: .no, again: .yes,
            note: "Früh gegangen", trigger: nil, wouldHaveHelped: nil, nextTime: "Wasser dazwischen",
            recordedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        let data = try KlarExportCoding.makeEncoder().encode(record)
        XCTAssertEqual(try KlarExportCoding.makeDecoder().decode(MorningAfterDTO.self, from: data), record)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KlarCore`
Expected: compile errors — `dayKey`, `end(ofDayKey:)`, `MorningAfterDTO` not found.

- [ ] **Step 3: Implement**

Add to `LogicalDay` (after `isLogicalDayBefore`, before the private `calendar(for:)`):

```swift
    /// The logical day as "yyyy-MM-dd". The key a morning-after record is filed under, and
    /// zero-padded so two keys compare correctly as plain strings.
    public static func dayKey(for date: Date, timezoneID: String) -> String {
        let day = components(for: date, timezoneID: timezoneID)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    /// The instant a logical day ends: the cutoff hour on the following calendar day.
    public static func end(ofDayKey key: String, timezoneID: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let calendar = calendar(for: timezoneID)
        guard let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let next = calendar.date(byAdding: .day, value: 1, to: start)
        else { return nil }
        return calendar.date(bySettingHour: cutoffHour, minute: 0, second: 0, of: next)
    }
```

Create `MorningAfter.swift`:

```swift
import Foundation

/// „Wie geht's dir heute körperlich?" — gut / angeschlagen / verkatert.
public enum MorningBody: String, Codable, CaseIterable, Sendable {
    case fine, rough, hungover
}

/// „Bereust du etwas von gestern?" — nein / ein bisschen / ja.
///
/// The middle case is `slightly`, not `some`: the value is always optional, and `.some` would
/// resolve to `Optional.some`.
public enum MorningRegret: String, Codable, CaseIterable, Sendable {
    case no, slightly, yes
}

/// „Würdest du es wieder so machen?" — ja / anders / nein.
public enum MorningAgain: String, Codable, CaseIterable, Sendable {
    case yes, differently, no
}

/// One logical day's morning-after answers (concept v3, module C).
///
/// A record with no answers is a skip. It exists so the day is never asked about again.
public struct MorningAfterDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var dayKey: String
    public var body: MorningBody?
    public var regret: MorningRegret?
    public var again: MorningAgain?
    public var note: String?
    /// Problem solving: „Was war der Auslöser?"
    public var trigger: String?
    /// „Was hätte geholfen?"
    public var wouldHaveHelped: String?
    /// „Was machst du nächstes Mal anders?" — the one answer shown back with the pattern.
    public var nextTime: String?
    public var recordedAt: Date

    public var isAnswered: Bool { body != nil || regret != nil || again != nil }

    public init(
        id: UUID = UUID(),
        dayKey: String,
        body: MorningBody? = nil,
        regret: MorningRegret? = nil,
        again: MorningAgain? = nil,
        note: String? = nil,
        trigger: String? = nil,
        wouldHaveHelped: String? = nil,
        nextTime: String? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.dayKey = dayKey
        self.body = body
        self.regret = regret
        self.again = again
        self.note = note
        self.trigger = trigger
        self.wouldHaveHelped = wouldHaveHelped
        self.nextTime = nextTime
        self.recordedAt = recordedAt
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KlarCore`
Expected: all tests pass, including the 7 new ones.

- [ ] **Step 5: Commit**

```bash
git add Packages/KlarCore/Sources/KlarCore/LogicalDay.swift Packages/KlarCore/Sources/KlarCore/MorningAfter.swift Packages/KlarCore/Tests/KlarCoreTests/LogicalDayTests.swift Packages/KlarCore/Tests/KlarCoreTests/MorningAfterDTOTests.swift
git commit -m "Add day keys and the morning-after record to KlarCore

A morning-after answer belongs to a logical day, not to an entry, so it
is filed under a zero-padded yyyy-MM-dd key that compares as a string.
end(ofDayKey:) gives the 05:00 boundary the expiry rule needs.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Which day is due

**Files:**
- Create: `Packages/KlarCore/Sources/KlarCore/MorningAfterService.swift`
- Test: create `Packages/KlarCore/Tests/KlarCoreTests/MorningAfterDueDayTests.swift`

**Interfaces:**
- Consumes: `LogicalDay.dayKey`, `LogicalDay.end(ofDayKey:timezoneID:)`, `MorningAfterDTO`, `EntryDTO(substanceID:timestamp:timezoneID:amount:contextTagIDs:)`.
- Produces: `MorningAfterService.expiry: TimeInterval` (48 h), `MorningAfterService.dueDayKey(entries:askingSubstanceIDs:records:now:nowTimezoneID:) -> String?`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import KlarCore

final class MorningAfterDueDayTests: XCTestCase {
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

    private func due(_ entries: [EntryDTO], records: [MorningAfterDTO] = [], asking: Set<UUID>? = nil, now: Date) -> String? {
        MorningAfterService.dueDayKey(
            entries: entries,
            askingSubstanceIDs: asking ?? [alcohol],
            records: records,
            now: now,
            nowTimezoneID: berlin
        )
    }

    func testAnEntryAtHalfPastTwoMakesThePreviousEveningDue() {
        XCTAssertEqual(due([entry(alcohol, date(2026, 9, 20, 2, 30))], now: date(2026, 9, 20, 10)), "2026-09-19")
    }

    func testASwitchedOffSubstanceNeverTriggers() {
        XCTAssertNil(due([entry(nicotine, date(2026, 9, 19, 21))], now: date(2026, 9, 20, 10)))
    }

    func testDueUntilFortyEightHoursAfterTheDayEnds() {
        let entries = [entry(alcohol, date(2026, 9, 19, 22))] // day ends 2026-09-20 05:00
        XCTAssertEqual(due(entries, now: date(2026, 9, 22, 4, 59)), "2026-09-19")
        XCTAssertNil(due(entries, now: date(2026, 9, 22, 5, 0)))
    }

    func testANewerDayHidesAnOlderUnansweredOne() {
        let entries = [entry(alcohol, date(2026, 9, 17, 21)), entry(alcohol, date(2026, 9, 19, 21))]
        XCTAssertEqual(due(entries, now: date(2026, 9, 20, 10)), "2026-09-19")
    }

    /// Once the newest day has a record, older unanswered days stay unasked.
    func testAnAnsweredNewestDayDoesNotFallBackToAnOlderOne() {
        let entries = [entry(alcohol, date(2026, 9, 17, 21)), entry(alcohol, date(2026, 9, 19, 21))]
        let records = [MorningAfterDTO(dayKey: "2026-09-19", body: .fine)]
        XCTAssertNil(due(entries, records: records, now: date(2026, 9, 20, 10)))
    }

    func testASkipStopsTheQuestion() {
        let entries = [entry(alcohol, date(2026, 9, 19, 21))]
        XCTAssertNil(due(entries, records: [MorningAfterDTO(dayKey: "2026-09-19")], now: date(2026, 9, 20, 10)))
    }

    func testNoEntriesMeansNothingIsDue() {
        XCTAssertNil(due([], now: date(2026, 9, 20, 10)))
    }

    func testTodaysEntriesAloneAreNotDue() {
        XCTAssertNil(due([entry(alcohol, date(2026, 9, 20, 9))], now: date(2026, 9, 20, 10)))
    }

    /// A morning cigarette must not cancel last night's card (spec § 1.3).
    func testAnEntryTodayDoesNotExpireYesterday() {
        let entries = [entry(alcohol, date(2026, 9, 19, 21)), entry(alcohol, date(2026, 9, 20, 9))]
        XCTAssertEqual(due(entries, now: date(2026, 9, 20, 10)), "2026-09-19")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KlarCore`
Expected: compile error — `MorningAfterService` not found.

- [ ] **Step 3: Implement**

Create `MorningAfterService.swift`:

```swift
import Foundation

public enum MorningAfterService {
    /// How long after a logical day ends its card may still appear.
    public static let expiry: TimeInterval = 48 * 60 * 60

    /// The logical day „Der Morgen danach" should ask about now, if any.
    ///
    /// Only the newest day before today with an entry of an asking substance is ever a
    /// candidate. If it already has a record — answered or skipped — nothing is due, and older
    /// days are never asked about. It expires 48 h after the day ends (05:00 the next calendar
    /// day, in the timezone of that day's latest entry).
    public static func dueDayKey(
        entries: [EntryDTO],
        askingSubstanceIDs: Set<UUID>,
        records: [MorningAfterDTO],
        now: Date,
        nowTimezoneID: String
    ) -> String? {
        let todayKey = LogicalDay.dayKey(for: now, timezoneID: nowTimezoneID)

        var latestEntryByDay: [String: EntryDTO] = [:]
        for entry in entries {
            guard let substanceID = entry.substanceID, askingSubstanceIDs.contains(substanceID) else { continue }
            let key = LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID)
            guard key < todayKey else { continue }
            if let known = latestEntryByDay[key], known.timestamp >= entry.timestamp { continue }
            latestEntryByDay[key] = entry
        }

        guard let candidate = latestEntryByDay.keys.max(),
              let latest = latestEntryByDay[candidate],
              !records.contains(where: { $0.dayKey == candidate }),
              let end = LogicalDay.end(ofDayKey: candidate, timezoneID: latest.timezoneID),
              now < end.addingTimeInterval(expiry)
        else { return nil }

        return candidate
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KlarCore`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/KlarCore/Sources/KlarCore/MorningAfterService.swift Packages/KlarCore/Tests/KlarCoreTests/MorningAfterDueDayTests.swift
git commit -m "Decide which day the morning-after card asks about

Only the newest day before today with an asking substance is a
candidate, never an older one, and it expires 48 h after the day ends.
An entry today does not cancel it, so a morning cigarette cannot wipe
out last night's card.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Patterns

**Files:**
- Modify: `Packages/KlarCore/Sources/KlarCore/MorningAfterService.swift`
- Test: create `Packages/KlarCore/Tests/KlarCoreTests/MorningPatternTests.swift`

**Interfaces:**
- Consumes: Task 1 and 2 types.
- Produces: `struct MorningPattern { days: Int; body: [MorningBody: Int]; regret: [MorningRegret: Int]; again: [MorningAgain: Int]; nextTime: String? }`, `MorningAfterService.pattern(substanceID: UUID, contextTagID: UUID?, entries: [EntryDTO], records: [MorningAfterDTO], limit: Int = 5, minimum: Int = 3) -> MorningPattern?`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import KlarCore

final class MorningPatternTests: XCTestCase {
    private let berlin = "Europe/Berlin"
    private let alcohol = UUID()
    private let coffee = UUID()
    private let club = UUID()

    private func evening(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: berlin)!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 21))!
    }

    private func key(_ day: Int) -> String { String(format: "2026-09-%02d", day) }

    private func entry(_ substance: UUID, day: Int, tags: [UUID]? = nil) -> EntryDTO {
        EntryDTO(substanceID: substance, timestamp: evening(day), timezoneID: berlin, amount: nil, contextTagIDs: tags)
    }

    private func pattern(_ entries: [EntryDTO], _ records: [MorningAfterDTO], tag: UUID? = nil) -> MorningPattern? {
        MorningAfterService.pattern(substanceID: alcohol, contextTagID: tag, entries: entries, records: records)
    }

    func testFewerThanThreeAnsweredDaysIsNoPattern() {
        let entries = [entry(alcohol, day: 1), entry(alcohol, day: 2)]
        let records = [MorningAfterDTO(dayKey: key(1), body: .hungover), MorningAfterDTO(dayKey: key(2), body: .fine)]
        XCTAssertNil(pattern(entries, records))
    }

    func testCountsEachAnswerOfTheMatchingDays() throws {
        let entries = (1...4).map { entry(alcohol, day: $0) }
        let records = [
            MorningAfterDTO(dayKey: key(1), body: .hungover, regret: .yes),
            MorningAfterDTO(dayKey: key(2), body: .hungover, regret: .no),
            MorningAfterDTO(dayKey: key(3), body: .fine, again: .yes),
            MorningAfterDTO(dayKey: key(4), body: .rough, regret: .slightly, again: .differently)
        ]
        let result = try XCTUnwrap(pattern(entries, records))
        XCTAssertEqual(result.days, 4)
        XCTAssertEqual(result.body, [.hungover: 2, .fine: 1, .rough: 1])
        XCTAssertEqual(result.regret, [.yes: 1, .no: 1, .slightly: 1])
        XCTAssertEqual(result.again, [.yes: 1, .differently: 1])
    }

    func testTheContextFilterKeepsOnlyDaysWithThatTag() throws {
        let entries = [
            entry(alcohol, day: 1, tags: [club]), entry(alcohol, day: 2, tags: [club]), entry(alcohol, day: 3, tags: [club]),
            entry(alcohol, day: 4), entry(alcohol, day: 5)
        ]
        let records = (1...5).map { MorningAfterDTO(dayKey: key($0), body: $0 <= 3 ? .hungover : .fine) }
        XCTAssertEqual(try XCTUnwrap(pattern(entries, records, tag: club)).body, [.hungover: 3])
        XCTAssertEqual(try XCTUnwrap(pattern(entries, records)).days, 5)
    }

    func testAPartialAnswerCountsAsADayButOnlyInWhatItAnswered() throws {
        let entries = (1...3).map { entry(alcohol, day: $0) }
        let records = [
            MorningAfterDTO(dayKey: key(1), body: .hungover),
            MorningAfterDTO(dayKey: key(2), body: .fine),
            MorningAfterDTO(dayKey: key(3), regret: .yes)
        ]
        let result = try XCTUnwrap(pattern(entries, records))
        XCTAssertEqual(result.days, 3)
        XCTAssertEqual(result.body, [.hungover: 1, .fine: 1])
        XCTAssertEqual(result.regret, [.yes: 1])
    }

    func testSkipsAreNotCounted() {
        let entries = (1...3).map { entry(alcohol, day: $0) }
        let records = [
            MorningAfterDTO(dayKey: key(1), body: .fine),
            MorningAfterDTO(dayKey: key(2), body: .fine),
            MorningAfterDTO(dayKey: key(3))
        ]
        XCTAssertNil(pattern(entries, records))
    }

    func testOnlyTheNewestFiveDaysAreCounted() throws {
        let entries = (1...7).map { entry(alcohol, day: $0) }
        let records = (1...7).map { MorningAfterDTO(dayKey: key($0), body: $0 <= 2 ? .hungover : .fine) }
        let result = try XCTUnwrap(pattern(entries, records))
        XCTAssertEqual(result.days, 5)
        XCTAssertEqual(result.body, [.fine: 5])
    }

    func testDaysOfAnotherSubstanceDoNotCount() {
        let entries = [entry(alcohol, day: 1), entry(coffee, day: 2), entry(coffee, day: 3)]
        let records = (1...3).map { MorningAfterDTO(dayKey: key($0), body: .fine) }
        XCTAssertNil(pattern(entries, records))
    }

    func testNextTimeIsTheLatestNonEmptyAnswer() throws {
        let entries = (1...3).map { entry(alcohol, day: $0) }
        var records = [
            MorningAfterDTO(dayKey: key(1), body: .hungover, nextTime: "Früher heim"),
            MorningAfterDTO(dayKey: key(2), body: .fine, nextTime: "   "),
            MorningAfterDTO(dayKey: key(3), body: .fine)
        ]
        XCTAssertEqual(try XCTUnwrap(pattern(entries, records)).nextTime, "Früher heim")
        records[2].nextTime = "Wasser dazwischen"
        XCTAssertEqual(try XCTUnwrap(pattern(entries, records)).nextTime, "Wasser dazwischen")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KlarCore`
Expected: compile error — `MorningPattern` / `pattern` not found.

- [ ] **Step 3: Implement**

Append to `MorningAfterService.swift`, above `public enum MorningAfterService`:

```swift
/// What the newest answered mornings after a substance looked like. Plain counts, no score.
public struct MorningPattern: Sendable, Equatable {
    /// Answered days counted, between `minimum` and `limit`.
    public let days: Int
    public let body: [MorningBody: Int]
    public let regret: [MorningRegret: Int]
    public let again: [MorningAgain: Int]
    /// The latest non-empty „Was machst du nächstes Mal anders?" among those days.
    public let nextTime: String?

    public init(days: Int, body: [MorningBody: Int], regret: [MorningRegret: Int], again: [MorningAgain: Int], nextTime: String?) {
        self.days = days
        self.body = body
        self.regret = regret
        self.again = again
        self.nextTime = nextTime
    }
}
```

and inside `MorningAfterService`, after `dueDayKey`:

```swift
    /// The pattern for one substance, optionally narrowed to days whose entries of that
    /// substance carry `contextTagID`. `nil` below `minimum` answered days.
    public static func pattern(
        substanceID: UUID,
        contextTagID: UUID?,
        entries: [EntryDTO],
        records: [MorningAfterDTO],
        limit: Int = 5,
        minimum: Int = 3
    ) -> MorningPattern? {
        var matchingDays: Set<String> = []
        for entry in entries where entry.substanceID == substanceID {
            if let contextTagID, entry.contextTagIDs?.contains(contextTagID) != true { continue }
            matchingDays.insert(LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID))
        }

        let counted = records
            .filter { $0.isAnswered && matchingDays.contains($0.dayKey) }
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(limit)
        guard counted.count >= minimum else { return nil }

        var body: [MorningBody: Int] = [:]
        var regret: [MorningRegret: Int] = [:]
        var again: [MorningAgain: Int] = [:]
        for record in counted {
            if let answer = record.body { body[answer, default: 0] += 1 }
            if let answer = record.regret { regret[answer, default: 0] += 1 }
            if let answer = record.again { again[answer, default: 0] += 1 }
        }
        let nextTime = counted.lazy
            .compactMap { $0.nextTime?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return MorningPattern(days: counted.count, body: body, regret: regret, again: again, nextTime: nextTime)
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KlarCore`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/KlarCore/Sources/KlarCore/MorningAfterService.swift Packages/KlarCore/Tests/KlarCoreTests/MorningPatternTests.swift
git commit -m "Count what the last mornings after a substance looked like

A pattern is the newest five answered days with that substance,
optionally narrowed to one context tag, and nothing below three. It is
counts only, no score, so the UI can say „3× verkatert" and no more.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Remove the weekly review and its notification

**Files:**
- Delete: `Klar/Klar/Features/Review/WeeklyReviewFlowView.swift`, `Klar/Klar/App/WeeklyReviewSummary.swift`, `Klar/Klar/Features/Settings/NotificationScheduler.swift`, `Klar/Klar/Persistence/Models/ReviewDecision.swift`
- Modify: `Klar/Klar/Features/History/HistoryView.swift`, `Klar/Klar/Features/History/TrendsSectionView.swift`, `Klar/Klar/App/RootView.swift`, `Klar/Klar/App/AppSettings.swift`, `Klar/Klar/Features/Settings/SettingsView.swift`, `Klar/Klar/App/KlarStore.swift`, `Klar/Klar/Persistence/ModelContainerFactory.swift`, `Klar/Klar/Persistence/ModelDTOMapping.swift`, `Klar/Klar/Persistence/ExportImportService.swift`, `Klar/Klar/Debug/DebugRootView.swift`, `Packages/KlarCore/Sources/KlarCore/DTOs.swift`, `Packages/KlarCore/Sources/KlarCore/Enums.swift`
- Test: `Klar/KlarTests/ExportImportTests.swift`, `Klar/KlarUITests/ScreenshotTests.swift`

**Interfaces:**
- Produces: `KlarExport.currentSchemaVersion == 2` (the envelope shrinks again in Task 5 and grows in Task 6 without another bump — no schema 2 file exists outside this branch). `ExportImportService.decode` checks the version before decoding the rest.

- [ ] **Step 1: Write the failing test**

In `ExportImportTests`, add:

```swift
    /// A file from before v3 has plans and no morning-after records. It must fail on its
    /// version, so the user sees why, not on whichever key happens to be missing.
    func testDecodeRejectsASchemaOneFileOnItsVersion() throws {
        let payload = #"{"schemaVersion": 1, "exportedAt": "1970-01-01T00:00:00Z", "substances": [], "entries": [], "contextTags": [], "goalPeriods": [], "plans": [], "planCheckIns": [], "substitutionActions": [], "whyNotes": [], "reviewDecisions": []}"#

        XCTAssertThrowsError(try ExportImportService.decode(Data(payload.utf8))) { error in
            XCTAssertEqual(error as? ExportImportError, .unknownSchemaVersion(1))
        }
    }
```

Change `testDecodeRejectsAnUnknownSchemaVersion`'s payload to the version alone, since the version is now checked first:

```swift
        let payload = #"{"schemaVersion": 999}"#
```

- [ ] **Step 2: Run the test to verify it fails**

Run the app unit tests.
Expected: `testDecodeRejectsASchemaOneFileOnItsVersion` fails (schema 1 is still current), `testDecodeRejectsAnUnknownSchemaVersion` fails with a `DecodingError`.

- [ ] **Step 3: Version-first decode and schema 2**

In `Packages/KlarCore/Sources/KlarCore/DTOs.swift`:
- delete `public struct ReviewDecisionDTO` entirely;
- in `KlarExport`: `currentSchemaVersion = 2`; remove the `reviewDecisions` property, its init parameter and its assignment.

In `Enums.swift` delete `public enum ReviewPlanDecision`.

In `ExportImportService.decode(_:)` replace the body with:

```swift
    static func decode(_ data: Data) throws -> KlarExport {
        // The version first, on its own: a file from another schema is missing keys this one
        // requires, and would otherwise fail as a generic decoding error instead of saying why.
        struct VersionProbe: Decodable { let schemaVersion: Int }
        let decoder = KlarExportCoding.makeDecoder()
        let version = try decoder.decode(VersionProbe.self, from: data).schemaVersion
        guard version == KlarExport.currentSchemaVersion else {
            throw ExportImportError.unknownSchemaVersion(version)
        }
        return try decoder.decode(KlarExport.self, from: data)
    }
```

In the same file delete `try context.delete(model: ReviewDecision.self)` from `wipeAll`, the `reviewDecisions:` argument from `buildExport`, and the `for dto in export.reviewDecisions { … }` loop from `insert`.

- [ ] **Step 4: Remove the review everywhere else**

1. `git rm Klar/Klar/Features/Review/WeeklyReviewFlowView.swift Klar/Klar/App/WeeklyReviewSummary.swift Klar/Klar/Features/Settings/NotificationScheduler.swift Klar/Klar/Persistence/Models/ReviewDecision.swift`
2. `ModelContainerFactory.schema`: remove `ReviewDecision.self`. `DebugRootView` preview container: remove `ReviewDecision.self`.
3. `ModelDTOMapping.swift`: delete `extension ReviewDecision`.
4. `KlarStore.swift`: delete `reviewDecisions()`, the `// MARK: - Weekly review` section with `recordReviewDecision`.
5. `TrendsSectionView.swift`: delete everything from `// MARK: - E4 · Weekly-Review-Archiv` to the end of the file (`ReviewArchiveSectionView` and `IdentifiableWeek`).
6. `HistoryView.swift`:
   - `enum Section` becomes `case calendar, trends`;
   - the options array loses `(Section.review, "Rückblick")`;
   - `sectionContent` loses `case .review: ReviewArchiveSectionView()`;
   - delete the computed `title` and pass `KlarScreen(title: "Verlauf")`;
   - in the doc comment replace „E1–E4" with „E1–E3", and rewrite the deviation paragraph to: „The draft's segmented control has two segments (Kalender / Rückblick). The weekly review is gone (concept v3), and „Trends" (E3) takes the second segment."
7. `RootView.swift` (`MainTabView`): delete `@State private var isReviewPresented`, the `.fullScreenCover(isPresented: $isReviewPresented)` modifier, and the `if WeeklyReviewSummary.isReviewDue(…) { … }` block in `presentDueMoments()`. Update the doc comment on the state properties to name only the plan check-in (it goes in Task 5).
8. `AppSettings.swift`: delete `areNotificationsEnabled` and `lastReviewedWeekStart` (properties, init lines, keys); `resetForOnboarding()` keeps only `hasCompletedOnboarding = false`.
9. `SettingsView.swift`: delete the `SettingsToggleRow(icon: "bell", …)` block together with the `KlarRowDivider()` directly above it, and delete `enableNotifications(_:)`.
10. `ExportImportTests.testJSONRoundTripRestoresIdenticalDatabase`: delete the `reviewDecision` insert and the `importedReviewDecisions` assertions.
11. `ScreenshotTests.testCaptureAllScreens`: delete the three lines of the `// E4 · Rückblick-Archiv` step.

Then confirm nothing still refers to the removed names:

```bash
grep -rn "ReviewDecision\|WeeklyReview\|NotificationScheduler\|lastReviewedWeekStart\|areNotificationsEnabled\|ReviewArchive\|ArchivedReviewView" Klar Packages/KlarCore/Sources Packages/KlarCore/Tests
```

Expected: no output.

- [ ] **Step 5: Build and run the tests**

Run the KlarCore tests, the app build, the app unit tests and the UI tests.
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add -A Klar Packages/KlarCore
git commit -m "Remove the weekly review

With plans gone there is nothing left to decide at the end of a week,
and a full-screen summary that pushes itself in once a week is the kind
of chore v3 is dropping. The archive, the reminder and ReviewDecision
go with it.

The export moves to schema 2 and reads the version before anything
else, so an old file is refused for its version rather than for
whichever key it lacks.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Remove plans; „Pläne" becomes „Grenzen"

**Files:**
- Delete: `Klar/Klar/Features/Plans/PlansView.swift`, `Klar/Klar/Features/Plans/PlanEditorView.swift`, `Klar/Klar/Features/CheckIn/PlanCheckInView.swift`, `Klar/Klar/Persistence/Models/Plan.swift`, `Klar/Klar/Persistence/Models/PlanCheckIn.swift`, `Packages/KlarCore/Sources/KlarCore/PlanService.swift`, `Packages/KlarCore/Sources/KlarCore/PlanSentence.swift`, `Packages/KlarCore/Tests/KlarCoreTests/PlanServiceTests.swift`, `Packages/KlarCore/Tests/KlarCoreTests/PlanSentenceTests.swift`
- Move: `Klar/Klar/Features/Plans/GoalsView.swift` → `Klar/Klar/Features/Limits/GoalCards.swift`; `Klar/Klar/Features/Plans/SubstitutionActionsView.swift` → `Klar/Klar/Features/Limits/SubstitutionActionsView.swift`
- Create: `Klar/Klar/Features/Limits/LimitsView.swift`
- Modify: `RootView.swift`, `TodayView.swift`, `TrendsSectionView.swift`, `CravingSOSView.swift`, `KlarStore.swift`, `KlarDate.swift`, `ModelContainerFactory.swift`, `ModelDTOMapping.swift`, `ExportImportService.swift`, `DemoDataSeeder.swift`, `DebugRootView.swift`, `DTOs.swift`, `Enums.swift`
- Test: `Klar/KlarUITests/KlarUITests.swift`, `Klar/KlarUITests/ScreenshotTests.swift`, `Klar/KlarTests/ExportImportTests.swift`, `Klar/KlarTests/ContextTagRelationshipTests.swift`

**Interfaces:**
- Produces: `KlarTab.limits`; `LimitsView`; accessibility identifier `limits.substitutionsLink`; `TodayView()` without parameters.

- [ ] **Step 1: Change the UI test first**

In `KlarUITests.testTabsAreReachableAfterOnboarding` replace the „Pläne" step with:

```swift
        app.tabBars.buttons["Grenzen"].tap()
        XCTAssertTrue(app.buttons["limits.substitutionsLink"].waitForExistence(timeout: 5))
```

and update the doc comment to „The four tabs are reachable and each renders its own screen." (unchanged count).

- [ ] **Step 2: Run it to verify it fails**

Run: `xcodebuild test … -only-testing:KlarUITests/KlarUITests/testTabsAreReachableAfterOnboarding -quiet`
Expected: FAIL — there is no „Grenzen" tab.

- [ ] **Step 3: Delete the plan code and types**

```bash
git rm Klar/Klar/Features/Plans/PlansView.swift Klar/Klar/Features/Plans/PlanEditorView.swift Klar/Klar/Features/CheckIn/PlanCheckInView.swift Klar/Klar/Persistence/Models/Plan.swift Klar/Klar/Persistence/Models/PlanCheckIn.swift Packages/KlarCore/Sources/KlarCore/PlanService.swift Packages/KlarCore/Sources/KlarCore/PlanSentence.swift Packages/KlarCore/Tests/KlarCoreTests/PlanServiceTests.swift Packages/KlarCore/Tests/KlarCoreTests/PlanSentenceTests.swift
mkdir -p Klar/Klar/Features/Limits
git mv Klar/Klar/Features/Plans/GoalsView.swift Klar/Klar/Features/Limits/GoalCards.swift
git mv Klar/Klar/Features/Plans/SubstitutionActionsView.swift Klar/Klar/Features/Limits/SubstitutionActionsView.swift
```

- `DTOs.swift`: delete `PlanDTO`, `PlanCheckInDTO`; remove `plans` and `planCheckIns` from `KlarExport` (properties, init parameters, assignments).
- `Enums.swift`: delete `PlanStatus` and `CheckInOutcome`.
- `ModelDTOMapping.swift`: delete `extension Plan` and `extension PlanCheckIn`.
- `ModelContainerFactory.schema` and the `DebugRootView` preview: remove `Plan.self` and `PlanCheckIn.self`.
- `ExportImportService.swift`: remove `Plan`/`PlanCheckIn` from `wipeAll`, `plans:`/`planCheckIns:` from `buildExport`, and the plan and check-in loops from `insert`. `entryByID` is then write-only: delete it and the `entryByID[dto.id] = entry` line.
- `KlarStore.swift`: delete `allPlans()`, `activePlans()`, `allCheckIns()`, the whole `// MARK: - Plans` and `// MARK: - Plan suggestion (G2)` sections. `deleteEntry` becomes:

```swift
    func deleteEntry(_ entry: Entry) {
        context.delete(entry)
        save()
    }
```

  and the type's doc comment drops „the plan-versioning rules": „…so the quota rules and the logical-day boundary live in exactly one place."
- `DemoDataSeeder.swift`: delete the block from `// Two plans; …` through the second `context.insert(Plan(…))`. `sozial` was only used by the plans: delete its `let` line. `allein`, `zuhause` and `club` stay, the entries use them.

- [ ] **Step 4: The Grenzen tab**

In `GoalCards.swift` delete `struct GoalsView` (from its doc comment `/// G4 · Ziele je Substanz.` through its closing brace) and put this doc comment on `GoalCard`:

```swift
/// One substance's limit on the Grenzen tab.
///
/// Every change *versions* the goal rather than overwriting it (see `KlarStore.setGoal`), so a
/// past month keeps the limit that was actually in force at the time.
```

Create `Klar/Klar/Features/Limits/LimitsView.swift`:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// Tab „Grenzen". The limits each substance runs under, the switch that decides whether
/// „Der Morgen danach" asks about it (added with the card), and the way to the substitutions
/// the Craving-SOS offers.
struct LimitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var substances: [Substance]
    @Query private var goalPeriods: [GoalPeriod]

    @State private var isManagingSubstances = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            KlarScreen(title: "Grenzen") {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 12) {
                        ForEach(activeSubstances) { substance in
                            GoalCard(substance: substance, store: store)
                        }
                    }

                    KlarDashedButton(title: "Substanzen verwalten", systemImage: "slider.horizontal.3") {
                        isManagingSubstances = true
                    }
                    .padding(.top, 12)

                    KlarCard(padding: 0) {
                        NavigationLink {
                            SubstitutionActionsView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Klar.textSecondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Ersatzhandlungen")
                                        .font(Klar.TypeScale.body)
                                        .foregroundStyle(Klar.text)
                                    Text("Genutzt im Craving-SOS")
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
                        .klarRowButtonStyle()
                        .accessibilityIdentifier("limits.substitutionsLink")
                    }
                    .padding(.top, 24)
                }
            }
            .sheet(isPresented: $isManagingSubstances) {
                SubstancesView()
            }
        }
    }
}
```

In `RootView.swift`:
- `enum KlarTab` becomes `case today, history, limits, help`;
- the third tab is

```swift
            LimitsView()
                .tabItem { Label("Grenzen", systemImage: "gauge.with.dots.needle.33percent") }
                .tag(KlarTab.limits)
```

- `TodayView(selectedTab: $selectedTab)` becomes `TodayView()`;
- delete `@State private var pendingCheckIn`, the `.sheet(item: $pendingCheckIn)` modifier, the `.task { await presentDueMoments() }` modifier, `presentDueMoments()`, and `struct PendingCheckIn`. The card brings a presentation back in Task 7.
- The comment next to `tabViewBottomAccessory` that names „Verlauf, Pläne und Hilfe" says „Verlauf, Grenzen und Hilfe".

- [ ] **Step 5: Übersicht, Trends, SOS, dates**

`TodayView.swift`:
- delete `@Binding var selectedTab`, `@Query private var plans`, `@State private var planBeingEdited`, `activePlan`, the `.sheet(item: $planBeingEdited)` modifier, the whole `if let activePlan { … } else if !substances.isEmpty { … }` block, and `struct PlanSummaryCard` with its `// MARK: - Plan card`;
- the type's doc comment: „The hierarchy of the screen is the hierarchy of the message: limits on top, what was actually logged underneath."

`TrendsSectionView.swift`:
- delete `@State private var planTagSeed`, the `.sheet(item: $planTagSeed)` modifier, and the trailing closure passed to `ContextDistributionCard`;
- in `ContextDistributionCard` delete `let onBuildPlan`, `dominant`, and the `if let dominant { … }` block;
- the empty text becomes „Noch keine Kontext-Tags erfasst. Sie sind optional.";
- the type's doc comment: `/// E3 · Trends je Substanz.` and nothing more.

`CravingSOSView.swift`: „Dieses Gefühl geht vorbei. Du hast einen Plan." → „Dieses Gefühl geht vorbei."

`KlarDate.swift`: for each of `dayAndMonth`, `weekStart(for:)`, `weekEnd(for:)`, `weekRange`, `weekRangeLong`, run

```bash
grep -rn "KlarDate.dayAndMonth\|KlarDate.weekStart\|KlarDate.weekEnd\|KlarDate.weekRange" Klar
```

and delete every helper with no remaining caller, together with its doc comment.

- [ ] **Step 6: Tests that still talk about plans**

- `ExportImportTests.testJSONRoundTripRestoresIdenticalDatabase`: delete the `plan` and `checkIn` inserts and the `importedPlans` / `importedCheckIns` assertions.
- `ContextTagRelationshipTests`: delete `testATagCanBeAPlanSituationAndAnEntryContextAtOnce`; in the file's doc comment, drop „a plan suggestion that never appears, and check-ins".
- `ScreenshotTests.testCaptureAllScreens`: replace the `// G2 · Pläne (leer)` and `// G4 · Ziele` steps with

```swift
        // G · Grenzen
        app.tabBars.buttons["Grenzen"].tap()
        XCTAssertTrue(app.buttons["limits.substitutionsLink"].waitForExistence(timeout: 5))
        capture(app, "G-Grenzen")
```

  and the H2 assertion text with „Dieses Gefühl geht vorbei."

Confirm:

```bash
grep -rn "Plan\b\|PlanDTO\|PlanCheckIn\|PlanService\|PlanSentence\|PlanStatus\|CheckInOutcome\|PlansView\|PlanEditor\|GoalsView()\|plans.goalsLink\|KlarTab.plans" Klar Packages/KlarCore/Sources Packages/KlarCore/Tests
```

Expected: no output.

- [ ] **Step 7: Build and run everything**

Run the KlarCore tests, the app unit tests and the UI tests.
Expected: all pass, including `testTabsAreReachableAfterOnboarding`.

- [ ] **Step 8: Commit**

```bash
git add -A Klar Packages/KlarCore
git commit -m "Remove if-then plans and turn the Pläne tab into Grenzen

Concept v3 drops action planning: for someone who wants to keep an eye
on their use rather than cut it, a plan is a chore without a reason.
The plan list, editor and check-in go, and so do the Übersicht card and
the „Plan dafür bauen?" offer in Trends.

The limits that lived one level down under Pläne → Ziele now fill the
tab directly, with the link to the substitutions below them.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Store the morning after

**Files:**
- Create: `Klar/Klar/Persistence/Models/MorningAfter.swift`, `Klar/KlarTests/KlarStoreMorningAfterTests.swift`
- Modify: `Klar/Klar/Persistence/Models/Substance.swift`, `Klar/Klar/Features/Onboarding/SubstanceCatalog.swift`, `Klar/Klar/App/KlarStore.swift`, `Klar/Klar/Persistence/ModelContainerFactory.swift`, `Klar/Klar/Persistence/ModelDTOMapping.swift`, `Klar/Klar/Persistence/ExportImportService.swift`, `Klar/Klar/Debug/DebugRootView.swift`, `Klar/Klar/Features/Limits/GoalCards.swift`, `Packages/KlarCore/Sources/KlarCore/DTOs.swift`
- Test: `Klar/KlarTests/ExportImportTests.swift`

**Interfaces:**
- Consumes: `MorningAfterDTO`, `MorningAfterService.dueDayKey`, `MorningAfterService.pattern`, `LogicalDay.dayKey`.
- Produces (all on `KlarStore`):
  - `allMorningAfters() -> [MorningAfter]`
  - `morningAfter(forDayKey: String) -> MorningAfter?`
  - `dueMorningAfterDay(now: Date = Date()) -> String?`
  - `entries(onDayKey: String) -> [Entry]` (oldest first)
  - `recordMorningAfter(dayKey: String, body: MorningBody?, regret: MorningRegret?, again: MorningAgain?, note: String?)`
  - `skipMorningAfter(dayKey: String)`
  - `recordReflection(dayKey: String, trigger: String?, wouldHaveHelped: String?, nextTime: String?)`
  - `morningPattern(for: Substance, contextTag: ContextTag? = nil) -> MorningPattern?`
  - `setAsksMorningAfter(_ asks: Bool, for: Substance)`
- Also: `Substance.asksMorningAfter: Bool`, `SubstanceDTO.asksMorningAfter`, `KlarExport.morningAfters`, `SubstanceCatalog.asksMorningAfterByDefault(_ name: String) -> Bool`.

- [ ] **Step 1: Write the failing tests**

Create `KlarStoreMorningAfterTests.swift`:

```swift
import XCTest
import SwiftData
import KlarCore
@testable import Klar

@MainActor
final class KlarStoreMorningAfterTests: XCTestCase {
    private func makeStore() -> KlarStore {
        KlarStore(context: TestModelContainer.makeInMemoryContext())
    }

    private func yesterdayEvening() -> Date {
        let today = KlarDate.logicalDay(for: Date())
        let yesterday = KlarDate.calendar.date(byAdding: .day, value: -1, to: today)!
        return KlarDate.calendar.date(bySettingHour: 21, minute: 0, second: 0, of: yesterday)!
    }

    func testNikotinDoesNotAskByDefaultAndEverythingElseDoes() {
        let store = makeStore()
        XCTAssertFalse(store.addSubstance(name: "Nikotin", unit: .piece).asksMorningAfter)
        XCTAssertTrue(store.addSubstance(name: "Alkohol", unit: .drink).asksMorningAfter)
        XCTAssertTrue(store.addSubstance(name: "Mate", unit: .drink).asksMorningAfter)
    }

    func testYesterdaysEntryMakesYesterdayDue() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let entry = store.addEntry(substance: alcohol, timestamp: yesterdayEvening())
        XCTAssertEqual(store.dueMorningAfterDay(), LogicalDay.dayKey(for: entry.timestamp, timezoneID: entry.timezoneID))
    }

    func testRecordingAnswersClearsTheDueDay() throws {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.addEntry(substance: alcohol, timestamp: yesterdayEvening())
        let key = try XCTUnwrap(store.dueMorningAfterDay())

        store.recordMorningAfter(dayKey: key, body: .hungover, regret: .yes, again: nil, note: "  ")

        XCTAssertNil(store.dueMorningAfterDay())
        let record = try XCTUnwrap(store.morningAfter(forDayKey: key))
        XCTAssertEqual(record.body, .hungover)
        XCTAssertEqual(record.regret, .yes)
        XCTAssertNil(record.note, "a blank note is stored as no note")
    }

    func testSkippingIsRememberedAndDoesNotOverwriteAnswers() throws {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.addEntry(substance: alcohol, timestamp: yesterdayEvening())
        let key = try XCTUnwrap(store.dueMorningAfterDay())

        store.recordMorningAfter(dayKey: key, body: .fine, regret: nil, again: nil, note: nil)
        store.skipMorningAfter(dayKey: key)

        XCTAssertEqual(store.allMorningAfters().count, 1)
        XCTAssertEqual(store.morningAfter(forDayKey: key)?.body, .fine)
    }

    func testReflectionLandsOnTheSameRecord() throws {
        let store = makeStore()
        store.recordMorningAfter(dayKey: "2026-09-19", body: nil, regret: .yes, again: nil, note: nil)
        store.recordReflection(dayKey: "2026-09-19", trigger: "Gruppendruck", wouldHaveHelped: "", nextTime: "Früher heim")

        XCTAssertEqual(store.allMorningAfters().count, 1)
        let record = try XCTUnwrap(store.morningAfter(forDayKey: "2026-09-19"))
        XCTAssertEqual(record.regret, .yes)
        XCTAssertEqual(record.trigger, "Gruppendruck")
        XCTAssertNil(record.wouldHaveHelped)
        XCTAssertEqual(record.nextTime, "Früher heim")
    }

    func testSwitchingASubstanceOffStopsItsCard() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.addEntry(substance: alcohol, timestamp: yesterdayEvening())

        store.setAsksMorningAfter(false, for: alcohol)

        XCTAssertNil(store.dueMorningAfterDay())
    }
}
```

In `ExportImportTests.testJSONRoundTripRestoresIdenticalDatabase`, before `try sourceContext.save()`:

```swift
        substance.asksMorningAfter = false
        let morning = MorningAfter(dayKey: "2026-02-01", body: .rough, regret: .slightly, again: .differently, note: "Zu spät", nextTime: "Wecker stellen")
        sourceContext.insert(morning)
```

and after the substance assertions:

```swift
        XCTAssertFalse(importedSubstance.asksMorningAfter)

        let importedMornings = try destinationContext.fetch(FetchDescriptor<MorningAfter>())
        XCTAssertEqual(importedMornings.count, 1)
        let importedMorning = try XCTUnwrap(importedMornings.first)
        XCTAssertEqual(importedMorning.id, morning.id)
        XCTAssertEqual(importedMorning.dayKey, "2026-02-01")
        XCTAssertEqual(importedMorning.body, .rough)
        XCTAssertEqual(importedMorning.regret, .slightly)
        XCTAssertEqual(importedMorning.again, .differently)
        XCTAssertEqual(importedMorning.note, "Zu spät")
        XCTAssertEqual(importedMorning.nextTime, "Wecker stellen")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the app unit tests.
Expected: compile errors — `MorningAfter`, `asksMorningAfter`, `dueMorningAfterDay` not found.

- [ ] **Step 3: Model, DTO and default**

Create `Klar/Klar/Persistence/Models/MorningAfter.swift`:

```swift
import Foundation
import SwiftData
import KlarCore

/// One logical day's „Der Morgen danach" answers. A record with no answers is a skip.
@Model
final class MorningAfter {
    var id: UUID = UUID()
    var dayKey: String = ""
    var bodyRawValue: String?
    var regretRawValue: String?
    var againRawValue: String?
    var note: String?
    var trigger: String?
    var wouldHaveHelped: String?
    var nextTime: String?
    var recordedAt: Date = Date()

    var body: MorningBody? {
        get { bodyRawValue.flatMap(MorningBody.init(rawValue:)) }
        set { bodyRawValue = newValue?.rawValue }
    }

    var regret: MorningRegret? {
        get { regretRawValue.flatMap(MorningRegret.init(rawValue:)) }
        set { regretRawValue = newValue?.rawValue }
    }

    var again: MorningAgain? {
        get { againRawValue.flatMap(MorningAgain.init(rawValue:)) }
        set { againRawValue = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        dayKey: String,
        body: MorningBody? = nil,
        regret: MorningRegret? = nil,
        again: MorningAgain? = nil,
        note: String? = nil,
        trigger: String? = nil,
        wouldHaveHelped: String? = nil,
        nextTime: String? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.dayKey = dayKey
        self.bodyRawValue = body?.rawValue
        self.regretRawValue = regret?.rawValue
        self.againRawValue = again?.rawValue
        self.note = note
        self.trigger = trigger
        self.wouldHaveHelped = wouldHaveHelped
        self.nextTime = nextTime
        self.recordedAt = recordedAt
    }
}
```

`Substance.swift`: add `var asksMorningAfter: Bool = true` after `isArchived`, an init parameter `asksMorningAfter: Bool = true` after `isArchived`, and `self.asksMorningAfter = asksMorningAfter`.

`DTOs.swift`, `SubstanceDTO`: add `public var asksMorningAfter: Bool` after `isArchived`, init parameter `asksMorningAfter: Bool = true`, assignment. `KlarExport`: add `public var morningAfters: [MorningAfterDTO]` after `whyNotes`, init parameter `morningAfters: [MorningAfterDTO] = []` after `whyNotes`, assignment.

`ModelDTOMapping.swift`: `Substance.toDTO()` passes `asksMorningAfter: asksMorningAfter`; add

```swift
extension MorningAfter {
    func toDTO() -> MorningAfterDTO {
        MorningAfterDTO(
            id: id, dayKey: dayKey, body: body, regret: regret, again: again, note: note,
            trigger: trigger, wouldHaveHelped: wouldHaveHelped, nextTime: nextTime, recordedAt: recordedAt
        )
    }
}
```

`ModelContainerFactory.schema` and the `DebugRootView` preview: add `MorningAfter.self`.

`ExportImportService.swift`:
- `wipeAll`: `try context.delete(model: MorningAfter.self)` before the save;
- `buildExport`: `morningAfters: try context.fetch(FetchDescriptor<MorningAfter>()).map { $0.toDTO() }`;
- `insert`: the `Substance(…)` call passes `asksMorningAfter: dto.asksMorningAfter`; after the why-notes loop:

```swift
        for dto in export.morningAfters {
            context.insert(MorningAfter(
                id: dto.id, dayKey: dto.dayKey, body: dto.body, regret: dto.regret, again: dto.again,
                note: dto.note, trigger: dto.trigger, wouldHaveHelped: dto.wouldHaveHelped,
                nextTime: dto.nextTime, recordedAt: dto.recordedAt
            ))
        }
```

`SubstanceCatalog.swift`, add to `enum SubstanceCatalog`:

```swift
    /// Nicotine is used every day by most who log it, and „verkatert?" means nothing for it —
    /// asking would turn the card into a daily chore. Everything else asks until switched off.
    static func asksMorningAfterByDefault(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("Nikotin") != .orderedSame
    }
```

`KlarStore.addSubstance` passes `asksMorningAfter: SubstanceCatalog.asksMorningAfterByDefault(name)` to the `Substance` init.

- [ ] **Step 4: KlarStore API**

Add after the `// MARK: - Substances` section:

```swift
    // MARK: - Der Morgen danach

    func allMorningAfters() -> [MorningAfter] {
        (try? context.fetch(FetchDescriptor<MorningAfter>())) ?? []
    }

    func morningAfter(forDayKey key: String) -> MorningAfter? {
        allMorningAfters().first { $0.dayKey == key }
    }

    /// The day the card should ask about now, if any (`MorningAfterService.dueDayKey`).
    /// Archived substances still count: their entries happened.
    func dueMorningAfterDay(now: Date = Date()) -> String? {
        let asking = Set(allSubstances(includeArchived: true).filter(\.asksMorningAfter).map(\.id))
        return MorningAfterService.dueDayKey(
            entries: allEntries().map { $0.toDTO() },
            askingSubstanceIDs: asking,
            records: allMorningAfters().map { $0.toDTO() },
            now: now,
            nowTimezoneID: KlarDate.timezoneID
        )
    }

    /// The entries filed under `key`, each read in its own timezone, oldest first.
    func entries(onDayKey key: String) -> [Entry] {
        allEntries()
            .filter { LogicalDay.dayKey(for: $0.timestamp, timezoneID: $0.timezoneID) == key }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Writes whatever was answered. Nothing answered is still a record — a skip.
    func recordMorningAfter(dayKey: String, body: MorningBody?, regret: MorningRegret?, again: MorningAgain?, note: String?) {
        let record = morningRecord(forDayKey: dayKey)
        record.body = body
        record.regret = regret
        record.again = again
        record.note = Self.nonBlank(note)
        record.recordedAt = Date()
        save()
    }

    /// Makes sure the day is never asked about again. Leaves an existing record alone.
    func skipMorningAfter(dayKey: String) {
        guard morningAfter(forDayKey: dayKey) == nil else { return }
        context.insert(MorningAfter(dayKey: dayKey))
        save()
    }

    func recordReflection(dayKey: String, trigger: String?, wouldHaveHelped: String?, nextTime: String?) {
        let record = morningRecord(forDayKey: dayKey)
        record.trigger = Self.nonBlank(trigger)
        record.wouldHaveHelped = Self.nonBlank(wouldHaveHelped)
        record.nextTime = Self.nonBlank(nextTime)
        save()
    }

    func morningPattern(for substance: Substance, contextTag: ContextTag? = nil) -> MorningPattern? {
        MorningAfterService.pattern(
            substanceID: substance.id,
            contextTagID: contextTag?.id,
            entries: allEntries().map { $0.toDTO() },
            records: allMorningAfters().map { $0.toDTO() }
        )
    }

    func setAsksMorningAfter(_ asks: Bool, for substance: Substance) {
        substance.asksMorningAfter = asks
        save()
    }

    private func morningRecord(forDayKey key: String) -> MorningAfter {
        if let existing = morningAfter(forDayKey: key) { return existing }
        let record = MorningAfter(dayKey: key)
        context.insert(record)
        return record
    }

    private static func nonBlank(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
```

- [ ] **Step 5: The switch on each limit card**

In `GoalCards.swift`, inside `GoalCard`'s `KlarCard`, after the `if !isPaused, goal != nil { … }` block:

```swift
            Divider()
                .overlay(Klar.borderSubtle)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Toggle(isOn: Binding(
                get: { substance.asksMorningAfter },
                set: { store.setAsksMorningAfter($0, for: substance) }
            )) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Morgen danach fragen")
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                    Text("Eine kurze Karte am Morgen nach einem Tag mit Einträgen")
                        .font(Klar.TypeScale.caption)
                        .foregroundStyle(Klar.textTertiary)
                }
            }
            .tint(Klar.accent)
            .accessibilityIdentifier("limits.asksMorningAfter.\(substance.name)")
```

- [ ] **Step 6: Run the tests to verify they pass**

Run the KlarCore tests, the app unit tests and the UI tests.
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add -A Klar Packages/KlarCore
git commit -m "Store the morning after, one record per logical day

MorningAfter keeps a day's three answers, an optional note and the
problem-solving answers. A record without answers is a skip, so the
day is never asked about twice. Each substance gets a switch for
whether it asks; Nikotin starts switched off, because a daily card for
a daily habit is exactly the chore v3 removes.

The export carries both, still as schema 2.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The card and the reflection flow

**Files:**
- Create: `Klar/Klar/Features/MorningAfter/MorningAfterCardView.swift`, `Klar/Klar/Features/MorningAfter/MorningReflectionView.swift`
- Modify: `Klar/Klar/App/RootView.swift`, `Klar/Klar/App/UITestSupport.swift`, `Klar/Klar/KlarApp.swift`
- Test: create `Klar/KlarUITests/MorningAfterUITests.swift`

**Interfaces:**
- Consumes: Task 6 `KlarStore` API, `KlarDate.weekdayName(_:)`, `KlarDate.logicalDay(for:timezoneID:)`, `KlarSegmentedControl`, `KlarPrimaryButton`, `KlarQuietButton`, `KlarInlineButton`, `KlarChip`, `KlarFlowLayout`, `KlarSectionLabel`, `KlarCard`.
- Produces: `MorningAfterCardView(dayKey: String)`, `MorningReflectionView(dayKey: String, onFinish: () -> Void)`, launch argument `--klar-uitest-seed-yesterday`, accessibility identifier `morningAfter.header`.

- [ ] **Step 1: Write the failing UI test**

```swift
import XCTest

final class MorningAfterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The card asks once about yesterday, and once answered it does not come back.
    @MainActor
    func testTheCardAsksOnceAndDoesNotReturn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--klar-uitest-seed-yesterday"]
        app.launch()

        XCTAssertTrue(app.staticTexts["morningAfter.header"].waitForExistence(timeout: 10))
        app.buttons["verkatert"].tap()
        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["morningAfter.header"].exists)

        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["Übersicht"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.staticTexts["morningAfter.header"].waitForExistence(timeout: 3))
    }

    /// Swiping the card away counts as a skip.
    @MainActor
    func testSkippingAlsoEndsTheQuestion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--klar-uitest-seed-yesterday"]
        app.launch()

        XCTAssertTrue(app.staticTexts["morningAfter.header"].waitForExistence(timeout: 10))
        app.buttons["Überspringen"].tap()

        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["Übersicht"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.staticTexts["morningAfter.header"].waitForExistence(timeout: 3))
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `xcodebuild test … -only-testing:KlarUITests/MorningAfterUITests -quiet`
Expected: FAIL — onboarding shows, `morningAfter.header` never appears.

- [ ] **Step 3: Seeding for the UI test**

`UITestSupport.swift`, add to the enum:

```swift
    /// Onboarding done, Alkohol, one entry at 21:00 on the previous logical day — the smallest
    /// state in which „Der Morgen danach" is due.
    static let seedYesterdayArgument = "--klar-uitest-seed-yesterday"

    static var isSeedYesterdayRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(seedYesterdayArgument)
    }

    @MainActor
    static func seedYesterday(container: ModelContainer) {
        let store = KlarStore(context: ModelContext(container))
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let today = KlarDate.logicalDay(for: Date())
        guard let yesterday = KlarDate.calendar.date(byAdding: .day, value: -1, to: today),
              let evening = KlarDate.calendar.date(bySettingHour: 21, minute: 0, second: 0, of: yesterday)
        else { return }
        store.addEntry(substance: alcohol, timestamp: evening)
    }
```

and `import SwiftData` at the top of the file.

`KlarApp.init`, inside the first `#if DEBUG` block:

```swift
        if UITestSupport.isSeedYesterdayRequested {
            UITestSupport.reset()
            DemoModeSupport.skipOnboarding()
        }
```

and inside the second `#if DEBUG` block:

```swift
        if UITestSupport.isSeedYesterdayRequested {
            UITestSupport.seedYesterday(container: container)
        }
```

- [ ] **Step 4: The card**

Create `Klar/Klar/Features/MorningAfter/MorningAfterCardView.swift`:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// „Der Morgen danach" (concept v3, module C).
///
/// Asks about one logical day, once. Everything is optional and nothing is judged: no option is
/// coloured, a good morning is not praised and a bad one is not commented on (P7, P8). What it
/// collects comes back as a pattern, on Übersicht and in the entry sheet — the card is the
/// input, not the point.
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

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var dayEntries: [Entry] { store.entries(onDayKey: dayKey) }

    private var header: String {
        guard let first = dayEntries.first else { return "Der Morgen danach" }
        let day = KlarDate.logicalDay(for: first.timestamp, timezoneID: first.timezoneID)
        return "Der Morgen danach · \(KlarDate.weekdayName(day))"
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
                        question: "Wie geht's dir heute körperlich?",
                        options: [(.fine, "gut"), (.rough, "angeschlagen"), (.hungover, "verkatert")],
                        selection: $bodyAnswer
                    )
                    AnswerRow(
                        question: "Bereust du etwas von gestern?",
                        options: [(.no, "nein"), (.slightly, "ein bisschen"), (.yes, "ja")],
                        selection: $regretAnswer
                    )
                    AnswerRow(
                        question: "Würdest du es wieder so machen?",
                        options: [(.yes, "ja"), (.differently, "anders"), (.no, "nein")],
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
                    KlarQuietButton(title: "Überspringen") {
                        store.skipMorningAfter(dayKey: dayKey)
                        dismiss()
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
        .fullScreenCover(isPresented: $isReflecting) {
            MorningReflectionView(dayKey: dayKey) { dismiss() }
        }
    }

    private func save() {
        store.recordMorningAfter(dayKey: dayKey, body: bodyAnswer, regret: regretAnswer, again: againAnswer, note: note)
    }
}

/// A question over a three-way control with nothing preselected. Tapping the selected option
/// again clears it, the same rule as the mood control in the entry sheet.
private struct AnswerRow<Value: Hashable>: View {
    let question: LocalizedStringKey
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

If the build reports that `Color(hex:)`, `KlarChip(text:compact:)`, `Klar.Radius.xl` or `klarShadow` are named differently, use the names `PlanCheckInView` used before Task 5 (`git show HEAD~2:Klar/Klar/Features/CheckIn/PlanCheckInView.swift`) — that view's dimmed-backdrop card is what this one copies.

- [ ] **Step 5: The reflection flow**

Create `Klar/Klar/Features/MorningAfter/MorningReflectionView.swift`:

```swift
import SwiftUI
import SwiftData
import KlarCore

/// Problem solving (concept § 4, module E), reached from the card when the answer to „Bereust
/// du etwas?" is „ja". Three optional questions; the third comes back next to that substance's
/// pattern. It ends in a note, not in a plan, and nothing asks later whether it worked.
struct MorningReflectionView: View {
    let dayKey: String
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var trigger = ""
    @State private var wouldHaveHelped = ""
    @State private var nextTime = ""

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 15))
                        .foregroundStyle(Klar.Palette.cyan600)
                    KlarSectionLabel(text: "Kurz nachdenken")
                    Spacer()
                    Button("Später") { finish() }
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                }
                .padding(.bottom, 6)

                Text("Was war los?")
                    .font(Klar.TypeScale.display(24))
                    .foregroundStyle(Klar.text)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 14) {
                        questionCard(number: 1, label: "Was war der Auslöser?", placeholder: "z. B. Gruppendruck, alle haben mitgemacht.", text: $trigger)
                        questionCard(number: 2, label: "Was hätte geholfen?", placeholder: "z. B. Früher gehen, bevor es kippt.", text: $wouldHaveHelped)
                        questionCard(number: 3, label: "Was machst du nächstes Mal anders?", placeholder: "Antwort tippen …", text: $nextTime)
                    }
                }
                .scrollIndicators(.hidden)

                KlarPrimaryButton(title: "Speichern") {
                    store.recordReflection(dayKey: dayKey, trigger: trigger, wouldHaveHelped: wouldHaveHelped, nextTime: nextTime)
                    finish()
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func questionCard(number: Int, label: LocalizedStringKey, placeholder: String, text: Binding<String>) -> some View {
        KlarCard(padding: 16) {
            HStack(spacing: 0) {
                Text("\(number) · ")
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                Text(label)
                    .font(Klar.TypeScale.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(Klar.textTertiary)
            }
            .padding(.bottom, 8)

            TextField(placeholder, text: text, axis: .vertical)
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.text)
                .lineLimit(1...4)
        }
    }

    private func finish() {
        dismiss()
        onFinish()
    }
}
```

- [ ] **Step 6: Present it**

In `RootView.swift`, `MainTabView`:

```swift
    @Environment(\.scenePhase) private var scenePhase
    /// „Der Morgen danach" is the one moment the app speaks unprompted. Presented here, on top
    /// of the tabs, so whichever tab is showing cannot swallow it.
    @State private var dueMorning: DueMorning?
    /// Kept apart from `dueMorning`, which is already `nil` by the time `onDismiss` runs.
    @State private var presentedMorningKey: String?
```

Modifiers on the `TabView`, after the entry sheet:

```swift
        .sheet(item: $dueMorning, onDismiss: {
            // Swiping the card away is a skip. After „Fertig" the record exists and this is a no-op.
            if let key = presentedMorningKey { store.skipMorningAfter(dayKey: key) }
            presentedMorningKey = nil
        }) { due in
            MorningAfterCardView(dayKey: due.dayKey)
                .presentationBackground(.clear)
        }
        .task { presentDueMorning() }
        .onChange(of: scenePhase) { _, phase in
            // The morning after usually starts with the app still in the background from the
            // night before, so checking only at launch would miss it.
            if phase == .active { presentDueMorning() }
        }
```

and:

```swift
    private func presentDueMorning() {
        guard dueMorning == nil, !isEntrySheetPresented, let key = store.dueMorningAfterDay() else { return }
        presentedMorningKey = key
        dueMorning = DueMorning(dayKey: key)
    }
```

At the end of the file:

```swift
/// `sheet(item:)` needs an Identifiable payload.
struct DueMorning: Identifiable {
    let dayKey: String
    var id: String { dayKey }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run the UI tests.
Expected: `MorningAfterUITests` passes both tests; the existing UI tests still pass (a fresh install has no entries, so no card).

- [ ] **Step 8: Commit**

```bash
git add -A Klar
git commit -m "Ask „Der Morgen danach" once about the last evening

The card comes up on launch and whenever the app returns from the
background, because the morning after usually starts with last night's
app still open. Three one-tap answers, nothing preselected, a note on
request; „Fertig" and „Überspringen" both end the question for good,
and so does swiping it away.

Regretting the evening offers the three problem-solving questions,
lifted from the old plan check-in. They end in a note for next time,
not in a plan.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Show the patterns

**Files:**
- Create: `Klar/Klar/App/MorningPatternText.swift`, `Klar/Klar/Features/MorningAfter/MorningPatternsCard.swift`, `Klar/KlarTests/MorningPatternTextTests.swift`
- Modify: `Klar/Klar/Features/Today/TodayView.swift`, `Klar/Klar/Features/Entry/EntrySheetView.swift`

**Interfaces:**
- Consumes: `MorningPattern`, `KlarStore.morningPattern(for:contextTag:)`.
- Produces: `MorningPatternText.summary(_ pattern: MorningPattern) -> String`, `MorningPatternText.contextual(_ pattern: MorningPattern, tagName: String) -> String`, `MorningPatternsCard(rows: [MorningPatternRow])`, `struct MorningPatternRow: Identifiable { substance: Substance; pattern: MorningPattern }`, accessibility identifiers `today.morningPatterns`, `entry.morningPattern`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import KlarCore
@testable import Klar

final class MorningPatternTextTests: XCTestCase {
    private func pattern(days: Int = 5, body: [MorningBody: Int] = [:], regret: [MorningRegret: Int] = [:]) -> MorningPattern {
        MorningPattern(days: days, body: body, regret: regret, again: [:], nextTime: nil)
    }

    func testListsTheCountsInAFixedOrder() {
        let text = MorningPatternText.summary(pattern(body: [.hungover: 3, .rough: 1, .fine: 1], regret: [.yes: 1, .slightly: 2]))
        XCTAssertEqual(text, "letzte 5: 3× verkatert, 1× angeschlagen, 1× bereut, 2× ein bisschen bereut")
    }

    func testLeavesOutWhatNeverHappened() {
        XCTAssertEqual(MorningPatternText.summary(pattern(days: 4, body: [.hungover: 2, .fine: 2])), "letzte 4: 2× verkatert")
    }

    func testSaysSoPlainlyWhenNothingWentWrong() {
        XCTAssertEqual(MorningPatternText.summary(pattern(days: 3, body: [.fine: 3], regret: [.no: 2])), "letzte 3: kein Kater, nichts bereut")
    }

    /// „kein Kater" would be a claim the answers never made.
    func testDoesNotClaimAnythingWhenOnlyTheLastQuestionWasAnswered() {
        XCTAssertEqual(MorningPatternText.summary(pattern(days: 3)), "letzte 3: ohne Angaben zu Kater und Reue")
    }

    func testTheContextualLineNamesTheTag() {
        XCTAssertEqual(MorningPatternText.contextual(pattern(days: 4, body: [.hungover: 3, .fine: 1]), tagName: "Club"), "Mit Club · letzte 4: 3× verkatert")
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run the app unit tests.
Expected: compile error — `MorningPatternText` not found.

- [ ] **Step 3: Implement the text**

Create `Klar/Klar/App/MorningPatternText.swift`:

```swift
import Foundation
import KlarCore

/// How a morning-after pattern reads, everywhere it appears. Counts in a fixed order, zeros
/// left out, no adjective and no verdict (P7).
enum MorningPatternText {
    /// "letzte 5: 3× verkatert, 1× bereut"
    static func summary(_ pattern: MorningPattern) -> String {
        var parts: [String] = []
        if let count = pattern.body[.hungover], count > 0 { parts.append("\(count)× verkatert") }
        if let count = pattern.body[.rough], count > 0 { parts.append("\(count)× angeschlagen") }
        if let count = pattern.regret[.yes], count > 0 { parts.append("\(count)× bereut") }
        if let count = pattern.regret[.slightly], count > 0 { parts.append("\(count)× ein bisschen bereut") }

        let tail: String
        if !parts.isEmpty {
            tail = parts.joined(separator: ", ")
        } else if pattern.body.isEmpty && pattern.regret.isEmpty {
            tail = "ohne Angaben zu Kater und Reue"
        } else {
            tail = "kein Kater, nichts bereut"
        }
        return "letzte \(pattern.days): \(tail)"
    }

    /// "Mit Club · letzte 4: 3× verkatert"
    static func contextual(_ pattern: MorningPattern, tagName: String) -> String {
        "Mit \(tagName) · \(summary(pattern))"
    }
}
```

Run the app unit tests. Expected: `MorningPatternTextTests` passes.

- [ ] **Step 4: Übersicht**

Create `Klar/Klar/Features/MorningAfter/MorningPatternsCard.swift`:

```swift
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
```

In `TodayView.swift`:
- add `@Query private var morningAfters: [MorningAfter]` next to the other queries (so the card refreshes when an answer lands);
- add

```swift
    private var morningRows: [MorningPatternRow] {
        store.allSubstances().compactMap { substance in
            store.morningPattern(for: substance).map { MorningPatternRow(substance: substance, pattern: $0) }
        }
    }
```

- in `todayScroll`, where the plan block was (after the quota cards, before `if todaysEntries.isEmpty`):

```swift
                    if !morningRows.isEmpty {
                        MorningPatternsCard(rows: morningRows)
                            .padding(.bottom, 18)
                    }
```

- [ ] **Step 5: Entry sheet**

In `EntrySheetView.swift`, `EntryDetailForm`, add:

```swift
    /// The substance's morning-after pattern, narrowed to the first selected tag (in display
    /// order) that has one of its own. Recomputed as tags are toggled.
    private var morningPatternLine: String? {
        guard let substance = entry.substance else { return nil }
        for tag in sortedTags where selectedTagIDs.contains(tag.id) {
            if let pattern = store.morningPattern(for: substance, contextTag: tag) {
                return MorningPatternText.contextual(pattern, tagName: tag.name)
            }
        }
        return store.morningPattern(for: substance).map { "Der Morgen danach · \(MorningPatternText.summary($0))" }
    }
```

and as the first child of the form's `VStack(alignment: .leading, spacing: 0)`, before `KlarSectionLabel(text: "Dosis (optional)", …)`:

```swift
                    if let line = morningPatternLine {
                        Text(line)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textSecondary)
                            .accessibilityIdentifier("entry.morningPattern")
                            .padding(.bottom, 16)
                    }
```

- [ ] **Step 6: Check it by hand**

Build, delete Klar from the simulator, run it with the demo seed (`--klar-demo-seed`, added to the scheme's launch arguments or via `xcrun simctl launch booted <bundle id> --klar-demo-seed`). The demo data gains morning-after records only in Task 9, so at this point expect: Übersicht shows no „Der Morgen danach" card, and the card for yesterday appears if yesterday had an asking entry. Answer it; no pattern yet (one day). This step is a smoke test that nothing crashes; the patterns are checked visually in Task 10.

- [ ] **Step 7: Run all tests**

Run the KlarCore tests, the app unit tests and the UI tests.
Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add -A Klar
git commit -m "Give the mornings back as patterns

Übersicht gets a „Der Morgen danach" card with one line per substance
that has three answered mornings — „Alkohol · letzte 5: 3× verkatert,
1× bereut" — and the user's own note for next time under it. The entry
sheet shows the same line for the substance being logged, narrowed to
a context tag when that tag has its own pattern.

Counts only. When nothing went wrong it says so; when a question was
never answered it does not pretend it was.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Demo data and example file

**Files:**
- Modify: `Klar/Klar/Persistence/DemoDataSeeder.swift`, `tools/generate_example_data.py`, `examples/README.md`
- Regenerate: `examples/klar-beispieldaten.json`

**Interfaces:**
- Consumes: `MorningAfter(dayKey:body:regret:again:nextTime:)`, `LogicalDay.dayKey`, the schema-2 export shape from Tasks 4–6.

- [ ] **Step 1: Demo seeder**

In `DemoDataSeeder.seed`, create coffee with `asksMorningAfter: false` (add the argument to its `Substance(…)` call) and nicotine with `asksMorningAfter: false`. After the entry loop, before `try context.save()`:

```swift
        // Answer most past alcohol evenings, so Übersicht and the entry sheet have a pattern.
        // The newest one stays open: that is the card the demo shows on launch.
        let alcoholDays = Set(
            try context.fetch(FetchDescriptor<Entry>())
                .filter { $0.substance?.id == alcohol.id }
                .map { LogicalDay.dayKey(for: $0.timestamp, timezoneID: $0.timezoneID) }
        )
        let todayKey = LogicalDay.dayKey(for: now, timezoneID: "Europe/Berlin")
        let answered = alcoholDays.filter { $0 < todayKey }.sorted().dropLast()
        for (index, key) in answered.enumerated() {
            let hungover = index % 3 != 1
            context.insert(MorningAfter(
                dayKey: key,
                body: hungover ? .hungover : .fine,
                regret: index % 3 == 0 ? .yes : .no,
                again: hungover ? .differently : .yes,
                nextTime: index == answered.count - 1 ? "Zwischendurch Wasser" : nil
            ))
        }
```

Entries are inserted but not yet saved when this runs; `context.fetch` sees pending inserts in SwiftData. If it does not in practice (count 0 in the debugger), move the block after a first `try context.save()` and save again at the end.

- [ ] **Step 2: Generator — remove plans and reviews**

In `tools/generate_example_data.py`:
- `SCHEMA_VERSION = 2`;
- delete the `Plan` and `CheckIn` dataclasses, `build_plans_and_checkins`, and the „Pläne (G1)" / open-check-in part of `report`;
- `Substance` gains `asks_morning_after: bool = True` and emits `"asksMorningAfter": self.asks_morning_after` in `dto()` (`compact` only drops `None`, so `False` survives — the app requires the key);
- `SUBSTANCES`: `nikotin` and `kaffee` get `asks_morning_after=False`;
- the `Feierabend` retagging loop in `build_plans_and_checkins` moves into `build` right after `entries.sort(…)`, keeping its body, with the comment „Drinking alone at home after work, tagged the way the user tags it." and a fixed start of `first_day + timedelta(weeks=9)`;
- the return value of `build` becomes `payload, entries, goals, mornings`, and `main` / `report` take `mornings` instead of `plans, check_ins`;
- the E3 check that required a context above 50 % drops its „Plan dafür bauen?" message — keep the print, delete the `problems.append`.

- [ ] **Step 3: Generator — morning-after records**

Add a dataclass after `Goal`:

```python
@dataclass
class Morning:
    day: date
    body: str | None
    regret: str | None
    again: str | None
    note: str | None = None
    next_time: str | None = None
    id: str = field(default_factory=new_id)

    def dto(self) -> dict:
        return compact(
            {
                "id": self.id,
                "dayKey": self.day.isoformat(),
                "body": self.body,
                "regret": self.regret,
                "again": self.again,
                "note": self.note,
                "nextTime": self.next_time,
                "recordedAt": iso(local(self.day + timedelta(days=1), rng.randint(8, 11), rng.randint(0, 55))),
            }
        )
```

and a builder:

```python
def build_mornings(entries: list[Entry], today: date) -> list[Morning]:
    """Roughly 70 % of past alcohol evenings are answered, the rest skipped (a record with no
    answers). Club and social nights come out rough more often than the others, so the entry
    sheet has a context pattern to show. The newest evening stays open: that is the card
    the app shows after the import."""
    evenings = sorted(
        {entry.day for entry in entries if entry.substance is SUBSTANCES["alkohol"] and entry.day < today}
    )
    loud = {
        entry.day
        for entry in entries
        if entry.substance is SUBSTANCES["alkohol"] and {TAGS["club"].id, TAGS["sozial"].id} & {t.id for t in entry.tags}
    }
    mornings: list[Morning] = []
    for day in evenings[:-1]:
        if rng.random() > 0.7:
            mornings.append(Morning(day, None, None, None))
            continue
        heavy = day in loud
        body = rng.choices(["fine", "rough", "hungover"], weights=[2, 3, 5] if heavy else [6, 3, 1])[0]
        regret = rng.choices(["no", "slightly", "yes"], weights=[4, 3, 3] if heavy else [8, 2, 1])[0]
        again = {"yes": "differently", "slightly": "differently", "no": "yes"}[regret] if rng.random() < 0.8 else None
        mornings.append(Morning(day, body, regret, again))
    for morning in reversed(mornings):
        if morning.regret == "yes":
            morning.next_time = "Nach dem dritten Getränk auf Wasser umsteigen"
            break
    return mornings
```

In `build`, after `goals = build_goals(…)`: `mornings = build_mornings(entries, today)`, and the payload gets `"morningAfters": [m.dto() for m in mornings]` in place of `plans`, `planCheckIns` and `reviewDecisions`.

In `report`, add a section:

```python
    print()
    print("  Der Morgen danach")
    answered = [m for m in mornings if m.body or m.regret or m.again]
    print(f"    {len(answered)} beantwortet · {len(mornings) - len(answered)} übersprungen")
    if len(answered) < 3:
        problems.append("weniger als drei beantwortete Morgen — Übersicht zeigt kein Muster")
    alcohol_days = {e.day for e in entries if e.substance is SUBSTANCES["alkohol"] and e.day < today}
    recorded = {m.day for m in mornings}
    open_days = sorted(alcohol_days - recorded)
    if not open_days or open_days[-1] != max(alcohol_days):
        problems.append("der jüngste Alkohol-Abend ist nicht offen — nach dem Import erscheint keine Karte")
```

`TAGS` must contain `"club"`; if the generator names it differently, use that key.

- [ ] **Step 4: Regenerate and check**

```bash
python3 tools/generate_example_data.py
```

Expected: the report ends with „Alle Prüfungen bestanden." If the newest alcohol evening is older than 48 h before the reference day, the card will not appear after import; that is acceptable, but note it in `examples/README.md`.

Then prove the app accepts the file: add to `ExportImportTests`

```swift
    /// The shipped example file must stay importable — it is what the screenshots are made from.
    func testTheExampleFileDecodes() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("examples/klar-beispieldaten.json")
        let export = try ExportImportService.decode(Data(contentsOf: url))
        XCTAssertEqual(export.schemaVersion, KlarExport.currentSchemaVersion)
        XCTAssertFalse(export.morningAfters.isEmpty)
    }
```

Run the app unit tests. Expected: pass. (If the simulator sandbox cannot read the repo path, delete this test and instead import the file by hand in Task 10 — note that in the commit body.)

- [ ] **Step 5: examples/README.md**

- the „Plans" and „Check-ins" table rows become one row: „Der Morgen danach | ~70 % of past alcohol evenings answered, the rest skipped, **the newest left open**";
- the „Two things happen on the first launch" section becomes „One thing happens on the first launch after importing: **Der Morgen danach** asks about the newest alcohol evening, if it ended less than 48 h before the reference day.";
- the „pinned numbers" paragraph drops the reason „below that, E3 stops offering to build a plan from it" and keeps „Sozial stays above 50 % of alcohol contexts" only if the generator still pins it;
- „Pläne → Ziele" becomes „Grenzen";
- the regenerating paragraph lists the new checks (fewer than three answered mornings, newest evening not open) instead of the check-in count.

- [ ] **Step 6: Commit**

```bash
git add Klar/Klar/Persistence/DemoDataSeeder.swift Klar/KlarTests/ExportImportTests.swift tools/generate_example_data.py examples/
git commit -m "Give the demo and example data mornings instead of plans

Both now carry morning-after records for most past alcohol evenings,
rougher on club and social nights so a context pattern shows up, and
leave the newest evening open so the card appears after an import.
Nicotine and coffee are switched off, as a user would have them.

The example file moves to schema 2.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Docs, stale strings, full verification

**Files:**
- Modify: `docs/klar-screens-implementation.md`, `docs/klar-mvp-konzept.md`, `Klar/Klar/Localizable.xcstrings`, `Klar/KlarUITests/ScreenshotTests.swift`

- [ ] **Step 1: Screenshot walk covers the new screens**

In `ScreenshotTests.testCaptureAllScreens`, nothing seeds yesterday, so the card cannot be captured in that walk. Add a second test to `ScreenshotTests`:

```swift
    @MainActor
    func testCaptureMorningAfter() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--klar-uitest-seed-yesterday"]
        app.launch()

        XCTAssertTrue(app.staticTexts["morningAfter.header"].waitForExistence(timeout: 10))
        capture(app, "D-Morgen-danach")
        app.buttons["ja"].firstMatch.tap()
        capture(app, "D-Morgen-danach-bereut")
    }
```

Run the UI tests. Expected: pass.

- [ ] **Step 2: Stale strings**

Build once, then drop every string Xcode marked stale:

```bash
python3 - <<'EOF'
import json, pathlib
path = pathlib.Path("Klar/Klar/Localizable.xcstrings")
data = json.loads(path.read_text())
stale = [k for k, v in data["strings"].items() if v.get("extractionState") == "stale"]
for key in stale:
    del data["strings"][key]
path.write_text(json.dumps(data, ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n")
print(len(stale), "stale strings removed")
EOF
git diff --stat Klar/Klar/Localizable.xcstrings
```

Open the file in Xcode once and let it re-save if the formatting diff is noisy; the content change is what matters. Build again. Expected: success.

- [ ] **Step 3: `docs/klar-screens-implementation.md`**

- Status line: the real unit and UI test counts from the last runs.
- Foundations table, `KlarScreen` row: „Used by Verlauf, Grenzen and Hilfe."
- Remove sections D (check-in, reflection), F (weekly review), E4 (archive) and G1/G2 (plans). Keep G4 content, retitled „G · Grenzen — [LimitsView.swift](../Klar/Klar/Features/Limits/LimitsView.swift)", with the goal-versioning notes and a line on the „Morgen danach fragen" switch (Nikotin off by default, `SubstanceCatalog.asksMorningAfterByDefault`).
- B section: the paragraph about the standing plan under the quota becomes one about the „Der Morgen danach" card (absent until three answered mornings, `MorningPatternsCard`).
- New section „D · Der Morgen danach — [MorningAfterCardView.swift](../Klar/Klar/Features/MorningAfter/MorningAfterCardView.swift)": when it is due (`MorningAfterService.dueDayKey`, newest day only, 48 h), when it is presented (launch and every return to foreground), what ends it (Fertig, Überspringen, swipe), the reflection flow and where its third answer comes back, the entry-sheet line.
- Every other mention of „Pläne", „Plan", „Wochenrückblick" in the file: rewrite or delete so the file describes the app as it now is. `grep -n "Plan\|Rückblick\|Review" docs/klar-screens-implementation.md` must end with only historical sentences you chose to keep.

- [ ] **Step 4: `docs/klar-mvp-konzept.md`**

- Modul B: delete the Weekly-Review bullet; the feedback is „Rückblick-Muster pro Substanz und Kontext-Tag (Modul C) in der Übersicht und im Eintrag-Sheet" plus the existing trends. Heading stays „Modul B — Feedback".
- Modul C, „Verfall": „Fällig ist nur der jüngste Konsumtag vor heute. Er verfällt 48 Stunden nach seinem Ende (05:00 am Folgetag). Ein neuer Konsumtag verdrängt einen älteren, unbeantworteten; ein Eintrag am selben Morgen tut das nicht." Add a bullet: „**Pro Substanz schaltbar** (‚Morgen danach fragen' im Tab Grenzen), bei Nikotin standardmäßig aus."
- Modul C, „Zurückspielen": remove „Der Weekly Review zeigt die Muster der Woche (Modul B)."
- Modul E, Problem Solving: triggered only by „bereut: ja" on the card; delete the „Grenze überschritten" trigger and say why in one clause („dieser Tag bekommt ohnehin am nächsten Morgen eine Karte").
- § 1 list, „Unverändert aus v2 bleiben": drop „der Weekly Review"; add a point „**Der Weekly Review fällt weg**: Die Rückmeldung kommt laufend über die Muster; ein wöchentliches Vollbild wäre genau die Art Pflicht-Moment, die P9 ausschließt."
- § 5 Validierung: nothing refers to the review — check.
- P1's evidence column stays; its sentence is still true.

- [ ] **Step 5: Full verification**

Run, in order: the KlarCore tests, the app unit tests, the UI tests. All must pass; record the counts for the PR.

By hand on the simulator (delete Klar first, then run with `--klar-demo-seed`), in light and in dark (`xcrun simctl ui D9360641-F9CD-4536-870B-3D66A89F6FEE appearance dark`):
1. The card appears on launch for the open demo evening. Answer „verkatert", „ja", then „Kurz drüber nachdenken", fill question 3, „Speichern". Screenshot the card and the reflection.
2. Übersicht shows the „Der Morgen danach" card with an Alkohol line and „Nächstes Mal: …". Screenshot.
3. Log Alkohol with the Club tag: the entry sheet shows the „Mit Club · …" line, or the substance line if Club has fewer than three answered days. Screenshot.
4. Grenzen: switch Alkohol's „Morgen danach fragen" off, background the app, bring it back: no card. Screenshot the tab.
5. Verlauf shows Kalender and Trends only; Trends has no „Plan dafür bauen?".
6. Einstellungen has no „Benachrichtigungen" row.

Save the screenshots to the scratchpad and show them to the user; they are not committed (block 4 regenerates the PNGs in `docs/screenshots/`).

- [ ] **Step 6: Commit**

```bash
git add docs/klar-screens-implementation.md docs/klar-mvp-konzept.md Klar/Klar/Localizable.xcstrings Klar/KlarUITests/ScreenshotTests.swift
git commit -m "Bring the docs and strings in line with the morning-after app

The screen notes lose the plan, check-in and review screens and gain
the card, its reflection flow, the Übersicht block and the Grenzen tab.
The concept records what building it settled: only the newest day is
ever asked about, each substance has a switch, problem solving starts
from regret alone, and the weekly review is gone.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Convert the owner's own export (not committed)

Runs after the branch is merged and the owner has exported from the old build. Nothing here goes into the repo.

- [ ] **Step 1: Ask the owner for the file path** of their schema-1 export (Einstellungen → Daten → Exportieren, saved to the Mac). Do not open or print its contents beyond counts.

- [ ] **Step 2: Convert** — write this to the scratchpad as `convert_v1_to_v2.py` and run it with the path:

```python
import json, sys, pathlib

source = pathlib.Path(sys.argv[1])
data = json.loads(source.read_text())
assert data.get("schemaVersion") == 1, f"expected schema 1, found {data.get('schemaVersion')}"

counts = {k: len(data.get(k, [])) for k in ("plans", "planCheckIns", "reviewDecisions")}
for key in counts:
    data.pop(key, None)

for substance in data["substances"]:
    substance["asksMorningAfter"] = substance["name"].strip().lower() != "nikotin"

data["morningAfters"] = []
data["schemaVersion"] = 2

target = source.with_name(source.stem + "-v2.json")
target.write_text(json.dumps(data, ensure_ascii=False, sort_keys=True))
print("dropped", counts, "->", target)
print(len(data["substances"]), "substances,", len(data["entries"]), "entries kept")
```

- [ ] **Step 3: Hand over** the path of the `-v2.json` file with the steps: delete the old app, install the new build, finish onboarding with any substance, Einstellungen → Daten → Importieren (the import replaces the store). Confirm with the owner that entry and substance counts match the script's output.

---

## Self-review notes

- Spec § 1.1–1.6 → Tasks 1–3 (core), 4–6 (export). § 2 → Task 6. § 3.1–3.2 → Task 7. § 3.3–3.4 → Task 8. § 3.5 → Tasks 5 and 6 (switch). § 3.6 → Tasks 4 and 5. § 4 → Tasks 9 and 11. § 5 → tests in each task plus Task 10. § 6 → Task 10.
- Deviations from the spec, both deliberate: `MorningRegret.slightly` instead of `some`; the Übersicht text adds „n× ein bisschen bereut" and „ohne Angaben zu Kater und Reue", because „kein Kater, nichts bereut" would otherwise be false for those answers.
