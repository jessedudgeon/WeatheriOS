import XCTest

final class Tests_iOS: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testLocationPermissionAndCoordinateForecast() {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["--ui-testing", "--empty"]
        app.launch()
        app.buttons["currentLocation"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 8) { allow.tap() }
        XCTAssertTrue(app.staticTexts["forecastPlace"].waitForExistence(timeout: 30), "A granted simulator location should trigger a forecast")
        XCTAssertEqual(app.staticTexts["forecastPlace"].label, "Current location")
    }

    func testDeniedLocationStillOffersSearch() {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["--ui-testing", "--empty"]
        app.launch()
        app.buttons["currentLocation"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.alerts.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Don'")).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 8))
        deny.tap()
        XCTAssertTrue(app.buttons["Search instead"].waitForExistence(timeout: 5))
        app.buttons["Search instead"].tap()
        XCTAssertTrue(app.textFields["citySearchField"].waitForExistence(timeout: 5))
    }

    func testLiveOpenMeteoLoadsWithoutWeatherKitProvisioning() {
        let app = XCUIApplication()
        app.launchArguments = ["--live-weather-test"]
        app.launch()
        XCTAssertTrue(app.staticTexts["forecastPlace"].waitForExistence(timeout: 45), "Live Open-Meteo should load without WeatherKit credentials")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Live forecast"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFishingAndMapNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["forecastPlace"].waitForExistence(timeout: 10))
        app.segmentedControls["weatherSection"].buttons["Fishing"].tap()
        XCTAssertTrue(app.otherElements["fishingHeader"].waitForExistence(timeout: 5) || app.staticTexts["Plan your next cast."].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Fishing briefing"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.segmentedControls["weatherSection"].buttons["Maps"].tap()
        XCTAssertTrue(app.staticTexts["weatherMapHeader"].waitForExistence(timeout: 5))
        app.segmentedControls["mapLayerPicker"].buttons["Wind"].tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
    }

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
