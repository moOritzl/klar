# Klar — Muster tab and open reviews (design)

Follows [2026-09-24-v3-morgen-danach-design.md](2026-09-24-v3-morgen-danach-design.md). v3 made
„Der Morgen danach" the core loop but gives almost nothing back: one line per substance on
Übersicht, one line in the entry sheet. Answers, notes and reflections are stored and never shown
again, and a card that is swiped away is lost for good. Meanwhile the tab „Grenzen" is mostly
configuration.

This block gives the answers a place (tab „Muster", day detail), lets a missed day be answered
later (Offen), and moves the limits to where they are read (Übersicht) and set (Einstellungen).

The opt-in afternoon reminder is the next block. It depends on the open-day logic defined here.

---

## Decisions taken before writing this spec

| Question | Decision |
|---|---|
| Where the morning-after data goes | A tab „Muster" replaces „Grenzen". It merges Trends and the morning-after evaluation per substance. |
| Where limits go | Their state stays on Übersicht (quota cards, now tappable). Editing lives on a per-substance page in Einstellungen. |
| Verlauf | Calendar only. The segmented control and the section swipe go. |
| Missed days | Stay answerable for 3 days after the day ends. Listed as „Offen" on Übersicht and Verlauf, and reachable from the day detail. |
| Swiping the card away | Means „Später": the card does not pop up again, the day stays open. Only „Überspringen" closes a day. |
| Notification-centre style inbox with badge | No. A counter is the pressure P9 rules out. A quiet list that only exists while something is open. |
| Export schema | Unchanged (2). Nothing in this block adds user data. |

## 0 · Prerequisite: small PR before this block

Lands first, without its own spec:

- **Kontextverteilung:** share = entries of the substance carrying the tag ÷ entries of the
  substance carrying **at least one** tag. Entries without context are not in the denominator.
  `StatsSummary` gains `taggedEntryCount`. Bars no longer sum to 100 %. A caption under the bars
  reads „Basis: N Einträge mit Kontext".
- **Kalender:** one dot per substance logged that day, in `Klar.substanceColor`, ordered by
  `sortOrder`, at most three. `KlarStore.loggedDays(inMonthOf:)` returns
  `[Date: [Substance]]`. The today cell keeps its dots in `Klar.bg`. VoiceOver names the
  substances.

Section 3.2 below reuses the new denominator.

---

## 1 · KlarCore

### 1.1 `LogicalDay.previousDayKey`

```swift
public static func previousDayKey(_ key: String) -> String?
```

The key of the calendar day before `key`. Correct across month and year boundaries. Used by the
card to tell „yesterday" from a later answer (§ 3.1).

### 1.2 Answer window and open days

```swift
public static let answerWindow: TimeInterval = 72 * 60 * 60

/// Days that can be answered or edited now, with or without a record.
public static func answerableDayKeys(
    entries: [EntryDTO],
    askingSubstanceIDs: Set<UUID>,
    now: Date,
    nowTimezoneID: String
) -> Set<String>

/// Answerable days with no record at all, newest first.
public static func openDayKeys(
    entries: [EntryDTO],
    askingSubstanceIDs: Set<UUID>,
    records: [MorningAfterDTO],
    now: Date,
    nowTimezoneID: String
) -> [String]
```

A day is answerable when:

1. it has at least one entry of an asking substance;
2. its key is strictly less than today's key;
3. `now < end(ofDayKey:) + answerWindow`, with `end` taken in the timezone of the day's latest
   entry. This is the same rule `dueDayKey` uses, with 72 h instead of 48 h.

A skip record removes a day from `openDayKeys` but not from `answerableDayKeys`. The user can
still answer a skipped day from the day detail. „Überspringen" means „don't list it", not „lock
it".

`dueDayKey` is unchanged. It still returns only the newest day, and its 48 h expiry still governs
the automatic pop-up.

### 1.3 Days shared with other substances

```swift
/// For the answered days of `substanceID`: how many of them also have entries of each other
/// asking substance.
public static func sharedDays(
    substanceID: UUID,
    askingSubstanceIDs: Set<UUID>,
    entries: [EntryDTO],
    records: [MorningAfterDTO]
) -> [UUID: Int]
```

Only answered records count, as in `pattern`. Substances that don't ask (Kaffee, Nikotin by
default) are not counted, because the user said they have nothing to do with the day after.

