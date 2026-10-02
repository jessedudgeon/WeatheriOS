# Purchasable modules

Basic weather stays free: current conditions, hourly/daily forecasts, weather alerts where supplied, search, optional location, saved places, units, offline weather, and maps. Fishing, Golf, and Lake Erie Fishing are optional non-consumable (one-time) purchases. No subscription or recurring price has been configured.

## Products to create in App Store Connect

| Reference name | Product ID | Unlocks |
| --- | --- | --- |
| Fishing | `jessedudgeon.Weather.module.fishing` | Existing fishing briefing, charts, and daylight windows |
| Golf | `jessedudgeon.Weather.module.golf` | Two-/four-hour daylight weather windows |
| Lake Erie Fishing | `jessedudgeon.Weather.module.lakeErieFishing` | Shore-city planner plus all Fishing functionality |

These IDs are stable. Set the type to **Non-Consumable**, choose real prices and storefront availability, supply localized descriptions and review screenshots, and submit the products with the app. The app displays Apple's localized `displayPrice`; it has no production fallback price or fake checkout. If a product is unavailable, its purchase action is unavailable. Confirm a single multiplatform App Store record/bundle configuration before claiming iPhone/Mac shared purchase availability. Family Sharing is not promised or enabled by the local test configuration.

Lake Erie Fishing is a standalone bundle: it does not require buying Fishing first. If someone already owns Fishing, the regional pack is still full price, with an explicit disclosure. Automatic credits/upgrade discounts are not implemented. Golf is independent. A future task-, item-, or region-specific feature gets its own stable catalog entry and view; add entitlement dependencies intentionally and test them.

## Access and transactions

StoreKit 2 loads products, verifies transactions, listens to `Transaction.updates`, refreshes `Transaction.currentEntitlements` on startup/foreground, handles cancellation/pending/failure, finishes delivered verified transactions, and restores with user-initiated `AppStore.sync()`. Refunded/revoked products no longer grant access. Entitlements are not stored as editable UserDefaults flags. Apple supplies the local signed entitlement history for offline access; a first-time purchase/restore needs connectivity. No server receipt validation or account system is introduced.

All paid entry points check access, including the existing Fishing tab. Unowned users see module details and a store action. Clearing saved weather does not delete purchases. Debug-only `--ui-testing` fixtures can grant module access for navigation tests; `--locked-modules` uses an empty entitlement fixture. `--storekit-testing` disables fixture grants and exercises real local StoreKit. None of these grants exist in Release builds.

## Local testing (no charges)

`WeatherModules.storekit` contains illustrative local test prices: Fishing $4.99, Golf $4.99, Lake Erie Fishing $7.99. These are test values only, not approved launch pricing. The configuration is bundled only with the iOS UI tests, not the shipping app.

For interactive testing in Xcode, edit the Run scheme → Options → StoreKit Configuration and select `WeatherModules.storekit`. Run the app, open Modules, and buy/restore. Use Xcode's transaction manager to refund/revoke or simulate Ask to Buy. Clear transactions between cases. Set the Run configuration back to None before App Store sandbox/TestFlight testing. The repository's standard Run schemes intentionally do not select the local store automatically.

Automated tests cover basic free access, locked navigation, owned modules, catalog inclusion rules, golf window validity, and a local StoreKit purchase → relaunch → restore → refund flow. Check the actual CI result before calling these verified. Additional sandbox acceptance: cancellation, failure, Ask to Buy approval/decline, offline relaunch, account switching, revoking a regional bundle while retaining a separately purchased Fishing product, and physical iOS/macOS purchase/restoration.

## Module data scope

- Golf applies transparent weather preferences, not course access or lightning detection: consecutive daylight hours, temperature 8–32°C, wind <25 km/h, gusts <35 km/h, rain chance <30%, no thunderstorm symbol/code. Stops before known sunset; rejects stale/missing data. Shows up to six non-overlapping windows over 48 hours.
- Lake Erie uses approximate city-center points for Port Clinton, Sandusky, Cleveland, Erie, and Buffalo. Its separate weather model/storage does not replace the user's main selected city. These are shore-city weather forecasts, not offshore wave forecasts. The National Weather Service marine link opens official reports externally. Buoys, waves, water temperature, fishing reports, species guidance, and regulations are not integrated.
- The optional Apple Weather adapter currently lacks the hourly wind/gust/daylight fields needed for hobby windows. The UI reports missing data rather than manufacturing results; Open-Meteo supplies them. Complete adapter parity before advertising equivalent module coverage with both providers.

## Commercial launch blockers

1. The current Open-Meteo forecast AND geocoding paths use the non-commercial free service. Do not release a paid-module app with these defaults. Obtain a commercial plan and implement an appropriate licensed deployment (prefer a backend for a paid API credential), or replace all affected data paths. No commercial account, credential, backend, or paid API subscription has been created here.
2. Configure Apple agreements, tax/banking, App Store products, real prices, signing, sandbox accounts, and review metadata. No real products or merchant accounts were created by this code change.
3. Complete purchase acceptance on devices, publish updated privacy/support pages, and finish the existing app release checklist. This is not a live App Store release.

Sources checked October 1, 2026:
- https://developer.apple.com/documentation/storekit/transaction/currententitlements
- https://developer.apple.com/documentation/storekit/transaction/updates
- https://developer.apple.com/documentation/storekit/appstore/sync()
- https://developer.apple.com/documentation/storekittest/sktestsession
- https://open-meteo.com/en/terms
- https://open-meteo.com/en/pricing
- https://www.weather.gov/cle/marine
