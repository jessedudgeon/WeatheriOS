import SwiftUI

struct ContentView: View {
    @StateObject private var model = WeatherViewModel.makeAppModel()
    @StateObject private var location = LocationManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var section = "Forecast"
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !model.savedPlaces.isEmpty { savedPlaces }
                    if model.selectedPlace != nil {
                        Picker("View", selection: $section) {
                            Text("Forecast").tag("Forecast")
                            Text("Maps").tag("Maps")
                            Text("Fishing").tag("Fishing")
                        }.pickerStyle(.segmented).accessibilityIdentifier("weatherSection")
                    }
                    if let message = location.message {
                        notice(message, symbol: "location.slash")
                        HStack {
                            Button("Location Settings") { openLocationSettings() }
                            Button("Search instead") { showSearch = true }
                        }.buttonStyle(.bordered)
                    }
                    if let message = model.message { notice(message, symbol: "wifi.exclamationmark") }
                    if section == "Maps", let place = model.selectedPlace {
                        WeatherMapView(place: place, units: model.units)
                    } else if let forecast = model.forecast {
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            if forecast.canUseOffline(at: context.date) {
                                if section == "Fishing" {
                                    FishingView(forecast: forecast, units: model.units, isCached: model.isCached)
                                } else {
                                    ForecastDashboard(forecast: forecast, units: model.units,
                                                      playful: model.playful, isCached: model.isCached)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("This saved forecast has expired.").font(.headline)
                                    Text("Connect to the internet and refresh to see current weather.")
                                    Button("Refresh weather") { model.refresh() }
                                        .buttonStyle(.borderedProminent).disabled(model.isLoading)
                                }.padding(.vertical, 40)
                            }
                        }
                        if let place = model.selectedPlace, !model.isSaved(place) {
                            Button { model.saveSelected() } label: {
                                Label("Save this place", systemImage: "star")
                            }.buttonStyle(.bordered).accessibilityIdentifier("savePlace")
                        }
                    } else if model.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Fetching weather for \(model.selectedPlace?.name ?? "your location")…")
                        }.frame(maxWidth: .infinity, minHeight: 300)
                    } else if model.selectedPlace != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "cloud.slash").font(.system(size: 52))
                            Text("Weather is unavailable").font(.title2.bold())
                            Button("Try again") { model.refresh() }.buttonStyle(.borderedProminent)
                            Button("Search another city") { showSearch = true }
                        }.frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        welcome
                    }
                }
                .padding(20)
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
            }
            .background(Color.primary.opacity(0.035))
            .navigationTitle("Weather")
            .refreshable { await model.waitForRefresh() }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        location.request()
                    } label: {
                        Label(location.isLocating ? "Finding location" : "Use current location", systemImage: "location")
                    }.disabled(location.isLocating).accessibilityIdentifier("currentLocation")
                    Button { showSearch = true } label: {
                        Label("Search cities", systemImage: "magnifyingglass")
                    }.accessibilityIdentifier("searchCities")
                    Button { model.refresh() } label: {
                        Label("Refresh weather", systemImage: "arrow.clockwise")
                    }.disabled(model.selectedPlace == nil || model.isLoading)
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }.accessibilityIdentifier("settings")
                }
            }
            .overlay(alignment: .bottom) {
                if location.isLocating {
                    HStack {
                        ProgressView()
                        Text("Finding your location…")
                        Button("Cancel") { location.cancel() }
                    }.padding().background(.regularMaterial, in: Capsule()).padding()
                }
            }
            .sheet(isPresented: $showSearch) {
                PlaceSearchView(model: model) { place in
                    location.cancel()
                    model.select(place)
                }
            }
            .sheet(isPresented: $showSettings) {
                WeatherSettingsView(model: model) { location.cancel() }
            }
            .onAppear { location.onLocation = { model.useLocation($0) } }
            .onChange(of: scenePhase) { phase in
                if phase == .active { model.refreshIfNeeded() }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 650)
        #endif
    }

    private func openLocationSettings() {
        #if os(iOS)
        openURL(URL(string: UIApplication.openSettingsURLString)!)
        #elseif os(macOS)
        openURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
        #endif
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 76))
                .accessibilityHidden(true)
            Text("Your day, at a glance.").font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text("Current conditions, the next 24 hours, and your 10-day outlook. Choose a city to get started.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Search for a city") { showSearch = true }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("welcomeSearch")
            Button("Use my location") { location.request() }.disabled(location.isLocating)
            Button("Try Berne, Indiana") {
                model.select(Place(name: "Berne, IN, US", latitude: 40.6581, longitude: -84.9519,
                                   timeZoneIdentifier: "America/Indiana/Indianapolis"))
            }.accessibilityIdentifier("tryBerne")
            Text("Location is optional and only requested when you ask. No account needed.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(.vertical, 64).frame(maxWidth: .infinity)
    }

    private var savedPlaces: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(model.savedPlaces) { place in
                    Button {
                        location.cancel()
                        model.select(place)
                    } label: {
                        Label(place.name, systemImage: model.selectedPlace?.id == place.id ? "star.fill" : "star")
                    }.buttonStyle(.bordered)
                        .tint(model.selectedPlace?.id == place.id ? .blue : .secondary)
                        .contextMenu { Button("Remove saved place", role: .destructive) { model.remove(place) } }
                }
            }
        }.accessibilityLabel("Saved places")
    }

    private func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout).padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ForecastDashboard: View {
    let forecast: Forecast
    let units: WeatherUnits
    let playful: Bool
    let isCached: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(forecast.place.name).font(.title2.bold()).accessibilityIdentifier("forecastPlace")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { heroTemperature; heroCondition }
                    VStack(alignment: .leading, spacing: 12) { heroTemperature; heroCondition }
                }
                if let today = forecast.days.first {
                    Text("High \(units.temperature(today.high)) · Low \(units.temperature(today.low)) · Feels like \(units.temperature(forecast.feelsLike))")
                }
                if playful {
                    Text(personality).font(.headline).padding(.top, 4)
                }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [Color(red: 0.08, green: 0.22, blue: 0.42), Color(red: 0.12, green: 0.38, blue: 0.54)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))

            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 4) {
                    if isCached || forecast.isStale(at: context.date) {
                        Label("Saved forecast · refresh for current conditions", systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.orange)
                    }
                    Text("\(forecast.isModelled == true ? "Model time" : "Observed") \(date(forecast.observedAt, format: "MMM d, h:mm a")) · Updated \(date(forecast.fetchedAt, format: "MMM d, h:mm a"))")
                    Text("Times shown in \(forecast.place.timeZone.identifier).")
                }.font(.caption).foregroundStyle(.secondary)
            }

            if !forecast.warnings.isEmpty {
                card("Weather alerts", symbol: "exclamationmark.triangle.fill") {
                    if isCached || forecast.isStale() {
                        Text("Saved alerts may no longer be current. Open the source for the latest information.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(forecast.warnings) { warning in
                        Link(destination: warning.url) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(warning.summary, systemImage: "arrow.up.right.square").font(.headline)
                                Text(warning.source).font(.caption)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                        }
                    }
                }
            } else {
                Text(forecast.alertsAvailable ? "No alerts were returned with this forecast. This app does not send emergency notifications." : "Weather alerts are unavailable for this forecast. Check your local weather authority for warnings.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            card("Next 24 hours", symbol: "clock") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 22) {
                        ForEach(forecast.upcomingHours()) { hour in
                            VStack(spacing: 12) {
                                Text(date(hour.date, format: "ha")).font(.caption)
                                Image(systemName: hour.symbol).symbolRenderingMode(.hierarchical).foregroundStyle(.secondary).font(.title2)
                                    .accessibilityHidden(true)
                                Text(units.temperature(hour.temperature)).font(.headline)
                                Text(hour.precipitationChance, format: .percent.precision(.fractionLength(0)))
                                    .font(.caption).foregroundStyle(.blue)
                            }.accessibilityElement(children: .combine)
                                .accessibilityLabel("\(date(hour.date, format: "ha")), \(units.temperature(hour.temperature)), precipitation chance \(Int(hour.precipitationChance * 100)) percent")
                        }
                    }.padding(.vertical, 6)
                }
            }

            card("10-day forecast", symbol: "calendar") {
                ForEach(forecast.days.prefix(10)) { day in
                    HStack(spacing: 12) {
                        Text(date(day.date, format: "EEE d")).frame(minWidth: 64, alignment: .leading)
                        Image(systemName: day.symbol).symbolRenderingMode(.hierarchical).foregroundStyle(.secondary).frame(width: 28)
                            .accessibilityHidden(true)
                        Text(day.precipitationChance, format: .percent.precision(.fractionLength(0)))
                            .font(.caption).foregroundStyle(.blue)
                        Spacer(minLength: 4)
                        Text(units.temperature(day.low)).foregroundStyle(.secondary)
                        Text(units.temperature(day.high)).fontWeight(.semibold)
                    }.padding(.vertical, 7).accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(date(day.date, format: "EEEE MMMM d")), low \(units.temperature(day.low)), high \(units.temperature(day.high)), precipitation chance \(Int(day.precipitationChance * 100)) percent")
                    if day.id != forecast.days.prefix(10).last?.id { Divider() }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                metric("Wind", value: units.wind(forecast.windSpeed), symbol: "wind")
                metric("Humidity", value: forecast.humidity.formatted(.percent.precision(.fractionLength(0))), symbol: "humidity")
                metric(forecast.uvIsDailyMaximum == true ? "Max UV today" : "UV index", value: "\(forecast.uvIndex)", symbol: "sun.max")
                metric("Feels like", value: units.temperature(forecast.feelsLike), symbol: "thermometer.medium")
                if let sunrise = forecast.days.first?.sunrise {
                    metric("Sunrise", value: date(sunrise, format: "h:mm a"), symbol: "sunrise")
                }
                if let sunset = forecast.days.first?.sunset {
                    metric("Sunset", value: date(sunset, format: "h:mm a"), symbol: "sunset")
                }
            }

            ForecastAttribution(forecast: forecast)

        }
    }

    private var heroTemperature: some View {
        Text(units.temperature(forecast.temperature))
            .font(.system(size: 80, weight: .thin, design: .rounded))
            .minimumScaleFactor(0.6).lineLimit(1).accessibilityIdentifier("currentTemperature")
    }

    private var heroCondition: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: forecast.symbol).font(.system(size: 38)).accessibilityHidden(true)
            Text(forecast.condition).font(.title3)
        }
    }

    private var personality: String {
        if forecast.temperature < 0 { return "Layers. Then another layer." }
        if forecast.temperature > 30 { return "A very good day to know where the shade is." }
        if (forecast.hours.first?.precipitationChance ?? 0) > 0.5 { return "Your umbrella would like to come along." }
        return "Weather checked. The rest of the day is yours."
    }

    private func date(_ value: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = forecast.place.timeZone
        formatter.dateFormat = format
        return formatter.string(from: value)
    }

    private func card<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(.secondary)
            content()
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        card(title, symbol: symbol) {
            Text(value).font(.title2.weight(.medium)).minimumScaleFactor(0.7).lineLimit(1)
        }
    }
}

