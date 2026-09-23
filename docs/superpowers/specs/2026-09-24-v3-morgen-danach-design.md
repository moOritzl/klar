# Klar — v3 block 1+2: „Der Morgen danach" replaces plans (design)

Implements concept v3 ([klar-mvp-konzept.md](../../klar-mvp-konzept.md), modules C and B) in
the app: if-then plans and the weekly review go, a morning-after check-in and the patterns it
produces come in.

This is the first of three blocks. Block 3 renames goals to limits (wording, „Geld gespart" →
Ausgaben, onboarding A3). Block 4 does README, landing page and the screenshot PNGs. Neither is
touched here beyond what this block needs to build, test and import.

---

## Decisions taken before writing this spec

| Question | Decision |
|---|---|
| How to slice v3 | Swap (plans out, morning-after in) and the patterns ship together. A review without patterns is a second diary (concept § 2.4). |
| Where limits and substitutions live | A tab „Grenzen" replaces „Pläne". Limits per substance on the screen, substitutions linked below. |
| UI name of the card | „Der Morgen danach". Code name `MorningAfter`. |
| Weekly review | Removed completely: full-screen flow, the history archive, the weekly notification, `ReviewDecision`. |
| Which substances trigger the card | A switch per substance, „Morgen danach fragen". Off for Nikotin, on for everything else, custom substances included. |
| Existing data on the owner's phone | No in-app migration. Export schema goes to 2 and schema 1 is rejected. The owner's export is converted once by a script that is not committed. |
| Where answers are stored | One record per logical day (approach A), joined to that day's entries when patterns are computed. |

---

## 1 · KlarCore

Everything below imports `Foundation` only, like the rest of the package.

### 1.1 Answers

```swift
public enum MorningBody: String, Codable, CaseIterable, Sendable { case fine, rough, hungover }
public enum MorningRegret: String, Codable, CaseIterable, Sendable { case no, some, yes }
public enum MorningAgain: String, Codable, CaseIterable, Sendable { case yes, differently, no }
```

UI labels: Körper „gut / angeschlagen / verkatert", Reue „nein / ein bisschen / ja",
Nochmal so „ja / anders / nein".

### 1.2 DTO

```swift
public struct MorningAfterDTO: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var dayKey: String          // "yyyy-MM-dd", LogicalDay.components of the day's entries
    public var body: MorningBody?
    public var regret: MorningRegret?
    public var again: MorningAgain?
    public var note: String?
    public var trigger: String?        // problem solving: „Was war der Auslöser?"
    public var wouldHaveHelped: String?// „Was hätte geholfen?"
    public var nextTime: String?       // „Was machst du nächstes Mal anders?"
    public var recordedAt: Date
    public var isAnswered: Bool { body != nil || regret != nil || again != nil }
}
```

A record with no answers is a skip. It exists so the day is never asked about again.

`LogicalDay` gains `public static func dayKey(for date: Date, timezoneID: String) -> String`,
built from `components(for:timezoneID:)`. Keys compare correctly as strings.

### 1.3 `MorningAfterService.dueDayKey`

```swift
public static func dueDayKey(
    entries: [EntryDTO],
    askingSubstanceIDs: Set<UUID>,
    records: [MorningAfterDTO],
    now: Date,
    nowTimezoneID: String
) -> String?
```

1. Keep entries whose `substanceID` is in `askingSubstanceIDs`.
2. Group them by `dayKey(entry.timestamp, entry.timezoneID)`.
3. The candidate is the **greatest** key strictly less than today's key (`dayKey(now, nowTimezoneID)`).
   No candidate → `nil`.
4. A record with that key exists (answered or skipped) → `nil`. Older days are never asked about,
   whether or not they have a record.
5. The day ends at 05:00 on the following calendar day, in the timezone of the latest entry of
   that day. `now >= end + 48 h` → `nil`.
6. Otherwise return the candidate.

This replaces the concept's „expires once the next consumption day begins": that rule would let
a morning cigarette cancel last night's card. The concept is updated to match (§ 6).

### 1.4 `MorningAfterService.pattern`

```swift
public struct MorningPattern: Sendable, Equatable {
    public let days: Int                       // answered days counted, 3...5
    public let body: [MorningBody: Int]
    public let regret: [MorningRegret: Int]
    public let again: [MorningAgain: Int]
    public let nextTime: String?               // latest non-empty nextTime among those days
}

public static func pattern(
    substanceID: UUID,
    contextTagID: UUID?,
    entries: [EntryDTO],
    records: [MorningAfterDTO],
    limit: Int = 5,
    minimum: Int = 3
) -> MorningPattern?
```

- Only answered records count.
- A record counts for the substance when at least one entry with that `dayKey` has the
  substance, and, if `contextTagID` is given, carries that tag.
