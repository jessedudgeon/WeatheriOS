# Release checklist

## Live data and location

- [ ] Select the owning Apple Developer team and confirm the existing bundle ID is registered.
- [ ] Open-Meteo is the default: verify no-key forecast loading. Review provider terms before commercial distribution.
- [ ] Only if using Apple Weather: enable WeatherKit capability AND its App Service for the identifier; regenerate provisioning.
- [ ] Build on a physical iPhone and verify Open-Meteo weather and attribution load.
- [ ] Verify precipitation/wind map layers, forecast timeline, retry, and browser fallback.
- [ ] Verify fishing charts, daylight windows, and stale-data behavior; do not label these as bite or safety predictions.
- [ ] Verify location Allow Once, While Using, denied, disabled Location Services, and timeout paths.
- [ ] Search Berne, London, and a city across the date line; verify destination-local forecast times.
- [ ] Save/relaunch/remove cities; change units; delete stored data; verify no old place returns.
- [ ] Switch cities rapidly and search while a prior search runs; confirm no outdated result replaces selection.
- [ ] Disable network after a forecast loads; verify saved-data label, retry, and expiry after 24 hours.
- [ ] Verify supported alerts link to the issuing source and unsupported alerts are not presented as all-clear.

## Presentation and distribution

- [ ] Inspect small iPhone, iPad portrait/landscape, and macOS window layouts.
- [ ] Test VoiceOver, largest accessibility text sizes, light/dark mode, and keyboard search.
- [ ] Supply final AppIcon assets (the original repository contains empty icon slots).
- [ ] Confirm the dynamic Apple Weather mark and legal attribution with Apple's current publishing requirements.
- [ ] Review privacy copy and App Store privacy answers against Apple's WeatherKit/location terms.
- [ ] Add screenshots, support URL, hosted privacy policy, age rating, and App Store metadata.
- [ ] Archive/validate using distribution signing, upload to TestFlight, perform device acceptance, then submit.

These are release gates, not claims of completed testing. No Apple Developer credentials, signing assets, or App Store access were supplied for this implementation.
