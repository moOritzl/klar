import Foundation
import SwiftData
import KlarCore

/// Single write path into SwiftData, and the bridge to the pure calculators in `KlarCore`.
///
/// Views read lists with `@Query` (SwiftData keeps those live), but every mutation and every
/// derived number goes through here — so the quota rules, the plan-versioning rules and the
/// logical-day boundary live in exactly one place.
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

    func allPlans() -> [Plan] {
        (try? context.fetch(FetchDescriptor<Plan>())) ?? []
    }

    func activePlans() -> [Plan] {
        allPlans()
            .filter { $0.status == .active }
            .sorted { $0.committedAt < $1.committedAt }
    }

    func allCheckIns() -> [PlanCheckIn] {
        (try? context.fetch(FetchDescriptor<PlanCheckIn>())) ?? []
    }

    func substitutionActions() -> [SubstitutionAction] {
        let all = (try? context.fetch(FetchDescriptor<SubstitutionAction>())) ?? []
        return all.sorted { $0.sortOrder < $1.sortOrder }
    }

    func latestWhyNote() -> WhyNote? {
        let all = (try? context.fetch(FetchDescriptor<WhyNote>())) ?? []
        return all.max { $0.createdAt < $1.createdAt }
    }

    func reviewDecisions() -> [ReviewDecision] {
        let all = (try? context.fetch(FetchDescriptor<ReviewDecision>())) ?? []
        return all.sorted { $0.weekStart > $1.weekStart }
    }

    // MARK: - Entries

    /// Entries whose *logical* day equals that of `date`.
    func entries(onLogicalDayOf date: Date) -> [Entry] {
        let target = KlarDate.logicalDay(for: date)
        return allEntries()
            .filter { KlarDate.logicalDay(for: $0.timestamp, timezoneID: $0.timezoneID) == target }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// The set of logical days in `month` that carry at least one entry — the calendar dots (E1).
    func loggedDays(inMonthOf date: Date) -> Set<Date> {
        let (year, month) = KlarDate.monthComponents(for: date)
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
        // Check-ins reference the entry that triggered them; drop them with it so the
        // check-in flow can't resurface an entry that no longer exists.
        for checkIn in allCheckIns() where checkIn.entry?.id == entry.id {
            context.delete(checkIn)
        }
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
            sortOrder: existing.count
        )
        context.insert(substance)
        save()
        return substance
    }

    func archiveSubstance(_ substance: Substance) {
        substance.isArchived = true
        save()
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

    // MARK: - Plans

    /// Creates a new plan, or a new *version* of an existing one (archiving the predecessor and
    /// pointing `supersededBy` at the replacement). Throws when the 3-active-plan cap is hit.
    func commitPlan(
        replacing existing: Plan?,
        situationTag: ContextTag?,
        situationText: String,
        actionText: String
    ) throws {
        let (updatedOld, newPlanDTO) = try PlanService.createVersion(
            of: existing?.toDTO(),
            situationTagID: situationTag?.id,
            situationText: situationText,
            actionText: actionText,
            existingPlans: allPlans().map { $0.toDTO() }
        )

        if let updatedOld, let existing {
            existing.status = updatedOld.status
            existing.supersededBy = updatedOld.supersededBy
        }

        context.insert(
            Plan(
                id: newPlanDTO.id,
                situationTag: situationTag,
                situationText: situationText,
                actionText: actionText,
                committedAt: newPlanDTO.committedAt,
                status: newPlanDTO.status
            )
        )
        save()
    }

    func setPlanStatus(_ plan: Plan, _ status: PlanStatus) {
        plan.status = status
        save()
    }

    /// The oldest un-answered check-in: an entry tagged with an active plan's situation tag,
    /// logged on a logical day *before* today. Never the same day — "einen Tag später ist
    /// Reflexion Auswertung, nicht Konfrontation".
    func pendingCheckIn(now: Date = Date()) -> (plan: Plan, entry: Entry)? {
        let plans = allPlans()
        let entries = allEntries()

        let pending = PlanService.pendingCheckIns(
            entries: entries.map { $0.toDTO() },
            plans: plans.map { $0.toDTO() },
            existingCheckIns: allCheckIns().map { $0.toDTO() },
            now: now,
            nowTimezoneID: KlarDate.timezoneID
        )

        guard let first = pending.min(by: { $0.entry.timestamp < $1.entry.timestamp }),
              let plan = plans.first(where: { $0.id == first.plan.id }),
              let entry = entries.first(where: { $0.id == first.entry.id })
        else { return nil }

        return (plan, entry)
    }

    func recordCheckIn(plan: Plan, entry: Entry, outcome: CheckInOutcome) {
        context.insert(PlanCheckIn(plan: plan, entry: entry, date: Date(), outcome: outcome))
        save()
    }

    /// "3/3 geholfen" — helped vs. total check-ins for a plan, optionally scoped to one week.
    func checkInTally(for plan: Plan, weekStart: Date? = nil) -> (helped: Int, total: Int) {
        var checkIns = allCheckIns().filter { $0.plan?.id == plan.id }
        if let weekStart {
            let weekEnd = KlarDate.calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            checkIns = checkIns.filter { $0.date >= weekStart && $0.date < weekEnd }
        }
        // `.adjusted` means the user reworked the plan rather than judging it — it counts
        // toward the total but not as a success.
        let helped = checkIns.filter { $0.outcome == .helped }.count
        return (helped, checkIns.count)
    }

    // MARK: - Plan suggestion (G2)

    /// The design's empty-plans state proposes a plan built from a real pattern: the context tag
    /// that carries the largest share of the user's entries. Below `minimumEntries` we stay quiet —
    /// "ein guter Plan braucht Kenntnis der eigenen Muster".
    func suggestedSituationTag(minimumEntries: Int = 3) -> (tag: ContextTag, share: Double)? {
        let entries = allEntries()
        guard entries.count >= minimumEntries else { return nil }

        var counts: [UUID: Int] = [:]
        var tagged = 0
        for entry in entries {
            guard let tags = entry.contextTags, !tags.isEmpty else { continue }
            tagged += 1
            for tag in tags { counts[tag.id, default: 0] += 1 }
        }
        guard tagged >= minimumEntries else { return nil }

        // Don't propose a tag that an active plan already covers.
        let covered = Set(activePlans().compactMap { $0.situationTag?.id })
        guard let best = counts
            .filter({ !covered.contains($0.key) })
            .max(by: { $0.value < $1.value })
        else { return nil }

        guard let tag = allContextTags().first(where: { $0.id == best.key }) else { return nil }
        return (tag, Double(best.value) / Double(tagged))
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

    // MARK: - Weekly review

    func recordReviewDecision(weekStart: Date, decision: ReviewPlanDecision) {
        let existing = reviewDecisions().first { KlarDate.weekStart(for: $0.weekStart) == weekStart }
        if let existing {
            existing.planDecision = decision
        } else {
            context.insert(ReviewDecision(weekStart: weekStart, planDecision: decision))
        }
        save()
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
