# Renaming the app and changing the bundle ID

The app ships as `Stylist` with the placeholder base ID `com.example.stylist`. Flavors add a suffix:

| Flavor | Display name | Android applicationId | iOS bundle ID | Deep-link scheme |
|---|---|---|---|---|
| dev | Stylist Dev | `com.example.stylist.dev` | `com.example.stylist.dev` | `stylist-dev://` |
| staging | Stylist Staging | `com.example.stylist.staging` | `com.example.stylist.staging` | `stylist-staging://` |
| prod | Stylist | `com.example.stylist` | `com.example.stylist` | `stylist://` |

Change these in **exactly these places**, then rebuild.

## Android (`app/android/app/build.gradle.kts`)

* **Base ID**: `namespace = "com.example.stylist"` and `applicationId = "com.example.stylist"` (both lines,
  top of the `android { }` block). If you change `namespace`, also move the Kotlin package folder
  `android/app/src/main/kotlin/com/example/stylist/` and its `package` line in `MainActivity.kt`.
* **Per-flavor name, ID suffix, deep-link scheme**: the `mapOf("dev" to Flavor(...), ...)` block inside
  `productFlavors { }`.

## iOS (`app/ios/Flutter/flavors/<flavor>.xcconfig`)

One file per flavor, containing everything that differs:

* `APP_DISPLAY_NAME`: the name under the icon
* `APP_BUNDLE_ID`: the bundle identifier (RunnerTests derives `<id>.RunnerTests` from it)
* `ASSETCATALOG_COMPILER_APPICON_NAME`: `AppIcon` (prod), `AppIcon-dev`, `AppIcon-staging`
* `DEEP_LINK_SCHEME`, `GOOGLE_REVERSED_CLIENT_ID` (**placeholder** until Firebase exists), `ASSOCIATED_DOMAIN`
  (**placeholder**), `CODE_SIGN_ENTITLEMENTS` (see "Universal links" below)

Nothing about name or bundle ID is hard-coded in the Xcode project or `Info.plist`; they read these variables.

## Dart / app side

* `app/lib/core/app_config.dart`: `appName` per flavor (used for the in-app window title only).
* Strings shown to users (including the iOS permission texts) live in `app/lib/l10n/app_en.arb`. After editing
  the three `ios*Usage` keys run `python3 app/tool/gen_ios_strings.py`.

## Firebase files (never committed)

| Platform | Put the real file here | Slot / example |
|---|---|---|
| Android | `app/android/app/src/<flavor>/google-services.json` | n/a |
| iOS | `app/ios/config/<flavor>/GoogleService-Info.plist` | `GoogleService-Info.plist.example` next to it |

Register each flavor's app in Firebase with that flavor's **bundle ID / applicationId**. The iOS build copies the plist
into the app automatically when it exists; when it does not, the build prints a warning and carries on (mock mode).
After you have the plist, copy its `REVERSED_CLIENT_ID` into `GOOGLE_REVERSED_CLIENT_ID` in the flavor xcconfig.

## Universal links (optional)

`ios/Runner/Runner.entitlements` declares `applinks:$(ASSOCIATED_DOMAIN)`. It is not applied until you set
`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` in the flavor xcconfig, because it needs the Associated Domains capability on
your App ID and an `apple-app-site-association` file on your domain. Custom-scheme deep links
(`stylist://onboarding/resume`) work without any of that.

## Icons

Replace `app/ios/Runner/Assets.xcassets/AppIcon.appiconset` with the real icon set, then
`python3 app/tool/make_flavor_icons.py` regenerates the badged dev/staging variants. Android launcher icons are the
Flutter defaults under `android/app/src/main/res/mipmap-*`.

## Re-applying the iOS flavor setup

`make ios-flavors-setup` (idempotent) re-runs `app/tool/setup_ios_flavors.rb`, the icon generator and the strings generator.
Note: `make` on macOS needs the Xcode license accepted once: `sudo xcodebuild -license`.
