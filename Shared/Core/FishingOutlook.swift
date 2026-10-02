import Foundation

struct FishingWindow: Identifiable {
    var id: Date { start }
    let start: Date
    let end: Date
    let maxWind: Double
    let maxGust: Double
    let maxRainChance: Double
}

/// Transparent weather-planning filters, not a fish-activity or boating-safety score.
struct FishingOutlook {
    let forecast: Forecast

    func windows(at now: Date = Date()) -> [FishingWindow] {
        guard !forecast.isStale(at: now), forecast.canUseOffline(at: now) else { return [] }
        let hours = forecast.hours.filter { $0.date >= now && $0.date < now.addingTimeInterval(86400) }
            .sorted { $0.date < $1.date }
        var groups: [[HourForecast]] = []
        var group: [HourForecast] = []
        for hour in hours {
            let qualifies = hour.isDaylight == true && (hour.windSpeed.map { $0 < 20 } ?? false)
                && (hour.windGust.map { $0 < 30 } ?? false) && hour.precipitationChance < 0.3
                && !(hour.symbol.contains("bolt")) && !(hour.weatherCode.map { $0 >= 95 } ?? false)
            let contiguous = group.last.map { abs(hour.date.timeIntervalSince($0.date) - 3600) < 1 } ?? true
            if !qualifies || !contiguous {
                if group.count >= 2 { groups.append(group) }
                group = []
            }
            if qualifies { group.append(hour) }
        }
        if group.count >= 2 { groups.append(group) }
        return Array(groups.compactMap { group -> FishingWindow? in
            guard let first = group.first, let last = group.last else { return nil }
            // Hourly daylight flags describe the sample time, not the whole hour.
            // Clip the last interval to sunset and the advertised 24-hour horizon.
            var end = min(last.date.addingTimeInterval(3600), now.addingTimeInterval(86400))
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = forecast.place.timeZone
            if let day = forecast.days.first(where: { calendar.isDate($0.date, inSameDayAs: last.date) }),
               let sunset = day.sunset {
                end = min(end, sunset)
            }
            guard end.timeIntervalSince(first.date) >= 7200 else { return nil }
            return FishingWindow(start: first.date, end: end,
                                 maxWind: group.compactMap(\.windSpeed).max() ?? 0,
                                 maxGust: group.compactMap(\.windGust).max() ?? 0,
                                 maxRainChance: group.map(\.precipitationChance).max() ?? 0)
        }.prefix(3))
    }

    func pressureChange(at now: Date = Date()) -> Double? {
        let hours = forecast.hours.sorted { $0.date < $1.date }
        guard let first = hours.first(where: { $0.date >= now }), let pressure = first.pressure,
              let later = hours.first(where: { $0.date >= first.date.addingTimeInterval(10800) }),
              later.date.timeIntervalSince(first.date) < 14400, let nextPressure = later.pressure else { return nil }
        return nextPressure - pressure
    }

    static func compass(_ degrees: Double) -> String {
        guard degrees.isFinite else { return "—" }
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return points[Int((normalized / 45).rounded()) % 8]
    }
}

enum WeatherMapLayer: String, CaseIterable, Identifiable {
    case precipitation, wind
    var id: String { rawValue }
    var title: String { self == .precipitation ? "Precipitation" : "Wind" }

    func url(for place: Place, units: WeatherUnits) -> URL {
        var url = URLComponents(string: "https://embed.windy.com/embed.html")!
        url.queryItems = [
            URLQueryItem(name: "type", value: "map"), URLQueryItem(name: "location", value: "coordinates"),
            URLQueryItem(name: "lat", value: String(place.latitude)), URLQueryItem(name: "lon", value: String(place.longitude)),
            URLQueryItem(name: "zoom", value: "7"), URLQueryItem(name: "level", value: "surface"),
            URLQueryItem(name: "overlay", value: self == .wind ? "wind" : "rain"),
            URLQueryItem(name: "product", value: "ecmwf"),
            URLQueryItem(name: "metricWind", value: units == .imperial ? "mph" : "km/h"),
            URLQueryItem(name: "metricTemp", value: units == .imperial ? "°F" : "°C"),
            URLQueryItem(name: "metricRain", value: units == .imperial ? "in" : "mm"),
            URLQueryItem(name: "marker", value: "true"), URLQueryItem(name: "pressure", value: "true")
        ]
        return url.url!
    }
}
