# Klar — UX fix batch (design)

Thirteen issues from a hands-on test pass, grouped into eight phases. Phases 1–7 are
independent and can ship in any order; phase 8 (dark mode) is the largest and comes last by
decision.

Source of the issue list: user test session, 2026-08-01. Screenshots referenced: Heute + entry
sheet, Hilfe, Verlauf/Kalender.

---

## Decisions taken before writing this spec

| Question | Decision |
|---|---|
| When to do dark mode | Own phase, last, same spec. Everything else ships first. |
| How far to push "interactive at the bottom" | Informative banner on top, interactive block bottom-weighted, in one reusable container. Klar typography kept; no system large titles. |
| Which "cringe" quota text | The `NewMonthCard` line "Jeder Monat beginnt bei null. Kein Rückblick auf den letzten, kein Vorwurf." The rest is covered by the app-wide copy pass. |
| CSV export | Removed completely, service function and UI. Import gets a real entry point. |

---

## Phase 1 · The app lock actually uses Face ID, and re-arms

Two separate defects behind two of the reported symptoms.

**1a — "Face-ID-Sperre ist eigentlich keine, sondern nur iPhone-Code."**

Root cause: no `NSFaceIDUsageDescription`. iOS refuses biometric evaluation without it and
`LAPolicy.deviceOwnerAuthentication` falls through to the passcode, silently. The project uses
`GENERATE_INFOPLIST_FILE = YES`, so this belongs in build settings, not in
[Info.plist](../../../Klar/Klar/Info.plist):

```
INFOPLIST_KEY_NSFaceIDUsageDescription = "Klar entsperrt deine Einträge mit Face ID."
```

Set in both Debug and Release configurations of the app target.

**1b — "Manchmal wird nicht nach FaceID / Code gefragt, sondern stuck auf dem Klar-Screen."**

Root cause: [AppLockOverlayView.swift:36](../../../Klar/Klar/Security/AppLockOverlayView.swift:36)
triggers authentication from `.task`, which runs once per view identity. Two paths lead to a
dead lock screen:

- The app backgrounds while already locked. On return the overlay's identity is unchanged,
  `.task` does not re-run, nothing prompts.
- The Face ID sheet is dismissed by the system when the app resigns active (`LAError.systemCancel`
  / `.appCancel`). `attemptUnlock` catches it, sets `isLocked = true`, and nothing retries.

Fix:

- `AppLockManager` gets an `isAuthenticating` flag so overlapping evaluations cannot stack, and
  distinguishes a *cancel* from a *failure* — a cancel must not paint "Erneut versuchen".
- `AppLockOverlayView` drives authentication from `scenePhase` becoming `.active` (plus the
  initial appearance), not from `.task` alone, and only when `isLocked && !isAuthenticating`.

Tests: unit tests on `AppLockManager` for the re-arm and the no-double-evaluation invariants,
using an injected `LAContext` stub. Manual verification in the simulator with an enrolled Face ID
(`xcrun simctl` biometry) for the background/foreground cycle.

---

## Phase 2 · Panic gesture removed

"Ich verstehe den Sinn gar nicht. Feature komplett entfernen."

Delete, in this order:

- [PanicView.swift](../../../Klar/Klar/Security/PanicView.swift) (213 lines, the calculator façade)
- `MultiTouchTapCatcher` and the `isPanicActive` gate in
  [RootView.swift](../../../Klar/Klar/App/RootView.swift) — roughly lines 34–45 and 141–216
- `isPanicGestureEnabled` and its `Keys` entry in
  [AppSettings.swift](../../../Klar/Klar/App/AppSettings.swift)
- The "Panik-Geste" toggle row in [SettingsView.swift](../../../Klar/Klar/Features/Settings/SettingsView.swift:52)
- The corresponding entries in `Localizable.xcstrings`
- The J2 section of [klar-screens-implementation.md](../../klar-screens-implementation.md)

The stale `klar.isPanicGestureEnabled` UserDefaults key is left in place on existing installs.
Cleaning it up would need migration code for a boolean nobody reads.

The gate order comment in `RootView` drops from four levels to three: app lock → onboarding →
tabs.

---

## Phase 3 · One format in, the same format out

"Beim Export nur das Format anbieten, das man auch importieren kann. Dem Nutzer nicht die Wahl
geben."

Today the app exports JSON *and* CSV, and has no import at all —
`ExportImportService.importJSON` is reachable only from
[DebugRootView.swift:61](../../../Klar/Klar/Debug/DebugRootView.swift:61).

**Remove:** `exportCSV` from
[ExportImportService.swift:11](../../../Klar/Klar/Persistence/ExportImportService.swift:11), the
CSV row, `isExportingCSV`, and the second `fileExporter` in
[DataManagementView.swift](../../../Klar/Klar/Features/Settings/DataManagementView.swift). No
tests cover CSV, so nothing else moves.

