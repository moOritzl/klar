#!/usr/bin/env python3
"""Generate an importable Klar export file with realistic sample data.

The dataset is deterministic (fixed RNG seed) and dated relative to a reference
day, so it can be regenerated whenever the sample data has gone stale:

    python3 tools/generate_example_data.py                    # relative to today
    python3 tools/generate_example_data.py --today 2026-12-24

It writes the same JSON shape `ExportImportService.exportJSON` produces, so it
can be fed straight into Einstellungen -> Daten -> "Daten importieren".

Substances are limited to legal, everyday ones (alcohol, nicotine, caffeine,
sugar) — the file is meant to be shown to other people.
"""

from __future__ import annotations

import argparse
import json
import random
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

# The app's own constants. See KlarCore/LogicalDay.swift and KlarExport.
SCHEMA_VERSION = 1
CUTOFF_HOUR = 5
TZ_NAME = "Europe/Berlin"
TZ = ZoneInfo(TZ_NAME)

WEEKS_OF_HISTORY = 21
SEED = 20260805

rng = random.Random(SEED)


def new_id() -> str:
    """A deterministic v4-shaped UUID in the uppercase form Swift encodes."""
    return str(uuid.UUID(int=rng.getrandbits(128), version=4)).upper()


def iso(dt: datetime) -> str:
    """ISO-8601 without fractional seconds — what JSONDecoder's .iso8601 accepts."""
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def local(day: date, hour: int, minute: int = 0) -> datetime:
    return datetime.combine(day, time(hour, minute), tzinfo=TZ)


def midnight(day: date) -> datetime:
    return datetime.combine(day, time(0, 0), tzinfo=TZ)


def logical_day(dt: datetime) -> date:
    """The day an entry counts towards: before 05:00 it still belongs to the night before."""
    local_dt = dt.astimezone(TZ)
    return local_dt.date() - timedelta(days=1) if local_dt.hour < CUTOFF_HOUR else local_dt.date()


def month_start(day: date) -> date:
    return day.replace(day=1)


