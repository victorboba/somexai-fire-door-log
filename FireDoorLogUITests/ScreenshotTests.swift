import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh FireDoorLog.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Fire doors"].waitForExistence(timeout: 15))
        sleep(1)
        snap("01-buildings", app)

        app.staticTexts["Meridian General"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Meridian General"].waitForExistence(timeout: 5))
        sleep(1)
        snap("02-register", app)

        // The deficiency filter: the openings actually carrying something unrepaired.
        app.buttons["Deficient"].firstMatch.tap()
        sleep(1)
        snap("03-deficiencies", app)

        app.buttons["All"].firstMatch.tap()
        sleep(1)
        let door = app.staticTexts["101A"].firstMatch
        if door.waitForExistence(timeout: 4) {
            door.tap()
            sleep(2)
            snap("04-inspection", app)
            let cancel = app.buttons["Cancel"].firstMatch
            if cancel.exists { cancel.tap() }
        }

        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        XCTAssertTrue(app.buttons["How do I use this app?"].waitForExistence(timeout: 6))
        app.buttons["How do I use this app?"].tap()
        sleep(1)
        snap("05-how-to", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 10))
        snap("paywall", app)
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
