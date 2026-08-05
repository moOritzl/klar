# Beispieldaten

`klar-beispieldaten.json` is a complete, importable Klar export: 21 weeks of one
plausible reduction story, shaped so that every screen in the app has something
to show.

## Importing

Einstellungen → Daten → **Daten importieren**, then pick the file. The import
replaces everything already on the device, so export first if that matters.

To get the file onto a simulator, drag it onto the simulator window and save it
to *Files*; on a device, AirDrop it or drop it in iCloud Drive.

## Who this is

Someone cutting down on drinking, who smokes mostly when they drink, and who logs
coffee to see the pattern rather than to limit it. Three substances — the same
three the app's own `DemoDataSeeder` uses, because that is what a real user keeps
up with.

| Substance | Unit | Goal | |
|---|---|---|---|
| Alkohol | Getränke | Reduktion, max. 6 | Watched for a month, then limited to 8, then tightened to 6 |
| Nikotin | Stück | Reduktion, max. 10 | Came later — one thing at a time |
| Kaffee | Getränke | Nur beobachten | Logged without a limit |

Two live reduction goals means the Today screen shows the **combined** quota card,
tightest allowance first. The other two goal badges (*Abstinenz*, *Pausiert*) are
not in the file — each substance carries one goal, and inventing a fourth
substance to display a badge is how the data stops looking like a person. Both
are one tap away in Pläne → Ziele.

## The story the numbers tell

Alcohol steps down from ~11 occasions a month to 6, and the average per occasion
from ~4.9 drinks to ~2. Nicotine follows more slowly. The trend chart in E3 shows
that decline, and the weekly review compares each week only against the user's own
previous one.

| | |
|---|---|
| Entries | 521 across 21 weeks |
| Day boundary | Club nights run past midnight and stay on the evening they started (05:00 cutoff) |
| Entry-free days | 6–10 per month, so the calendar has gaps to show |
| Context tags | The four built-ins plus Feierabend, Stress, Arbeit, Wochenende |
| Optional fields | 20 entries carry a note, 188 a mood, 124 no context at all |
| Plans | 2 active, 1 paused, 1 archived (superseded by the active party plan) |
| Check-ins | 35 answered, **1 deliberately left open** |
| Goals | 6 periods; alcohol is versioned three times |

Two numbers are pinned rather than sampled, because neither survives a random
draw: *Sozial* stays above 50 % of alcohol contexts (below that, E3 stops offering
to build a plan from it), and the last two weeks are set so the trend card reads
"↓" instead of "↑". See `plan_alcohol` in the generator.

## Two things happen on the first launch after importing

1. **A plan check-in** (D1) appears, for the one entry left unanswered.
2. Once that is dismissed, the **weekly review** (F1–F3) is due — `lastReviewedWeekStart`
   lives in UserDefaults, not in the export, so a fresh device always has one waiting.

Both are one-shot: answering them consumes them.

Not reachable from this file: the "Neuer Monat" card (B3) only renders on the 1st.
Generate with `--today` set to the 1st of a month to see it.

## Regenerating

The dataset is dated relative to a reference day and goes stale. Regenerate it:

```bash
python3 tools/generate_example_data.py
```

Pass `--today 2026-12-24` to date it to a specific day. The generator is
deterministic (fixed seed) and prints what the app's own calculators will compute,
failing loudly if a quota is already spent, a month has no entry-free days, the
dominant context slips below 50 %, or the pending check-in count is not exactly one.

## Assumptions

Timestamps are written in `Europe/Berlin`. The logical-day and calendar maths in
the app read each entry's own stored timezone, so the data is correct anywhere —
but a device in another timezone will bucket the small hours differently at the
edges. Change `TZ_NAME` in the generator if that matters.
