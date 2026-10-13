# Firebase setup (needs your accounts; nothing here is done yet)

1. Create Firebase projects (e.g. `stylist-dev`, `stylist-staging`, `stylist-prod`). Enable **Authentication**
   with the **Google** provider and **Anonymous** (guest mode).
2. Register the apps with their bundle IDs / application IDs:
   `com.example.stylist.dev`, `com.example.stylist.staging`, `com.example.stylist` (replace the placeholder
   `com.example` once the final ID is chosen: Gradle flavors in `app/android/app/build.gradle.kts`, iOS
   bundle identifiers, and the URL scheme in `Info.plist`).
3. Download `google-services.json` into `app/android/app/src/<flavor>/` and `GoogleService-Info.plist` into
   `app/ios/config/<flavor>/` (both are git-ignored) and apply the `com.google.gms.google-services` Gradle
   plugin / add the plist build phase. Android also needs the SHA-1/SHA-256 of your signing keys registered
   for Google sign-in.
4. iOS: add the reversed client ID from the plist as a URL scheme.
5. API: create a service account (Firebase Admin). Locally set `GOOGLE_APPLICATION_CREDENTIALS`; in AWS put
   the JSON in the `*/firebase-credentials-json` secret (see `infra/README.md`).
6. Optional local development: run the Firebase Auth emulator and set `FIREBASE_AUTH_EMULATOR_HOST` for the
   API (Admin SDK honours it).

`google_sign_in` 7.x requires `GoogleSignIn.instance.initialize(...)` with the server client ID before the
first sign-in; wire that in `FirebaseAuthProvider` once the project exists.
