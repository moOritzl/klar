import XCTest

/// Walks the app and attaches a screenshot of each screen to the result bundle.
///
/// This is a design-fidelity check, not an assertion suite: it exists so the implemented screens
/// can be put side by side with the draft in `Klar App Draft.dc.html`.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--klar-uitest-reset"]
        app.launch()

        // A1 · Privatsphäre
        XCTAssertTrue(app.staticTexts["Alles bleibt auf deinem Gerät."].waitForExistence(timeout: 15))
        capture(app, "A1-Privatsphaere")

        let skipLock = app.buttons["Später einrichten"]
        if skipLock.waitForExistence(timeout: 2) { skipLock.tap() } else { app.buttons["Weiter"].tap() }

        // A2 · Substanzauswahl
        XCTAssertTrue(app.staticTexts["Was möchtest du erfassen?"].waitForExistence(timeout: 5))
        app.buttons["Alkohol"].tap()
        app.buttons["MDMA"].tap()
        capture(app, "A2-Substanzauswahl")
        app.buttons["Weiter"].tap()

        // A3 · Ziel je Substanz
        XCTAssertTrue(app.staticTexts["Was ist dein Ziel?"].waitForExistence(timeout: 5))
        app.buttons["Reduktion"].firstMatch.tap()
        capture(app, "A3-Ziele")
        app.buttons["Weiter"].tap()

        // A4 · Ersatzhandlungen
        XCTAssertTrue(app.staticTexts["Was hilft dir im Moment?"].waitForExistence(timeout: 5))
        app.buttons["Eine Runde rausgehen"].tap()
        capture(app, "A4-Ersatzhandlungen")
        app.buttons["App öffnen"].tap()

        // B2 · Heute (leerer Tag)
        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5))
        capture(app, "B2-Heute-leer")

        // C1 · Substanz wählen
        app.buttons["Eintrag erfassen"].tap()
        XCTAssertTrue(app.staticTexts["Neuer Eintrag"].waitForExistence(timeout: 5))
        capture(app, "C1-Substanz-waehlen")

        // C2 · Gespeichert
        app.buttons["MDMA"].tap()
        XCTAssertTrue(app.staticTexts["Gespeichert."].waitForExistence(timeout: 5))
        capture(app, "C2-Gespeichert")
        app.buttons["Fertig"].tap()

        // B1 · Heute (gefüllt)
        XCTAssertTrue(app.staticTexts["today.loggedSection"].waitForExistence(timeout: 5))
        capture(app, "B1-Heute-gefuellt")

        // E1 · Verlauf · Kalender
        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.buttons["Vorheriger Monat"].waitForExistence(timeout: 5))
        capture(app, "E1-Kalender")

        // M · Muster
        app.tabBars.buttons["Muster"].tap()
        XCTAssertTrue(app.buttons["patterns.substance.MDMA"].waitForExistence(timeout: 5))
        capture(app, "M-Muster")

        // H1 · Hilfe
        app.tabBars.buttons["Hilfe"].tap()
        XCTAssertTrue(app.buttons["help.sos"].waitForExistence(timeout: 5))
        capture(app, "H1-Hilfe")

        // H2 · Craving-SOS
        app.buttons["help.sos"].tap()
        XCTAssertTrue(app.staticTexts["Dieses Gefühl geht vorbei."].waitForExistence(timeout: 5))
        capture(app, "H2-Craving-SOS")

        // H2b · Atemübung (part of the SOS flow, no drafted screen of its own)
        app.buttons["Atemübung starten"].tap()
        XCTAssertTrue(
            app.staticTexts["Vier Sekunden ein, vier halten, vier aus, vier halten."]
                .waitForExistence(timeout: 5)
        )
        capture(app, "H2b-Atemuebung")
        app.buttons["Schließen"].firstMatch.tap()

        app.buttons["Schließen"].firstMatch.tap()

        // H3 · Notfall
        app.buttons["help.emergency"].tap()
        XCTAssertTrue(app.staticTexts["Notfall"].waitForExistence(timeout: 5))
        capture(app, "H3-Notfall")
        app.navigationBars.buttons.firstMatch.tap()

        // H4 · Beratung
        app.buttons["help.counseling"].tap()
        XCTAssertTrue(app.staticTexts["Beratung"].waitForExistence(timeout: 5))
        capture(app, "H4-Beratung")
        app.navigationBars.buttons.firstMatch.tap()

        // H5 · Risiko-Infos
        app.buttons["help.riskInfo"].tap()
        XCTAssertTrue(app.staticTexts["Risiko-Infos"].waitForExistence(timeout: 5))
        capture(app, "H5-Risiko-Infos")
        app.buttons["MDMA"].firstMatch.tap()
        capture(app, "H5-Risiko-Infos-Detail")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        // I1 · Einstellungen
        app.tabBars.buttons["Übersicht"].tap()
        app.buttons["Einstellungen"].tap()
        XCTAssertTrue(app.staticTexts["Einstellungen"].waitForExistence(timeout: 5))
        capture(app, "I1-Einstellungen")

        // I2 · Substanzen, I3 · eine Substanz
        app.buttons["settings.substances"].tap()
        XCTAssertTrue(app.buttons["settings.substance.MDMA"].waitForExistence(timeout: 5))
        capture(app, "I2-Substanzen")
        app.buttons["settings.substance.MDMA"].tap()
        XCTAssertTrue(app.staticTexts["Morgen danach fragen"].waitForExistence(timeout: 5))
        capture(app, "I3-Substanz")
    }

    @MainActor
    func testCaptureMorningAfter() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--klar-uitest-seed-yesterday"]
        app.launch()

        XCTAssertTrue(app.staticTexts["morningAfter.header"].waitForExistence(timeout: 10))
        capture(app, "D-Morgen-danach")
        app.buttons["ja"].firstMatch.tap()
        capture(app, "D-Morgen-danach-bereut")

        // B · Offen, E1 with the ring, E2 with „Rückblick nachtragen"
        app.buttons["Später"].tap()
        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5))
        capture(app, "B-Offen")
        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.buttons["Vorheriger Monat"].waitForExistence(timeout: 5))
        capture(app, "E1-Kalender-offen")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Rückblick offen")).firstMatch.tap()
        XCTAssertTrue(app.buttons["dayDetail.morning"].waitForExistence(timeout: 5))
        capture(app, "E2-Tagesdetail-offen")
    }
}
