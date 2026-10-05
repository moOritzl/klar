import XCTest
@testable import Klar

/// `MainTabView.shouldPresentMorning` is the pure guard behind `presentDueMorning()` — pulled out
/// so the app-lock and entry-sheet interlocks are testable without driving `AppLockManager`'s
/// Face ID plumbing or a real `TabView`.
final class MainTabViewMorningGuardTests: XCTestCase {
    func testDoesNotPresentWhileLocked() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: true, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-20", lastPresentedKey: nil
        ))
    }

    func testPresentsWhenUnlockedAndADayIsDue() {
        XCTAssertTrue(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-20", lastPresentedKey: nil
        ))
    }

    func testDoesNotPresentWithNoDueDay() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: nil, lastPresentedKey: nil
        ))
    }

    func testDoesNotPresentWhileTheEntrySheetIsOpen() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: true, dueMorning: nil, dueKey: "2026-09-20", lastPresentedKey: nil
        ))
    }

    func testDoesNotReplaceACardAlreadyOnScreen() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false,
            dueMorning: DueMorning(dayKey: "2026-09-19"), dueKey: "2026-09-20", lastPresentedKey: nil
        ))
    }

    /// Locked wins even when everything else says "present" — the whole point of the guard.
    func testLockedWinsOverAnOtherwiseDueDay() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: true, isEntrySheetPresented: false,
            dueMorning: nil, dueKey: "2026-09-20", lastPresentedKey: nil
        ))
    }

    /// The card pops up by itself once per day; after „Später" it waits in „Offen".
    func testDoesNotPresentTheSameDayTwice() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-20", lastPresentedKey: "2026-09-20"
        ))
    }

    func testPresentsANewDayAfterAnOlderOneWasShown() {
        XCTAssertTrue(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-20", lastPresentedKey: "2026-09-19"
        ))
    }

    /// If the newer day's entries are deleted, an older day that already popped up becomes due
    /// again — it must not pop up a second time.
    func testDoesNotPresentAnOlderDayAgain() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-19", lastPresentedKey: "2026-09-20"
        ))
    }
}