**Add:** an import row in the same screen. The complication is that `importJSON` refuses a
non-empty store (`ExportImportError.storeNotEmpty`), so importing into a used app means
replacing what is there. Order matters:

1. `fileImporter(allowedContentTypes: [.json])`
2. Decode and schema-check the file **before** touching the store. This needs
   `importJSON` split into `decode(_:) throws -> KlarExport` and
   `restore(_:context:)`; a corrupt file must never be able to wipe good data.
3. Confirmation dialog stating plainly that the current data is replaced.
4. `wipeAll` → `restore` → set `hasCompletedOnboarding = true` (otherwise the user lands in
   onboarding on top of a full store).

Round-trip test: seed a store, export, wipe, import, assert entity counts and a sample entry
match. A second test asserts a malformed file leaves the store untouched.

The settings row label changes from "Daten exportieren / löschen" to "Daten".

---

## Phase 4 · Banner on top, controls in thumb reach

Covers two reports: "Hilfe-Buttons sind so weit oben" and "Kalender / Pläne — Komponenten mit
denen man interagiert sollten unten sein."

Measured from the screenshots: on Hilfe the last tappable row ends at ~46 % of the screen
height, leaving ~45 % dead space below it. Every tab today is a top-aligned `ScrollView`.

**New component — `KlarScreen`** in
[KlarComponents.swift](../../../Klar/Klar/DesignSystem/KlarComponents.swift):

```swift
KlarScreen(title: "Verlauf") {
    // banner zone: informative only, never tappable
} content: {
    // everything interactive
}
```

Behaviour:

- Banner zone sits at the top with generous vertical padding — the "fetter Banner" effect,
  built from the existing `Klar.TypeScale`, not from a system navigation bar.
- Content block is bottom-weighted: flexible space between banner and content absorbs the
  leftover height, so short screens push their controls into thumb reach.
- When the content is taller than the viewport the flexible space collapses to zero and the
  screen scrolls normally. Implemented with `containerRelativeFrame(.vertical)` and a
  `Spacer(minLength: 0)` — deployment target is iOS 26.5, so no back-compat gymnastics.
- `scrollBounceBehavior(.basedOnSize)` throughout, which also fixes the calendar's phantom
  scroll (phase 5).

**Per-screen split:**

| Screen | Banner (informative) | Bottom block (interactive) |
|---|---|---|
| Hilfe | "Hilfe" | SOS card, Notfall, Beratung, Risiko-Infos |
| Verlauf · Kalender | "Verlauf", the two stat tiles (Einträge / Eintragsfrei) | Calendar card with month chevrons and day cells, legend |
| Pläne | "Pläne", subtitle, Ziel card | Plan cards, "Plan hinzufügen", navigation rows |

The stat tiles moving from footer to banner is deliberate: they are the summary of the month, and
they are the only thing on that screen nobody taps.

**The segmented control.** Kalender/Trends/Rückblick is interactive, so the stated rule sends it
to the bottom, but pinned directly above the tab bar it reads as a second tab row. It goes into a
`safeAreaInset(edge: .bottom)` accessory bar styled distinctly from the tab bar — inset from the
edges, on the screen's own surface colour, so it reads as part of the screen and not as chrome.
If that turns out to look like two stacked tab bars in the simulator, the fallback is leaving it
in the banner zone as navigation rather than action, and that decision is made from a screenshot,
not in advance.

Heute keeps its current structure. It already has its primary action bottom-right as a FAB, and
its content grows with entries, so bottom-weighting would fight itself. It adopts the banner
typography only, for consistency.

Verification: simulator screenshots of all three screens, empty and populated.

---

## Phase 5 · Calendar interaction

"Lässt nach oben / unten scrollen, obwohl es nichts zum scrollen gibt. Lässt sich durch
rechts / links wischen nicht navigieren."

- Phantom scroll: `scrollBounceBehavior(.basedOnSize)` — inherited from `KlarScreen` in phase 4,
  so this is only a check that it took effect, not separate work.
- Horizontal swipe for month navigation: `DragGesture(minimumDistance: 20)` on the calendar card,
  acting on `onEnded` only when `abs(translation.width) > abs(translation.height)` so it cannot
  steal the vertical scroll. Left swipe = next month, right = previous. The forward direction
  respects the existing `isCurrentMonth` guard: future months stay unreachable, and a swipe that
  would go there does nothing rather than bouncing.
- The chevrons stay. They are the accessible path and the discoverable one.
- The month change gets the same `withAnimation` treatment in both paths, so tapping and swiping
  look identical.

Test: `HistoryView`'s month math is already pure (`shiftMonth`); a unit test covers the forward
guard. The gesture itself is verified in the simulator.

---

## Phase 6 · Entry sheet spacing

"Spacing etwas komisch (siehe Foto eintrag hinzufügen)."

The screenshot is the empty state: no substances configured. What happens today at
[EntrySheetView.swift:68](../../../Klar/Klar/Features/Entry/EntrySheetView.swift:68) is that the
explanatory sentence renders, then an empty `ScrollView` claims all remaining height, and the
`.medium` detent holds a half-screen of nothing.

