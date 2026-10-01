import XCTest
@testable import WeatherCore

final class FishingOutlookTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1800000000)

    func testDaylightContiguousWindowsAreMerged() {
        let windows = FishingOutlook(forecast: fixture()).windows(at: now)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.end.timeIntervalSince(windows.first!.start), 6 * 3600)
    }

    func testMissingWindDoesNotCountAsCalm() {
        var f = fixture()
        var hours = f.hours
        hours[2].windSpeed = nil
        f = replacingHours(f, hours)
        XCTAssertEqual(FishingOutlook(forecast: f).windows(at: now).count, 2)
    }

    func testStormsNightAndStrongGustsExcluded() {
        var hours = fixture().hours
        for i in hours.indices { hours[i].isDaylight = false }
        XCTAssertTrue(FishingOutlook(forecast: replacingHours(fixture(), hours)).windows(at: now).isEmpty)
        for i in hours.indices { hours[i].isDaylight = true; hours[i].windGust = 40 }
        XCTAssertTrue(FishingOutlook(forecast: replacingHours(fixture(), hours)).windows(at: now).isEmpty)
        for i in hours.indices { hours[i].windGust = 20; hours[i].weatherCode = 95 }
        XCTAssertTrue(FishingOutlook(forecast: replacingHours(fixture(), hours)).windows(at: now).isEmpty)
    }

    func testStaleForecastHasNoSuggestedWindows() {
        XCTAssertTrue(FishingOutlook(forecast: fixture()).windows(at: now.addingTimeInterval(1801)).isEmpty)
    }

    func testPressureTrendIsThreeHoursAndCompassWraps() {
        XCTAssertEqual(FishingOutlook(forecast: fixture()).pressureChange(at: now), 3)
        XCTAssertEqual(FishingOutlook.compass(360), "N")
        XCTAssertEqual(FishingOutlook.compass(-90), "W")
        XCTAssertEqual(FishingOutlook.compass(225), "SW")
    }

    private func fixture() -> Forecast {
        Forecast(place: Place(name: "Lake", latitude: 40, longitude: -85, timeZoneIdentifier: "UTC"),
                 fetchedAt: now, observedAt: now, condition: "Clear", symbol: "sun.max", temperature: 20,
                 feelsLike: 20, humidity: 0.5, windSpeed: 10, uvIndex: 3,
                 hours: (0..<6).map { HourForecast(date: now.addingTimeInterval(Double($0) * 3600), symbol: "sun.max", temperature: 20,
                                                 precipitationChance: 0.1, windSpeed: 10, windGust: 20, pressure: 1010 + Double($0), isDaylight: true, weatherCode: 0) },
                 days: [], warnings: [], alertsAvailable: false, attributionURL: URL(string: "https://open-meteo.com")!, lightMarkURL: nil, darkMarkURL: nil)
    }
    private func replacingHours(_ f: Forecast, _ hours: [HourForecast]) -> Forecast {
        Forecast(place: f.place, fetchedAt: f.fetchedAt, observedAt: f.observedAt, condition: f.condition, symbol: f.symbol,
                 temperature: f.temperature, feelsLike: f.feelsLike, humidity: f.humidity, windSpeed: f.windSpeed, uvIndex: f.uvIndex,
                 hours: hours, days: f.days, warnings: f.warnings, alertsAvailable: f.alertsAvailable,
                 attributionURL: f.attributionURL, lightMarkURL: nil, darkMarkURL: nil)
    }
}