def add_months(day: date, count: int) -> date:
    month_index = day.month - 1 + count
    return date(day.year + month_index // 12, month_index % 12 + 1, 1)


def compact(payload: dict) -> dict:
    """Drop None values — every optional DTO field decodes with decodeIfPresent."""
    return {key: value for key, value in payload.items() if value is not None}


# --------------------------------------------------------------------------- #
# Model
# --------------------------------------------------------------------------- #


@dataclass
class Substance:
    name: str
    unit: str
    color_index: int
    sort_order: int
    cost: str | None = None
    archived: bool = False
    id: str = field(default_factory=new_id)

    def dto(self) -> dict:
        return compact(
            {
                "id": self.id,
                "name": self.name,
                "unit": self.unit,
                "colorIndex": self.color_index,
                "costPerUnitRaw": self.cost,
                "sortOrder": self.sort_order,
                "isArchived": self.archived,
            }
        )


@dataclass
class Tag:
    name: str
    built_in: bool
    id: str = field(default_factory=new_id)

    def dto(self) -> dict:
        return {"id": self.id, "name": self.name, "isBuiltIn": self.built_in}


@dataclass
class Entry:
    substance: Substance
    when: datetime
    amount: str | None
    tags: list[Tag]
    mood: int | None = None
    note: str | None = None
    edited: datetime | None = None
    id: str = field(default_factory=new_id)

    @property
    def day(self) -> date:
        return logical_day(self.when)

    def dto(self) -> dict:
        return compact(
            {
                "id": self.id,
                "substanceID": self.substance.id,
                "timestamp": iso(self.when),
                "timezoneID": TZ_NAME,
                "amountRaw": self.amount,
                "contextTagIDs": [tag.id for tag in self.tags] or None,
                "mood": self.mood,
                "note": self.note,
                # Logged in the moment, a minute or two after the fact.
                "createdAt": iso(self.when + timedelta(minutes=rng.randint(1, 6))),
                "editedAt": iso(self.edited) if self.edited else None,
            }
        )


@dataclass
class Goal:
    substance: Substance
    goal_type: str
    limit: int | None
    valid_from: date
    valid_until: date | None
    id: str = field(default_factory=new_id)

    def dto(self) -> dict:
        return compact(
            {
                "id": self.id,
                "substanceID": self.substance.id,
                "type": self.goal_type,
                "monthlyLimit": self.limit,
                "validFrom": iso(midnight(self.valid_from)),
                "validUntil": iso(midnight(self.valid_until)) if self.valid_until else None,
            }
        )


@dataclass
class Plan:
    tag: Tag
    situation: str
    action: str
    committed: date
    status: str
    superseded_by: str | None = None
    id: str = field(default_factory=new_id)

    def dto(self) -> dict:
        return compact(
            {
                "id": self.id,
                "situationTagID": self.tag.id,
                "situationText": self.situation,
                "actionText": self.action,
                "committedAt": iso(local(self.committed, 20, 30)),
                "status": self.status,
                "supersededBy": self.superseded_by,
            }
        )


@dataclass
class CheckIn:
    plan: Plan
    entry: Entry
    when: datetime
    outcome: str
    id: str = field(default_factory=new_id)

    def dto(self) -> dict:
        return {
            "id": self.id,
            "planID": self.plan.id,
            "entryID": self.entry.id,
            "date": iso(self.when),
            "outcome": self.outcome,
        }


# --------------------------------------------------------------------------- #
# Fixed content
# --------------------------------------------------------------------------- #

# Someone cutting down on drinking, who smokes mostly when they drink, and who logs
# coffee to see the pattern rather than to limit it. Three is what a real user keeps
# up with — the same three the app's own DemoDataSeeder uses. Both drink and smoke
# carry a reduction goal, so the Today screen shows the combined quota card.
SUBSTANCES = {
    "alkohol": Substance("Alkohol", "drink", 0, 0, cost="5.50"),
    "nikotin": Substance("Nikotin", "piece", 1, 1, cost="0.45"),
    "kaffee": Substance("Kaffee", "drink", 2, 2, cost="2.80"),
}

# The four built-in names must match ContextTagSeeder.builtInNames exactly, or the
# seeder inserts a second copy of each on the next launch.
TAGS = {
    "allein": Tag("Allein", True),
    "sozial": Tag("Sozial", True),
    "club": Tag("Club", True),
    "zuhause": Tag("Zuhause", True),
    "feierabend": Tag("Feierabend", False),
    "stress": Tag("Stress", False),
    "arbeit": Tag("Arbeit", False),
    "wochenende": Tag("Wochenende", False),
}

SUBSTITUTIONS = [
    "Eine Runde um den Block",
    "Kalt duschen",
    "Marie anrufen",
    "Alkoholfreies Bier aus dem Kühlschrank",
    "Zehn Minuten Klavier",
]

WHY_NOTES = [
    (
        -18,
        "Ich will morgens wieder klar sein, ohne erst zwei Kaffee zu brauchen.",
    ),
    (
        -6,
        "Weil ich sonntags wieder Lust auf die Woche haben will. "
        "Und weil Marie gesagt hat, sie vermisst die Abende, an denen wir beide noch was mitkriegen.",
    ),
]

# Split by occasion, or the file ends up toasting a birthday on an entry tagged
# „Allein". A note that contradicts its own context tag is the detail that gives a
# generated dataset away.
ALCOHOL_NOTES = {
    "social": [
        "Nach dem zweiten auf Wasser umgestiegen.",
        "Runde ausgegeben, selbst beim alkoholfreien geblieben.",
        "Anstoßen zum Geburtstag, danach Schluss.",
        "Alle wollten noch weiter. Bin trotzdem gefahren.",
    ],
    "club": [
        "War laut, bin früh raus.",
        "Erst um zwei losgekommen. Sonntag war entsprechend.",
        "Zwischendurch zwei Wasser, das hat geholfen.",
    ],
    "home": [
        "Zwei statt vier. Ging leichter als gedacht.",
        "Wollte eigentlich gar nichts. Dann doch eins.",
        "Aus Gewohnheit aufgemacht, nicht aus Lust.",
    ],
}

NICOTINE_NOTES = [
    "Nach dem Meeting, ging schneller als gedacht.",
    "Draußen mit den anderen, mehr aus Gewohnheit.",
    "Erst nach dem Spaziergang — hat den Abstand verlängert.",
]

COFFEE_NOTES = [
    "Zweiter vor 11, danach Tee.",
    "Im Büro aus Reflex.",
    "Letzter vor 14 Uhr, Schlaf war deutlich besser.",
]


# --------------------------------------------------------------------------- #
# Timeline
# --------------------------------------------------------------------------- #


def build(today: date, now_hour: int) -> dict:
    monday = today - timedelta(days=today.weekday())
    first_day = monday - timedelta(weeks=WEEKS_OF_HISTORY)
    days = [first_day + timedelta(days=offset) for offset in range((today - first_day).days + 1)]

    entries: list[Entry] = []

    # Days with nothing logged at all, drawn first so they survive: the calendar
    # counts them ("Eintragsfrei") and the concept treats an entry-free day as the
    # calm baseline rather than a gap. Everything else is placed around them.
    # Sampled per month, not across the whole range, so no single month ends up
    # fully saturated and the calendar has gaps everywhere you page to.
    quiet_days: set[date] = set()
    for month in sorted({month_start(day) for day in days}):
        pool = [day for day in days if month_start(day) == month and day != today]
        quiet_days |= set(rng.sample(pool, k=max(1, round(len(pool) * 0.23))))
    open_days = [day for day in days if day not in quiet_days]

    # --- Alcohol: the substance the whole story is about ------------------- #
    #
    # Occasions per month step down, and so does the amount per occasion, so the
    # trend line in E3 and the week-over-week delta in the review have something
    # to show.
    alcohol_quota = {
        month_start(first_day): 8,
        add_months(first_day, 1): 11,
        add_months(first_day, 2): 9,
        add_months(first_day, 3): 7,
        add_months(first_day, 4): 6,
        add_months(first_day, 5): 2,
    }
    alcohol_days = pick_days(open_days, alcohol_quota, weekend_bias=3.2, today=today)

    # --- Nicotine: a slower, less clean decline ---------------------------- #
    nicotine_quota = {
        month_start(first_day): 13,
        add_months(first_day, 1): 13,
        add_months(first_day, 2): 12,
        add_months(first_day, 3): 11,
        add_months(first_day, 4): 9,
        add_months(first_day, 5): 3,
    }
    nicotine_days = pick_days(
        open_days, nicotine_quota, weekend_bias=1.8, today=today, prefer=alcohol_days
    )

    span = max((today - first_day).days, 1)
    alcohol_plan = plan_alcohol(alcohol_days, first_day, span)

    for day in days:
        is_today = day == today
        progress = (day - first_day).days / span  # 0 at the start, 1 today
        weekend = day.weekday() >= 5

        if day in quiet_days and not is_today:
            continue

        # Coffee: the everyday baseline. Tapers a little, never disappears.
        if rng.random() < (0.9 if not weekend else 0.75):
            cups = rng.choices([1, 2, 3], weights=[0.3, 0.5, 0.2])[0]
            if progress > 0.6:
                cups = min(cups, 2)
            slots = [(7, 15, 45), (12, 40, 30), (15, 30, 40)][:cups]
            for index, (hour, minute, jitter) in enumerate(slots):
                when = local(day, hour, minute) + timedelta(minutes=rng.randint(0, jitter))
                if is_today and when > local(day, now_hour):
                    continue
                entries.append(
                    Entry(
                        substance=SUBSTANCES["kaffee"],
                        when=when,
                        amount="1",
                        tags=[TAGS["arbeit"]] if index < 2 and not weekend else [TAGS["zuhause"]],
                        mood=weighted_mood(progress),
                        note=maybe(COFFEE_NOTES, 0.05),
                    )
                )

        if day in alcohol_days and not is_today:
            kind, drinks = alcohol_plan[day]
            entries.extend(alcohol_occasion(day, progress, kind, drinks))

        if day in nicotine_days and not is_today:
            entries.extend(nicotine_occasion(day, progress, day in alcohol_days))

    # Today gets a couple of entries so the Heute tab is populated but calm.
    entries.append(
        Entry(
            substance=SUBSTANCES["kaffee"],
            when=local(today, 8, 5),
            amount="1",
            tags=[TAGS["zuhause"]],
            mood=1,
        )
    )
    entries.append(
        Entry(
            substance=SUBSTANCES["nikotin"],
            when=local(today, 11, 40),
            amount="1",
            tags=[TAGS["arbeit"], TAGS["stress"]],
            mood=0,
            note="Nach dem Standup. Wollte eigentlich vorher rausgehen.",
        )
    )

    entries.sort(key=lambda entry: entry.when)

    # A couple of entries carry an edit stamp — someone corrected the dose later.
    for entry in rng.sample([e for e in entries if e.day < today - timedelta(days=14)], k=3):
        entry.edited = entry.when + timedelta(days=1, hours=rng.randint(1, 9))

    goals = build_goals(first_day, today)
    plans, check_ins, review_decisions = build_plans_and_checkins(entries, first_day, monday, today)

    return {
        "schemaVersion": SCHEMA_VERSION,
        "exportedAt": iso(local(today, now_hour, 12)),
        "substances": [substance.dto() for substance in SUBSTANCES.values()],
        "entries": [entry.dto() for entry in entries],
        "contextTags": [tag.dto() for tag in TAGS.values()],
        "goalPeriods": [goal.dto() for goal in goals],
        "plans": [plan.dto() for plan in plans],
        "planCheckIns": [check_in.dto() for check_in in check_ins],
        "substitutionActions": [
            {"id": new_id(), "text": text, "sortOrder": index}
            for index, text in enumerate(SUBSTITUTIONS)
        ],
        "whyNotes": [
            {"id": new_id(), "text": text, "createdAt": iso(local(today + timedelta(weeks=offset), 21, 10))}
            for offset, text in WHY_NOTES
        ],
        "reviewDecisions": review_decisions,
    }, entries, goals, plans, check_ins


def weighted_mood(progress: float) -> int | None:
    """Mood drifts upward over the timeline, and is left blank about half the time."""
    if rng.random() < 0.55:
        return None
    return rng.choices([1, 0, -1], weights=[0.25 + progress * 0.35, 0.45, 0.3 - progress * 0.2])[0]


def maybe(pool: list[str], probability: float) -> str | None:
    return rng.choice(pool) if rng.random() < probability else None


def pick_days(
    days: list[date],
    quota: dict[date, int],
    weekend_bias: float,
    today: date,
    prefer: set[date] | None = None,
) -> set[date]:
    """Choose `quota[month]` occasion days per month, favouring weekends."""
    chosen: set[date] = set()
    for month, count in quota.items():
        pool = [day for day in days if month_start(day) == month and day != today]
        if not pool:
            continue
        weights = []
        for day in pool:
            weight = weekend_bias if day.weekday() >= 4 else 1.0
            if prefer and day in prefer:
                weight *= 2.5
            weights.append(weight)
        picked: set[date] = set()
        while len(picked) < min(count, len(pool)):
            picked.add(rng.choices(pool, weights=weights)[0])
        chosen |= picked
    return chosen


# A fixed wobble around the dose curve instead of a random one. Two numbers in this
# file have to hold no matter which reference day is used: „Sozial" must stay the
# dominant context (or E3 drops the „Plan dafür bauen?" offer at 50 %), and the most
# recent week must sit below the one before it (or the trend card reads „↑"). Neither
# survives being left to a sampler.
WOBBLE = [0.3, -0.25, 0.1, -0.3, 0.25, -0.1]


def plan_alcohol(alcohol_days: set[date], first_day: date, span: int) -> dict[date, tuple[str, int]]:
    """Assign every drinking day a setting and a number of drinks, up front.

    Proportions are fixed rather than sampled: roughly 15 % club nights, 50 % other
    social occasions, the rest at home. Club nights only land on a Friday or Saturday
    and stop once the reduction takes hold.
    """
    days = sorted(alcohol_days)
    total = len(days)
    weekend_early = [d for d in days if d.weekday() >= 4 and (d - first_day).days / span < 0.75]
    club = set(rng.sample(weekend_early, min(len(weekend_early), round(total * 0.15))))
    rest = [d for d in days if d not in club]
    social = set(rng.sample(rest, min(len(rest), round(total * 0.5))))

    plan: dict[date, tuple[str, int]] = {}
    for index, day in enumerate(days):
        progress = (day - first_day).days / span
        # ~4.9 drinks per occasion at the start, ~2.3 now. The curve steepens towards
        # the present so the decline is still visible inside the eight weeks the chart
        # plots, and the wobble fades out so the last weeks hug the curve.
        drinks = 4.9 - 2.6 * progress**1.3 + WOBBLE[index % len(WOBBLE)] * (1 - 0.65 * progress)
        kind = "club" if day in club else ("social" if day in social else "home")
        plan[day] = (kind, max(1, round(drinks)))

    # The trend card compares the two most recent weeks that have occasions. A week
    # holding a single occasion has that evening's total *as* its average, so the pair
    # can land flat or inverted on rounding alone. The last two weeks are therefore
    # pinned rather than left to the curve.
    weeks: dict[date, list[date]] = {}
    for day in days:
        weeks.setdefault(day - timedelta(days=day.weekday()), []).append(day)
    ordered = sorted(weeks)
    if len(ordered) >= 2:
        for day in weeks[ordered[-2]]:
            plan[day] = (plan[day][0], 3)
        for day in weeks[ordered[-1]]:
            plan[day] = (plan[day][0], 2)
    return plan


def alcohol_occasion(day: date, progress: float, kind: str, drinks: int) -> list[Entry]:
    """One evening, one to five entries — all on the same logical day.

    Only the first entry carries context tags: the tag describes the occasion, not
    every single glass. That keeps the context distribution in E3 a count of
    *evenings*, and it keeps the check-in in D1 asking once per evening.
    """
    entries: list[Entry] = []
    if kind == "club":
        tags_first = [TAGS["sozial"], TAGS["club"]]
        start_hour, start_minute = 21, rng.randint(0, 50)
    elif kind == "social":
        tags_first = [TAGS["sozial"]]
        start_hour, start_minute = 19, rng.randint(0, 50)
    else:
        # „Allein" rather than „Zuhause": drinking by yourself is the context that
        # means something here, and splitting the two left a 2 % stub in the chart.
        tags_first = [TAGS["allein"]]
        start_hour, start_minute = 20, rng.randint(0, 40)

    when = local(day, start_hour, start_minute)
    for index in range(drinks):
        # A club night runs past midnight; those entries stay on the same logical day.
        entries.append(
            Entry(
                substance=SUBSTANCES["alkohol"],
                when=when,
                amount="1",
                tags=tags_first if index == 0 else [],
                mood=weighted_mood(progress) if index == 0 else None,
                note=maybe(ALCOHOL_NOTES[kind], 0.22) if index == 0 else None,
            )
        )
        when += timedelta(minutes=rng.randint(35, 80))
        if 3 <= when.hour < CUTOFF_HOUR:
            break
    return entries


def nicotine_occasion(day: date, progress: float, with_alcohol: bool) -> list[Entry]:
    """A smoking day, spread across the waking hours rather than bunched up.

    Context follows the clock, not the loop counter — a cigarette at 14:00 is at work,
    one at 22:00 on a Friday you are out drinking is at the club. Deriving it from the
    index instead put „Club" on a Friday afternoon.

    Never tagged „Sozial" or „Feierabend": those two belong to the active plans, and
    every entry carrying one owes a check-in.
    """
    count = max(1, round(rng.gauss(3.6 - progress * 1.4, 1.0)))
    weekday = day.weekday() < 5

    start = local(day, 8, rng.randint(10, 50))
    last_hour = 23 if with_alcohol else 20
    step = (last_hour - 8) * 60 / max(count, 1)

    entries: list[Entry] = []
    for index in range(count):
        when = start + timedelta(minutes=step * index + rng.randint(-25, 25))
        hour = when.hour
        if with_alcohol and hour >= 20:
            tags = [TAGS["club"] if day.weekday() >= 4 else TAGS["zuhause"]]
        elif weekday and 8 <= hour < 18:
            tags = [TAGS["arbeit"]] + ([TAGS["stress"]] if rng.random() < 0.4 else [])
        elif not weekday:
            tags = [TAGS["wochenende"]]
        else:
            tags = [TAGS["allein"] if rng.random() < 0.6 else TAGS["zuhause"]]
        entries.append(
            Entry(
                substance=SUBSTANCES["nikotin"],
                when=when,
                amount="1",
                tags=tags,
                mood=weighted_mood(progress),
                note=maybe(NICOTINE_NOTES, 0.08) if index == 0 else None,
            )
        )
    return entries


def build_goals(first_day: date, today: date) -> list[Goal]:
    """Goal periods are anchored to month starts, exactly as KlarStore.setGoal writes them.

    Nothing is edited in place: tightening a limit closes the old period and opens a
    new one, so a past month keeps the limit that was actually in force at the time.
    Alcohol carries three periods for that reason — it is the whole arc of the file.
    """
    m0 = month_start(first_day)
    m1, m2, m4 = (add_months(first_day, offset) for offset in (1, 2, 4))

    return [
        # Alcohol: watched for a month first, then reduced, then reduced further.
        Goal(SUBSTANCES["alkohol"], "observe", None, m0, m1),
        Goal(SUBSTANCES["alkohol"], "reduction", 8, m1, m4),
        Goal(SUBSTANCES["alkohol"], "reduction", 6, m4, None),
        # Nicotine came later — one thing at a time — and is the second live quota.
        Goal(SUBSTANCES["nikotin"], "reduction", 12, m2, m4),
        Goal(SUBSTANCES["nikotin"], "reduction", 10, m4, None),
        # Coffee: watched, never limited. Logged to see the pattern, not to cut it.
        Goal(SUBSTANCES["kaffee"], "observe", None, m0, None),
    ]


def build_plans_and_checkins(
    entries: list[Entry],
    first_day: date,
    monday: date,
    today: date,
) -> tuple[list[Plan], list[CheckIn], list[dict]]:
    party_v1 = Plan(
        tag=TAGS["sozial"],
        situation="Auf einer Party",
        action="Erst ein Wasser bestellen",
        committed=first_day + timedelta(weeks=4),
        status="archived",
    )
    party_v2 = Plan(
        tag=TAGS["sozial"],
        situation="Auf einer Party",
        action="Alkoholfreies Bier in der Hand behalten",
        committed=first_day + timedelta(weeks=13),
        status="active",
    )
    party_v1.superseded_by = party_v2.id

    evening = Plan(
        tag=TAGS["feierabend"],
        situation="Der Tag ist vorbei und ich komme heim",
        action="Zuerst 15 Minuten rausgehen",
        committed=first_day + timedelta(weeks=9),
        status="active",
    )
    # A plan the user pushed aside during the last review — paused, not deleted.
    stress = Plan(
        tag=TAGS["stress"],
        situation="Der Tag kippt und ich merke Druck",
        action="Drei Minuten Atmen, dann entscheiden",
        committed=first_day + timedelta(weeks=6),
        status="paused",
    )

    plans = [party_v1, party_v2, evening, stress]

    # The Feierabend tag only exists once its plan does, so no entry predates it.
    # Drinking alone at home after work is exactly the situation that plan is for.
    evening_start = evening.committed
    for entry in entries:
        if (
            entry.substance is SUBSTANCES["alkohol"]
            and entry.day >= evening_start
            and TAGS["allein"] in entry.tags
            and rng.random() < 0.8
        ):
            entry.tags = [TAGS["feierabend"]]

    # A check-in is due for every past entry carrying an active plan's situation
    # tag, so every one of them needs an answer here — anything missed resurfaces
    # as a pending check-in on launch. All but the newest are answered, which
    # leaves exactly one waiting after the import (D1) instead of a queue.
    watched = {TAGS["sozial"].id: (party_v1, party_v2), TAGS["feierabend"].id: (evening, evening)}
    to_answer = [
        entry
        for entry in entries
        if entry.day < today and watched.keys() & {tag.id for tag in entry.tags}
    ]
    to_answer.pop()  # the newest one stays unanswered

    check_ins: list[CheckIn] = []
    for entry in to_answer:
        tag_id = next(iter(watched.keys() & {tag.id for tag in entry.tags}))
        early, late = watched[tag_id]
        plan = early if entry.day < late.committed else late
        # Success rate climbs over the timeline; "adjusted" is rare.
        progress = (entry.day - first_day).days / max((today - first_day).days, 1)
        outcome = rng.choices(
            ["helped", "notHelped", "adjusted"],
            weights=[0.5 + progress * 0.45, 0.42 - progress * 0.3, 0.08],
        )[0]
        check_ins.append(
            CheckIn(
                plan=plan,
                entry=entry,
                when=local(entry.day + timedelta(days=1), rng.randint(9, 20), rng.randint(0, 55)),
                outcome=outcome,
            )
        )

    # Weekly review decisions for the completed weeks. Mostly "keep" — the point
    # of the review is that most weeks end in no change.
    decisions: list[dict] = []
    week = monday - timedelta(weeks=WEEKS_OF_HISTORY - 1)
    while week < monday:
        decisions.append(
            {
                "id": new_id(),
                "weekStart": iso(midnight(week)),
                "planDecision": rng.choices(["keep", "adjust", "pause"], weights=[0.7, 0.22, 0.08])[0],
            }
        )
        week += timedelta(weeks=1)

    return plans, check_ins, decisions


# --------------------------------------------------------------------------- #
# Report
# --------------------------------------------------------------------------- #


def report(today: date, entries, goals, plans, check_ins) -> None:
    """Re-derives, in Python, what the app's own calculators will show — so a
    generated file that would look broken on screen fails here instead."""
    problems: list[str] = []

    by_substance: dict[str, list[Entry]] = {}
    for entry in entries:
        by_substance.setdefault(entry.substance.name, []).append(entry)

    print(f"Referenztag: {today} · {len(entries)} Einträge über {WEEKS_OF_HISTORY} Wochen")
    print()
    print("  Substanzen")
    for name, group in sorted(by_substance.items(), key=lambda item: -len(item[1])):
        days = {entry.day for entry in group}
        print(f"    {name:<13} {len(group):>4} Einträge · {len(days):>3} Tage · zuletzt {max(days)}")

    print()
    print("  Kalender je Monat (E1)")
    entry_days = {entry.day for entry in entries}
    first_day = min(entry_days)
    month = month_start(first_day)
    while month <= month_start(today):
        span_start = max(month, first_day)
        span_end = min(add_months(month, 1) - timedelta(days=1), today)
        elapsed = (span_end - span_start).days + 1
        logged = sum(1 for day in entry_days if month_start(day) == month)
        counted = sum(1 for entry in entries if month_start(entry.day) == month)
        print(
            f"    {month:%Y-%m}  {counted:>4} Einträge · "
            f"{logged} erfasste, {elapsed - logged} eintragsfreie Tage"
        )
        if elapsed >= 20 and elapsed - logged < 3:
            problems.append(f"{month:%B}: fast keine eintragsfreien Tage")
        month = add_months(month, 1)

    print()
    print("  Kontingent (Heute-Tab)")
    for goal in goals:
        if goal.goal_type != "reduction" or goal.valid_until is not None:
            continue
        used = len(
            {
                entry.day
                for entry in entries
                if entry.substance is goal.substance and month_start(entry.day) == month_start(today)
            }
        )
        print(f"    {goal.substance.name:<13} noch {goal.limit - used} von {goal.limit}")
        if used >= goal.limit:
            problems.append(f"{goal.substance.name}: Kontingent schon am {today.day}. aufgebraucht")

    print()
    print("  Ziel-Status (G4)")
    for substance in SUBSTANCES.values():
        periods = [goal for goal in goals if goal.substance is substance]
        current = [g for g in periods if g.valid_from <= today and (g.valid_until is None or g.valid_until > today)]
        if not periods:
            state = "kein Ziel"
        elif not current:
            state = "Pausiert"
        else:
            state = {"reduction": "Reduktion", "abstinence": "Abstinenz", "observe": "Nur beobachten"}[
                current[-1].goal_type
            ]
        print(f"    {substance.name:<13} {state}{'  (archiviert)' if substance.archived else ''}")

    print()
    print("  Ø Dosis Alkohol je Woche (Trend-Chart, letzte 8 mit Einträgen)")
    weekly: dict[date, list[int]] = {}
    for entry in entries:
        if entry.substance is not SUBSTANCES["alkohol"]:
            continue
        weekly.setdefault(entry.day - timedelta(days=entry.day.weekday()), []).append(entry.day)
    series = sorted(weekly.items())[-8:]
    for week, days in series:
        occasions = len(set(days))
        print(f"    {week}  Ø {len(days) / occasions:>4.1f} Getränke · {occasions} Gelegenheiten")
    if len(series) < 2:
        problems.append("Trend-Chart braucht mindestens zwei Wochen mit Einträgen")
    else:
        current = len(series[-1][1]) / len(set(series[-1][1]))
        previous = len(series[-2][1]) / len(set(series[-2][1]))
        arrow = "↓" if current < previous else ("↑" if current > previous else "→")
        print(f"    Karte zeigt: {current:.1f} Getränke  {arrow} von {previous:.1f}")
        if current > previous:
            problems.append("die jüngste Woche liegt über der vorigen — die Karte zeigt ↑")

    print()
    print("  Kontextverteilung Alkohol (E3)")
    counts: dict[str, int] = {}
    for entry in entries:
        if entry.substance is not SUBSTANCES["alkohol"]:
            continue
        for tag in entry.tags:
            counts[tag.name] = counts.get(tag.name, 0) + 1
    total = sum(counts.values())
    ranked = sorted(counts.items(), key=lambda item: -item[1])
    for name, count in ranked:
        print(f"    {name:<13} {count / total:>5.0%}")
    if ranked[0][1] / total < 0.5:
        problems.append(
            f"kein Kontext über 50 % ({ranked[0][0]} bei {ranked[0][1] / total:.0%}) — "
            "der „Plan dafür bauen?“-Vorschlag bleibt aus"
        )

    print()
    print("  Pläne (G1)")
    for plan in plans:
        tally = [c for c in check_ins if c.plan is plan]
        helped = sum(1 for c in tally if c.outcome == "helped")
        label = f"{helped}/{len(tally)} geholfen" if tally else "noch kein Check-in"
        print(f"    {plan.status:<9} „{plan.situation}“ · {label}")

    # PlanService.pendingCheckIns: an entry tagged with an *active* plan's situation
    # tag, on a logical day before today, with no check-in — one is intentional.
    answered = {check_in.entry.id for check_in in check_ins}
    active_tags = {plan.tag.id for plan in plans if plan.status == "active"}
    open_check_ins = [
        entry
        for entry in entries
        if entry.day < today
        and entry.id not in answered
        and active_tags & {tag.id for tag in entry.tags}
    ]
    print(f"    offene Check-ins beim Start: {len(open_check_ins)}")
    if len(open_check_ins) != 1:
        problems.append(f"{len(open_check_ins)} offene Check-ins statt genau einem")

    print()
    if problems:
        print("  ⚠︎ " + "\n  ⚠︎ ".join(problems))
    else:
        print("  Alle Prüfungen bestanden.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--today", type=date.fromisoformat, default=date.today())
    parser.add_argument("--now-hour", type=int, default=14)
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "examples" / "klar-beispieldaten.json",
    )
    args = parser.parse_args()

    payload, entries, goals, plans, check_ins = build(args.today, args.now_hour)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

    report(args.today, entries, goals, plans, check_ins)
    print()
    print(f"Geschrieben: {args.out} ({args.out.stat().st_size / 1024:.0f} kB)")


if __name__ == "__main__":
    main()
