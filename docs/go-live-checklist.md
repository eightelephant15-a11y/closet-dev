# Go-live checklist (mock -> real services)

Ordered. Do not skip ahead: each step's "Success" is the entry condition for the next. Nothing here has been run (it needs your accounts and a
real device); every command is copy-paste. Values in `<angle brackets>` are yours. Never paste secrets into chat, tickets or git.

Time estimate: Firebase 30 min, local API against Firebase 20 min, device tests 45 min, AWS staging 2 to 3 hours the first time.

---

## 0. Baseline: the repo is healthy on your machine

```bash
make setup && make test && make api-local        # terminal 1
make api-smoke                                   # terminal 2
```

**Success:** tests pass, the smoke test prints `17/17 passed`. (macOS: accept the Xcode license once with `sudo xcodebuild -license`.)

## 1. Choose the final identity

1. Decide the app name and the real bundle ID, e.g. `com.yourco.stylist`.
2. Apply them using [rename-app.md](rename-app.md), then re-check [placeholders.md](placeholders.md).
3. `git grep -n com.example` should only show the `*.example` files and docs.

**Success:** `make apk-dev` builds and the installed app shows the new name; `applicationId` ends with `.dev` for the dev flavor.

## 2. Create the Firebase project(s)

1. console.firebase.google.com > **Add project** (`<app>-dev`; do staging and prod later or use one project per environment).
2. **Build > Authentication > Get started > Sign-in method**: enable **Google** (set the support email) and **Anonymous**.
3. **Project settings > General > Your apps**: add an Android app and an iOS app per flavor, with exactly these IDs:
   dev `<base>.dev`, staging `<base>.staging`, prod `<base>`.

**Success:** Authentication shows Google and Anonymous as *Enabled*; the Apps list shows the apps with the correct IDs.

## 3. Android: fingerprints and `google-services.json`

```bash
# debug key (used by `flutter run`)
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | grep -E "SHA1|SHA-256"
# or for every variant:
cd app/android && ./gradlew signingReport
```

1. Paste the **SHA-1 and SHA-256** into each Android app (Project settings > your Android app > Add fingerprint). Do the same later for your upload/release key and, if you use Play App Signing, the Play-signing key.
2. Download `google-services.json` per flavor into `app/android/app/src/<flavor>/google-services.json` (git-ignored; examples sit beside them).
3. Download a file for **every flavor you build** (the Gradle plugin is skipped only while none exist).

**Success:** `make apk-dev` still builds; `unzip -p app/build/app/outputs/flutter-apk/app-dev-debug.apk resources.arsc | strings | grep -c <your-project-id>` is non-zero (Firebase values were merged).

## 4. iOS: plist and reversed client ID

1. Download `GoogleService-Info.plist` per flavor into `app/ios/config/<flavor>/GoogleService-Info.plist` (git-ignored).
2. Open each plist, copy `REVERSED_CLIENT_ID` into `GOOGLE_REVERSED_CLIENT_ID` in `app/ios/Flutter/flavors/<flavor>.xcconfig`.
3. Build: `make ios-dev` (unsigned) or run from Xcode with your team selected for real devices.

**Success:** `ls app/build/ios/iphoneos/Runner.app/GoogleService-Info.plist` exists; the build log has no "GoogleService-Info.plist not found" warning;
`/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' app/build/ios/iphoneos/Runner.app/Info.plist` lists your reversed client ID.

## 5. Google sign-in client ID

Firebase console > Authentication > Sign-in method > Google > **Web SDK configuration > Web client ID**. Use it as:
`--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>` for every real build (add it to your run configs and CI).

**Success:** you will see it work in step 8; without it Android sign-in fails with "serverClientId must be provided" or error code 10.

## 6. Firebase Admin credentials for the API

1. Firebase console > Project settings > **Service accounts > Generate new private key**. Keep the file outside the repo.
2. `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json` and `export FIREBASE_PROJECT_ID=<project-id>`.

**Success:** step 7 returns 200 for a real token.

## 7. Run the local API against real Firebase

```bash
export AUTH_MODE=firebase APP_ENV=dev
make api-local             # same SQLite + migrations, but verifies real Firebase ID tokens
curl -s localhost:8000/v1/config | head -c 300
```

