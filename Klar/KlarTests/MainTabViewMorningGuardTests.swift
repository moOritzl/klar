import XCTest
@testable import Klar

/// `MainTabView.shouldPresentMorning` is the pure guard behind `presentDueMorning()` — pulled out
/// so the app-lock and entry-sheet interlocks are testable without driving `AppLockManager`'s
/// Face ID plumbing or a real `TabView`.
final class MainTabViewMorningGuardTests: XCTestCase {
    func testDoesNotPresentWhileLocked() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: true, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-20"
        ))
    }

    func testPresentsWhenUnlockedAndADayIsDue() {
        XCTAssertTrue(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: "2026-09-20"
        ))
    }

    func testDoesNotPresentWithNoDueDay() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false, dueMorning: nil, dueKey: nil
        ))
    }

    func testDoesNotPresentWhileTheEntrySheetIsOpen() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: true, dueMorning: nil, dueKey: "2026-09-20"
        ))
    }

    func testDoesNotReplaceACardAlreadyOnScreen() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: false, isEntrySheetPresented: false,
            dueMorning: DueMorning(dayKey: "2026-09-19"), dueKey: "2026-09-20"
        ))
    }

    /// Locked wins even when everything else says "present" — the whole point of the guard.
    func testLockedWinsOverAnOtherwiseDueDay() {
        XCTAssertFalse(MainTabView.shouldPresentMorning(
            isLocked: true, isEntrySheetPresented: false,
            dueMorning: nil, dueKey: "2026-09-20"
        ))
    }
}
