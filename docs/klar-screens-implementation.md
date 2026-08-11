# Klar — Screen-by-Screen Implementation

Implements `Klar App Draft.dc.html` from the Claude Design project *Klar iOS App Design*
(`3914b56a-7154-4644-ab7e-6585381fe30f`). All 33 drafted screens are built.

**Status:** builds clean; 30 unit tests + 5 UI tests pass; every screen below has been driven
end-to-end in the simulator (`KlarUITests/ScreenshotTests`).

---

## 1. Foundations

| Layer | File | Notes |
|---|---|---|
| Design tokens | [KlarTheme.swift](../Klar/Klar/DesignSystem/KlarTheme.swift) | 1:1 port of `tokens/{colors,typography,spacing}.css`. Names mirror the CSS custom properties, so one token change in the design maps to one change here. Each semantic alias resolves per trait collection, which is how dark mode stays one line per token. |
| Shared components | [KlarComponents.swift](../Klar/Klar/DesignSystem/KlarComponents.swift) | Card, buttons, chips, segmented control, quota bar, step dots, flow layout. |
| Screen scaffold | [KlarScreen.swift](../Klar/Klar/DesignSystem/KlarScreen.swift) | Background, padding, `navigationTitle`/`navigationSubtitle`, and `scrollBounceBehavior(.basedOnSize)`. Used by Verlauf, Pläne and Hilfe. The `NavigationStack` comes from the caller — three of the four tabs already had one for their own links. Heute keeps its own layout (FAB + growing content) and opts into the bounce fix by hand. |
| Settings (device) | [AppSettings.swift](../Klar/Klar/App/AppSettings.swift) | UserDefaults. Deliberately **not** SwiftData — device prefs must not land in the data export. |
| Data access | [KlarStore.swift](../Klar/Klar/App/KlarStore.swift) | The single write path, and the bridge to `KlarCore`'s pure calculators. |
| Dates | [KlarDate.swift](../Klar/Klar/App/KlarDate.swift) | **05:00 logical-day boundary.** An entry at 02:30 belongs to the night before. Every "today"/"this month" question goes through here. Normalizing is *not* idempotent — a normalized day is 00:00, which is before the cutoff — so a value that already is a logical day must never be fed back in: `entries(onLogicalDayOf:)` takes wall-clock instants, `entries(onLogicalDay:)` takes normalized days. |
| Shell | [RootView.swift](../Klar/Klar/App/RootView.swift) | Gate order: app lock → onboarding → tabs. Carries the `tabViewBottomAccessory` — the "Eintrag erfassen" bar that replaced a floating `+` button, and the reason logging is reachable from every tab. No `tabBarMinimizeBehavior`: it was tried and on these screens the bar never came back, taking three of the four tabs with it. |

**Fonts.** SF Pro throughout, no font files bundled. The design's `--font-display` was PT Serif
and was ported as `Font.system(design: .serif)` — the one token deliberately dropped since. A
serif headline is a web-magazine signal, and next to a real `navigationTitle` it read as a
picture of an app rather than an app. `TypeScale.display(_:)` survives as a size/weight step in
SF Pro, so the call sites did not have to change.

**Chrome.** Every tab is a `NavigationStack` with a real large title, which is what buys the
collapse-on-scroll and the scroll-edge treatment. Heute puts the logical-day line in
`navigationSubtitle` and the gear in a `.topBarTrailing` toolbar item; the hand-built header row
is gone. No `.toolbarBackground` overrides anywhere — they suppress the very effect the bar is
there for.

**Cards.** `KlarCard` is a fill on a darker page, never an outline: `Klar.surface` on
`Klar.bgSubtle`. Controls (text fields, chips, capsule buttons) keep their borders, surfaces do
not — that split is the whole rule. `bgSubtle` was moved one step down (`#F4F6F6` / `#0E1719`)
when the borders went, because in dark the old pair measured 1.15:1 and the cards dissolved
without their outline. The optional `header:` slot adds a label row and a full-bleed hairline,
the `insetGrouped` pattern.

**Light and dark.** The draft ships light mode only; the dark values are derived from the same teal
ramp read from the other end, so both schemes stay one family. Einstellungen → Darstellung offers
System / Hell / Dunkel, defaulting to System. `RootView` applies it by setting
`window.overrideUserInterfaceStyle` rather than `.preferredColorScheme`, because the latter leaves
sheets and tab-bar chrome following the system.

---

## 2. Screens

### A · Onboarding — [OnboardingFlowView.swift](../Klar/Klar/Features/Onboarding/OnboardingFlowView.swift)

