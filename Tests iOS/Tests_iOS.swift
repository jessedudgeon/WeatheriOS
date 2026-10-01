import XCTest

final class Tests_iOS: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFirstLaunchOffersSearchWithoutLocationPermission() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--empty"]
        app.launch()
        XCTAssertTrue(app.buttons["welcomeSearch"].waitForExistence(timeout: 10))
        app.buttons["welcomeSearch"].tap()
        XCTAssertTrue(app.textFields["citySearchField"].waitForExistence(timeout: 5))
    }

    func testForecastAndSavedPlaceCanBeCleared() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["forecastPlace"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["currentTemperature"].label, "68°")
        // Save is below the dashboard, so reach it by scrolling.
        let save = app.buttons["savePlace"]
        for _ in 0..<12 {
            if save.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(save.isHittable)
        save.tap()
        app.buttons["settings"].tap()
        let clear = app.buttons["clearWeatherData"]
        for _ in 0..<8 {
            if clear.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(clear.isHittable)
        clear.tap()
        app.buttons["Delete all"].tap()
        XCTAssertTrue(app.buttons["welcomeSearch"].waitForExistence(timeout: 5))
    }
}
