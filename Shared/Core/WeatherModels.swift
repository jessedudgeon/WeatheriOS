import Foundation

struct Place: Codable, Identifiable, Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String

    var id: String { String(format: "%.3f,%.3f", latitude, longitude) }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .gmt }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        latitude.isFinite && longitude.isFinite &&
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

enum WeatherUnits: String, CaseIterable, Identifiable {
    case imperial, metric
    var id: String { rawValue }
    var label: String { self == .imperial ? "°F / mph" : "°C / km/h" }
    func temperature(_ celsius: Double) -> String {
        let value = self == .imperial ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }
    func wind(_ kilometersPerHour: Double) -> String {
        let value = self == .imperial ? kilometersPerHour / 1.609344 : kilometersPerHour
        return "\(Int(value.rounded())) \(self == .imperial ? "mph" : "km/h")"
    }
}

struct HourForecast: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let symbol: String
    let temperature: Double
    let precipitationChance: Double
}

struct DayForecast: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let symbol: String
    let low: Double
    let high: Double
    let precipitationChance: Double
    let sunrise: Date?
    let sunset: Date?
}

struct WeatherWarning: Codable, Identifiable {
    var id: String { url.absoluteString + summary }
    let summary: String
    let source: String
    let url: URL
}

struct Forecast: Codable {
    let place: Place
    let fetchedAt: Date
    let observedAt: Date
    let condition: String
    let symbol: String
    let temperature: Double
    let feelsLike: Double
    let humidity: Double
    let windSpeed: Double
    let uvIndex: Int
    let hours: [HourForecast]
    let days: [DayForecast]
    let warnings: [WeatherWarning]
    let alertsAvailable: Bool
    let attributionURL: URL
    let lightMarkURL: URL
    let darkMarkURL: URL

    func isStale(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(fetchedAt) > 30 * 60
    }

    func canUseOffline(at date: Date = Date()) -> Bool {
        let age = date.timeIntervalSince(fetchedAt)
        return age >= -60 && age <= 24 * 60 * 60
    }

    func upcomingHours(at date: Date = Date()) -> [HourForecast] {
        Array(hours.filter { $0.date >= date.addingTimeInterval(-3600) }.prefix(24))
    }
}

/// Bounded storage: removing a place also removes its weather and coordinates.
struct WeatherPersistence {
    let defaults: UserDefaults
    private let placesKey = "weather.places.v1"
    private let cacheKey = "weather.cache.v1"
    private let selectedKey = "weather.selected.v1"

    var places: [Place] {
        get {
            guard let data = defaults.data(forKey: placesKey),
                  let places = try? JSONDecoder().decode([Place].self, from: data) else { return [] }
            var ids = Set<String>()
            return Array(places.filter { $0.isValid && ids.insert($0.id).inserted }.prefix(12))
        }
        nonmutating set {
            defaults.set(try? JSONEncoder().encode(Array(newValue.filter(\.isValid).prefix(12))), forKey: placesKey)
        }
    }

    var selectedID: String? {
        get { defaults.string(forKey: selectedKey) }
        nonmutating set { defaults.set(newValue, forKey: selectedKey) }
    }

    private var cache: [String: Forecast] {
        get {
            guard let data = defaults.data(forKey: cacheKey),
                  let cache = try? JSONDecoder().decode([String: Forecast].self, from: data) else { return [:] }
            return cache
        }
        nonmutating set { defaults.set(try? JSONEncoder().encode(newValue), forKey: cacheKey) }
    }

    func cached(for place: Place, at date: Date = Date()) -> Forecast? {
        guard let item = cache[place.id], item.place.id == place.id, item.canUseOffline(at: date) else { return nil }
        return item
    }

    func save(_ forecast: Forecast) {
        var items = cache.filter { $0.value.canUseOffline() }
        items[forecast.place.id] = forecast
        // Keep at most twelve saved forecasts plus the most recent unsaved location.
        let keptIDs = Set(places.map(\.id) + [forecast.place.id])
        items = items.filter { keptIDs.contains($0.key) }
        cache = items
    }

    func remove(_ place: Place) {
        places = places.filter { $0.id != place.id }
        var items = cache
        items.removeValue(forKey: place.id)
        cache = items
        if selectedID == place.id { selectedID = nil }
    }

    func clear() {
        [placesKey, cacheKey, selectedKey].forEach { defaults.removeObject(forKey: $0) }
    }
}
