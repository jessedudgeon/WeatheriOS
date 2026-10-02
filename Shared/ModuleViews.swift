import SwiftUI

struct ModuleStoreView: View {
    @ObservedObject var store: ModuleStore
    let open: (WeatherModule) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Make weather yours.").font(.largeTitle.bold()).accessibilityIdentifier("moduleStoreHeader")
            Text("Basic weather is free. Add the hobbies and places that matter to you.").foregroundStyle(.secondary)
            Label("Forecasts, search, saved places, and weather maps stay free.", systemImage: "checkmark.circle.fill")
                .font(.callout).foregroundStyle(.teal)
            if store.isCheckingAccess || store.isLoading { ProgressView("Checking the store…") }
            if let message = store.message { Text(message).font(.callout).accessibilityIdentifier("purchaseMessage") }
            ForEach(WeatherModule.allCases) { module in
                VStack(alignment: .leading, spacing: 14) {
                    Label(module.title, systemImage: module.symbol).font(.title2.bold())
                    Text(module.summary)
                    Text(module.details).font(.caption).foregroundStyle(.secondary)
                    if module == .lakeErieFishing && store.owns(.fishing) && !store.owns(module) {
                        Text("You already own Fishing. This adds the Lake Erie planner at the displayed full price; previous purchases are not credited.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if store.owns(module) {
                        Label(module == .fishing && !store.ownedProductIDs.contains(module.productID) ? "Included with Lake Erie Fishing" : "Purchased", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.teal)
                        Button("Open \(module.title)") { open(module) }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("openModule_\(module.id)")
                    } else if store.pendingProductIDs.contains(module.productID) {
                        Label("Awaiting purchase approval", systemImage: "clock")
                    } else if let product = store.product(for: module) {
                        Button {
                            Task { await store.purchase(module) }
                        } label: {
                            Text(store.purchasingID == module.productID ? "Purchasing…" : "Buy for \(product.displayPrice)")
                        }.buttonStyle(.borderedProminent)
                            .disabled(store.isBusy || store.isCheckingAccess)
                            .accessibilityIdentifier("buyModule_\(module.id)")
                        Text("One-time purchase. No subscription.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(store.isLoading ? "Loading price…" : "Purchase currently unavailable. Please try again later.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 20))
            }
            ViewThatFits {
                HStack { storeButtons }
                VStack(alignment: .leading) { storeButtons }
            }
            Text("Purchases use your Apple Account and can be restored. Deleting saved weather does not delete purchases.")
                .font(.footnote).foregroundStyle(.secondary)
        }.task { await store.loadProducts() }
    }
    @ViewBuilder private var storeButtons: some View {
        Button(store.isRestoring ? "Restoring…" : "Restore Purchases") { Task { await store.restore() } }
            .disabled(store.isBusy).accessibilityIdentifier("restorePurchases")
        Button("Reload Store") { Task { await store.loadProducts() } }.disabled(store.isLoading || store.isBusy)
    }
}

struct LockedModuleView: View {
    let module: WeatherModule
    let checking: Bool
    let showStore: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(module.title, systemImage: module.symbol).font(.largeTitle.bold())
            Text(module.summary)
            if checking { ProgressView("Checking purchases…") }
            else {
                Label("Optional paid module", systemImage: "lock.fill").foregroundStyle(.secondary)
                Text(module.details).font(.callout).foregroundStyle(.secondary)
                Button("View module & price", action: showStore).buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("viewModuleStore")
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 24))
            .accessibilityIdentifier("lockedModule_\(module.id)")
    }
}

