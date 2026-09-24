import XCTest

final class MorningAfterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The card asks once about yesterday, and once answered it does not come back.
    @MainActor
    func testTheCardAsksOnceAndDoesNotReturn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--klar-uitest-seed-yesterday"]
        app.launch()

        XCTAssertTrue(app.staticTexts["morningAfter.header"].waitForExistence(timeout: 10))
        app.buttons["verkatert"].tap()
        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.staticTexts["Übersicht"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["morningAfter.header"].exists)

        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["Übersicht"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.staticTexts["morningAfter.header"].waitForExistence(timeout: 3))
    }

    /// Tapping „Überspringen" counts as a skip and the card does not come back.
    @MainActor
    func testSkippingAlsoEndsTheQuestion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--klar-uitest-seed-yesterday"]
        app.launch()

        XCTAssertTrue(app.staticTexts["morningAfter.header"].waitForExistence(timeout: 10))
        app.buttons["Überspringen"].tap()

        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["Übersicht"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.staticTexts["morningAfter.header"].waitForExistence(timeout: 3))
    }
}