**Success:** `/v1/config` returns JSON; the console banner says `AUTH_MODE=firebase (real Firebase tokens)`. (`make api-smoke` is expected to fail here: it needs dev tokens.)

## 8. First manual test on a real device (Google sign-in + guest upgrade)

Phone and laptop on the same Wi-Fi. Find the laptop's IP (`ipconfig getifaddr en0`), start the API with `HOST=0.0.0.0 make api-local`, then:

```bash
cd app && flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://<laptop-ip>:8000 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>
```

(Android debug builds allow cleartext http; iOS allows local-network http. Staging/prod must use https.)

| # | Do this | Success looks like |
|---|---|---|
| 1 | Fresh install, open the app | Welcome screens; "Try it first" and "Sign in with Google" visible. API log shows `GET /v1/config 200` |
| 2 | Tap **Sign in with Google**, choose an account | Google sheet appears, then the age gate. API log: `POST /v1/auth/session 200` |
| 3 | Cancel the Google sheet once | Back on Welcome, no error toast |
| 4 | Sign out (finish onboarding first or kill and use Settings) and tap **Try it first** | Age gate appears. Firebase console > Authentication > Users shows a new **Anonymous** user |
| 5 | Confirm 16+, answer the quiz (pick Womenswear, Slim, two colours, Work), fill basics (name "Test", city Austin), allow permissions, "Use sample closet", see the first outfit | Three outfits with "why" lines; none contain items you excluded |
| 6 | Tap **Save outfit** | Sign-in sheet appears (guest only) |
| 7 | Continue with Google | Outfit saved. Firebase Users: the **same** anonymous user row now has the Google provider (no second user). Settings shows your email, not "guest account" |
| 8 | Open Settings > Privacy choices | AI-training switch ON, analytics shows your earlier choice |
| 9 | Kill the app mid-quiz in a new account, reopen | Resumes on the same question with answers kept |
| 10 | Sign in on a second device or emulator with the same Google account | Lands on your current step with quiz answers restored |
| 11 | Settings > Export my data > Request export > Download and share | A `my-data.json` share sheet; the file contains your profile city and quiz answers |
| 12 | Settings > Delete my account (type DELETE) | Back to Welcome; sign in again shows "scheduled for deletion" with **Restore my account**; restoring returns you to Home |
| 13 | Turn on airplane mode during the quiz, finish a few questions, turn it off | Queue empties on reconnect (API log shows `PUT /v1/me/preferences`, `PUT /v1/onboarding`) |

If step 7 creates a second Firebase user, check that linking uses the same anonymous session (do not sign out between guest start and save).

## 9. PostHog and Sentry

**PostHog** (US cloud): create a project, copy the **Project API key** (starts `phc_`). Build with `--dart-define=POSTHOG_KEY=<key>`.
**Success:** after opting in to analytics and walking steps 1 to 5 above, the Live events view shows `welcome_viewed` ... `first_outfit_viewed` with
`time_to_first_outfit_ms`; with analytics declined, **no** events arrive. Create the funnel from [analytics.md](analytics.md).

**Sentry**: create two projects (Flutter, Python/FastAPI), copy both DSNs.
App: `--dart-define=SENTRY_DSN=<flutter-dsn>`. API: `SENTRY_DSN=<api-dsn>` (locally) or the Secrets Manager entry (AWS, step 10).
**Success (API):** `python -c "import sentry_sdk; sentry_sdk.init(dsn='<api-dsn>'); sentry_sdk.capture_message('go-live test')"` appears in Sentry within a minute.
**Success (app):** `sentry-cli send-event -m "go-live test" --dsn <flutter-dsn>` appears; for a real crash, temporarily throw in a dev build and confirm the stack trace is symbolicated (upload debug symbols for release builds).

## 10. AWS staging (plan first, review, then apply)

Details in [../infra/README.md](../infra/README.md).

1. Use a **dedicated AWS account** for staging; enable MFA, set a budget alert (about $60/month to start).
2. Create the state bucket + lock table once, then uncomment `backend "s3"` in `infra/envs/staging/versions.tf`.
3. `cp infra/envs/staging/terraform.tfvars.example infra/envs/staging/terraform.tfvars` and fill it in.
4. Plan, and **read it**:

