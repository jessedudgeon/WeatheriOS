import SwiftUI
import WebKit

struct WeatherMapView: View {
    let place: Place
    let units: WeatherUnits
    @State private var layer: WeatherMapLayer = .precipitation
    @State private var loading = true
    @State private var error: String?
    @State private var reload = UUID()
    private var url: URL { layer.url(for: place, units: units) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather in motion").font(.title.bold()).accessibilityIdentifier("weatherMapHeader")
            Text(place.name).foregroundStyle(.secondary)
            Picker("Map layer", selection: $layer) {
                ForEach(WeatherMapLayer.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("mapLayerPicker")
            Text(layer == .precipitation
                 ? "Precipitation forecast · ECMWF. Use the timeline to explore forecast rain and snow. This is a forecast layer, not live radar."
                 : "Surface wind forecast · ECMWF. Use the timeline to explore wind direction and speed.")
                .font(.callout).foregroundStyle(.secondary)
            ZStack(alignment: .top) {
                WeatherWebMap(url: url, loading: $loading, error: $error)
                    .id(url.absoluteString + reload.uuidString)
                    .frame(height: 520)
                if loading {
                    ProgressView("Loading map…").padding(12).background(.regularMaterial, in: Capsule()).padding()
                }
                if let error {
                    VStack(spacing: 12) {
                        Text(error).multilineTextAlignment(.center)
                        Button("Retry map") { self.error = nil; loading = true; reload = UUID() }
                            .buttonStyle(.borderedProminent)
                        Link("Open map in browser", destination: url)
                    }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 20))
            HStack {
                Link("Open full map", destination: url)
                Spacer()
                Button { error = nil; loading = true; reload = UUID() } label: { Label("Reload", systemImage: "arrow.clockwise") }
            }
            Text("Map and forecast layers by Windy.com / ECMWF; base-map credit is shown on the map. Opening Maps sends this place’s coordinates to Windy. Map forecasts can differ from the selected weather provider.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: layer) { _ in loading = true; error = nil }
        .task(id: url.absoluteString + reload.uuidString) {
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            guard !Task.isCancelled, loading else { return }
            loading = false
            error = "The map is taking too long. Check your connection or open it in your browser."
        }
    }
}

private final class MapNavigation: NSObject, WKNavigationDelegate {
    var loading: Binding<Bool>
    var error: Binding<String?>
    init(loading: Binding<Bool>, error: Binding<String?>) { self.loading = loading; self.error = error }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading.wrappedValue = false
        error.wrappedValue = nil
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ error: Error) {
        if (error as? URLError)?.code == .cancelled { return }
        loading.wrappedValue = false
        self.error.wrappedValue = "The map couldn’t load. Check your connection and try again."
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loading.wrappedValue = false
        error.wrappedValue = "The map stopped responding. Tap Retry map."
    }
}

#if os(iOS)
private struct WeatherWebMap: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    @Binding var error: String?
    func makeCoordinator() -> MapNavigation { MapNavigation(loading: $loading, error: $error) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    static func dismantleUIView(_ view: WKWebView, coordinator: MapNavigation) { view.stopLoading(); view.navigationDelegate = nil }
}
#elseif os(macOS)
private struct WeatherWebMap: NSViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    @Binding var error: String?
    func makeCoordinator() -> MapNavigation { MapNavigation(loading: $loading, error: $error) }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
    static func dismantleNSView(_ view: WKWebView, coordinator: MapNavigation) { view.stopLoading(); view.navigationDelegate = nil }
}
#endif
