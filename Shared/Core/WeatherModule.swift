import Foundation

/// Stable identifiers shared by the store, access checks, and future module views.
enum WeatherModule: String, CaseIterable, Identifiable {
    case fishing, golf, lakeErieFishing
    var id: String { rawValue }
    var productID: String { "jessedudgeon.Weather.module.\(rawValue)" }
    var title: String {
        switch self {
        case .fishing: return "Fishing"
        case .golf: return "Golf"
        case .lakeErieFishing: return "Lake Erie Fishing"
        }
    }
    var symbol: String {
        switch self {
        case .fishing: return "fish.fill"
        case .golf: return "flag.fill"
        case .lakeErieFishing: return "water.waves"
        }
    }
    var summary: String {
        switch self {
        case .fishing: return "Plan a trip with daylight windows, wind and gust charts, pressure trends, and rain at a glance."
        case .golf: return "Find two- or four-hour daylight weather windows and review wind, rain, and temperature for your round."
        case .lakeErieFishing: return "A Lake Erie shore-city planner with regional shortcuts and official marine resources. Includes the full Fishing module."
        }
    }
    var details: String {
        switch self {
        case .fishing: return "Uses the selected place’s weather forecast. Does not include fish sightings, bite predictions, water temperature, or lake levels."
        case .golf: return "Weather planning for any selected location. Does not include tee-time booking, course conditions, or lightning detection."
        case .lakeErieFishing: return "Compare planning locations from Port Clinton to Buffalo. Uses shore-city weather, with links to official marine reports; wave and buoy readings are not integrated. No additional Fishing purchase is required."
        }
    }
    func isUnlocked(by productIDs: Set<String>) -> Bool {
        productIDs.contains(productID) || (self == .fishing && productIDs.contains(WeatherModule.lakeErieFishing.productID))
    }
}

struct GolfWindow: Identifiable {
    var id: Date { start }
    let start: Date
    let end: Date
    let maxWind: Double
    let maxRainChance: Double
    let low: Double
    let high: Double
}

struct GolfOutlook {
    let forecast: Forecast
    func windows(duration: Int, at now: Date = Date()) -> [GolfWindow] {
        guard [2, 4].contains(duration), !forecast.isStale(at: now), forecast.canUseOffline(at: now) else { return [] }
        let hours = forecast.hours.filter { $0.date >= now && $0.date < now.addingTimeInterval(48 * 3600) }.sorted { $0.date < $1.date }
        var results: [GolfWindow] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = forecast.place.timeZone
        for index in hours.indices {
            guard index + duration <= hours.count else { break }
            let slice = Array(hours[index..<(index + duration)])
            guard slice.allSatisfy({ hour in
                hour.isDaylight == true && (hour.windSpeed.map { $0 >= 0 && $0 < 25 } ?? false)
                    && (hour.windGust.map { $0 >= 0 && $0 < 35 } ?? false)
                    && hour.precipitationChance >= 0 && hour.precipitationChance < 0.3
                    && (8...32).contains(hour.temperature) && !hour.symbol.contains("bolt")
                    && !(hour.weatherCode.map { $0 >= 95 } ?? false)
            }) else { continue }
            let start = slice[0].date
            let end = start.addingTimeInterval(Double(duration) * 3600)
            guard zip(slice, slice.dropFirst()).allSatisfy({ abs($1.date.timeIntervalSince($0.date) - 3600) < 1 }),
                  end <= now.addingTimeInterval(48 * 3600) else { continue }
            if let sunset = forecast.days.first(where: { calendar.isDate($0.date, inSameDayAs: start) })?.sunset,
               end > sunset { continue }
            if let previous = results.last, start < previous.end { continue }
            results.append(GolfWindow(start: start, end: end, maxWind: slice.compactMap(\.windSpeed).max()!,
                                      maxRainChance: slice.map(\.precipitationChance).max()!,
                                      low: slice.map(\.temperature).min()!, high: slice.map(\.temperature).max()!))
            if results.count == 6 { break }
        }
        return results
    }
}
