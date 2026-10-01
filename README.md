# Weather

Native SwiftUI weather for iPhone, iPad, and Mac, using Apple WeatherKit. The original 2022 static screen has been replaced with current conditions, a 24-hour forecast, a 10-day outlook, weather alerts, saved places, and optional location access.

## Run

1. Open `Weather.xcodeproj` in Xcode 15 or later (current stable Xcode recommended).
2. Select **Weather-iOS** or **Weather-macOS** and your device/simulator.
3. In Signing & Capabilities, select your Apple Developer team. The existing bundle ID is `jessedudgeon.Weather`; change it only if needed for your developer account.
4. Enable **WeatherKit** for this App ID in Apple Developer → Certificates, Identifiers & Profiles, including the WeatherKit App Service. Refresh provisioning profiles in Xcode. Both targets already contain the WeatherKit entitlement; macOS also has network and location sandbox permissions.
5. Build and run. Search a city or tap the location button. Save frequently used places using **Save this place** below the forecast.

Both app bundles include a required-reason privacy manifest for their own UserDefaults storage (CA92.1).

WeatherKit requires an appropriately provisioned Apple Developer account. There is no API key to paste into source code. Live WeatherKit requests will not succeed until signing and the App ID service are configured. Apple's setup guide: https://developer.apple.com/weatherkit/.

Minimum OS versions: **iOS/iPadOS 16**, **macOS 13**. Existing app bundle identity and signing team were preserved.

## Features

- Current temperature, apparent temperature, condition, humidity, wind, UV, sunrise/sunset.
- Hourly precipitation probability and temperature; daily high/low and precipitation probability.
- Destination time zones, including searched cities outside the device's time zone.
- On-demand approximate location and city/postal-code search; permission denial never blocks search.
- Up to 12 saved places, deletion controls, Fahrenheit/mph or Celsius/km/h, optional playful copy.
- Refresh, last-observation/update times, foreground refresh after 30 minutes, explicit cached/offline display for up to 24 hours.
- WeatherKit alert details with source links; Apple Weather branding and legal attribution.
- Light/dark appearance, adaptive layouts, Dynamic Type, VoiceOver labels, iPad and Mac layouts.
- No accounts, analytics, advertising, background location, third-party dependencies, or backend.

Forecasts are not emergency notifications. Alert availability varies by location and provider response. The app does not send push alerts. Radar, widgets, and a website are outside this native app release.

## Tests

```sh
swift test
xcodebuild -project Weather.xcodeproj -scheme Weather-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Weather.xcodeproj -scheme Weather-macOS \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Choose an installed simulator name using `xcrun simctl list devices available`. GitHub Actions detects one automatically. CI runs the core tests, both Release builds, and deterministic iOS UI tests. Debug UI tests inject a fixture provider and isolated preferences using `--ui-testing`; this path is absent in Release. Tests do not require WeatherKit credentials. Live provider/signing behavior still requires an authorized device test.

## Architecture

`Shared/Core` contains Codable models, unit conversion, cache policy, and bounded persistence, independently testable as a Swift package. `AppleWeatherProvider` adapts WeatherKit behind a protocol. `WeatherViewModel` coordinates cancellable search/fetch operations and guards against out-of-order results. `LocationManager` handles explicit permission requests, cancellation, and timeouts. SwiftUI views render state without making weather requests directly.

See [release checklist](docs/RELEASE.md), [privacy](docs/PRIVACY.md), and [checkpoint](docs/CHECKPOINT.md).
