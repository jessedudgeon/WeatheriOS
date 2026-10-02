import XCTest
@testable import WeatherCore

final class WeatherCoreTests: XCTestCase {
    private let place = Place(name: "Berne", latitude: 40.65, longitude: -84.95, timeZoneIdentifier: "America/Indiana/Indianapolis")

    func testUnitConversions() {
        XCTAssertEqual(WeatherUnits.imperial.temperature(0), "32°")
        XCTAssertEqual(WeatherUnits.imperial.temperature(-40), "-40°")
        XCTAssertEqual(WeatherUnits.metric.temperature(20.2), "20°")
        XCTAssertEqual(WeatherUnits.imperial.wind(16.09344), "10 mph")
        XCTAssertEqual(WeatherUnits.metric.wind(16), "16 km/h")
    }

    func testCoordinatesAreValidated() {
        XCTAssertTrue(place.isValid)
        XCTAssertFalse(Place(name: "Bad", latitude: 91, longitude: 0, timeZoneIdentifier: "UTC").isValid)
        XCTAssertFalse(Place(name: "Bad", latitude: .nan, longitude: 0, timeZoneIdentifier: "UTC").isValid)
        XCTAssertFalse(Place(name: " ", latitude: 0, longitude: 0, timeZoneIdentifier: "UTC").isValid)
    }

    func testIdentityIgnoresDisplayName() {
        let renamed = Place(name: "Berne, IN", latitude: place.latitude, longitude: place.longitude, timeZoneIdentifier: place.timeZoneIdentifier)
        XCTAssertEqual(place.id, renamed.id)
    }

    func testTimeZoneUsesDestination() {
        XCTAssertEqual(place.timeZone.identifier, "America/Indiana/Indianapolis")
        XCTAssertEqual(Place(name: "Test", latitude: 0, longitude: 0, timeZoneIdentifier: "invalid").timeZone, .gmt)
    }

    func testCacheFreshnessAndExpiry() {
        let now = Date()
        let forecast = fixture(now)
        XCTAssertFalse(forecast.isStale(at: now.addingTimeInterval(1800)))
        XCTAssertTrue(forecast.isStale(at: now.addingTimeInterval(1801)))
        XCTAssertTrue(forecast.canUseOffline(at: now.addingTimeInterval(86400)))
        XCTAssertFalse(forecast.canUseOffline(at: now.addingTimeInterval(86401)))
        XCTAssertFalse(forecast.canUseOffline(at: now.addingTimeInterval(-120)))
    }

    func testHourlyForecastDropsPastHoursAndLimitsTo24() {
        let now = Date()
        let forecast = fixture(now)
        let hours = forecast.upcomingHours(at: now.addingTimeInterval(7200))
        XCTAssertEqual(hours.count, 24)
        XCTAssertEqual(hours.first?.date, now.addingTimeInterval(3600))
    }

    func testPersistenceRoundTripAndRemoval() throws {
        try withStore { store in
            store.places = [place]
            store.selectedID = place.id
            store.save(fixture(Date()))
            XCTAssertEqual(store.places, [place])
            XCTAssertEqual(store.selectedID, place.id)
            XCTAssertEqual(store.cached(for: place)?.temperature, 20)
            store.remove(place)
            XCTAssertTrue(store.places.isEmpty)
            XCTAssertNil(store.cached(for: place))
            XCTAssertNil(store.selectedID)
        }
    }

    func testSavedPlaceLimitAndDeduplication() throws {
        try withStore { store in
            store.places = [place, place]
            XCTAssertEqual(store.places.count, 1)
            store.places = (0..<20).map { Place(name: "Place \($0)", latitude: Double($0), longitude: 0, timeZoneIdentifier: "UTC") }
            XCTAssertEqual(store.places.count, 12)
        }
    }

    func testExpiredCacheIsNotReturned() throws {
        try withStore { store in
            let now = Date()
            store.save(fixture(now))
            XCTAssertNil(store.cached(for: place, at: now.addingTimeInterval(86401)))
        }
    }

    func testClearRemovesStoredCoordinatesAndForecasts() throws {
        try withStore { store in
            store.places = [place]
            store.selectedID = place.id
            store.save(fixture(Date()))
            store.clear()
            XCTAssertTrue(store.places.isEmpty)
            XCTAssertNil(store.cached(for: place))
            XCTAssertNil(store.selectedID)
        }
    }

    func testCorruptPersistenceRecoversWithoutCrash() throws {
        try withStore { store in
            store.defaults.set(Data("broken".utf8), forKey: "weather.places.v1")
            store.defaults.set(Data("broken".utf8), forKey: "weather.cache.v1")
            XCTAssertTrue(store.places.isEmpty)
            XCTAssertNil(store.cached(for: place))
        }
    }

    private func withStore(_ test: (WeatherPersistence) throws -> Void) throws {
        let name = "WeatherCoreTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try test(WeatherPersistence(defaults: defaults))
    }

    private func fixture(_ date: Date) -> Forecast {
        Forecast(place: place, fetchedAt: date, observedAt: date, condition: "Clear", symbol: "sun.max",
                 temperature: 20, feelsLike: 20, humidity: 0.5, windSpeed: 16, uvIndex: 3,
                 hours: (0..<48).map { HourForecast(date: date.addingTimeInterval(Double($0) * 3600), symbol: "sun.max", temperature: 20, precipitationChance: 0.1) },
                 days: [], warnings: [], alertsAvailable: false,
                 attributionURL: URL(string: "https://example.com/legal")!,
                 lightMarkURL: URL(string: "https://example.com/light")!,
                 darkMarkURL: URL(string: "https://example.com/dark")!)
    }
}
