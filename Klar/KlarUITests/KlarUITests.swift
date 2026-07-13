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

    @MainActor
    func testDebugScreenLaunchesAndSeedsDemoData() throws {
        let app = XCUIApplication()
        app.launch()

        let seedButton = app.buttons["Demodaten einspielen"]
        XCTAssertTrue(seedButton.waitForExistence(timeout: 15))
        seedButton.tap()

        XCTAssertTrue(app.staticTexts["Demodaten eingespielt."].waitForExistence(timeout: 15))
    }
}
