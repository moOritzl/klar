import XCTest
import KlarCore
@testable import Klar

@MainActor
final class SubstanceSubtitleTests: XCTestCase {
    private func makeStore() -> KlarStore {
        KlarStore(context: TestModelContainer.makeInMemoryContext())
    }

    func testReductionShowsTheLimitAndTheMorningSwitch() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.setGoal(for: alcohol, type: .reduction, monthlyLimit: 4)
        XCTAssertEqual(SubstancesView.subtitle(for: alcohol, store: store), "max. 4 / Monat · Morgen danach")
    }

    func testNoGoalReadsAsObservingAndNicotineDoesNotAsk() {
        let store = makeStore()
        let nicotine = store.addSubstance(name: "Nikotin", unit: .piece)
        XCTAssertEqual(SubstancesView.subtitle(for: nicotine, store: store), "Beobachten")
    }

    func testAPausedGoalSaysSo() {
        let store = makeStore()
        let alcohol = store.addSubstance(name: "Alkohol", unit: .drink)
        store.setGoal(for: alcohol, type: .abstinence, monthlyLimit: nil)
        store.pauseGoal(for: alcohol)
        XCTAssertEqual(SubstancesView.subtitle(for: alcohol, store: store), "Pausiert · Morgen danach")
    }
}
