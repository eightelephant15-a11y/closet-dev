# Placeholders: every value that must be replaced before launch

Nothing below is a secret. Secrets (keys, DSNs, service accounts) are never committed; they are listed under
"Provided at build / deploy time". To find leftovers any time: `git grep -n -e example.com -e REPLACE -e com.example -e PLACEHOLDER`.

## Identity

| Placeholder | Current value | Change it in |
|---|---|---|
| App display name | `Stylist` (`Stylist Dev`, `Stylist Staging`) | Android: `app/android/app/build.gradle.kts` (flavor table). iOS: `app/ios/Flutter/flavors/<flavor>.xcconfig` (`APP_DISPLAY_NAME`). In-app title: `app/lib/core/app_config.dart` (`appName`). Strings that say "Stylist": `app/lib/l10n/app_en.arb` (`appTitle`, `ios*Usage`), then `python3 app/tool/gen_ios_strings.py` |
| Bundle ID / application ID | `com.example.stylist` (+ `.dev`, `.staging`) | Android: `app/android/app/build.gradle.kts` (`namespace`, `applicationId`) and the Kotlin package folder. iOS: `app/ios/Flutter/flavors/<flavor>.xcconfig` (`APP_BUNDLE_ID`). Then `app/tool/measure_startup.sh` (`PKG`), `app/ios/config/*/GoogleService-Info.plist.example`, `app/android/app/src/*/google-services.json.example`, and register the new IDs in Firebase. See [rename-app.md](rename-app.md) |
| Deep-link scheme | `stylist://`, `stylist-dev://`, `stylist-staging://` | Android: flavor table in `build.gradle.kts`. iOS: `DEEP_LINK_SCHEME` in the flavor xcconfig |
| Universal-link domains | `stylist.example.com`, `stylist-dev.example.com`, `stylist-staging.example.com` | iOS: `ASSOCIATED_DOMAIN` in the flavor xcconfig + enable `CODE_SIGN_ENTITLEMENTS` (see the comment there). Android has no App Links host yet: add an `<intent-filter android:autoVerify="true">` with your host in `app/android/app/src/main/AndroidManifest.xml` |
| App icons | Flutter default (Android), generated placeholder (iOS dev/staging get a DEV/STG band) | iOS: replace `app/ios/Runner/Assets.xcassets/AppIcon.appiconset`, then `python3 app/tool/make_flavor_icons.py`. Android: `app/android/app/src/main/res/mipmap-*/ic_launcher.png` (or add per-flavor `src/<flavor>/res`) |
| Launch screen | Flutter default | `app/ios/Runner/Base.lproj/LaunchScreen.storyboard`, `app/android/app/src/main/res/drawable*/launch_background.xml` |
| Colours, type, spacing, radius, motion | Neutral indigo palette, system font | `app/lib/theme/tokens.dart` (one file). A bundled font: add it to `pubspec.yaml` and set `TypeTokens.fontFamily`. Re-run `flutter test test/theme_contrast_test.dart` (fails if text contrast drops below WCAG AA) |

## Legal and policy

| Placeholder | Current value | Change it in |
|---|---|---|
| Privacy policy URL | `https://example.com/privacy` | API runtime config: env `PRIVACY_POLICY_URL` (`api/.env.example`, `infra/envs/<env>/terraform.tfvars` -> `privacy_policy_url`); code defaults in `api/app/core/config.py` and `app/lib/core/app_config.dart` (`privacyUrl`) |
| Terms URL | `https://example.com/terms` | same as above with `TERMS_URL` / `terms_url` |
| Policy version | `2026-01` | env `POLICY_VERSION` (`terraform.tfvars` -> `policy_version`). Bump whenever the policy text changes: it is stored with each user's consents |
| Minimum age | 16 | `api/app/api/v1/config.py` (`MIN_AGE`) and the age-gate strings in `app_en.arb` |

## Backend endpoints

| Placeholder | Current value | Change it in |
|---|---|---|
| Staging API URL | `https://api.staging.example.com` | `app/lib/core/app_config.dart` (staging case) or build with `--dart-define=API_BASE_URL=...` |
| Prod API URL | `https://api.example.com` | `app/lib/core/app_config.dart` (prod case) or `--dart-define=API_BASE_URL=...` |
| Region / AWS account | `us-east-1`, none | `infra/envs/<env>/main.tf` (`region`), AWS profile when running Terraform |
| Terraform state bucket + lock table | `REPLACE-ME-terraform-state` / `REPLACE-ME-terraform-locks` | commented `backend "s3"` block in `infra/envs/<env>/versions.tf` |
| ACM certificate, alert email | none | `infra/envs/<env>/terraform.tfvars` (`certificate_arn`, `alert_email`); copy from `terraform.tfvars.example` |

## Firebase (files are git-ignored; examples show the slot)

| Item | Put the real value here |
|---|---|
| `google-services.json` (Android, per flavor) | `app/android/app/src/<flavor>/google-services.json` (example next to it) |
| `GoogleService-Info.plist` (iOS, per flavor) | `app/ios/config/<flavor>/GoogleService-Info.plist` (example next to it) |
| iOS reversed client ID | `GOOGLE_REVERSED_CLIENT_ID` in `app/ios/Flutter/flavors/<flavor>.xcconfig` (currently `com.googleusercontent.apps.REPLACE_WITH_REVERSED_CLIENT_ID_<FLAVOR>`) |
| Google web client ID | `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` (`app/lib/core/app_config.dart`, used in `bootstrap.dart`) |
| Firebase project ID (API) | env `FIREBASE_PROJECT_ID` (`api/.env.example`, `terraform.tfvars` -> `firebase_project_id`) |
| Firebase Admin service account | AWS Secrets Manager `stylist-<env>/firebase-credentials-json`; locally `GOOGLE_APPLICATION_CREDENTIALS` |

## Provided at build / deploy time (never in git)

| Secret | Where it goes |
|---|---|
| PostHog project key | `--dart-define=POSTHOG_KEY=...` (CI secret for release builds) |
| Sentry DSN (app) | `--dart-define=SENTRY_DSN=...` |
| Sentry DSN (API) | Secrets Manager `stylist-<env>/sentry-dsn`; locally env `SENTRY_DSN` |
| Database URL | generated by Terraform into Secrets Manager `stylist-<env>/database-url` |
| `DEV_AUTH_SECRET` | local only (`make api-local` sets a throwaway value); must never be set in deployed environments |
| AWS deploy role for GitHub Actions | repository secret `AWS_STAGING_DEPLOY_ROLE` (workflow `deploy-staging.yml`, disabled) |
| Anthropic API key | Secrets Manager `stylist-<env>/anthropic-api-key` (only delivered to the worker when `claude_vision_enabled = true`); locally env `ANTHROPIC_API_KEY` for `make eval-vision PROVIDER=claude` |
| `STORAGE_SIGNING_SECRET` | local-disk photo URLs only; has a throwaway default that the settings refuse outside dev/local/test (S3 uses real presigned URLs) |
| Apple signing / Android upload key | not configured; see [go-live-checklist.md](go-live-checklist.md) |

## Intentional test data (not placeholders to replace)

`ada@example.com`, `Ada Lovelace` and `dev-google-ada` in `fake_auth_provider.dart`, `dev_auth_provider.dart`, `api/app/smoke.py` and tests are fixtures for mock and
local modes. `api/app/data/sample_closet.py` and `app/lib/features/closet/data/sample_garments.dart` are the sample closet shown to guests, with flat illustrations in
`app/assets/sample_closet/` drawn by `tool/make_sample_images.py`. Replace them with real photography before launch (keep the file names, or update both lists).
