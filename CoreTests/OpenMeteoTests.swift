import XCTest
@testable import WeatherCore

final class OpenMeteoTests: XCTestCase {
    func testRealProviderResponseDecodesAndNormalizesUnits() throws {
        let response = try decoder()
        let forecast = try response.forecast(for: place)
        XCTAssertEqual(forecast.hours.count, 240)
        XCTAssertEqual(forecast.days.count, 10)
        XCTAssertEqual(forecast.sourceName, "Open-Meteo")
        XCTAssertNil(forecast.lightMarkURL)
        XCTAssertEqual(forecast.place.timeZoneIdentifier, "America/Indiana/Indianapolis")
        XCTAssertEqual(forecast.humidity, response.current.relative_humidity_2m / 100)
        XCTAssertEqual(forecast.pressure, response.current.pressure_msl)
        XCTAssertEqual(forecast.windSpeed, response.current.wind_speed_10m)
        XCTAssertEqual(forecast.observedAt.timeIntervalSince1970, response.current.time)
        XCTAssertTrue(forecast.hours.allSatisfy { (0...1).contains($0.precipitationChance) })
        XCTAssertFalse(forecast.alertsAvailable)
        XCTAssertTrue(forecast.isModelled == true)
    }

    func testMissingArrayEntriesDoNotCrashOrBecomeFakeZeroRain() throws {
        var object = try JSONSerialization.jsonObject(with: fixtureData()) as! [String: Any]
        var hourly = object["hourly"] as! [String: Any]
        hourly["precipitation_probability"] = [NSNull(), 20]
        object["hourly"] = hourly
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: JSONSerialization.data(withJSONObject: object))
        let forecast = try response.forecast(for: place)
        XCTAssertEqual(forecast.hours.count, 1)
        XCTAssertEqual(forecast.hours[0].precipitationChance, 0.2)
    }

    func testEmptyForecastIsRejected() throws {
        var object = try JSONSerialization.jsonObject(with: fixtureData()) as! [String: Any]
        var hourly = object["hourly"] as! [String: Any]
        hourly["time"] = []
        object["hourly"] = hourly
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try response.forecast(for: place))
    }

    func testWeatherCodesAndNightSymbols() {
        XCTAssertEqual(OpenMeteoResponse.condition(0, isDay: false).symbol, "moon.stars.fill")
        XCTAssertEqual(OpenMeteoResponse.condition(95).name, "Thunderstorms")
        XCTAssertEqual(OpenMeteoResponse.condition(67).name, "Freezing rain")
        XCTAssertEqual(OpenMeteoResponse.condition(999).name, "Conditions unavailable")
    }

    func testMapURLsHaveCorrectCoordinatesLayersAndUnits() {
        for layer in WeatherMapLayer.allCases {
            let url = layer.url(for: place, units: .imperial)
            let query = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
            XCTAssertEqual(url.host, "embed.windy.com")
            XCTAssertEqual(query["overlay"], layer == .wind ? "wind" : "rain")
            XCTAssertEqual(query["lat"], String(place.latitude))
            XCTAssertEqual(query["metricWind"], "mph")
            XCTAssertEqual(query["metricRain"], "in")
        }
    }

    private var place: Place { Place(name: "Berne", latitude: 40.658, longitude: -84.951, timeZoneIdentifier: "UTC") }
    private func fixtureData() throws -> Data {
        try Data(contentsOf: Bundle.module.url(forResource: "open-meteo", withExtension: "json", subdirectory: "Fixtures")!)
    }
    private func decoder() throws -> OpenMeteoResponse { try JSONDecoder().decode(OpenMeteoResponse.self, from: fixtureData()) }
}
