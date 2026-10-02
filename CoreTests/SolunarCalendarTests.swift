import XCTest
@testable import WeatherCore

final class SolunarCalendarTests: XCTestCase {
    private let berne = Place(name: "Berne", latitude: 40.6581, longitude: -84.9519,
                              timeZoneIdentifier: "America/Indiana/Indianapolis")
    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    func testIlluminationAgainstPinnedSunCalcReference() {
        // Independent SunCalc 1.9.0 output; covers waning, new and full phases.
        for (iso, fraction, phase) in [
            ("2026-10-02T12:00:00Z", 0.6279445619329418, 0.7088158991804998),
            ("2026-10-10T12:00:00Z", 0.0009425369106514925, 0.9902261075170178),
            ("2026-10-26T12:00:00Z", 0.9972541124030925, 0.5166874685181039)
        ] {
            let light = SolunarCalendar.illumination(at: date(iso))
            XCTAssertEqual(light.fraction, fraction, accuracy: 0.000001)
            XCTAssertEqual(light.phase, phase, accuracy: 0.000001)
        }
    }

    func testRiseSetAgainstReferenceAndLocalDate() throws {
        let day = try XCTUnwrap(SolunarCalendar.days(for: berne, starting: date("2026-10-10T12:00:00Z")).first)
        let rise = try XCTUnwrap(day.periods.first { $0.event == "Moonrise" })
        let set = try XCTUnwrap(day.periods.first { $0.event == "Moonset" })
        // Reference uses quadratic interpolation; our bisection should agree within five minutes.
        XCTAssertEqual(rise.peak.timeIntervalSince1970, date("2026-10-10T11:53:14Z").timeIntervalSince1970, accuracy: 300)
        XCTAssertEqual(set.peak.timeIntervalSince1970, date("2026-10-10T22:59:27Z").timeIntervalSince1970, accuracy: 300)
        XCTAssertEqual(day.date, date("2026-10-10T04:00:00Z"))
        XCTAssertEqual(day.phaseName, "New moon")
        for period in day.periods {
            XCTAssertEqual(period.end.timeIntervalSince(period.start), period.kind == .major ? 7200 : 3600)
        }
    }

    func testDaylightSavingAndEveryEventBelongsToDestinationDate() {
        for (iso, duration) in [("2026-03-08T12:00:00Z", 23.0), ("2026-11-01T12:00:00Z", 25.0)] {
            let days = SolunarCalendar.days(for: berne, starting: date(iso))
            XCTAssertEqual(days.count, 7)
            XCTAssertEqual(days[1].date.timeIntervalSince(days[0].date), duration * 3600)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = berne.timeZone
            for day in days {
                XCTAssertTrue((0...1).contains(day.illumination))
                for period in day.periods {
                    XCTAssertTrue(calendar.isDate(period.peak, inSameDayAs: day.date))
                }
                XCTAssertEqual(Set(day.periods.map(\.id)).count, day.periods.count)
            }
        }
    }

    func testPolarDaysDoNotInventMoonriseAndInvalidCoordinatesReturnNothing() {
        let pole = Place(name: "North Pole", latitude: 90, longitude: 0, timeZoneIdentifier: "UTC")
        let days = SolunarCalendar.days(for: pole, starting: date("2026-10-02T12:00:00Z"), count: 1)
        XCTAssertEqual(days.count, 1)
        XCTAssertTrue(days[0].periods.filter { $0.kind == .minor }.isEmpty)
        XCTAssertFalse(days[0].periods.filter { $0.kind == .major }.isEmpty)
        let bad = Place(name: "Invalid", latitude: .nan, longitude: 0, timeZoneIdentifier: "UTC")
        XCTAssertTrue(SolunarCalendar.days(for: bad, starting: Date()).isEmpty)
        XCTAssertTrue(SolunarCalendar.days(for: berne, starting: Date(), count: -1).isEmpty)
    }

    func testInternationalDateLineUsesSelectedPlaceCalendar() {
        let place = Place(name: "Kiritimati", latitude: 1.87, longitude: -157.43, timeZoneIdentifier: "Pacific/Kiritimati")
        let days = SolunarCalendar.days(for: place, starting: date("2026-10-02T12:00:00Z"))
        XCTAssertEqual(days.first?.date, date("2026-10-02T10:00:00Z"))
    }
}