struct GolfView: View {
    let forecast: Forecast
    let units: WeatherUnits
    let isCached: Bool
    @State private var duration = 4
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 20) {
                Label("Golf weather", systemImage: "flag.fill").font(.largeTitle.bold()).accessibilityIdentifier("golfHeader")
                Text(forecast.place.name).font(.headline)
                Picker("Round length", selection: $duration) {
                    Text("2 hours").tag(2)
                    Text("4 hours").tag(4)
                }.pickerStyle(.segmented)
                Text("Daylight windows · next 48 hours").font(.title2.bold())
                let windows = isCached ? [] : GolfOutlook(forecast: forecast).windows(duration: duration, at: context.date)
                if windows.isEmpty {
                    Text(isCached || forecast.isStale(at: context.date) ? "Refresh weather to calculate upcoming rounds." : "No window meets every filter, or the required hourly data is unavailable.")
                        .foregroundStyle(.secondary)
                }
                ForEach(windows) { window in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(time(window.start)) – \(time(window.end))").font(.headline)
                        Text("\(units.temperature(window.low)) to \(units.temperature(window.high)) · Wind up to \(units.wind(window.maxWind))")
                        Text("Rain chance up to \(Int((window.maxRainChance * 100).rounded()))%")
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18))
                }
                Text("Filters: consecutive daylight hours, air temperature \(units.temperature(8))–\(units.temperature(32)), wind below \(units.wind(25)), gusts below \(units.wind(35)), rain chance below 30%, and no forecast thunderstorm symbol. Suggested windows do not overlap.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("These are weather preferences, not a course-opening or lightning-safety determination. Check the course and local alerts before play.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Times shown in \(forecast.place.timeZoneIdentifier). Updated \(time(forecast.fetchedAt)).")
                    .font(.caption).foregroundStyle(.secondary)
                ForecastAttribution(forecast: forecast)
            }
        }
    }
    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = forecast.place.timeZone
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}

struct LakeErieFishingView: View {
    let units: WeatherUnits
    let source: WeatherSource
    @StateObject private var model = WeatherViewModel.makeRegionalModel()
    private static let places = [
        Place(name: "Port Clinton, OH", latitude: 41.5120, longitude: -82.9377, timeZoneIdentifier: "America/New_York"),
        Place(name: "Sandusky, OH", latitude: 41.4489, longitude: -82.7079, timeZoneIdentifier: "America/New_York"),
        Place(name: "Cleveland, OH", latitude: 41.4993, longitude: -81.6944, timeZoneIdentifier: "America/New_York"),
        Place(name: "Erie, PA", latitude: 42.1292, longitude: -80.0851, timeZoneIdentifier: "America/New_York"),
        Place(name: "Buffalo, NY", latitude: 42.8864, longitude: -78.8784, timeZoneIdentifier: "America/New_York")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Lake Erie Fishing", systemImage: "water.waves").font(.largeTitle.bold()).accessibilityIdentifier("lakeErieHeader")
            Text("Choose a shore city for your fishing-weather briefing. These are city forecasts, not offshore marine forecasts.").foregroundStyle(.secondary)
            Menu {
                ForEach(Self.places) { place in Button(place.name) { model.select(place) } }
            } label: {
                Label(model.selectedPlace?.name ?? "Choose a shore city", systemImage: "mappin.and.ellipse")
            }.buttonStyle(.borderedProminent)
            Link("Official Lake Erie marine reports & observations", destination: URL(string: "https://www.weather.gov/cle/marine")!)
            Text("Open the official reports for waves and marine warnings. No wave heights, water temperatures, fish reports, or catch forecasts are integrated here.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Refresh regional weather") { model.refresh() }.disabled(model.isLoading)
            if model.isLoading { ProgressView("Loading shore-city weather…") }
            if let message = model.message { Text(message).foregroundStyle(.secondary) }
            if let forecast = model.forecast {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if forecast.canUseOffline(at: context.date) {
                        FishingView(forecast: forecast, units: units, isCached: model.isCached)
                    } else { Text("This saved forecast has expired. Refresh regional weather.") }
                }
            }
        }.onAppear {
            model.source = source
            if model.selectedPlace == nil { model.select(Self.places[0]) }
        }.onChange(of: source) { model.source = $0 }
    }
}

extension WeatherViewModel {
    @MainActor static func makeRegionalModel() -> WeatherViewModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            return WeatherViewModel(provider: PreviewWeatherProvider(), defaults: UserDefaults(suiteName: "WeatherRegional")!)
        }
        #endif
        return WeatherViewModel(defaults: UserDefaults(suiteName: "WeatherRegional")!)
    }
}
