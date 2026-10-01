import Foundation

/// The network boundary is decoded separately so array lengths, missing values, units,
/// and timestamp handling are covered by fixture tests without a live connection.
struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let time: Double
        let temperature_2m: Double
        let apparent_temperature: Double
        let relative_humidity_2m: Double
        let weather_code: Int
        let is_day: Int
        let wind_speed_10m: Double
        let wind_direction_10m: Double?
        let wind_gusts_10m: Double?
        let pressure_msl: Double?
    }
    struct Hourly: Decodable {
        let time: [Double]
        let temperature_2m: [Double?]
        let precipitation_probability: [Double?]
        let weather_code: [Int?]
        let wind_speed_10m: [Double?]
        let wind_gusts_10m: [Double?]
        let pressure_msl: [Double?]
        let is_day: [Int?]
        let precipitation: [Double?]
    }
    struct Daily: Decodable {
        let time: [Double]
        let weather_code: [Int?]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_probability_max: [Double?]
        let sunrise: [Double?]
        let sunset: [Double?]
        let uv_index_max: [Double?]
    }
    let timezone: String
    let current: Current
    let hourly: Hourly
    let daily: Daily

    func forecast(for requestedPlace: Place, fetchedAt: Date = Date()) throws -> Forecast {
        let place = Place(name: requestedPlace.name, latitude: requestedPlace.latitude,
                          longitude: requestedPlace.longitude, timeZoneIdentifier: timezone)
        let hours: [HourForecast] = hourly.time.indices.compactMap { i in
            guard let temp = hourly.temperature_2m.value(at: i),
                  let code = hourly.weather_code.value(at: i),
                  let rain = hourly.precipitation_probability.value(at: i) else { return nil }
            return HourForecast(date: Date(timeIntervalSince1970: hourly.time[i]),
                                symbol: Self.condition(code, isDay: hourly.is_day.value(at: i) != 0).symbol,
                                temperature: temp, precipitationChance: min(1, max(0, rain / 100)),
                                windSpeed: hourly.wind_speed_10m.value(at: i),
                                windGust: hourly.wind_gusts_10m.value(at: i),
                                pressure: hourly.pressure_msl.value(at: i),
                                precipitation: hourly.precipitation.value(at: i),
                                isDaylight: hourly.is_day.value(at: i).map { $0 == 1 }, weatherCode: code)
        }
        let days: [DayForecast] = daily.time.indices.compactMap { i in
            guard let low = daily.temperature_2m_min.value(at: i),
                  let high = daily.temperature_2m_max.value(at: i),
                  let code = daily.weather_code.value(at: i),
                  let rain = daily.precipitation_probability_max.value(at: i) else { return nil }
            return DayForecast(date: Date(timeIntervalSince1970: daily.time[i]),
                               symbol: Self.condition(code).symbol, low: low, high: high,
                               precipitationChance: min(1, max(0, rain / 100)),
                               sunrise: daily.sunrise.value(at: i).flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil },
                               sunset: daily.sunset.value(at: i).flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil })
        }
        guard !hours.isEmpty, !days.isEmpty else { throw ForecastDataError.incomplete }
        let condition = Self.condition(current.weather_code, isDay: current.is_day == 1)
        return Forecast(place: place, fetchedAt: fetchedAt, observedAt: Date(timeIntervalSince1970: current.time),
                        condition: condition.name, symbol: condition.symbol,
                        temperature: current.temperature_2m, feelsLike: current.apparent_temperature,
                        humidity: min(1, max(0, current.relative_humidity_2m / 100)),
                        windSpeed: current.wind_speed_10m, uvIndex: Int((daily.uv_index_max.value(at: 0) ?? 0).rounded()),
                        hours: hours, days: days, warnings: [], alertsAvailable: false,
                        attributionURL: URL(string: "https://open-meteo.com/")!,
                        lightMarkURL: nil, darkMarkURL: nil, sourceName: "Open-Meteo",
                        pressure: current.pressure_msl, windGust: current.wind_gusts_10m,
                        windDirection: current.wind_direction_10m, isModelled: true, uvIsDailyMaximum: true)
    }

    static func condition(_ code: Int, isDay: Bool = true) -> (name: String, symbol: String) {
        switch code {
        case 0: return ("Clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1: return ("Mostly clear", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 2: return ("Partly cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: return ("Overcast", "cloud.fill")
        case 45, 48: return ("Fog", "cloud.fog.fill")
        case 51, 53, 55: return ("Drizzle", "cloud.drizzle.fill")
        case 56, 57: return ("Freezing drizzle", "cloud.sleet.fill")
        case 61, 63, 65: return ("Rain", "cloud.rain.fill")
        case 66, 67: return ("Freezing rain", "cloud.sleet.fill")
        case 71, 73, 75, 77: return ("Snow", "cloud.snow.fill")
        case 80, 81, 82: return ("Rain showers", "cloud.heavyrain.fill")
        case 85, 86: return ("Snow showers", "cloud.snow.fill")
        case 95, 96, 99: return ("Thunderstorms", "cloud.bolt.rain.fill")
        default: return ("Conditions unavailable", "cloud")
        }
    }
}

private extension Array {
    func value<T>(at index: Int) -> T? where Element == T? {
        indices.contains(index) ? self[index] : nil
    }
}

enum ForecastDataError: LocalizedError {
    case incomplete
    case response(Int)
    var errorDescription: String? {
        switch self {
        case .incomplete: return "The weather provider returned an incomplete forecast. Please try again."
        case .response(429): return "The weather provider’s request limit was reached. Wait a minute and retry."
        case .response: return "The weather provider is temporarily unavailable. Please try again."
        }
    }
}