### 1.4 Patterns over all days

No API change. The Muster tab calls `pattern(…, limit: .max)`. The existing `limit: 5` default
stays for Übersicht and the entry sheet.

---

## 2 · App data and store

- **No model change.** „Später" is device state, not user data:
  `AppSettings.lastPresentedMorningDayKey: String?` in `UserDefaults`, like the other device
  settings.
- `KlarStore` gains:
  - `openMorningAfterDays(now:) -> [String]`
  - `canAnswerMorningAfter(dayKey:now:) -> Bool`
  - `morningDistribution(for:) -> MorningPattern?`, which is `pattern` with `limit: .max`,
    minimum 3
  - `morningPatternsByContext(for:) -> [(ContextTag, MorningPattern)]`, with `limit: .max`,
    minimum 3 per tag
  - `sharedMorningDays(for:) -> [(Substance, Int)]`, ordered by count
  - `reflections(for:limit:) -> [MorningAfter]`: records of days with an entry of the substance
    and at least one non-empty `trigger`, `wouldHaveHelped` or `nextTime`, newest first
- `recordMorningAfter` already reuses an existing record. Answering a skipped day turns the skip
  into an answer. It gets a test.

---

## 3 · UI

### 3.1 Card „Der Morgen danach"

- **Wording by distance.**
  - If `dayKey == previousDayKey(todayKey)`, everything stays as it is: header
    „Der Morgen danach · Samstag", „Wie geht's dir heute körperlich?",
    „Bereust du etwas von gestern?".
  - Otherwise the header reads „Der Morgen danach · Sa., 26. Sep.", and the questions become
    „Wie ging's dir am Tag danach körperlich?" and „Bereust du etwas von dem Tag?".
  - „Würdest du es wieder so machen?" is the same in both.
- **Prefill.** Opened for a day that already has a record, the card shows its answers and note.
  Tapping an option still toggles it.
- **Buttons.** **Fertig** (primary), then one quiet row with **Später** and **Überspringen**.
  - „Später" saves nothing and dismisses.
  - „Überspringen" calls `skipMorningAfter` as today. On a day that already has a record it only
    dismisses.
  - Swiping the card away behaves like „Später".
- **Automatic presentation** (`MainTabView`).
  - `shouldPresentMorning` gains `lastPresentedKey: String?` and returns `false` when
    `dueKey == lastPresentedKey`.
  - Presenting the card sets `settings.lastPresentedMorningDayKey = dueKey`.
  - The `onDismiss` skip goes. Dismissing no longer writes anything.
  - Net effect: the card appears by itself once per consumption day, as P9 requires.
- **Manual presentation.** From Offen, the day detail and the Übersicht row, the same view is
  presented as a sheet with `presentationBackground(.clear)`. It is never marked as
  auto-presented.

### 3.2 Tab „Muster"

- **Tab.** `KlarTab.limits` becomes `.patterns`, label „Muster", SF Symbol
  `chart.xyaxis.line`. New folder `Features/Patterns/`.
- **Header.** `KlarScreen(title: "Muster")`, then the substance chips from today's Trends
  (active substances in `sortOrder`). The selection is shared with `MainTabView` so Übersicht can
  preselect a substance (§ 3.4).
