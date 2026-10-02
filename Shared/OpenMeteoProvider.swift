import Foundation

struct OpenMeteoProvider: WeatherProviding {
    var session: URLSession = .shared

    func forecast(for place: Place) async throws -> Forecast {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "10"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "precipitation_unit", value: "mm"),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code,wind_speed_10m,wind_gusts_10m,pressure_msl,is_day,precipitation"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,uv_index_max")
        ]
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ForecastDataError.incomplete }
        guard (200..<300).contains(http.statusCode) else { throw ForecastDataError.response(http.statusCode) }
        let forecast = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return try forecast.forecast(for: place)
    }
}

struct PlaceSearchResponse: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let admin1: String?
        let country_code: String?
        let timezone: String?
        var place: Place {
            Place(name: [name, admin1, country_code].compactMap { $0 }.joined(separator: ", "),
                  latitude: latitude, longitude: longitude, timeZoneIdentifier: timezone ?? "GMT")
        }
    }
    let results: [Result]?
}

struct OpenPlaceSearch {
    func search(_ text: String) async throws -> [Place] {
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [URLQueryItem(name: "name", value: text), URLQueryItem(name: "count", value: "10"),
                          URLQueryItem(name: "language", value: "en"), URLQueryItem(name: "format", value: "json")]
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw ForecastDataError.incomplete
        }
        return try JSONDecoder().decode(PlaceSearchResponse.self, from: data).results?.map(\.place) ?? []
    }
}
