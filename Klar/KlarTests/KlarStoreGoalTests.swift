import XCTest
import SwiftData
import KlarCore
@testable import Klar

@MainActor
final class KlarStoreGoalTests: XCTestCase {

    private func makeStore() -> KlarStore {
        KlarStore(context: TestModelContainer.makeInMemoryContext())
    }

    /// Regression: `setGoal` used to stamp `validFrom = Date()`. `QuotaCalculator` resolves a
    /// month's goal by asking which period was in force *at the start of that month*, so a goal
    /// created on the 14th silently did not apply until the 1st of the next month — a user who
    /// finished onboarding mid-month saw no quota card at all on „Heute".
    func testGoalSetMidMonthAppliesToTheCurrentMonth() {
        let store = makeStore()
        let substance = store.addSubstance(name: "Alkohol", unit: .drink)

        store.setGoal(for: substance, type: .reduction, monthlyLimit: 4)

        let quota = store.quota(for: substance)
        XCTAssertEqual(quota.goalType, .reduction)
        XCTAssertEqual(quota.limit, 4)
        XCTAssertEqual(quota.remaining, 4)
        XCTAssertNotNil(
            store.primaryQuotaSubstance(),
            "Today must be able to lead with the substance the user just set a limit for."
        )
    }

    func testLoggingAnEntryDrainsTheRemainingQuota() {
        let store = makeStore()
        let substance = store.addSubstance(name: "Alkohol", unit: .drink)
        store.setGoal(for: substance, type: .reduction, monthlyLimit: 4)

        store.addEntry(substance: substance)

        let quota = store.quota(for: substance)
        XCTAssertEqual(quota.occasions, 1)
        XCTAssertEqual(quota.remaining, 3)
    }

    /// Editing a goal must not retroactively rewrite whether a past month was met.
    func testChangingAGoalVersionsItRatherThanOverwriting() {
        let store = makeStore()
        let substance = store.addSubstance(name: "Alkohol", unit: .drink)

        store.setGoal(for: substance, type: .reduction, monthlyLimit: 4)
        store.setGoal(for: substance, type: .reduction, monthlyLimit: 6)

        XCTAssertEqual(store.currentGoal(for: substance)?.monthlyLimit, 6)
        XCTAssertEqual(store.quota(for: substance).limit, 6)
        XCTAssertEqual(
            store.allGoalPeriods().count, 2,
            "The superseded period must survive so past months keep the limit that applied then."
        )
    }

    func testPausingAGoalRemovesTheQuotaAndReportsPaused() {
        let store = makeStore()
        let substance = store.addSubstance(name: "Alkohol", unit: .drink)
        store.setGoal(for: substance, type: .reduction, monthlyLimit: 4)

        store.pauseGoal(for: substance)

        XCTAssertTrue(store.isGoalPaused(for: substance))
        XCTAssertNil(store.currentGoal(for: substance))
        XCTAssertNil(
            store.quota(for: substance).limit,
            "The „Pausiert“ badge and the quota card must agree from the moment the user taps."
        )
    }

    func testObserveGoalHasNoQuotaCard() {
        let store = makeStore()
        let substance = store.addSubstance(name: "MDMA", unit: .mg)

        store.setGoal(for: substance, type: .observe, monthlyLimit: nil)

        XCTAssertEqual(store.quota(for: substance).goalType, .observe)
        XCTAssertNil(store.quota(for: substance).limit)
        XCTAssertNil(store.primaryQuotaSubstance())
    }
}