- **Cards, top to bottom, for the selected substance:**
  1. **Häufigkeit.** Two tiles, „Pro Woche" (`occasionFrequencyPerWeek`, one decimal) and
     „Ø Abstand" (days). Ø Abstand moves here out of `DoseTrendCard`.
  2. **Der Morgen danach.** Only if the substance asks.
     - Header „Der Morgen danach · N Tage", counted over all answered days.
     - One row per question (Körper, Reue, Nochmal so):
       - a stacked horizontal bar over that question's answered days;
       - under it, the counts in option order with zeros left out, e.g.
         „gut 6 · angeschlagen 3 · verkatert 2".
     - Bar colours are one hue, three steps (`teal700`, `teal400`, `teal300`), in option order
       and the same for every question. No green or red, no highlight on any answer (P7).
     - If `sharedMorningDays` is non-empty, a tertiary line follows: „Davon 3 Tage zusammen mit
       Cannabis, 1 mit Alkohol".
     - Below three answered days, only the sentence „Muster erscheinen nach drei Rückblicken."
       No progress indicator.
  3. **Kontext.** `ContextDistributionCard` moves here and gains one line per tag.
     - Unchanged per tag: name, share and bar (the denominator from § 0).
     - New: if the substance asks and the tag has a pattern of its own (≥ 3 answered days), a
       second tertiary line reads „5 Tage: 4× verkatert, 1× bereut".
     - This line comes from a new `MorningPatternText.tally(_:)`, the `summary` fragments with
       „N Tage:" instead of „letzte N:".
  4. **Ø Dosis über Zeit.** `DoseTrendCard` unchanged, minus Ø Abstand.
  5. **Deine Sätze.** Only if the substance asks and has reflections.
     - The newest five, each with the date as caption („Sa., 26. Sep.") and up to three lines:
       „Auslöser: …", „Hätte geholfen: …", „Nächstes Mal: …".
     - Empty fields are left out. Older ones stay reachable through the calendar.
- **Order.** How often comes first, then what it was like, then where it happens, then the
  amount, then the user's own words.
- **Empty state.** No substances → the sentence from today's Trends.
- `TrendsSectionView.swift` is deleted. `DoseTrendCard` and `ContextDistributionCard` move to
  `Features/Patterns/`.

### 3.3 Verlauf

- `HistoryView` loses the segmented control, `Section`, the section swipe and its comments.
  `KlarScreen(title: "Verlauf")` holds the Offen card (§ 3.5), `CalendarStatsView`, the calendar
  and the legend.
- **Calendar.** Open days get a 1 pt `Klar.borderStrong` ring around the day number. Today is
  never open, so this cannot collide with the today pill. VoiceOver appends „Rückblick offen".
- **Day detail** (`DayDetailView`). Below the entries, when the day has an entry of an asking
  substance, a card headed „Der Morgen danach":
  - **Answered:**
    - „Körper: verkatert", „Reue: ein bisschen", „Nochmal so: anders", each only if answered;
    - then the note;
    - then the three reflection answers with the labels from § 3.2.5.
    - While `canAnswerMorningAfter`, a „Bearbeiten" button opens the prefilled card. Afterwards
      the block is read-only.
  - **Skipped:** „Übersprungen." plus „Rückblick nachtragen" while `canAnswerMorningAfter`.
  - **No record:** „Rückblick nachtragen" while `canAnswerMorningAfter`. Otherwise no block.

### 3.4 Übersicht

Order: quota cards, Offen card, Kurzmuster card, „Heute erfasst".

- **Quota cards.** `QuotaCard` and each row of `MultiQuotaCard` become buttons that open a
  sheet with `LimitEditor` for that substance (§ 3.6).
- **Offen card** (§ 3.5): only while `openMorningAfterDays` is non-empty.
- **Kurzmuster card** (`MorningPatternsCard`). Each row becomes a button. It switches to the
  Muster tab with that substance selected. Content unchanged.

### 3.5 Offen card

`Features/MorningAfter/OpenMorningsCard.swift` is one component, used on Übersicht and Verlauf.

- `KlarCard` with a `KlarSectionLabel` „Offen". One row per open day, newest first (at most
  three by construction).
- Each row shows „Samstag, 26. Sep." and the day's asking substances as compact chips. Tapping
  it opens the card for that day.
- No badge, no count in the tab bar, no colour. Nothing is rendered when nothing is open.
- The identifier `morning.open.<dayKey>` is on each row.

### 3.6 Einstellungen

- **Substanzen** (was „Substanzen & Kosten"). `SubstancesView` becomes a list of navigation
  rows: colour dot, name, and a subtitle with the limit („max. 4 / Monat", „Abstinenz",
  „Beobachten", „Pausiert"), plus „· Morgen danach" when the substance asks. „Substanz
  hinzufügen" stays.
- **Substance page** (`Features/Settings/SubstanceSettingsView.swift`), top to bottom:
  - **Grenze.** `LimitEditor`, i.e. `GoalCard` without the name row and without the toggle:
    stepper, Reduktion/Abstinenz/Beobachten, „Ziel pausieren". Versioning via
    `KlarStore.setGoal` is unchanged.
  - **„Morgen danach fragen"** toggle (moved from `GoalCard`, same identifier pattern:
    `settings.asksMorningAfter.<name>`).
  - **„Kosten je <Einheit>"** (moved from `SubstanceRow`, same parsing).
  - **„Archivieren"** with the existing confirmation dialog.
