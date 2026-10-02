import Foundation
import CoreLocation
import WeatherKit

protocol WeatherProviding {
    func forecast(for place: Place) async throws -> Forecast
}

struct AppleWeatherProvider: WeatherProviding {
    func forecast(for place: Place) async throws -> Forecast {
        let service = WeatherService.shared
        async let weatherRequest = service.weather(for: CLLocation(latitude: place.latitude, longitude: place.longitude))
        async let attributionRequest = service.attribution
        let (weather, attribution) = try await (weatherRequest, attributionRequest)
        let current = weather.currentWeather
        return Forecast(
            place: place, fetchedAt: Date(), observedAt: current.date,
            condition: current.condition.description, symbol: current.symbolName,
            temperature: current.temperature.converted(to: .celsius).value,
            feelsLike: current.apparentTemperature.converted(to: .celsius).value,
            humidity: current.humidity,
            windSpeed: current.wind.speed.converted(to: .kilometersPerHour).value,
            uvIndex: current.uvIndex.value,
            hours: weather.hourlyForecast.forecast.map {
                HourForecast(date: $0.date, symbol: $0.symbolName,
                             temperature: $0.temperature.converted(to: .celsius).value,
                             precipitationChance: $0.precipitationChance)
            },
            days: weather.dailyForecast.forecast.map {
                DayForecast(date: $0.date, symbol: $0.symbolName,
                            low: $0.lowTemperature.converted(to: .celsius).value,
                            high: $0.highTemperature.converted(to: .celsius).value,
                            precipitationChance: $0.precipitationChance,
                            sunrise: $0.sun.sunrise, sunset: $0.sun.sunset)
            },
            warnings: (weather.weatherAlerts ?? []).map {
                WeatherWarning(summary: $0.summary, source: $0.source, url: $0.detailsURL)
            },
            alertsAvailable: weather.weatherAlerts != nil,
            attributionURL: attribution.legalPageURL,
            lightMarkURL: attribution.combinedMarkLightURL,
            darkMarkURL: attribution.combinedMarkDarkURL
        )
    }
}
