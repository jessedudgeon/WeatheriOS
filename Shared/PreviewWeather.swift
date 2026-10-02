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
        var hours: [HourForecast] = []
        for index in 0..<24 {
            let date = now.addingTimeInterval(Double(index) * 3600.0)
            let temperature = 20.0 + Double(index % 5)
            let wind = 12.0 + Double(index % 5)
            let pressure = 1012.0 + Double(index) / 4.0
            let hour = HourForecast(date: date, symbol: "cloud.sun.fill", temperature: temperature,
                                    precipitationChance: 0.2, windSpeed: wind, windGust: 22.0,
                                    pressure: pressure, precipitation: 0.1, isDaylight: true, weatherCode: 2)
            hours.append(hour)
        }
        var days: [DayForecast] = []
        for index in 0..<10 {
            let date = now.addingTimeInterval(Double(index) * 86400.0)
            days.append(DayForecast(date: date, symbol: "cloud.sun.fill", low: 12.0, high: 24.0,
                                    precipitationChance: 0.2, sunrise: nil, sunset: nil))
        }
        return Forecast(
            place: place, fetchedAt: now, observedAt: now, condition: "Partly Cloudy", symbol: "cloud.sun.fill",
            temperature: 20, feelsLike: 19, humidity: 0.55, windSpeed: 16, uvIndex: 3,
            hours: hours, days: days, warnings: [], alertsAvailable: true,
            attributionURL: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!,
            lightMarkURL: nil, darkMarkURL: nil, sourceName: "Preview fixture", pressure: 1012, windGust: 22, windDirection: 225)
    }
}
#endif
