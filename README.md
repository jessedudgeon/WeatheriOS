# Weather

Native SwiftUI forecasts, precipitation/wind maps, and a fishing-weather briefing for iPhone, iPad, and Mac.

## Run without WeatherKit setup

1. Open `Weather.xcodeproj` in Xcode 15 or later (CI uses Xcode 16.4).
2. Select **Weather-iOS** or **Weather-macOS**. Choose your Apple signing team for a physical device, or run in an iPhone simulator.
3. Build and run. Tap **Try Berne, Indiana**, search for a city, or tap **Use my location**.

**Open-Meteo is the default forecast provider and requires no API key for personal/non-commercial use.** Forecasts, maps, and fishing weather do not require paid WeatherKit provisioning. Open-Meteo's free service has usage limits and is not licensed for commercial/subscription/ad-supported use; review https://open-meteo.com/en/terms before distribution or monetization.

Minimum OS versions: iOS/iPadOS 16 and macOS 13. The original bundle ID is preserved as `jessedudgeon.Weather`.

## Location troubleshooting

- **iPhone simulator:** choose **Features → Location → Custom Location** in Simulator. A simulator does not have a physical GPS fix. You can use latitude `40.6581`, longitude `-84.9519` for Berne. Alternatively, use city search or the Berne quick-start button.
- **iPhone/iPad:** allow Weather under Settings → Privacy & Security → Location Services. The app's Location Settings button opens its settings page.
- **Mac:** enable Location Services and allow Weather in System Settings → Privacy & Security → Location Services. Keep Wi-Fi enabled to help macOS locate the computer. Mac builds include the network/location sandbox permissions.
- Location runs only after a button press. The app waits up to 25 seconds after permission is granted, tolerates temporary `locationUnknown` errors, stops after a usable fix, and provides an actionable error. Forecast fetching starts immediately from coordinates and does not wait for reverse geocoding.
- Search remains usable when location permission is denied. Open-Meteo/GeoNames search is tried first, with Apple geocoding as a fallback for addresses/postal codes.

## Forecast, Maps, Fishing

**Forecast:** current/modelled conditions, hourly outlook, 10-day forecast, precipitation probability, wind, humidity, UV, sunrise/sunset, saved places, unit settings, and optional playful copy. Open-Meteo's daily maximum UV is explicitly labeled. Forecast timestamps use the destination time zone.

**Maps:** interactive Windy/ECMWF precipitation and surface-wind layers centered on the selected place, with a forecast timeline, unit selection, provider attribution, retry, and browser fallback. Precipitation is a forecast layer, not live radar. Opening the Maps view loads Windy's embedded map and sends it the selected coordinates.

**Fishing:** wind/gust and pressure charts, wind direction, local sunrise/sunset, air temperature, rain probability/amount, and upcoming calmer/drier daylight windows. Windows require at least two contiguous forecast hours with wind <20 km/h, gusts <30 km/h, rain chance <30%, daylight, and no forecast thunderstorm symbol/code. Missing data does not count as calm/dry, and stale/cached forecasts do not produce trip suggestions. These are transparent planning filters, not a bite prediction or a boating-safety determination. Water temperature, lake levels, tides, and species-specific activity are not supplied by these weather APIs.

Offline forecasts remain labeled as saved; data older than 24 hours is not displayed. Settings can remove individual places or all stored places/forecasts. No accounts, app analytics, ads, or background location tracking.

## Optional Apple Weather

The WeatherKit adapter is retained. To use it, add the **WeatherKit** capability to your target in Xcode, enable its capability and App Service for your App ID in Apple Developer, and refresh provisioning profiles. Then choose **Apple Weather** in the app's Settings. The default entitlements do not demand WeatherKit, so the Open-Meteo path can run without it. If Apple Weather fails, the app explains how to switch back to Open-Meteo. Setup: https://developer.apple.com/weatherkit/.

Apple Weather supplies source-linked alerts when available. Open-Meteo does not supply official alerts; the app explicitly reports that limitation. Neither mode sends emergency notifications.

## Test

```sh
swift test
xcodebuild -project Weather.xcodeproj -scheme Weather-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Weather.xcodeproj -scheme Weather-macOS \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Choose an installed simulator using `xcrun simctl list devices available`. CI selects one automatically. Core tests cover persistence, cache expiry, units, live-response decoding, incomplete API responses, map URLs, fishing filters, and pressure trends. UI tests cover first launch, saved-data deletion, Maps/Fishing navigation, and a real Open-Meteo forecast without WeatherKit credentials. Fixture-only tests use `--ui-testing`; the explicit live test uses `--live-weather-test`. Both launch hooks exist only in Debug builds.

See [checkpoint](docs/CHECKPOINT.md), [release checklist](docs/RELEASE.md), and [privacy](docs/PRIVACY.md).

## Optional modules

Basic forecasts, search, saved places, and maps stay free. The Modules tab offers one-time Fishing, Golf, and Lake Erie Fishing purchases through StoreKit 2, with restoration and verified access. Lake Erie Fishing includes general Fishing; Golf is separate. Real prices appear only when Apple returns configured products. Until then, purchases are shown as unavailable.

See [module setup and testing](docs/MODULES.md) for the local StoreKit configuration, product IDs, coverage, and commercial release blockers. The current free Open-Meteo service must be replaced with an appropriately licensed data deployment before releasing paid features.
