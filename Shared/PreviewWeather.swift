import Foundation

extension WeatherViewModel {
    @MainActor static func makeAppModel() -> WeatherViewModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--live-weather-test") {
            let defaults = UserDefaults(suiteName: "WeatherLiveTests")!
            defaults.removePersistentDomain(forName: "WeatherLiveTests")
            let model = WeatherViewModel(defaults: defaults)
            model.select(Place(name: "Berne, IN, US", latitude: 40.6581, longitude: -84.9519,
                               timeZoneIdentifier: "America/Indiana/Indianapolis"))
            return model
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let defaults = UserDefaults(suiteName: "WeatherUITests")!
            defaults.removePersistentDomain(forName: "WeatherUITests")
            let model = WeatherViewModel(provider: PreviewWeatherProvider(), defaults: defaults)
            if !ProcessInfo.processInfo.arguments.contains("--empty") {
                model.select(Place(name: "Berne, IN, US", latitude: 40.6581, longitude: -84.9519,
                                   timeZoneIdentifier: "America/Indiana/Indianapolis"))
            }
            return model
        }
        #endif
        return WeatherViewModel()
    }
}

#if DEBUG
struct PreviewWeatherProvider: WeatherProviding {
    func forecast(for place: Place) async throws -> Forecast {
        let now = Date()
        return Forecast(
            place: place, fetchedAt: now, observedAt: now, condition: "Partly Cloudy", symbol: "cloud.sun.fill",
            temperature: 20, feelsLike: 19, humidity: 0.55, windSpeed: 16, uvIndex: 3,
            hours: (0..<24).map { index in
                HourForecast(date: now.addingTimeInterval(Double(index) * 3600), symbol: "cloud.sun.fill",
                             temperature: 20 + Double(index % 5), precipitationChance: 0.2,
                             windSpeed: 12 + Double(index % 5), windGust: 22, pressure: 1012 + Double(index) / 4,
                             precipitation: 0.1, isDaylight: true, weatherCode: 2)
            },
            days: (0..<10).map { index in
                DayForecast(date: now.addingTimeInterval(Double(index) * 86400), symbol: "cloud.sun.fill",
                            low: 12, high: 24, precipitationChance: 0.2, sunrise: nil, sunset: nil)
            }, warnings: [], alertsAvailable: true,
            attributionURL: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!,
            lightMarkURL: nil, darkMarkURL: nil, sourceName: "Preview fixture", pressure: 1012, windGust: 22, windDirection: 225)
    }
}
#endif