- The newest `limit` matching days are counted. Fewer than `minimum` → `nil`.
- A day with a partial answer counts in `days` and only in the tallies it answered.

### 1.5 Removed from KlarCore

`PlanService`, `PlanSentence`, `PlanDTO`, `PlanCheckInDTO`, `ReviewDecisionDTO`, `PlanStatus`,
`CheckInOutcome`, `ReviewPlanDecision`, and their tests.

### 1.6 Export

`KlarExport.currentSchemaVersion = 2`. The envelope drops `plans`, `planCheckIns` and
`reviewDecisions` and gains `morningAfters: [MorningAfterDTO]`. `SubstanceDTO` gains
`asksMorningAfter: Bool`. The decoder keeps rejecting any version other than the current one.

---

## 2 · App data

- New `@Model final class MorningAfter`, field for field the DTO, enums stored as raw strings
  as in the other models.
- `Substance.asksMorningAfter: Bool = true`. `SubstanceCatalog` sets it to `false` for Nikotin
  when onboarding creates the substance; custom substances keep `true`.
- `Plan`, `PlanCheckIn` and `ReviewDecision` are deleted and leave the schema in
  `ModelContainerFactory` and the debug preview.
- `KlarStore`:
  - drop every plan, check-in, suggestion and review-decision method;
  - `deleteEntry` no longer cleans up check-ins;
  - add `dueMorningAfterDay(now:) -> String?`, `recordMorningAfter(dayKey:body:regret:again:note:)`,
    `skipMorningAfter(dayKey:)`, `recordReflection(dayKey:trigger:wouldHaveHelped:nextTime:)`,
    `morningPattern(for:contextTag:) -> MorningPattern?`, `setAsksMorningAfter(_:for:)`,
    and `entries(onDayKey:)` for the card's chips.
- `AppSettings` loses `lastReviewedWeekStart` and `areNotificationsEnabled`.
  `NotificationScheduler` is deleted.

---

## 3 · UI

### 3.1 „Der Morgen danach" card

- Presented by `MainTabView` when `dueMorningAfterDay` returns a key: on first appearance and
  again whenever the scene becomes active, so opening the app from the background the next
  morning shows it. Same presentation as today's check-in: dimmed backdrop, card, clear sheet
  background.
- Header: `KlarSectionLabel` „Der Morgen danach · Samstag" (weekday of the logical day).
  Below it, chips for that day's substances and context tags, deduplicated.
- Three rows, each a label and a `KlarSegmented` with three options and no preselection:
  „Wie geht's dir heute körperlich?", „Bereust du etwas von gestern?",
  „Würdest du es wieder so machen?". Tapping the selected option clears it, like the mood
  control in the entry sheet.
- Optional note field, collapsed behind „Notiz hinzufügen".
- When regret is „ja", a quiet link appears: „Kurz drüber nachdenken" → the reflection flow (3.2).
- Buttons: **Fertig** (records whatever is answered; if nothing is, records a skip) and
  **Überspringen** (records a skip). Swiping the sheet away records a skip.
- No praise for good answers, no comment on bad ones, no colour coding of options.

### 3.2 Reflection flow (problem solving)

