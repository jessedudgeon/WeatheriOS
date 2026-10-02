import Foundation

struct SolunarPeriod: Identifiable {
    enum Kind: String { case major = "Major", minor = "Minor" }
    var id: Date { peak }
    let kind: Kind
    let event: String
    let peak: Date
    var start: Date { peak.addingTimeInterval(kind == .major ? -3600 : -1800) }
    var end: Date { peak.addingTimeInterval(kind == .major ? 3600 : 1800) }
}

struct SolunarDay: Identifiable {
    var id: Date { date }
    let date: Date
    let illumination: Double
    let phase: Double
    let periods: [SolunarPeriod]
    var phaseName: String {
        let names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
                     "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        return names[Int((phase * 8).rounded()) % 8]
    }
}

/// Low-precision astronomical estimates; not a prediction of fish activity.
/// Coordinates/illumination adapted from SunCalc 1.9.0 (BSD-2-Clause).
/// See astronomyLicense below. Event search uses the destination's actual civil day.
enum SolunarCalendar {
    private static let rad = Double.pi / 180
    private static let obliquity = 23.4397 * rad

    static func days(for place: Place, starting date: Date, count: Int = 7) -> [SolunarDay] {
        guard place.isValid, date.timeIntervalSince1970.isFinite else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        let start = calendar.startOfDay(for: date)
        return (0..<max(0, min(count, 31))).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let end = calendar.date(byAdding: .day, value: 1, to: day),
                  let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) else { return nil }
            let light = illumination(at: noon)
            return SolunarDay(date: day, illumination: light.fraction, phase: light.phase,
                              periods: events(from: day, to: end, place: place))
        }
    }

    private struct Coordinates {
        let ra: Double
        let dec: Double
        let distance: Double
    }
    private static func daysSinceJ2000(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545
    }
    private static func coordinates(longitude l: Double, latitude b: Double, distance: Double) -> Coordinates {
        Coordinates(ra: atan2(sin(l) * cos(obliquity) - tan(b) * sin(obliquity), cos(l)),
                    dec: asin(sin(b) * cos(obliquity) + cos(b) * sin(obliquity) * sin(l)), distance: distance)
    }
    private static func moon(_ d: Double) -> Coordinates {
        let meanLongitude = rad * (218.316 + 13.176396 * d)
        let anomaly = rad * (134.963 + 13.064993 * d)
        let distanceAngle = rad * (93.272 + 13.229350 * d)
        return coordinates(longitude: meanLongitude + rad * 6.289 * sin(anomaly),
                           latitude: rad * 5.128 * sin(distanceAngle), distance: 385001 - 20905 * cos(anomaly))
    }
    static func illumination(at date: Date) -> (fraction: Double, phase: Double) {
        let d = daysSinceJ2000(date)
        let anomaly = rad * (357.5291 + 0.98560028 * d)
        let correction = rad * (1.9148 * sin(anomaly) + 0.02 * sin(2 * anomaly) + 0.0003 * sin(3 * anomaly))
        let sun = coordinates(longitude: anomaly + correction + rad * 102.9372 + .pi, latitude: 0, distance: 149598000)
        let m = moon(d)
        let cosine = sin(sun.dec) * sin(m.dec) + cos(sun.dec) * cos(m.dec) * cos(sun.ra - m.ra)
        let separation = acos(max(-1, min(1, cosine)))
        let incidence = atan2(sun.distance * sin(separation), m.distance - sun.distance * cos(separation))
        let angle = atan2(cos(sun.dec) * sin(sun.ra - m.ra),
                          sin(sun.dec) * cos(m.dec) - cos(sun.dec) * sin(m.dec) * cos(sun.ra - m.ra))
        return ((1 + cos(incidence)) / 2, 0.5 + 0.5 * incidence * (angle < 0 ? -1 : 1) / .pi)
    }
    private static func position(at date: Date, place: Place) -> (horizon: Double, transit: Double, upper: Bool) {
        let d = daysSinceJ2000(date)
        let m = moon(d)
        let hourAngle = rad * (280.16 + 360.9856235 * d + place.longitude) - m.ra
        let latitude = place.latitude * rad
        let sine = sin(latitude) * sin(m.dec) + cos(latitude) * cos(m.dec) * cos(hourAngle)
        let altitude = asin(max(-1, min(1, sine)))
        let h = max(0, altitude)
        let refraction = 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179))
        return (altitude + refraction - 0.133 * rad, sin(hourAngle), cos(hourAngle) >= 0)
    }
    private static func events(from start: Date, to end: Date, place: Place) -> [SolunarPeriod] {
        var result: [SolunarPeriod] = []
        // Five-minute bracketing followed by bisection. Scan actual 23/24/25-hour days.
        var left = start
        while left < end {
            let right = min(left.addingTimeInterval(300), end)
            let a = position(at: left, place: place)
            let b = position(at: right, place: place)
            for isTransit in [false, true] {
                let av = isTransit ? a.transit : a.horizon
                let bv = isTransit ? b.transit : b.horizon
                guard (av <= 0 && bv > 0) || (av >= 0 && bv < 0) else { continue }
                var low = left
                var high = right
                for _ in 0..<16 {
                    let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
                    let p = position(at: mid, place: place)
                    let value = isTransit ? p.transit : p.horizon
                    if (value >= 0) == (av >= 0) { low = mid } else { high = mid }
                }
                let peak = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
                guard peak >= start, peak < end else { continue }
                let event = isTransit ? (position(at: peak, place: place).upper ? "Moon upper transit" : "Moon lower transit")
                    : (av < bv ? "Moonrise" : "Moonset")
                result.append(SolunarPeriod(kind: isTransit ? .major : .minor, event: event, peak: peak))
            }
            left = right
        }
        return result.sorted { $0.peak < $1.peak }
    }
}

extension SolunarCalendar {
    static let astronomyLicense = """
Astronomy adapted from SunCalc 1.9.0 (https://github.com/mourner/suncalc).

Copyright (c) 2014, Vladimir Agafonkin
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice, this list of
      conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice, this list
      of conditions and the following disclaimer in the documentation and/or other materials
      provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

"""
}
