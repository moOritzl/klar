# Screenshots

Captured on an iPhone 17 Pro simulator (iOS 26.5) running the app against
[`examples/klar-beispieldaten.json`](../../examples/klar-beispieldaten.json).
Every number visible in them comes from that file — nothing is mocked up.

Each screen exists twice under the same filename: `light/` and `dark/`. Both sets
were walked in the same order from the same freshly seeded store, so the two
halves of a pair show identical data.

| File | Screen | What it shows |
|---|---|---|
| `01-checkin.png` | Plan check-in (D1) | Fires on launch, for the one entry the dataset leaves unanswered |
| `02-heute.png` | Heute (B1) | Combined quota card — two live limits, tightest first — plus the active plan and the day's entries |
| `03-rueckblick-1.png` | Weekly review 1/3 (F1) | "Was war." — the week's counts and the direction against the previous week |
| `04-rueckblick-2.png` | Weekly review 2/3 (F2) | July landing exactly on its limit: "6 von 6", bar fully drained |
| `05-rueckblick-3.png` | Weekly review 3/3 (F3) | The decision the review always ends in |
| `06-kalender.png` | Verlauf · Kalender (E1) | A full month: 72 entries, 10 entry-free days |
| `07-tagesdetail.png` | Tagesdetail (E2) | One day end to end — work coffee, a stress cigarette, three drinks alone, and the note that goes with them |
| `08-trends.png` | Verlauf · Trends (E3) | The dose curve, "↓ von 3 Getränke", the context split, and the plan offer at 57 % |
| `09-rueckblick-archiv.png` | Verlauf · Rückblick (E4) | Twelve archived weeks with varying outcomes |
| `10-plaene.png` | Pläne (G1) | Two active plans with their real check-in tallies |
| `11-ziele.png` | Ziele (G4) | Reduktion ×2 and Nur beobachten; Abstinenz and Pausieren one tap away |
| `12-eintrag.png` | Eintrag erfassen (C1) | The substance picker — one tap to log |
| `13-hilfe.png` | Hilfe (H1) | |
| `14-craving-sos.png` | Craving-SOS (H2) | The user's own "Warum" and their five substitution actions |
| `15-einstellungen.png` | Einstellungen (I1) | |

The check-in in `01` and the review in `03`–`05` are both one-shot: answering them
consumes them, so re-seed before recapturing.

## Recapturing

The dataset is dated relative to a reference day, so these go stale with it.
Regenerate the data first:

```bash
python3 tools/generate_example_data.py
```

Seeding is the fiddly part — the store lives in the app's own container, so the
data has to be written from inside the app process. A throwaway unit test in
`KlarTests` hosted by the app does it in one call:

```swift
let data = try Data(contentsOf: URL(fileURLWithPath: "…/examples/klar-beispieldaten.json"))
let context = ModelContext(ModelContainerFactory.makeContainer())
try ExportImportService.replaceAll(with: data, context: context)
DemoModeSupport.skipOnboarding()
UserDefaults.standard.removeObject(forKey: "klar.lastReviewedWeekStart")
```

Run it against a booted simulator, then launch the app — it comes up populated,
with the check-in and the weekly review both due. Switch schemes between the two
passes with `xcrun simctl ui <udid> appearance light|dark`.

`--klar-demo-seed` does something similar but seeds `DemoDataSeeder`'s much
smaller sample instead, which is not what these screenshots show.
