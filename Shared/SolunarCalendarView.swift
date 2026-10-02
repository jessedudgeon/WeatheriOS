import SwiftUI

struct SolunarCalendarView: View {
    let place: Place
    @State private var selectedDay = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let days = SolunarCalendar.days(for: place, starting: context.date)
            VStack(alignment: .leading, spacing: 16) {
                Label("Solunar fishing calendar", systemImage: "moon.stars.fill")
                    .font(.title2.bold()).accessibilityIdentifier("solunarHeader")
                Text("Seven days · \(place.timeZoneIdentifier)").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                            Button { selectedDay = index } label: {
                                VStack(spacing: 6) {
                                    Text(index == 0 ? "Today" : time(day.date, format: "EEE"))
                                    Text(time(day.date, format: "MMM d")).font(.caption)
                                    Text(day.illumination, format: .percent.precision(.fractionLength(0)))
                                        .font(.caption.bold())
                                }.padding(10)
                            }.buttonStyle(.bordered)
                                .tint(selectedDay == index ? .teal : .secondary)
                                .accessibilityLabel("\(time(day.date, format: "EEEE MMMM d")), \(day.phaseName)")
                                .accessibilityAddTraits(selectedDay == index ? .isSelected : [])
                                .accessibilityIdentifier("solunarDay\(index)")
                        }
                    }
                }
                if days.indices.contains(selectedDay) {
                    let day = days[selectedDay]
                    Text(day.phaseName).font(.headline).accessibilityIdentifier("moonPhase")
                    Text("\(Int((day.illumination * 100).rounded()))% illuminated at local noon")
                        .font(.caption).foregroundStyle(.secondary)
                    periods(day, kind: .major)
                    periods(day, kind: .minor)
                } else {
                    Text("Solunar estimates are unavailable for this location.")
                }
                Text("Estimated major periods span one hour before and after each moon transit; minor periods span 30 minutes before and after moonrise or moonset. Dates follow each event’s peak; windows may cross midnight. These traditional solunar periods are not a catch forecast. Weather and local water conditions still matter.")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Astronomy credits") {
                    Text(SolunarCalendar.astronomyLicense).font(.caption).foregroundStyle(.secondary)
                }.font(.caption)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func periods(_ day: SolunarDay, kind: SolunarPeriod.Kind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(kind.rawValue) periods").font(.subheadline.bold())
            let periods = day.periods.filter { $0.kind == kind }
            if periods.isEmpty {
                Text("No \(kind == .major ? "moon transit" : "moonrise or moonset") occurs on this local date.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(periods) { period in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(time(period.start, format: "EEE h:mm a")) – \(time(period.end, format: "EEE h:mm a"))")
                        .font(.subheadline.weight(.medium))
                    Text("\(period.event) · \(time(period.peak, format: "h:mm a z"))")
                        .font(.caption).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
            }
        }
    }
    private func time(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = place.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
