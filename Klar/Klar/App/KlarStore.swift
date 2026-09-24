import Foundation
import SwiftData
import KlarCore

/// Single write path into SwiftData, and the bridge to the pure calculators in `KlarCore`.
///
/// Views read lists with `@Query` (SwiftData keeps those live), but every mutation and every
/// derived number goes through here — so the quota rules and the logical-day boundary live in
/// exactly one place.
@MainActor
struct KlarStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Fetching

    func allSubstances(includeArchived: Bool = false) -> [Substance] {
        let all = (try? context.fetch(FetchDescriptor<Substance>())) ?? []
        return all
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func allEntries() -> [Entry] {
        (try? context.fetch(FetchDescriptor<Entry>())) ?? []
    }

    func allContextTags() -> [ContextTag] {
        let all = (try? context.fetch(FetchDescriptor<ContextTag>())) ?? []
        return all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func allGoalPeriods() -> [GoalPeriod] {
        (try? context.fetch(FetchDescriptor<GoalPeriod>())) ?? []
    }

    func substitutionActions() -> [SubstitutionAction] {
        let all = (try? context.fetch(FetchDescriptor<SubstitutionAction>())) ?? []
        return all.sorted { $0.sortOrder < $1.sortOrder }
    }

    func latestWhyNote() -> WhyNote? {
        let all = (try? context.fetch(FetchDescriptor<WhyNote>())) ?? []
        return all.max { $0.createdAt < $1.createdAt }
    }

    // MARK: - Entries

    /// Entries whose *logical* day equals that of the wall-clock instant `date`.
    ///
    /// Pass a real moment (`Date()`, an entry's timestamp). Passing an already-normalized logical
    /// day would apply the 05:00 cutoff a second time and land on the day before — use
    /// `entries(onLogicalDay:)` for those.
    func entries(onLogicalDayOf date: Date) -> [Entry] {
        entries(onLogicalDay: KlarDate.logicalDay(for: date))
    }

    /// Entries on `day`, which must already be a normalized logical day (`KlarDate.logicalDay`) —
    /// the form the calendar grid and `loggedDays` deal in.
    func entries(onLogicalDay day: Date) -> [Entry] {
        allEntries()
            .filter { KlarDate.logicalDay(for: $0.timestamp, timezoneID: $0.timezoneID) == day }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// The set of logical days in `month` that carry at least one entry — the calendar dots (E1).
    ///
    /// `date` is a month anchor from the calendar grid, so its calendar month is taken as given.
    /// Reading it through `monthComponents` instead would push a 00:00 anchor on the 1st back into
    /// the previous month, and the dots would then describe a different month than the grid drew.
    func loggedDays(inMonthOf date: Date) -> Set<Date> {
        let anchor = KlarDate.calendar.dateComponents([.year, .month], from: date)
        guard let year = anchor.year, let month = anchor.month else { return [] }
        var days: Set<Date> = []
        for entry in allEntries() {
            let day = KlarDate.logicalDay(for: entry.timestamp, timezoneID: entry.timezoneID)
            let components = KlarDate.calendar.dateComponents([.year, .month], from: day)
            if components.year == year && components.month == month {
                days.insert(day)
            }
        }
        return days
    }

    @discardableResult
    func addEntry(
        substance: Substance?,
        timestamp: Date = Date(),
        amount: Decimal? = nil,
        contextTags: [ContextTag] = [],
        mood: Int? = nil,
        note: String? = nil
    ) -> Entry {
        let entry = Entry(
            substance: substance,
            timestamp: timestamp,
            timezoneID: KlarDate.timezoneID,
            amount: amount,
            contextTags: contextTags.isEmpty ? nil : contextTags,
            mood: mood,
            note: note
        )
        context.insert(entry)
        save()
        return entry
    }

    func updateEntry(
        _ entry: Entry,
        timestamp: Date? = nil,
        amount: Decimal?? = nil,
        contextTags: [ContextTag]? = nil,
        mood: Int?? = nil,
        note: String?? = nil
    ) {
        if let timestamp { entry.timestamp = timestamp }
        if let amount { entry.amount = amount }
        if let contextTags { entry.contextTags = contextTags.isEmpty ? nil : contextTags }
        if let mood { entry.mood = mood }
        if let note { entry.note = note }
        entry.editedAt = Date()
        save()
    }

    func deleteEntry(_ entry: Entry) {
        context.delete(entry)
        save()
    }

    // MARK: - Substances

    @discardableResult
    func addSubstance(name: String, unit: SubstanceUnit) -> Substance {
        let existing = allSubstances(includeArchived: true)
        let substance = Substance(
            name: name,
            unit: unit,
            colorIndex: existing.count,
            sortOrder: existing.count,
            asksMorningAfter: SubstanceCatalog.asksMorningAfterByDefault(name)
        )
        context.insert(substance)
        save()
        return substance
    }

    func archiveSubstance(_ substance: Substance) {
        substance.isArchived = true
        save()
    }

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
        // A day-after pattern for a substance the user switched off is noise, not a feature —
        // they said this one is not about the day after (coffee, nicotine). The records stay and
        // the pattern comes back if the substance is switched on again.
        guard substance.asksMorningAfter else { return nil }
        return MorningAfterService.pattern(
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

    // MARK: - Goals
    //
    // Goals are *versioned*, never edited in place: changing a goal closes the current period
    // (`validUntil = now`) and opens a new one. Historic months therefore keep the limit that
    // was actually in force at the time, which is what `QuotaCalculator` reads.

    func currentGoal(for substance: Substance) -> GoalPeriod? {
        let now = Date()
        return allGoalPeriods()
            .filter { $0.substance?.id == substance.id }
            .filter { $0.validFrom <= now && ($0.validUntil == nil || $0.validUntil! > now) }
            .max { $0.validFrom < $1.validFrom }
    }

    /// True when the substance once had a goal but none is currently in force (G4 "Pausiert").
    func isGoalPaused(for substance: Substance) -> Bool {
        guard currentGoal(for: substance) == nil else { return false }
        return allGoalPeriods().contains { $0.substance?.id == substance.id }
    }

    /// Goal periods are anchored to month boundaries, never to the wall-clock moment of the edit.
    ///
    /// `QuotaCalculator` picks the period that was in force *at the start of the month* it is
    /// asked about. A period stamped `validFrom = now` would therefore not apply to the very
    /// month it was created in — a user who onboards on the 14th would see no quota at all until
    /// the 1st. Closing the old period at the same boundary keeps past months resolving to the
    /// limit that actually applied to them.
    func setGoal(for substance: Substance, type: GoalType, monthlyLimit: Int?) {
        let monthStart = KlarDate.startOfMonth()

        if let current = currentGoal(for: substance) {
            guard current.type != type || current.monthlyLimit != monthlyLimit else { return }
            current.validUntil = monthStart
        }

        context.insert(
            GoalPeriod(
                substance: substance,
                type: type,
                monthlyLimit: type == .reduction ? monthlyLimit : nil,
                validFrom: monthStart,
                validUntil: nil
            )
        )
        save()
    }

    /// Ends the current goal period without opening a new one. Closed at the month boundary for
    /// the same reason `setGoal` opens there — so the "Pausiert" badge and the (now absent)
    /// quota card agree with each other from the moment the user taps.
    func pauseGoal(for substance: Substance) {
        guard let current = currentGoal(for: substance) else { return }
        current.validUntil = KlarDate.startOfMonth()
        save()
    }

    func quota(for substance: Substance, on date: Date = Date()) -> QuotaResult {
        let (year, month) = KlarDate.monthComponents(for: date)
        return QuotaCalculator.quota(
            entries: allEntries().map { $0.toDTO() },
            substanceID: substance.id,
            goalPeriods: allGoalPeriods().map { $0.toDTO() },
            year: year,
            month: month,
            timezoneID: KlarDate.timezoneID
        )
    }

    func stats(for substance: Substance, referenceDate: Date = Date()) -> StatsSummary {
        StatsCalculator.summary(
            entries: allEntries().map { $0.toDTO() },
            substanceID: substance.id,
            referenceDate: referenceDate,
            referenceTimezoneID: KlarDate.timezoneID
        )
    }

    /// Every substance the Today screen shows a quota for: all active reduction goals, the
    /// tightest remaining allowance first. Abstinence and observe-only goals have no quota card.
    ///
    /// Ties resolve by `sortOrder` so the list never reshuffles arbitrarily between renders.
    func quotaSubstances(on date: Date = Date()) -> [SubstanceQuota] {
        allSubstances()
            .compactMap { substance -> SubstanceQuota? in
                let result = quota(for: substance, on: date)
                guard result.goalType == .reduction, result.limit != nil else { return nil }
                return SubstanceQuota(substance: substance, quota: result)
            }
            .sorted {
                let lhs = $0.quota.remaining ?? .max
                let rhs = $1.quota.remaining ?? .max
                if lhs != rhs { return lhs < rhs }
                return $0.substance.sortOrder < $1.substance.sortOrder
            }
    }

    /// The single substance surfaces with room for only one quota (weekly review) lead with:
    /// the one with the tightest remaining allowance.
    func primaryQuotaSubstance() -> Substance? {
        quotaSubstances().first?.substance
    }

    // MARK: - Substitution actions

    @discardableResult
    func addSubstitutionAction(text: String) -> SubstitutionAction {
        let action = SubstitutionAction(text: text, sortOrder: substitutionActions().count)
        context.insert(action)
        save()
        return action
    }

    func deleteSubstitutionAction(_ action: SubstitutionAction) {
        context.delete(action)
        renumberSubstitutionActions()
    }

    /// Reorders and renumbers. Written out by hand rather than using SwiftUI's
    /// `Array.move(fromOffsets:toOffset:)` so the store stays free of a SwiftUI dependency.
    func moveSubstitutionActions(from source: IndexSet, to destination: Int) {
        var actions = substitutionActions()
        let moved = source.sorted().map { actions[$0] }
        // Remove from the back so the earlier indices stay valid.
        for index in source.sorted(by: >) {
            actions.remove(at: index)
        }
        // `destination` refers to the pre-removal array, so shift it by however many of the
        // moved items sat before it.
        let insertionIndex = destination - source.filter { $0 < destination }.count
        actions.insert(contentsOf: moved, at: max(0, min(insertionIndex, actions.count)))

        for (index, action) in actions.enumerated() {
            action.sortOrder = index
        }
        save()
    }

    private func renumberSubstitutionActions() {
        for (index, action) in substitutionActions().enumerated() {
            action.sortOrder = index
        }
        save()
    }

    // MARK: - Why notes

    func setWhyNote(_ text: String) {
        context.insert(WhyNote(text: text))
        save()
    }

    // MARK: - Context tags

    @discardableResult
    func addContextTag(name: String) -> ContextTag {
        let tag = ContextTag(name: name, isBuiltIn: false)
        context.insert(tag)
        save()
        return tag
    }

    // MARK: - Saving

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // A failed save means the write is lost, and silently dropping a user's entry is the
            // worst possible failure for a trust-first app. Surface it loudly in debug; in release
            // the context keeps the change in memory and the next save can still succeed.
            assertionFailure("KlarStore save failed: \(error)")
        }
    }
}

/// One row of the Today screen's quota list: a substance and its month-to-date quota.
struct SubstanceQuota: Identifiable {
    let substance: Substance
    let quota: QuotaResult

    var id: UUID { substance.id }
}
