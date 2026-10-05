import Foundation
import SwiftData
import KlarCore

enum DemoDataSeeder {
    static func seed(context: ModelContext) throws {
        try ContextTagSeeder.seedIfNeeded(context: context)

        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!

        let coffee = Substance(name: "Kaffee", unit: .drink, colorIndex: 0, costPerUnit: Decimal(string: "3.00"), sortOrder: 0, asksMorningAfter: false)
        let alcohol = Substance(name: "Alkohol", unit: .drink, colorIndex: 1, costPerUnit: Decimal(string: "5.00"), sortOrder: 1)
        let nicotine = Substance(name: "Nikotin", unit: .piece, colorIndex: 2, sortOrder: 2, asksMorningAfter: false)
        let cannabis = Substance(name: "Cannabis", unit: .g, colorIndex: 3, costPerUnit: Decimal(string: "10.00"), sortOrder: 3)
        for substance in [coffee, alcohol, nicotine, cannabis] {
            context.insert(substance)
        }

        let tags = try context.fetch(FetchDescriptor<ContextTag>())
        let zuhause = tags.first { $0.name == "Zuhause" }
        let allein = tags.first { $0.name == "Allein" }
        let club = tags.first { $0.name == "Club" }

        let periodStart = calendar.date(byAdding: .month, value: -3, to: now)!

        // Goal change mid-period: alcohol limit tightened 6 weeks ago.
        let changeDate = calendar.date(byAdding: .weekOfYear, value: -6, to: now)!
        context.insert(GoalPeriod(substance: alcohol, type: .reduction, monthlyLimit: 10, validFrom: periodStart, validUntil: changeDate))
        context.insert(GoalPeriod(substance: alcohol, type: .reduction, monthlyLimit: 6, validFrom: changeDate, validUntil: nil))
        context.insert(GoalPeriod(substance: coffee, type: .observe, monthlyLimit: nil, validFrom: periodStart, validUntil: nil))

        func insertEntry(_ substance: Substance, day: Date, hour: Int, minute: Int = 0, tag: ContextTag?) {
            let timestamp = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            context.insert(Entry(
                substance: substance,
                timestamp: timestamp,
                timezoneID: "Europe/Berlin",
                amount: 1,
                contextTags: tag.map { [$0] }
            ))
        }

        var entryCount = 0
        var dayOffset = 0
        while entryCount < 40 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now), day >= periodStart else { break }
            dayOffset += 1

            if dayOffset % 2 == 0 {
                insertEntry(coffee, day: day, hour: 8, tag: zuhause)
                entryCount += 1
            }
            if dayOffset % 9 == 0 {
                // Night session crossing midnight: two entries, one logical day.
                insertEntry(alcohol, day: day, hour: 23, minute: 30, tag: club)
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: day) {
                    insertEntry(alcohol, day: nextDay, hour: 1, minute: 15, tag: club)
                }
                entryCount += 2
                if dayOffset % 18 == 0 {
                    // Some club nights are mixed — the Muster tab names those days.
                    insertEntry(cannabis, day: day, hour: 23, minute: 45, tag: club)
                    entryCount += 1
                }
            }
            if dayOffset % 4 == 0 {
                insertEntry(nicotine, day: day, hour: 20, tag: allein)
                entryCount += 1
            }
            if dayOffset % 7 == 0 {
                insertEntry(cannabis, day: day, hour: 21, tag: zuhause)
                entryCount += 1
            }
        }

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
        // Muster all have a pattern. The newest regretted days carry a written reflection — six back, because some
        // of the newest answered days are cannabis-only and the alcohol view needs its own.
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
            let reflects = regretted && index >= answered.count - 6
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

        try context.save()
    }
}