- **New group „Craving-SOS":** „Ersatzhandlungen" (`SubstitutionActionsView`, presented as a
  sheet like the other rows), „Dein ‚Warum'", „Vertrauensperson". The last two move out of
  „Deine Daten", which keeps „Substanzen" and „Daten".
- **Deleted:** `LimitsView.swift`, `GoalCard`. The limit UI lives in
  `Features/Limits/LimitEditor.swift`, which the Übersicht sheet and the substance page share.

---

## 4 · Demo and example data

- **`DemoDataSeeder`:**
  - one day of mixed use (two asking substances, answered);
  - one open day (yesterday or the day before, no record), so the Offen card, the calendar ring
    and the pop-up can be seen;
  - at least one record with all three reflection answers.
- **`tools/generate_example_data.py`:** make sure some answered days have two asking
  substances. The file's dates lie in the past, so it has no open days. That is fine.
  Regenerate `examples/klar-beispieldaten.json`.

---

## 5 · Tests

**KlarCore** (`swift test`):
- `previousDayKey` across month and year boundaries.
- `answerableDayKeys` and `openDayKeys`:
  - answerable at +71 h after day end, not at +72 h;
  - today's day never appears;
  - a switched-off substance does not count;
  - a skip record removes the day from `openDayKeys` but not from `answerableDayKeys`;
  - an answered record removes it from `openDayKeys`;
  - several open days come newest first;
  - a newer day does *not* hide an older one here (unlike `dueDayKey`).
- `sharedDays`: counts only answered days, only asking substances, never the substance itself.

**App** (`KlarTests`):
- `MainTabViewMorningGuardTests`: `dueKey == lastPresentedKey` → no presentation; a different
  key → presentation.
- `KlarStore`:
  - `openMorningAfterDays` and `canAnswerMorningAfter` against seeded entries;
  - answering a skipped day makes it answered;
  - `reflections` filters by substance and skips empty records.
- `MorningPatternTextTests`: `tally` wording, zeros left out, the all-zero case.

**UI** (`KlarUITests`):
- `testTabsAreReachableAfterOnboarding`: „Muster" instead of „Grenzen". The substitutions check
  moves to Einstellungen › Ersatzhandlungen.
- `MorningAfterUITests`:
  - the existing two tests stay. Skipping also asserts that no `morning.open.*` row exists.
  - **New:** seed yesterday, launch, tap „Später", relaunch. The card does not pop up, the
    Übersicht row `morning.open.<key>` exists, tapping it opens the card, and after „Fertig" the
    row is gone.
- `ScreenshotTests`: Muster (with patterns), Verlauf with an Offen card, day detail with a
  review, substance page. „E3-Trends" and „G-Grenzen" go.

**By hand before the PR:** simulator (iPhone 17 Pro, iOS 26.5) on demo data, light and dark,
with screenshots of Muster, Verlauf, day detail and the substance page.

---

## 6 · Docs in this block

- **`docs/klar-screens-implementation.md`:**
  - E without the Trends segment, plus the Offen card, the calendar ring and the day-detail
    block;
  - a new section for Muster, replacing G;
  - D1 with „Später", prefill and wording by distance;
  - I with the substance page and the „Craving-SOS" group;
  - B with tappable quota and pattern rows.
- **`docs/klar-mvp-konzept.md`:**
  - **Modul B:** patterns live in the tab „Muster", over all answered days, per context and with
    mixed use named.
  - **Modul C:**
    - the card pops up once per consumption day;
    - „Später" keeps the day open;
    - open days can be answered for 72 h after the day ends, via Offen and the day detail;
    - „Überspringen" only removes a day from the list.
  - **Modul D:** limits are shown on Übersicht and set per substance in Einstellungen.
  - P9 stays as written. The reminder block rewrites it.

---

## 7 · Out of scope

- The afternoon reminder and the P9 rewording (next block).
- Renaming a substance or changing its unit.
- The „Geld gespart" wording in the substances list, and the green „↓ von …" delta in
  `DoseTrendCard`.
- Dose against consequences (needs more data and careful wording).
- README, landing page, pitch deck.
