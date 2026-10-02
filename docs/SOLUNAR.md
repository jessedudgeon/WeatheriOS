# Solunar fishing calendar

The dashboard offers seven civil dates in the selected place's time zone. Calculations are local and independent of network weather freshness. No additional API, account, payment, or key is needed. Paid hobby/location modules and any StoreKit catalog are deferred to a future patch; none is exposed in this release.

## Method

Moon coordinates and illuminated fraction are adapted from the BSD-2-Clause SunCalc 1.9.0 algorithms: https://github.com/mourner/suncalc/blob/v1.9.0/suncalc.js. The original license is retained in the Swift source and exposed through Astronomy credits in the app. Phase names use the nearest eighth of the lunar cycle; percent illumination is evaluated at local noon.

Rise/set use apparent moon altitude and SunCalc's 0.133-degree horizon convention. Major centers are actual upper/lower meridian crossings (hour angle), not fixed clock times or a fixed 12-hour offset from moonrise. Five-minute brackets and bisection locate events. The search follows Calendar day boundaries, including 23- and 25-hour DST days. No rise/set is manufactured on polar dates without a crossing.

Major windows extend one hour either side of a transit; minor windows extend 30 minutes either side of rise/set. These durations are explicit traditional planning conventions, not statistically calibrated fish-activity forecasts. The event peak determines its calendar date. Full weekday labels show when a window crosses midnight. Time-zone abbreviation is shown on the event peak, including DST changes.

This is low-precision astronomy: terrain, horizon obstructions, observer elevation, detailed lunar perturbations, and atmospheric variation are not modeled. Times are approximate, especially at extreme latitudes. This does not establish fishing success, water conditions, or boating safety. Existing weather filters remain separately labeled.

## Verification

Core regression coverage compares illumination and rise/set against the version-pinned JavaScript reference, checks destination dates, DST boundaries, international date line, polar missing events, invalid coordinates, and period lengths. UI coverage exercises the consolidated dashboard, inline map layer switch, and changing calendar day. Native compilation and simulator results must be checked in PR CI.