Nothing is written to the store until the final step. Abandoning halfway leaves no trace.

| Screen | State | Wiring |
|---|---|---|
| **A1** Privatsphäre | ✅ | "Face ID einrichten" **actually authenticates** via `LAContext` before the switch is set — the lock is proven to work at setup, not discovered broken at the worst moment. On a device with no biometrics/passcode the step degrades to a plain "Weiter" instead of dangling a lock it can't deliver. |
| **A2** Substanzauswahl | ✅ | Starter list in [SubstanceCatalog.swift](../Klar/Klar/Features/Onboarding/SubstanceCatalog.swift) (7, alphabetical, no icons). "Eigene hinzufügen" supported. |
| **A3** Ziel je Substanz | ✅ | Reduktion / Abstinenz / Beobachten. Default is **Beobachten** — "kein Ziel am Tag 1 nötig". The limit stepper only appears for Reduktion. |
| **A4** Ersatzhandlungen | ✅ | Suggestions are offered but **nothing is pre-selected** — Behavior Substitution only works if the alternative is the user's own. Writes `SubstitutionAction`s consumed by H2. |

### B · Übersicht — [TodayView.swift](../Klar/Klar/Features/Today/TodayView.swift)

**The screen is no longer called „Heute".** It leads with a *monthly* quota, carries a standing
plan under it, and only the third block is about today — so a title promising one day forced the
quota card to correct it („Diesen Monat") just to be read right. The title is scope-neutral, each
block names its own timeframe (`AUGUST` on the card, `Di., 11. Aug.` on the „Heute erfasst"
header), and nothing has to talk its way out of its container. The file, the type and the screen
IDs below still say Today/Heute; only what the user reads changed.

| Screen | State | Wiring |
|---|---|---|
| **B1** Heute (gefüllt) | ✅ | `KlarStore.quotaSubstances()` lists **every** active reduction limit, tightest remaining first. One substance → the large quota card (with the substance named); several → one combined `MultiQuotaCard` with a row + bar per substance. The bar **drains** rather than fills — filled segments are what *remains*. The count is a `QuotaCount`: small „Noch", the number at 28pt with `contentTransition(.numericText())` so it rolls when an entry lands, small „von N". Same wording as before, different weighting. |
| **B2** Heute (leerer Tag) | ✅ | "Ein ruhiger Tag." No "Noch nichts geloggt!" — an entry-free day is the calm baseline, not a gap. Asserted in `testOnboardingThenLogFirstEntry`. |
| **B3** Monatserster | ✅ | The dark "Neuer Monat" card renders when `KlarDate.isFirstOfMonth()` — "Kontingent: N." for one limit, "Kontingente: Alkohol 4 · Nikotin 10." for several. |

Over the limit, the headline flips from "Noch 2 von 4" to "5 von 4 diesen Monat" — factual, no red,
no appeal.

**The date names the logical day, not the wall clock.** Between midnight and 05:00 those disagree,
and the date labels the entries listed under it, so it has to follow them: at 02:15 it reads
"Mo., 3. Aug. · bis 5 Uhr". It sits on the "Heute erfasst" header rather than on the screen,
because that is the only block it labels. On an entry-free day there is no such header, and the
date drops out with it — *except* inside the cutoff window, where it appears under "Ein ruhiger
Tag." because there it changes what the next tap will do. Same rule throughout: the hint shows
only where the shown day contradicts the phone. `today` is `@State` refreshed when the scene
becomes active — "bis 5 Uhr" stops being true at 05:00, and a computed `Date()` would only be
right by accident. The same window makes the entry confirmation name the day ("Alkohol · jetzt,
02:15 · noch Montag"), and Settings states the rule under "Tag" without offering it as a control.

### C · Eintrag erfassen — [EntrySheetView.swift](../Klar/Klar/Features/Entry/EntrySheetView.swift)

**All three states share one header language.** C1 kept a hand-built 22pt `Text` in its content
for one round while C2 and C3 had a 34pt `navigationTitle` — so saving jumped the title size
right in the middle of the task. C1 is now a `navigationTitle` too („Neuer Eintrag", which also
stops two different screens both being called „Eintrag") and carries no toolbar button: it is a
two-tap screen whose point is speed, and the drag indicator plus the page visible behind a sheet
that never fills the screen are exit enough.

**The action's placement follows the screen's job, and that difference is deliberate.**
`EntryDetailForm.Mode` carries it rather than a set of booleans that could be combined into
states that make no sense:

| | `.saved` | `.edit` |
|---|---|---|
| What it is | the terminal step of a flow | an inspector on an existing entry |
| Detent | `.large` — every field visible with room for large Dynamic Type | `[.medium, .large]` |
| „Fertig" | prominent, pinned via `safeAreaBar(edge: .bottom)` | toolbar `.confirmationAction` |
| Delete | no — undoing a tap is a swipe away | yes |

The bottom bar is why `.saved` can afford full height: pinning the action means the extra height
costs no reachability. `.edit` writes every field as it is changed, so „Fertig" only closes —
which is what a toolbar button says and a large primary button would overstate.

**„jetzt" is passed in, not inferred.** `EntryStamp.subtitle(for:isFresh:)` used to derive it
from `isToday`, so *every* entry logged earlier today read „Alkohol · jetzt, 08:05" when opened
at 20:44. Only the screen that just wrote the entry passes `isFresh: true`; the edit sheet shows
the plain time.

**„Gespeichert." is the sheet's title, not a badge inside it.** It used to be a `SavedHeader`: a
green check in a circle with a bold line next to it, and the form starting right underneath. It
confirmed nothing the haptic had not already confirmed, and it sat in the position a title
belongs in without being one. Both post-save states now use `navigationTitle` +
`navigationSubtitle`, with „Fertig" as a `.confirmationAction` toolbar item — reachable without
scrolling past every optional field to find it. `EntryStamp.subtitle(for:)` builds the
„Alkohol · jetzt, 02:15 · noch Montag" line for both.

The sheet sits on `Klar.bgSubtle` rather than `Klar.surface`. On the card colour every field had
to be outlined just to be visible against its own background, which is how borders survived here
after being removed everywhere else. The dose field keeps its border — it is a text field, and
iOS outlines controls. Mood is the design system's `KlarSegmentedControl` instead of three
hand-drawn buttons; tapping the active segment still clears it, which a plain `Picker` cannot
express.

| Screen | State | Wiring |
|---|---|---|
| **C1** Substanz wählen | ✅ | The entry is written **the instant a substance is tapped**. No confirmation step, no "Bist du sicher?" — shame is the enemy of data quality. |
| **C2** Gespeichert | ✅ | Dose / context / mood / timestamp, all optional, all saved as you type. Same form is reused for editing an entry later (E2). |
| **C3** Über dem Limit | ✅ | Shown instead of C2 when the entry pushed the user past the limit. Details stay editable later — "Details sind optional und nachreichbar". |

Mood is stored as `Int` (1 / 0 / −1) so the scale can widen later without a migration.

### D · Plan-Check-in — [PlanCheckInView.swift](../Klar/Klar/Features/CheckIn/PlanCheckInView.swift)

| Screen | State | Wiring |
|---|---|---|
| **D1** Eine Frage | ✅ | Surfaced by `MainTabView` on foregrounding, from `KlarStore.pendingCheckIn()` → `PlanService.pendingCheckIns`. Fires only for an entry whose logical day is **strictly before today** — a day later, reflection is evaluation, not confrontation. |
| **D2** Reflexion bei "Nein" | ✅ | Three questions. Answers 1–2 append to the entry's `note` (visible again in the day detail); **answer 3 pre-fills the plan editor**, so the reflection ends in a changed plan rather than in a feeling. |

### E · Verlauf — [HistoryView.swift](../Klar/Klar/Features/History/HistoryView.swift) · [TrendsSectionView.swift](../Klar/Klar/Features/History/TrendsSectionView.swift)

| Screen | State | Wiring |
|---|---|---|
| **E1** Monatskalender | ✅ | Dots per logged logical day; month navigation (future months disabled); "Einträge" / "Eintragsfrei" tiles. |
| **E2** Tagesdetail | ✅ | Tap any past day. Entries editable + deletable; "Eintrag nachtragen" back-fills at noon of that day. |
| **E3** Trends | ✅ | Swift Charts line of Ø dose per week; Ø gap; context distribution. When one context clears 50 %, the card offers to **build a plan for exactly that tag** — the bridge into Modul C. |
| **E4** Rückblick-Archiv | ✅ | Past weeks, newest first, opening a read-only version of F1/F2. |

> **Deviation.** The draft's segmented control has two segments (Kalender / Rückblick) but ships a
> third screen, Trends (E3), with no entry point drawn. A third segment is the smallest change that
> makes every designed screen reachable.

### F · Weekly Review — [WeeklyReviewFlowView.swift](../Klar/Klar/Features/Review/WeeklyReviewFlowView.swift)

| Screen | State | Wiring |
|---|---|---|
| **F1** Was war | ✅ | Purely descriptive. Numbers from [WeeklyReviewSummary.swift](../Klar/Klar/App/WeeklyReviewSummary.swift). |
| **F2** Ziel & Plan | ✅ | Quota + plan tally. The plan balance appears **only here**, never on Heute. |
| **F3** Eine Frage nach vorn | ✅ | Behalten / anpassen / pausieren. "Pausieren" **actually pauses the plans** — a review that changed nothing would be theatre. |

Triggered on launch when the previous week is over and unreviewed *and* the user has entries — a
review of nothing is noise, not feedback. This feedback layer is not optional: logging without it is
behaviourally inert (Konzept § 2.1).

### G · Pläne — [PlansView.swift](../Klar/Klar/Features/Plans/PlansView.swift) · [PlanEditorView.swift](../Klar/Klar/Features/Plans/PlanEditorView.swift) · [GoalsView.swift](../Klar/Klar/Features/Plans/GoalsView.swift) · [SubstitutionActionsView.swift](../Klar/Klar/Features/Plans/SubstitutionActionsView.swift)

| Screen | State | Wiring |
|---|---|---|
| **G1** Pläne (aktiv) | ✅ | Per-plan check-in tally. 3-active-plan cap enforced in `PlanService`, surfaced as an alert. |
| **G2** Pläne (leer) | ✅ | The suggestion card appears only once the user's **own entries** show a dominant context tag (≥ 3 tagged entries). A plan needs knowledge of one's own patterns, so it can't arrive on day 1. |
| **G3** Plan-Editor | ✅ | Editing **versions** the plan (archives the old one, `supersededBy` → new, fresh commitment date) rather than mutating it. |
| **G4** Ziele | ✅ | Limit / type / pause. Every change versions the goal — editing a goal must never retroactively rewrite whether a past month was met. |
| **G5** Ersatzhandlungen | ✅ | Reorder + delete. Same data source as the SOS; order matters (the SOS leads with the first). |

> **Additions.** (1) The draft draws G4 and G5 with no entry point; they're linked from the bottom of
> the Pläne tab, which is where the concept says goals belong ("Ziele leben hier, nicht in den
> Settings"). (2) The draft's "WENN" row shows only tag chips, but the model — and the resulting
> "Wenn …, dann …" sentence — also needs a situation *phrase*. Picking a tag pre-fills it from a
> template ([PlanTemplates](../Klar/Klar/Features/Plans/PlanEditorView.swift)); the field stays editable.
> (3) Both phrases are typed standalone ("Auf einer Party"), so wherever they're read back as one
> sentence — the plan card, the Check-in, the Plan-Bilanz — they run through
> [PlanSentence.fragment](../Packages/KlarCore/Sources/KlarCore/PlanSentence.swift), which lowercases
> the leading word unless it was deliberately capitalised ("AA-Meeting", "U-Bahn"). The Heute-Karte
> keeps the raw text: it labels the halves WENN / DANN instead of composing them.

### H · Hilfe — [HelpView.swift](../Klar/Klar/Features/Help/HelpView.swift) · [CravingSOSView.swift](../Klar/Klar/Features/Help/CravingSOSView.swift) · [HelpContent.swift](../Klar/Klar/Features/Help/HelpContent.swift)

| Screen | State | Wiring |
|---|---|---|
| **H1** Übersicht | ✅ | SOS top, reference material bottom. |
| **H2** Craving-SOS | ✅ | 20-min urge-surfing timer anchored to a **wall-clock deadline**, so it keeps running correctly if the user leaves the app to actually go for that walk. Box-breathing exercise, the user's own "Warum", their own alternatives, one-tap call. |
| **H3** Notfall | ✅ | One-tap `tel://112`, warning signs, first-aid steps. |
| **H4** Beratung | ⚠️ | Three real national services + a link to the DHS Suchthilfeverzeichnis. **See below.** |
| **H5** Risiko-Infos | ⚠️ | 7 substances: dangers, dangerous combinations, emergency symptoms, attributed sources. Zero dosage guidance. **See below.** |

### I · Einstellungen — [SettingsView.swift](../Klar/Klar/Features/Settings/SettingsView.swift)

✅ Reached from the gear on Heute, never a tab. Face ID lock (refuses to switch on when the device
can't honour it), auto-lock delay, substances & costs, "Warum", Vertrauensperson,
notifications, export/delete.

### J · System-Screens

| Screen | State | Wiring |
|---|---|---|
| **J1** Sperrbildschirm | ✅ | [AppLockOverlayView](../Klar/Klar/Security/AppLockOverlayView.swift). `SnapshotShieldView` covers the app-switcher snapshot — the real content is gone *before* iOS screenshots the window. |

---

## 3. Things you must decide or supply before shipping

These are the real gaps. Everything else above is wired.

### 3.1 H4 · Beratung — the local directory is deliberately not shipped

The draft shows city-level entries with distances ("Suchtberatung Mitte · 2,1 km"). **I did not
invent them.** Fabricating a counseling contact in this app could send someone to a number that
doesn't answer at the worst possible moment. What ships: three real, publicly listed national
services (Sucht & Drogen Hotline, BZgA-Infotelefon, TelefonSeelsorge) and an outbound link to the
DHS's officially maintained directory.

To ship the drafted city UI you need a **vetted, maintained data source** — DHS or a licensing
agreement — plus a plan for keeping it current. The `CounselingOffer` model and the badge system
(Anonym / Kostenlos / 24/7) already support it. `AppSettings.counselingCity` exists and is unused.

### 3.2 H5 · Risiko-Infos — content needs expert review

The 7 entries are written to the constitution's rules (harm avoidance only; no dosage, no "how-to")
and attributed to BZgA / drugcom / mindzone / Saferparty. **They have not been reviewed by a
clinician or lawyer.** For a 17+ German-market app making public-health claims, they should be,
before submission.

### 3.3 Notifications are minimal

Only a weekly-review reminder (Monday 10:00) is scheduled. Copy is **generic by contract** — no
notification text may ever name a substance, a dose, or an entry
([NotificationScheduler](../Klar/Klar/Features/Settings/NotificationScheduler.swift)). Not built: a
plan-check-in nudge, quota-reset notice. Both are currently surfaced in-app on launch instead.

### 3.4 Not built, because the draft doesn't draw them

From the concept (§ 4, Modul D): **eintragsfreie Serien, Meilensteine, Geld-gespart-Schätzung.** The
cost basis is captured (Substanzen & Kosten) and `Substance.costPerUnit` is populated, but nothing
consumes it. The draft's closing panel argues *against* a stats surface ("Zahlen ohne Handlungsfrage
sind Selbstzweck"), so this is a product decision, not an oversight.

### 3.5 App Group is not provisioned

[AppGroupContainer](../Klar/Klar/Persistence/AppGroupContainer.swift) prefers
`group.de.lenhard.klar` and silently falls back to Application Support. Fine today; **required** the
moment you add a widget or App Intent that must read the same store. Needs a paid Apple Developer
account.

### 3.6 Strings are inline German

There is no localization catalog work — `Localizable.xcstrings` is essentially untouched (and had an
uncommitted modification before this change). German-only is the stated MVP scope; if EN is ever in
scope, the inline literals are the migration cost.

---

## 4. Two real bugs found and fixed while verifying

Both were found by *looking at the running app*, not by the tests — worth recording.

**1. A new user saw no quota card at all in their first month.**
`QuotaCalculator` resolves a month's goal by asking which `GoalPeriod` was in force **at the start of
that month** (that's the contract its tests encode). My `setGoal` stamped `validFrom = Date()`, so a
goal created on the 14th only took effect on the 1st of the *next* month. Onboarding sets a goal and
Today then showed nothing. Fixed by anchoring `validFrom`/`validUntil` to month boundaries
(`KlarDate.startOfMonth`). Regression tests in
[KlarStoreGoalTests](../Klar/KlarTests/KlarStoreGoalTests.swift).

**2. The 1st of the month vanished from the calendar.**
`LazyVGrid` held two sibling `ForEach`es both keyed `id: \.self` over `Int` — leading blanks (`0,1,…`)
and day numbers (`1...31`). They flatten into one identity space, so id `1` collided and the blank
won, silently swallowing day 1 for any month starting Tuesday or later. Fixed with a single
uniquely-identified cell list.

---

## 5. Running it

```bash
# Build + all tests
cd Klar && xcodebuild -project Klar.xcodeproj -scheme Klar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Re-capture every screen as PNGs (design-fidelity check)
xcodebuild ... -only-testing:KlarUITests/ScreenshotTests -resultBundlePath /tmp/res.xcresult test
xcrun xcresulttool export attachments --path /tmp/res.xcresult --output-path /tmp/shots
```

`--klar-uitest-reset` as a launch argument wipes UserDefaults + the store, so the app starts from a
genuinely clean install ([UITestSupport](../Klar/Klar/App/UITestSupport.swift), DEBUG only).

`DebugRootView` is still in the target and can be swapped back into `KlarApp` to exercise the
persistence layer by hand.
