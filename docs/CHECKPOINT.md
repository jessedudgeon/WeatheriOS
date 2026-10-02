# Weather completion checkpoint — 2026-10-01

## Starting state

Repository main `cee0c82`: two 2022 commits; a static SwiftUI weather screen; no weather service, models, location/search, persistence, docs, or meaningful tests. Both iOS and macOS targets existed. There were no repository AGENTS.md instructions.

## Implemented

Live WeatherKit adapter and injectable provider; core forecast/place models; weather dashboard; 24-hour and 10-day forecasts; metrics; source-linked weather alerts; Apple attribution; search and optional location with permission/timeout handling; saved places; unit/personality settings; bounded local cache and delete controls; stale/offline labels; destination time zones; request cancellation and result identity checks; iOS 16/macOS 13 deployment floors; entitlements; shared schemes; core and UI tests; GitHub Actions; setup/privacy/release docs.

## Verification status

Local verification passed: all 13 Swift files parsed with tree-sitter-swift with zero syntax errors; the Xcode project parsed with pbxproj; entitlement plists and shared scheme XML parsed; source membership and generator idempotence checks passed; git diff whitespace validation passed. These are structural/syntax checks, not Swift type-checking or native execution.

GitHub publication was explicitly approved on 2026-10-01. The branch was uploaded through the authorized GitHub connection because terminal Git authentication is unavailable. PR: https://github.com/jessedudgeon/WeatheriOS/pull/1.

Native CI at commit `920a11f`, using Xcode 16.4 on macOS 15:
- iOS Simulator Release build: passed.
- macOS Release build: passed.
- Swift core tests: all 11 passed, zero failures.
- iPhone simulator UI tests: running at this checkpoint; consult PR checks for the latest result.

Added the UserDefaults required-reason privacy manifest (`CA92.1`) to both application bundles after release review. Local resource-membership, plist, and generator-idempotence checks passed. The follow-up CI run must verify packaging. PR events now run branch CI once, while pushes to main retain post-merge checks.

This editing environment has no Xcode, simulator, Apple signing credentials, or authorized live WeatherKit access. Simulator fixtures validate app flows without claiming live-provider acceptance. No App Store or TestFlight release has occurred.

## Remaining release gates

Configure Apple Developer WeatherKit service/provisioning, verify real forecasts and location permissions on devices, supply release icon assets, finish manual accessibility/device QA, and archive/TestFlight/App Store submission. See RELEASE.md for concrete checks. No store release has occurred.

## Live-data correction, Maps and Fishing

User reported the app launched but could not load weather or location. WeatherKit provisioning was a dependency in the original path; Open-Meteo is now the default no-key provider, and WeatherKit is opt-in. Default entitlements no longer require WeatherKit. Forecast API returned a real Berne response with 240 hourly samples and 10 daily samples during development. City search also has an Open-Meteo/GeoNames path.

Location fixes: permission-prompt time is excluded from the fix timeout, transient locationUnknown errors keep listening, usable coordinates immediately trigger weather without waiting for reverse geocoding, and platform-specific recovery/settings guidance is displayed. Actual device OS permissions and hardware fixes still need on-device confirmation.

Added Maps (Windy ECMWF precipitation forecast and surface wind) and Fishing (wind/gust and pressure charts, sunrise/sunset, rain, air temperature, and transparent daylight weather-window filters). No live-radar, water-temperature, tide, lake-level, or fish-activity claims are made.

At `6a13ee0`, both Release builds and all 21 core tests passed. The Debug UI build exposed an over-complex fixture expression; the fixture was broken into typed local arrays. The next CI run must confirm Debug compilation, real Open-Meteo loading in the simulator, and Maps/Fishing navigation. Prior baseline CI `628ab78` had all four jobs green, including simulator UI tests. See PR #1 checks for current status.

## Verified acceptance — October 1, 2026 (Indianapolis)

CI run https://github.com/jessedudgeon/WeatheriOS/actions/runs/36944008363 at `b2eb2f4` passed both native Release builds, all 21 core tests, and all 10 iPhone simulator UI executions. The UI suite confirmed a real no-key Open-Meteo forecast, native location permission/coordinate delivery, denied-location search recovery, Maps/Fishing navigation, saved-data deletion, and first-launch behavior. Live search returned Berne, Indiana, and both Windy map endpoints returned HTTP 200.

Retrieved and inspected CI screenshots of the live forecast and fishing briefing. Adjusted hourly/daily cloud-symbol contrast in light mode and added the end weekday to fishing-window labels. Physical-device positioning, map interaction, landscape/dynamic-type review, final app icons, and distribution signing remain release checks. No claim of App Store/TestFlight release.

## Follow-up — fishing boundaries and adaptable forecast rows

Confirmed the final previous revision `68fffff` passed all four CI jobs in run 36945062320. Continued on the existing PR branch.

- Fishing windows now stop at a supplied local sunset and at the advertised 24-hour horizon. A window shortened below two hours is discarded before selecting up to three results. When sunset is unavailable, the existing hourly daylight flags remain the fallback.
- Map loading/error state now resets for every URL change, including a different place or units, as well as a different layer.
- Daily forecast rows can stack their date/condition and temperature groups when horizontal space is insufficient, with explicit high/low labels.
- Added three regression tests for sunset clipping, minimum duration, and the 24-hour boundary.

Local diff checks passed; this Linux session has no Swift/Xcode. Native builds and automated tests for this follow-up must be checked in PR CI. Physical-device acceptance, final icons, and signing/distribution remain outstanding.

## Purchasable modules — October 1, 2026

Continued from merged main `1623616` on `codex/purchasable-modules`. Added a stable module catalog and StoreKit 2 non-consumable purchase/restore/access lifecycle. Basic weather and maps remain free; existing Fishing is gated, Golf adds round-length weather windows, and Lake Erie Fishing adds a shore-city planner and includes general Fishing. Added local StoreKit configuration, entitlement/golf regression tests, locked/owned UI tests, and a local purchase/relaunch/restore/refund UI test. Native CI must verify this change; no local Xcode runtime is available.

See MODULES.md for exact product IDs, illustrative test-only prices, access rules, data limitations, and App Store setup. Real prices/products and commercial weather licensing remain unconfigured. No paid launch or App Store submission occurred.
