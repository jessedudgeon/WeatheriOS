# Weather privacy

Weather has no account system, advertising, app analytics, or background location tracking.

When you explicitly request your location, Apple's location services provide coordinates. The app requests kilometer-level accuracy; actual precision is controlled by the OS. It listens briefly for a usable fix and then stops. Forecast requests send selected coordinates to Open-Meteo by default, or to Apple Weather if that optional provider is selected. The forecast provider also receives ordinary network request information such as your IP address.

City/postal-code searches go to Open-Meteo's geocoding service (GeoNames data), with Apple geocoding as a fallback. Tapping Load precipitation & wind map on the weather dashboard loads a Windy embedded map and sends the selected location, units, and layer to Windy; the map can contact its own map/tile providers. The map uses an ephemeral web-data store. No map is loaded until you tap its Load button. Solunar calculations run entirely on-device and do not contact another provider.

Saved places, coordinates, settings, and recent forecasts are stored in the app's preferences on this device. They may be included in device backups according to device settings. Forecasts older than 24 hours are not displayed and are pruned on later successful updates. Settings → Delete saved places and weather removes local places and weather caches. Individual removal deletes that place's cached forecast. Unit, provider, and personality preferences remain until app data is reset.

The UserDefaults required-reason privacy manifest declares access to the app's own preferences (CA92.1). This does not replace review of App Store privacy labels or third-party provider terms before distribution.

Provider policies and attribution:
- Open-Meteo: https://open-meteo.com/en/terms (including its server-log retention policy).
- GeoNames: https://www.geonames.org/.
- Apple: https://www.apple.com/legal/privacy/.
- Windy embed: https://embed.windy.com/; map/provider attribution remains visible in the embedded map.

Opening source, alert, policy, or support links contacts those websites under their policies. Project support: https://github.com/jessedudgeon/WeatheriOS/issues. Avoid sharing private coordinates or credentials in public issues.

Review and host this policy at a public URL before App Store distribution.
