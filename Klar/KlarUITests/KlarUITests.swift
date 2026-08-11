//
//  KlarUITests.swift
//  KlarUITests
//
//  Created by Moritz Lenhard on 13.07.26.
//

import XCTest

final class KlarUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Start from a clean install: no completed onboarding, no store.
        app.launchArguments = ["--klar-uitest-reset"]
        app.launch()
        return app
    }

    /// The core loop end to end: onboarding (A1–A4) → Heute (B2) → log an entry (C1/C2).
    /// If this passes, the app's spine is wired: settings gate, SwiftData writes, quota read-back.
    @MainActor
    func testOnboardingThenLogFirstEntry() throws {
        let app = launchFreshApp()

        // A1 · Privatsphäre. The simulator has no Face ID enrolled, so the step offers a plain
        // "Weiter"; on a device with biometrics it would offer "Später einrichten".
        let privacyHeadline = app.staticTexts["Alles bleibt auf deinem Gerät."]
        XCTAssertTrue(privacyHeadline.waitForExistence(timeout: 15))

        let skipLock = app.buttons["Später einrichten"]
        if skipLock.waitForExistence(timeout: 2) {
            skipLock.tap()
        } else {
            app.buttons["Weiter"].tap()
        }

        // A2 · Substanzauswahl.
        XCTAssertTrue(app.staticTexts["Was möchtest du erfassen?"].waitForExistence(timeout: 5))
        app.buttons["Alkohol"].tap()
        app.buttons["Weiter"].tap()

        // A3 · Ziel je Substanz.
        XCTAssertTrue(app.staticTexts["Was ist dein Ziel?"].waitForExistence(timeout: 5))
        app.buttons["Weiter"].tap()

        // A4 · Ersatzhandlungen.
        XCTAssertTrue(app.staticTexts["Was hilft dir im Moment?"].waitForExistence(timeout: 5))
        app.buttons["App öffnen"].tap()

        // B2 · Heute, empty day.
        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Ein ruhiger Tag."].exists,
            "A day with no entries must read as a calm baseline, not as a gap to fill."
        )

        // C1 · Two taps to "gespeichert".
        app.buttons["Eintrag erfassen"].tap()
        XCTAssertTrue(app.staticTexts["Neuer Eintrag"].waitForExistence(timeout: 5))
        app.buttons["Alkohol"].tap()

        // C2 · Saved, details optional.
        XCTAssertTrue(app.staticTexts["Gespeichert."].waitForExistence(timeout: 5))
        app.buttons["Fertig"].tap()

        // The entry is on Heute, and the calm-day copy is gone.
        XCTAssertTrue(app.staticTexts["today.loggedSection"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Ein ruhiger Tag."].exists)
    }

    /// The four tabs are reachable and each renders its own screen.
    @MainActor
    func testTabsAreReachableAfterOnboarding() throws {
        let app = launchFreshApp()

        // Fast-path through onboarding.
        XCTAssertTrue(app.staticTexts["Alles bleibt auf deinem Gerät."].waitForExistence(timeout: 15))
        let skipLock = app.buttons["Später einrichten"]
        if skipLock.waitForExistence(timeout: 2) {
            skipLock.tap()
        } else {
            app.buttons["Weiter"].tap()
        }
        XCTAssertTrue(app.staticTexts["Was möchtest du erfassen?"].waitForExistence(timeout: 5))
        app.buttons["Alkohol"].tap()
        app.buttons["Weiter"].tap()
        app.buttons["Weiter"].tap()
        app.buttons["App öffnen"].tap()

        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.buttons["Kalender"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Pläne"].tap()
        XCTAssertTrue(app.staticTexts["Noch kein Plan."].waitForExistence(timeout: 5))

        app.tabBars.buttons["Hilfe"].tap()
        XCTAssertTrue(app.buttons["help.sos"].waitForExistence(timeout: 5))
    }
}
