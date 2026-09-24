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
        for substance in [coffee, alcohol, nicotine] {
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
            }
            if dayOffset % 4 == 0 {
                insertEntry(nicotine, day: day, hour: 20, tag: allein)
                entryCount += 1
            }
        }

        // Answer most past alcohol evenings, so Übersicht and the entry sheet have a pattern.
        // The newest one is left unanswered on purpose, to exercise the "never asked about an
        // older day once it's no longer the newest" path — it is ~8 days old here, past the 48 h
        // expiry, so no card shows on launch. Launch with --klar-uitest-seed-yesterday to see one.
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

        try context.save()
    }
}