```bash
cd infra/envs/staging
aws sso login --profile <staging-profile> && export AWS_PROFILE=<staging-profile>
terraform init
terraform plan -out tfplan
```

Review checklist: only `create` actions (no `destroy`); one VPC, 2+2 subnets, 1 NAT, one `aws_db_instance` (not publicly accessible, encrypted), one Redis group,
one S3 bucket with all four public-access blocks, 2 empty secrets + 1 generated DB secret, an ECS cluster/service/ALB, 2 EventBridge rules (purge daily, exports every 15 min).
Anything unexpected: stop and ask before applying.

5. `terraform apply tfplan` (only after the review), then:

```bash
aws secretsmanager put-secret-value --secret-id stylist-staging/sentry-dsn --secret-string '<api-dsn>'
aws secretsmanager put-secret-value --secret-id stylist-staging/firebase-credentials-json --secret-string file://service-account.json
```

6. Build and push the API image (immutable tag), run migrations as a one-off ECS task, then roll out the service (see `infra/README.md` "Deploying a new API version").

**Success:** `curl http://<alb_dns_name>/health` returns `{"status":"ok"}`; `curl .../v1/config` returns flags; ECS service shows 1/1 running;
CloudWatch log group `/ecs/stylist-staging-api` shows request lines; no alarms in ALARM. Run step 8 again with `API_BASE_URL=http://<alb_dns_name>`
(add a certificate + domain before real users: staging without TLS is for testing only).

## 11. Device checks

### Cold start under 2 seconds

Android: `app/tool/measure_startup.sh prod 10`. iPhone: Instruments > App Launch (see [performance.md](performance.md)).
**Success:** median under 2000 ms on both a mid-range Android and an iPhone 12 or newer.

### TalkBack walkthrough (Android: Settings > Accessibility > TalkBack)

| Screen | Do | Success looks like |
|---|---|---|
| Welcome | Swipe right through elements | Hears "Page 1 of 3" + title/body, then "Skip", "Try it first, button", "Sign in with Google, button" |
| Age gate | Swipe through | Heading, explanation, two buttons; no unlabeled elements |
| Quiz | Move to an option, double-tap | Announces "Womenswear, not selected" then "selected"; "Question 1 of 6" is announced; Next stays disabled until answered |
| Colours | Swipe through | Each colour is announced by name (not "unlabeled"); selected state spoken |
| Permission primer | Swipe | Reason text is read before the Allow/Not now buttons |
| First items | Swipe | The ring is announced as "N of 10 items"; the unlock checklist is readable |
| First outfit | Swipe | Each card announced as "Outfit N", items and the "why" line read in order; Save outfit is a button |
| Settings > Delete | Try confirmation | Field label "Type DELETE to confirm"; button announces disabled state |

### VoiceOver walkthrough (iOS: Settings > Accessibility > VoiceOver)

Repeat the same table. Additionally: rotor headings navigation (Welcome title, Quiz question, Settings sections should appear as headings);
the back-swipe gesture on the quiz returns to the previous card via the Back button; dialogs trap focus.

### Dynamic type / display size

iOS: Settings > Accessibility > Display & Text Size > Larger Text (max). Android: Display size and font size at largest.
**Success:** no clipped or overlapping text on any onboarding screen; every button remains tappable (scrolling is fine). Automated coverage:
`app/test/accessibility_test.dart` (100/150/200%, light and dark).

## 12. Finish

1. Enable the deploy workflow: remove `if: false` in `.github/workflows/deploy-staging.yml`, add the repository secret `AWS_STAGING_DEPLOY_ROLE` (OIDC role).
2. Branch protection on `main`: require the CI jobs (`api lint + mypy + pytest`, `app format + analyze + test`, `terraform fmt + validate`, iOS and Android builds, secret scan).
3. Replace remaining placeholders ([placeholders.md](placeholders.md)), update [checklist.md](checklist.md) statuses from "Blocked" to "Verified (manual)" with the date.

**Success:** a fresh clone passes CI, a staging deploy is one click, and every step 8 row passed on a real device.