Extracted from `PlanCheckInView` into its own view: three optional text fields
(„Was war der Auslöser?", „Was hätte geholfen?", „Was machst du nächstes Mal anders?") and
„Speichern". Writes to the day's `MorningAfter` record. Reached only from the card. The
limit-exceeded trigger in the concept is dropped: that day gets a card the next morning anyway.

### 3.3 Übersicht

- `PlanSummaryCard`, the „Noch kein Plan." card and the plan editor sheet go.
- In their slot: a card headed „Der Morgen danach" with one row per substance that has a
  pattern (`contextTag: nil`), in substance sort order. Row text:
  „Alkohol · letzte 5: 3× verkatert, 1× bereut".
  - Fragments in fixed order, zero counts left out: `n× verkatert`, `n× angeschlagen`,
    `n× bereut` (regret = ja).
  - All three zero: „kein Kater, nichts bereut".
  - If the pattern has `nextTime`, a second line in tertiary text: „Nächstes Mal: …".
- No substance with a pattern → no card, no placeholder.

### 3.4 Entry sheet (C2)

Under the header, one line in secondary text with the pattern of the entry's substance. When
context tags are selected, the first selected tag (in tag display order) that has its own
pattern narrows it: „Mit Club · letzte 4: 3× verkatert". Updates live as tags are toggled.
No pattern → no line.

### 3.5 Tab „Grenzen"

- `KlarTab.plans` becomes `.limits`, label „Grenzen", SF Symbol `gauge.with.dots.needle.33percent`.
- The screen is a `KlarScreen` titled „Grenzen" with the `GoalCard`s of today's `GoalsView`
  inline (no push), then „Substanzen verwalten", then a card linking to „Ersatzhandlungen".
- Each `GoalCard` gets a toggle row „Morgen danach fragen" at the bottom.
- `GoalsView` as a pushed screen is removed; its content moves into the tab.
- Wording inside the cards (Reduktion, Ziel, Geld gespart) is block 3.

### 3.6 Removed

| What | Where |
|---|---|
| Plans list, editor, check-in | `Features/Plans/PlansView.swift`, `PlanEditorView.swift`, `Features/CheckIn/PlanCheckInView.swift` |
| Plan card and empty-plan card | `TodayView.swift` |
| „Plan dafür bauen?" suggestion | `TrendsSectionView.swift` |
| Weekly review | `Features/Review/WeeklyReviewFlowView.swift`, `App/WeeklyReviewSummary.swift`, `ReviewArchiveSectionView` and the „Rückblick" segment in `HistoryView` (Kalender and Trends remain) |
| Weekly notification | `NotificationScheduler.swift`, the toggle in `SettingsView` |
| „Du hast einen Plan." | `CravingSOSView.swift` — the line becomes „Dieses Gefühl geht vorbei." |
| Orphaned strings | `Localizable.xcstrings` |
| Plan date helpers no longer used | `KlarDate.swift` |

---

## 4 · Data, demo and example files

- **Owner's data:** export from the current build, convert with a scratchpad script (schema 2,
  drop plans/check-ins/review decisions, add `asksMorningAfter` by the Nikotin rule), delete the
  app, install the new build, import. The file stays on the Mac and the script is not committed.
- **`DemoDataSeeder`:** no plans; morning-after records for most past consumption days so both
  Übersicht rows and the entry-sheet line appear.
- **`tools/generate_example_data.py`:** `SCHEMA_VERSION = 2`, no plans, check-ins or review
  decisions; deterministic morning-after records for roughly 70 % of eligible days, with enough
  hangovers on club/party nights for a context pattern to show. Regenerate
  `examples/klar-beispieldaten.json`; update the plan mentions in `examples/README.md`.

---

## 5 · Tests

**KlarCore** (`swift test`):
- `dueDayKey`: entry at 02:30 belongs to the previous day; switched-off substance never triggers;
  due at +47 h, not due at +48 h after day end; a newer day hides an older unanswered one; a skip
  record stops the question; no entries → `nil`; today's entries alone → `nil`.
- `pattern`: below three answered days → `nil`; context filter; partial answers; skips ignored;
  only the newest five counted; `nextTime` is the latest non-empty one.
- `dayKey` across the cutoff and across timezones.

**App** (`KlarTests`):
- `ExportImportTests` round-trips `MorningAfter` and `asksMorningAfter`; a schema-1 file is
  rejected before anything is deleted.
- The plan case in `ContextTagRelationshipTests` goes.
- `KlarStore` tests for `recordMorningAfter`, `skipMorningAfter` and the Nikotin default.

**UI** (`KlarUITests`):
- The tab test asserts the „Grenzen" tab instead of „Noch kein Plan.".
- New: seed an entry for yesterday, launch, the card appears, answer and tap Fertig, relaunch,
  the card does not come back. Seeding goes through a new `UITestSupport` launch argument
  (`--klar-uitest-seed-yesterday`: onboarding done, Alkohol, one entry at 21:00 on the previous
  logical day), next to the existing `--klar-uitest-reset`.
- `ScreenshotTests` walk the new screens (card, Übersicht with patterns, Grenzen) and pass.
  The PNGs are regenerated and committed in block 4.

**By hand before the PR:** the flow in the simulator (iPhone 17 Pro, iOS 26.5) on demo data,
light and dark, with screenshots.

---

## 6 · Docs in this block

- `docs/klar-screens-implementation.md`: remove D (check-in), F (review), E4 (archive), G1/G2
  (plans); add the card, the reflection flow, the Übersicht card, the entry-sheet line and the
  Grenzen tab; fix the test counts.
- `docs/klar-mvp-konzept.md`:
  - module B without the weekly review; the feedback is the patterns;
  - module C: the expiry rule from § 1.3, the per-substance switch;
  - module E: reflection reached from „bereut: ja" only;
  - § 5 validation without review metrics;
  - P1's wording stays true (every entry leads to feedback, now via patterns).
- README and landing page: block 4.

---

## 7 · Out of scope

Limit wording, „Geld gespart" → Ausgaben, onboarding A3 (block 3). README, landing page,
screenshot PNGs, the pitch deck (block 4). Push notifications of any kind. iCloud sync.
