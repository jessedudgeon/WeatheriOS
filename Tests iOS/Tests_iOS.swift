import XCTest
import StoreKitTest

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

    func testStoreKitPurchaseRelaunchRestoreAndRefund() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "WeatherModules", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--storekit-testing"]
        app.launch()
        app.segmentedControls["weatherSection"].buttons["Modules"].tap()
        let buy = app.buttons["buyModule_fishing"]
        XCTAssertTrue(buy.waitForExistence(timeout: 15))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: buy)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 30), .completed)
        buy.tap()
        let unlocked = app.buttons["openModule_fishing"].waitForExistence(timeout: 30)
        if !unlocked {
            print("StoreKit transaction count: \(session.allTransactions().count)")
            print(XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription)
            print(app.debugDescription)
        }
        XCTAssertTrue(unlocked)
        app.terminate()
        app.launch()
        app.segmentedControls["weatherSection"].buttons["Fishing"].tap()
        XCTAssertTrue(app.staticTexts["Plan your next cast."].waitForExistence(timeout: 10))
        app.segmentedControls["weatherSection"].buttons["Modules"].tap()
        let restore = app.buttons["restorePurchases"]
        for _ in 0..<12 { if restore.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(restore.isHittable)
        restore.tap()
        // The store status is above the cards; wait by existence, not visibility.
        XCTAssertTrue(app.staticTexts["Your module purchases have been restored."].waitForExistence(timeout: 15))
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        for _ in 0..<12 { if app.segmentedControls["weatherSection"].isHittable { break }; app.swipeDown() }
        app.segmentedControls["weatherSection"].buttons["Fishing"].tap()
        XCTAssertTrue(app.buttons["viewModuleStore"].waitForExistence(timeout: 15))
    }

    func testLockedModulesLeaveBasicWeatherFree() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--locked-modules"]
        app.launch()
        XCTAssertTrue(app.staticTexts["forecastPlace"].waitForExistence(timeout: 10))
        app.segmentedControls["weatherSection"].buttons["Fishing"].tap()
        XCTAssertTrue(app.buttons["viewModuleStore"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Plan your next cast."].exists)
        app.buttons["viewModuleStore"].tap()
        XCTAssertTrue(app.staticTexts["moduleStoreHeader"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["openModule_fishing"].exists)
        app.segmentedControls["weatherSection"].buttons["Forecast"].tap()
        XCTAssertTrue(app.staticTexts["forecastPlace"].waitForExistence(timeout: 5))
    }

    func testOwnedGolfAndRegionalModulesOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.segmentedControls["weatherSection"].buttons["Modules"].tap()
        let golf = app.buttons["openModule_golf"]
        for _ in 0..<8 { if golf.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(golf.isHittable)
        golf.tap()
        XCTAssertTrue(app.staticTexts["golfHeader"].waitForExistence(timeout: 5))
        app.buttons["All modules"].tap()
        let regional = app.buttons["openModule_lakeErieFishing"]
        for _ in 0..<10 { if regional.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(regional.isHittable)
        regional.tap()
        XCTAssertTrue(app.staticTexts["lakeErieHeader"].waitForExistence(timeout: 5))
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