private struct PlaceSearchView: View {
    @ObservedObject var model: WeatherViewModel
    let select: (Place) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("City, state, or postal code", text: $query)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("citySearchField")
                    .onSubmit { model.search(query) }
                if model.isSearching { ProgressView("Searching…") }
                if let message = model.searchMessage { Text(message).foregroundStyle(.secondary) }
                if query.count < 2 { Text("Search anywhere. Add a state or country for a more precise match.").foregroundStyle(.secondary) }
                Text("Place search: Open-Meteo / GeoNames; Apple fallback.").font(.caption2).foregroundStyle(.secondary)
                List(model.searchResults) { place in
                    Button {
                        select(place)
                        dismiss()
                    } label: {
                        Label(place.name, systemImage: "mappin.and.ellipse")
                    }.buttonStyle(.plain).padding(.vertical, 8)
                }.listStyle(.plain)
            }.padding().navigationTitle("Find a place")
                .toolbar { ToolbarItem { Button("Done") { dismiss() } } }
                .onChange(of: query) { model.search($0) }
                .onDisappear { model.cancelSearch() }
        }
        #if os(macOS)
        .frame(width: 520, height: 460)
        #endif
    }
}

private struct WeatherSettingsView: View {
    @ObservedObject var model: WeatherViewModel
    let beforeClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Picker("Weather provider", selection: $model.source) {
                        ForEach(WeatherSource.allCases) { Text($0.label).tag($0) }
                    }
                    Text("Open-Meteo works without an API key for personal, non-commercial use. Apple Weather needs a WeatherKit-enabled signing profile.")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Units", selection: $model.units) {
                        ForEach(WeatherUnits.allCases) { Text($0.label).tag($0) }
                    }.accessibilityIdentifier("unitsPicker")
                    Toggle("A little personality", isOn: $model.playful)
                }
                Section("Saved places") {
                    if model.savedPlaces.isEmpty { Text("No saved places yet.").foregroundStyle(.secondary) }
                    ForEach(model.savedPlaces) { place in
                        HStack {
                            Text(place.name)
                            Spacer()
                            Button(role: .destructive) { model.remove(place) } label: {
                                Label("Remove", systemImage: "trash")
                            }.accessibilityLabel("Remove \(place.name)")
                        }
                    }
                }
                Section("Privacy & storage") {
                    Text("Weather sends requested coordinates to your chosen forecast provider (Open-Meteo by default, or Apple Weather). City searches use Open-Meteo / GeoNames, with Apple search as a fallback. Maps sends the selected coordinates to Windy when opened. Saved places and recent forecasts stay on this device. There are no accounts, ads, app analytics, or background location tracking.")
                    Text("Cached weather is kept for offline display for up to 24 hours and is always marked as saved. Alerts are informational; this app does not deliver emergency notifications.")
                    Button("Delete saved places and weather", role: .destructive) { confirmClear = true }
                        .accessibilityIdentifier("clearWeatherData")
                    Link("Open-Meteo terms & privacy", destination: URL(string: "https://open-meteo.com/en/terms")!)
                    Link("Windy map provider", destination: URL(string: "https://embed.windy.com/")!)
                    Link("Apple privacy policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                }
                Section("About") {
                    Text("Weather · 1.1")
                    Link("Project & support", destination: URL(string: "https://github.com/jessedudgeon/WeatheriOS/issues")!)
                }
            }.formStyle(.grouped).navigationTitle("Settings")
                .toolbar { ToolbarItem { Button("Done") { dismiss() } } }
                .confirmationDialog("Delete all saved places and cached forecasts?", isPresented: $confirmClear, titleVisibility: .visible) {
                    Button("Delete all", role: .destructive) {
                        beforeClear()
                        model.clearData()
                        dismiss()
                    }
                }
        }
        #if os(macOS)
        .frame(width: 560, height: 620)
        #endif
    }
}


struct ForecastAttribution: View {
    let forecast: Forecast
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Link(destination: forecast.attributionURL) {
            VStack(spacing: 8) {
                if let mark = colorScheme == .dark ? forecast.lightMarkURL : forecast.darkMarkURL {
                    AsyncImage(url: mark) { image in image.resizable().scaledToFit() } placeholder: { Text("Apple Weather").font(.headline) }
                        .frame(width: 130, height: 26)
                } else {
                    Text(forecast.sourceName ?? "Weather provider").font(.headline)
                }
                Text(forecast.sourceName == "Open-Meteo" ? "Weather data by Open-Meteo · CC BY 4.0" : "Weather data sources & attribution").font(.caption)
            }.frame(maxWidth: .infinity).padding(.vertical)
        }.accessibilityLabel("\(forecast.sourceName ?? "Apple Weather") data sources and attribution")
    }
}