- The empty state becomes a centred block with an action that resolves it — "Substanzen
  auswählen", opening `SubstancesView` — instead of a sentence pointing at a screen the user then
  has to find.
- That state gets a fitted detent (`.presentationDetents([.height(300)])`) so the sheet is the
  size of its content.
- The populated picker keeps `[.medium, .large]`. Its own spacing gets a pass at the same time:
  the 18 pt gap under the subtitle and the 34 pt bottom padding are tuned against the list, not
  against an empty container.

---

## Phase 7 · Copy pass

Two items: the specific quota line, and "für jeden Text anti-ai-writing anwenden".

**7a — the quota line.** Delete "Jeder Monat beginnt bei null. Kein Rückblick auf den letzten,
kein Vorwurf." from
[TodayView.swift:312](../../../Klar/Klar/Features/Today/TodayView.swift:312). The card keeps
"Neuer Monat" and the factual "Kontingent: 4." — the information stays, the absolution goes.

**7b — the app-wide pass.** Baseline, measured with `slopcheck.py` over the 328 user-facing
strings extracted from the sources (1714 words):

| Metric | Count | per 1000 words |
|---|---|---|
| em dash | 32 | 18.7 |
| flagged vocabulary | 0 | 0.0 |
| inflated significance | 0 | 0.0 |
| negative parallelism | 0 | 0.0 |
| rule of three | 4 | 2.3 |

The vocabulary is clean. The tell is structural and it is the same construction 32 times:
*[Fakt] — [Beruhigung]*. "Max. 3 aktive Pläne — Fokus statt Liste." "Noch kein Plan — das ist in
Ordnung." "Generische Texte — nie Substanznamen." "Möchtest du deinen Plan dazu ansehen? —
Freiwillig, nicht jetzt nötig." Once it is visible it is visible everywhere, and it is what reads
as therapeutic voice-over.

Rule for the pass: **delete the reassurance clause, do not rewrite it.** An em dash survives only
where it separates a genuine aside that carries information. Target under 6 per 1000 words, which
is about 8 in the whole app.

Not changed: the German quotation marks `„…"` (correct typography, a scanner false positive) and
the rule-of-three hits (real enumerations — "Leber, Herz und Schlaf", "Ziele, Pläne und Notizen").

Mechanical constraint: `Localizable.xcstrings` is keyed by the German source string, so every
edited `Text("…")` needs its catalogue entry updated in the same commit or the key goes stale.

Verification: re-run `slopcheck.py` on a freshly extracted string dump and check the em-dash
density; diff-read every changed string for meaning drift.

---

## Phase 8 · Dark mode, System as default

"System-Standard sollte Default-Option sein."

There is no appearance setting at all today.
[KlarTheme.swift](../../../Klar/Klar/DesignSystem/KlarTheme.swift) is 25 literal light colors and
[RootView.swift:55](../../../Klar/Klar/App/RootView.swift:55) pins `.preferredColorScheme(.light)`
with the comment "The design ships light only."

**Setting.** `AppAppearance { system, light, dark }` in `AppSettings`, defaulting to `.system`,
surfaced as a picker row in Settings. `RootView` applies
`.preferredColorScheme(settings.appearance.colorScheme)`, where `.system` maps to `nil`.

**Tokens.** The semantic aliases become adaptive via
`Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })`, keeping all tokens in one
file. Asset-catalog color sets were considered and rejected: 25 new folders would break the
one-token-one-line mapping to the CSS design file that the current header comment promises.

The dark ramp is derived from the existing teal scale rather than invented: `teal950` as
background, `teal900` as surface, `teal800` as border, `teal100`/`teal300` as text, and
`emerald500` unchanged as accent — it already passes contrast on both ends.

**The parts that are not just tokens:**

- 42 `.white` literals across 16 files. Most sit on inverse surfaces (accent button, inverse card)
  and stay correct, but each needs checking; the ones that mean "the page" have to become
  `Klar.surface`.
- `Klar.Shadow` is `teal900` at 6–12 % opacity, which is invisible on a dark background.
  Elevation in dark mode comes from a 1 px `Klar.border` instead, so `klarShadow` becomes
  appearance-aware.
- `LaunchBackground.colorset` needs a dark variant, or the launch frame flashes light before the
  first real frame.
- `KlarInverseCard` and `PanicView`'s dark styling — the latter is gone by phase 2.

Verification: simulator screenshots of every main screen in both schemes, toggled with
`xcrun simctl ui booted appearance dark|light`, plus a contrast check on text over `bgSubtle` and
over `accent`.

---

## Out of scope

- Anything about the panic façade beyond deleting it.
- The `MultiQuotaReproTests` / `KlarStoreQuotaSubstancesTests` work in progress on the branch.
- Restructuring Heute beyond adopting the banner typography.
