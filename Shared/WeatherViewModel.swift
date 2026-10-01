import Foundation
import Combine
import CoreLocation

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var forecast: Forecast?
    @Published private(set) var selectedPlace: Place?
    @Published private(set) var savedPlaces: [Place]
    @Published private(set) var isLoading = false
    @Published private(set) var isCached = false
    @Published private(set) var message: String?
    @Published private(set) var searchResults: [Place] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchMessage: String?
    @Published var units: WeatherUnits { didSet { defaults.set(units.rawValue, forKey: "weather.units") } }
    @Published var source: WeatherSource {
        didSet {
            defaults.set(source.rawValue, forKey: "weather.source")
            if oldValue != source { refresh() }
        }
    }
    @Published var playful: Bool { didSet { defaults.set(playful, forKey: "weather.playful") } }

    private let provider: (any WeatherProviding)?
    private let persistence: WeatherPersistence
    private let defaults: UserDefaults
    private let searchGeocoder = CLGeocoder()
    private var fetchTask: Task<Void, Never>?
    private var fetchTimeout: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var requestID = UUID()
    private var searchID = UUID()

    init(provider: (any WeatherProviding)? = nil, defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
        persistence = WeatherPersistence(defaults: defaults)
        savedPlaces = persistence.places
        units = WeatherUnits(rawValue: defaults.string(forKey: "weather.units") ?? "") ?? .imperial
        source = WeatherSource(rawValue: defaults.string(forKey: "weather.source") ?? "") ?? .openMeteo
        playful = defaults.bool(forKey: "weather.playful")
        if let place = savedPlaces.first(where: { $0.id == persistence.selectedID }) ?? savedPlaces.first {
            select(place)
        }
    }

    func select(_ place: Place) {
        guard place.isValid else { return }
        fetchTask?.cancel()
        fetchTimeout?.cancel()
        requestID = UUID()
        let id = requestID
        selectedPlace = place
        persistence.selectedID = savedPlaces.contains(where: { $0.id == place.id }) ? place.id : nil
        forecast = persistence.cached(for: place)
        isCached = forecast != nil
        message = nil
        isLoading = true
        let activeProvider: any WeatherProviding
        if let provider { activeProvider = provider }
        else if source == .apple { activeProvider = AppleWeatherProvider() }
        else { activeProvider = OpenMeteoProvider() }
        let source = self.source
        fetchTask = Task { [weak self] in
            do {
                let result = try await activeProvider.forecast(for: place)
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.fetchTimeout?.cancel()
                self.forecast = result
                self.selectedPlace = result.place
                self.persistence.save(result)
                self.isCached = false
                self.isLoading = false
            } catch {
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.fetchTimeout?.cancel()
                let detail: String
                if source == .apple {
                    detail = "Apple Weather couldn’t load. Its App ID needs WeatherKit provisioning. Switch to Open-Meteo in Settings to load weather without that setup."
                } else if let error = error as? URLError {
                    detail = "Weather couldn’t connect: \(error.localizedDescription) Try again when you’re online."
                } else {
                    detail = "Weather couldn’t load: \(error.localizedDescription)"
                }
                self.message = detail + (self.forecast == nil ? "" : " Showing the last saved forecast.")
                self.isLoading = false
            }
        }
        fetchTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled, let self, self.requestID == id, self.isLoading else { return }
            self.fetchTask?.cancel()
            self.isLoading = false
            self.message = self.forecast == nil
                ? "Weather took too long to load. Check your connection and try again."
                : "Refresh timed out. Showing your last saved forecast."
        }
    }

    func refresh() {
        if let place = selectedPlace { select(place) }
    }

    func refreshIfNeeded() {
        if let forecast, !forecast.isStale(), !isCached { return }
        if !isLoading { refresh() }
    }

    func waitForRefresh() async {
        refresh()
        await fetchTask?.value
    }

    func saveSelected() {
        guard let place = selectedPlace, !isSaved(place) else { return }
        guard savedPlaces.count < 12 else {
            message = "You can save up to 12 places. Remove one before adding another."
            return
        }
        savedPlaces.append(place)
        persistence.places = savedPlaces
        persistence.selectedID = place.id
        if let forecast { persistence.save(forecast) }
    }

    func isSaved(_ place: Place) -> Bool { savedPlaces.contains { $0.id == place.id } }

    func remove(_ place: Place) {
        persistence.remove(place)
        savedPlaces = persistence.places
        if selectedPlace?.id == place.id {
            fetchTask?.cancel()
            fetchTimeout?.cancel()
            requestID = UUID()
            forecast = nil
            selectedPlace = nil
            message = nil
            isLoading = false
            if let next = savedPlaces.first { select(next) }
        }
    }

    func clearData() {
        fetchTask?.cancel()
        fetchTimeout?.cancel()
        requestID = UUID()
        cancelSearch()
        persistence.clear()
        savedPlaces = []
        selectedPlace = nil
        forecast = nil
        message = nil
        isLoading = false
        isCached = false
    }

    func search(_ query: String) {
        cancelSearch()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        let id = searchID
        isSearching = true
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !Task.isCancelled else { return }
                var places = (try? await OpenPlaceSearch().search(trimmed)) ?? []
                try Task.checkCancellation()
                if places.isEmpty {
                    places = try await self.searchGeocoder.geocodeAddressString(trimmed).compactMap(Self.place)
                }
                guard !Task.isCancelled, self.searchID == id else { return }
                var ids = Set<String>()
                self.searchResults = places.filter { $0.isValid && ids.insert($0.id).inserted }
                self.searchMessage = self.searchResults.isEmpty ? "No places found. Try a city with its state or country." : nil
                self.isSearching = false
            } catch {
                guard let self, !Task.isCancelled, self.searchID == id else { return }
                self.searchMessage = "Search couldn’t finish. Check your connection and try again."
                self.isSearching = false
            }
        }
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchGeocoder.cancelGeocode()
        searchID = UUID()
        searchResults = []
        searchMessage = nil
        isSearching = false
    }

    func useLocation(_ location: CLLocation) {
        // Forecasting must not wait for reverse geocoding, which can fail independently.
        select(Place(name: "Current location", latitude: location.coordinate.latitude,
                     longitude: location.coordinate.longitude, timeZoneIdentifier: TimeZone.current.identifier))
    }

    private static func place(_ placemark: CLPlacemark) -> Place? {
        guard let location = placemark.location else { return nil }
        let parts = [placemark.locality ?? placemark.name, placemark.administrativeArea, placemark.isoCountryCode]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return Place(name: parts.isEmpty ? "Selected location" : parts.joined(separator: ", "),
                     latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                     timeZoneIdentifier: (placemark.timeZone ?? .current).identifier)
    }
}
