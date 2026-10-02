import SwiftUI
import Charts

struct FishingView: View {
    let forecast: Forecast
    let units: WeatherUnits
    let isCached: Bool
    private var outlook: FishingOutlook { FishingOutlook(forecast: forecast) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 20) {
                Label("Fishing weather", systemImage: "fish.fill")
                    .font(.title2.bold()).accessibilityIdentifier("fishingHeader")
                if isCached || forecast.isStale(at: context.date) {
                    Label("Saved weather — refresh before planning your trip.", systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.orange)
                }

                section("Calmer, drier daylight windows", symbol: "clock.badge.checkmark") {
                    let windows = isCached ? [] : outlook.windows(at: context.date)
                    if windows.isEmpty {
                        Text(isCached || forecast.isStale(at: context.date)
                             ? "Refresh the forecast to calculate upcoming windows."
                             : "No two-hour window meets all the filters in the next 24 hours, or the required hourly data is unavailable.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(windows) { window in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(time(window.start, format: "EEE h:mm a")) – \(time(window.end, format: "EEE h:mm a"))")
                                .font(.headline).foregroundStyle(.teal)
                            Text("Wind up to \(units.wind(window.maxWind)) · Gusts \(units.wind(window.maxGust))")
                            Text("Rain chance up to \(Int((window.maxRainChance * 100).rounded()))%")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                    Text("Filters: daylight, wind below \(units.wind(20)), gusts below \(units.wind(30)), rain chance below 30%, and no forecast thunderstorm symbol. These are planning filters, not a catch prediction or a safe-boating assessment.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Text("Pressure: \(pressureTrend(at: context.date))")
                    .font(.subheadline).foregroundStyle(.secondary)

                section("Wind & gusts · next 24 hours", symbol: "wind") {
                    let hours = forecast.upcomingHours(at: context.date).filter { $0.windSpeed != nil }
                    if hours.isEmpty {
                        Text("Hourly wind data is unavailable from this forecast.").foregroundStyle(.secondary)
                    } else {
                        Chart(hours) { hour in
                            if let speed = hour.windSpeed {
                                LineMark(x: .value("Time", hour.date), y: .value("Wind", windValue(speed)))
                                    .foregroundStyle(by: .value("Series", "Wind"))
                            }
                            if let gust = hour.windGust {
                                LineMark(x: .value("Time", hour.date), y: .value("Gusts", windValue(gust)))
                                    .foregroundStyle(by: .value("Series", "Gusts"))
                            }
                        }.chartForegroundStyleScale(["Wind": Color.teal, "Gusts": Color.orange])
                            .chartYAxisLabel(units == .imperial ? "mph" : "km/h")
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                                    AxisGridLine()
                                    AxisValueLabel { if let date = value.as(Date.self) { Text(time(date, format: "ha")) } }
                                }
                            }.frame(height: 190)
                    }
                }

                section("Pressure trend · next 24 hours", symbol: "chart.xyaxis.line") {
                    let hours = forecast.upcomingHours(at: context.date).filter { $0.pressure != nil }
                    if hours.isEmpty {
                        Text("Hourly pressure data is unavailable from this forecast.").foregroundStyle(.secondary)
                    } else {
                        Chart(hours) { hour in
                            if let pressure = hour.pressure {
                                LineMark(x: .value("Time", hour.date), y: .value("Pressure", pressure))
                                    .foregroundStyle(.teal)
                            }
                        }.chartYScale(domain: .automatic(includesZero: false)).chartYAxisLabel("hPa")
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                                    AxisGridLine()
                                    AxisValueLabel { if let date = value.as(Date.self) { Text(time(date, format: "ha")) } }
                                }
                            }.frame(height: 170)
                    }
                    Text("Pressure is shown as a weather trend; it is not converted into an unsupported bite score.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Text("Water temperature, lake level, tides, and species-specific bite activity are not available in this weather feed. Check local water conditions and fishing regulations before heading out.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func pressureTrend(at date: Date) -> String {
        guard let change = outlook.pressureChange(at: date) else { return "3-hour trend unavailable" }
        let label = abs(change) < 0.5 ? "Steady" : (change > 0 ? "Rising" : "Falling")
        return "\(label) · \(String(format: "%+.1f", change)) hPa / 3 hr"
    }

    private func windValue(_ speed: Double) -> Double { units == .imperial ? speed / 1.609344 : speed }
    private func time(_ date: Date, format: String = "h:mm a") -> String {
        let f = DateFormatter()
        f.timeZone = forecast.place.timeZone
        f.dateFormat = format
        return f.string(from: date)
    }
    private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }
}
