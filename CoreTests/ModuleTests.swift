import XCTest
@testable import WeatherCore

final class ModuleTests: XCTestCase {
    func testNoPurchaseUnlocksNothing() {
        for module in WeatherModule.allCases { XCTAssertFalse(module.isUnlocked(by: [])) }
    }
    func testIndividualPurchasesDoNotUnlockOtherModules() {
        XCTAssertTrue(WeatherModule.fishing.isUnlocked(by: [WeatherModule.fishing.productID]))
        XCTAssertFalse(WeatherModule.golf.isUnlocked(by: [WeatherModule.fishing.productID]))
        XCTAssertFalse(WeatherModule.lakeErieFishing.isUnlocked(by: [WeatherModule.fishing.productID]))
        XCTAssertFalse(WeatherModule.fishing.isUnlocked(by: [WeatherModule.golf.productID]))
    }
    func testRegionalPurchaseIncludesFishingAndRevocationRemovesIt() {
        let purchased: Set<String> = [WeatherModule.lakeErieFishing.productID]
        XCTAssertTrue(WeatherModule.fishing.isUnlocked(by: purchased))
        XCTAssertTrue(WeatherModule.lakeErieFishing.isUnlocked(by: purchased))
        XCTAssertFalse(WeatherModule.golf.isUnlocked(by: purchased))
        XCTAssertFalse(WeatherModule.fishing.isUnlocked(by: purchased.subtracting(purchased)))
        XCTAssertTrue(WeatherModule.fishing.isUnlocked(by: [WeatherModule.fishing.productID]))
    }
    func testUnknownProductsDoNotUnlockFeatures() {
        for module in WeatherModule.allCases { XCTAssertFalse(module.isUnlocked(by: ["unknown"])) }
        XCTAssertEqual(Set(WeatherModule.allCases.map(\.productID)).count, WeatherModule.allCases.count)
    }
    func testGolfConsecutiveDurationAndNoOverlap() {
        let f = fixture()
        let windows = GolfOutlook(forecast: f).windows(duration: 4, at: f.fetchedAt)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].end.timeIntervalSince(windows[0].start), 14400)
        XCTAssertEqual(windows[1].start, windows[0].end)
        XCTAssertTrue(GolfOutlook(forecast: f).windows(duration: 0, at: f.fetchedAt).isEmpty)
    }
    func testGolfRejectsMissingDataStormsAndStaleForecasts() {
        let f = fixture()
        XCTAssertTrue(GolfOutlook(forecast: f).windows(duration: 2, at: f.fetchedAt.addingTimeInterval(1801)).isEmpty)
        XCTAssertTrue(GolfOutlook(forecast: fixture(missing: true)).windows(duration: 2, at: f.fetchedAt).isEmpty)
        XCTAssertTrue(GolfOutlook(forecast: fixture(storm: true)).windows(duration: 2, at: f.fetchedAt).isEmpty)
    }
    func testGolfDoesNotExtendRoundPastSunsetOrBridgeGap() {
        let f = fixture(sunsetOffset: 3.5)
        XCTAssertTrue(GolfOutlook(forecast: f).windows(duration: 4, at: f.fetchedAt).isEmpty)
        let windows = GolfOutlook(forecast: f).windows(duration: 2, at: f.fetchedAt)
        XCTAssertEqual(windows.count, 1)
        let gaps = fixture(gap: true)
        XCTAssertTrue(GolfOutlook(forecast: gaps).windows(duration: 4, at: gaps.fetchedAt).isEmpty)
    }
    private func fixture(missing: Bool = false, storm: Bool = false, sunsetOffset: Double = 10, gap: Bool = false) -> Forecast {
        let now = Date(timeIntervalSince1970: 1800000000)
        let hours = (0..<8).map { index in
            HourForecast(date: now.addingTimeInterval(Double(gap ? index * 2 : index) * 3600),
                         symbol: storm ? "cloud.bolt" : "sun.max", temperature: 20, precipitationChance: 0.1,
                         windSpeed: missing ? nil : 10, windGust: 20, isDaylight: true)
        }
        let day = DayForecast(date: now, symbol: "sun.max", low: 15, high: 25, precipitationChance: 0.1,
                              sunrise: now.addingTimeInterval(-3600), sunset: now.addingTimeInterval(sunsetOffset * 3600))
        return Forecast(place: Place(name: "Course", latitude: 40, longitude: -85, timeZoneIdentifier: "UTC"),
                        fetchedAt: now, observedAt: now, condition: "Clear", symbol: "sun.max", temperature: 20,
                        feelsLike: 20, humidity: 0.5, windSpeed: 10, uvIndex: 3, hours: hours, days: [day], warnings: [],
                        alertsAvailable: false, attributionURL: URL(string: "https://open-meteo.com")!, lightMarkURL: nil, darkMarkURL: nil)
    }
}
