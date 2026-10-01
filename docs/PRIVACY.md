# Weather privacy

Weather has no account system, advertising, third-party analytics, or background location tracking.

When you explicitly request your location, Apple's location services provide coordinates. The app requests kilometer-level accuracy; the actual precision is controlled by the OS. Coordinates are sent to Apple WeatherKit to request forecasts. City and postal-code searches are sent to Apple's geocoding service. Reverse geocoding sends requested coordinates to Apple to display a place name.

Saved places, coordinates, settings, and recent forecasts are stored locally in the app's preferences. These may be included in device backups according to device settings. Forecasts older than 24 hours are not displayed and are pruned on subsequent successful updates. Settings → Delete saved places and weather removes the app's locally stored places and weather cache. Removing an individual saved place removes its cached forecast. Units/personality preferences remain until app data is reset.

Opening an alert, attribution, privacy, or support link contacts the destination website, whose own privacy policy applies. Apple processes weather/search/location requests under its policies: https://www.apple.com/legal/privacy/.

Project support: https://github.com/jessedudgeon/WeatheriOS/issues. Do not include private coordinates or account credentials in public issue reports.

Review this policy and host it at a public URL before App Store distribution.
