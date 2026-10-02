import XCTest

final class Tests_macOS: XCTestCase {
    func testForecastLoadsWithoutNetworkCredentials() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["forecastPlace"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["currentTemperature"].label, "68°")
    }
}
