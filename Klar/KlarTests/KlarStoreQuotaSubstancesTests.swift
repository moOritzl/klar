import XCTest
import SwiftData
import KlarCore
@testable import Klar

/// B1 must show *every* substance that carries a reduction limit — not just the tightest one.
/// `quotaSubstances()` is the single source for that list and its order.
@MainActor
final class KlarStoreQuotaSubstancesTests: XCTestCase {

    private func makeStore() -> KlarStore {
        KlarStore(context: TestModelContainer.makeInMemoryContext())
    }

    func testQuotaSubstancesListsEveryReductionLimitTightestFirst() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let coffee = store.addSubstance(name: "Kaffee", unit: .drink)
        let nicotine = store.addSubstance(name: "Nikotin", unit: .piece)

        store.setGoal(for: alcohol, type: .reduction, monthlyLimit: 4)
        store.setGoal(for: coffee, type: .reduction, monthlyLimit: 20)
        store.setGoal(for: nicotine, type: .reduction, monthlyLimit: 10)

        let quotas = store.quotaSubstances()

        XCTAssertEqual(
            quotas.map(\.substance.name), ["Alkohol", "Nikotin", "Kaffee"],
            "All substances with a limit must appear, tightest remaining first."
        )
        XCTAssertEqual(quotas.map(\.quota.limit), [4, 10, 20])
    }

    func testLoggingKeepsTheListCompleteAndReordersByRemaining() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let nicotine = store.addSubstance(name: "Nikotin", unit: .piece)
        store.setGoal(for: alcohol, type: .reduction, monthlyLimit: 10)
        store.setGoal(for: nicotine, type: .reduction, monthlyLimit: 8)

        store.addEntry(substance: nicotine)

        let quotas = store.quotaSubstances()
        XCTAssertEqual(quotas.map(\.substance.name), ["Nikotin", "Alkohol"])
        XCTAssertEqual(quotas.first?.quota.remaining, 7)
    }

    func testQuotaSubstancesSkipsObserveAbstinenceAndPausedGoals() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        let coffee = store.addSubstance(name: "Kaffee", unit: .drink)
        let mdma = store.addSubstance(name: "MDMA", unit: .mg)
        let nicotine = store.addSubstance(name: "Nikotin", unit: .piece)

        store.setGoal(for: alcohol, type: .reduction, monthlyLimit: 4)
        store.setGoal(for: coffee, type: .observe, monthlyLimit: nil)
        store.setGoal(for: mdma, type: .abstinence, monthlyLimit: nil)
        store.setGoal(for: nicotine, type: .reduction, monthlyLimit: 10)
        store.pauseGoal(for: nicotine)

        XCTAssertEqual(store.quotaSubstances().map(\.substance.name), ["Alkohol"])
    }
}
