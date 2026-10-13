plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.stylist"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.stylist"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"
    productFlavors {
        // THE place to change the Android app name, application ID suffix and deep-link scheme.
        // The base application ID is `applicationId` above. See docs/rename-app.md.
        data class Flavor(val suffix: String, val appName: String, val scheme: String)
        mapOf(
            "dev" to Flavor(".dev", "Stylist Dev", "stylist-dev"),
            "staging" to Flavor(".staging", "Stylist Staging", "stylist-staging"),
            "prod" to Flavor("", "Stylist", "stylist"),
        ).forEach { (name, f) ->
            create(name) {
                dimension = "env"
                if (f.suffix.isNotEmpty()) applicationIdSuffix = f.suffix
                resValue("string", "app_name", f.appName)
                manifestPlaceholders["deepLinkScheme"] = f.scheme
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Firebase (Google sign-in). Real files are git-ignored: put google-services.json in
// app/src/<flavor>/ (dev, staging, prod). Until at least one exists the plugin is skipped so mock-mode
// builds keep working. Once you add one, add one for EVERY flavor you build. See docs/rename-app.md.
if (listOf("dev", "staging", "prod").any { file("src/$it/google-services.json").exists() }) {
    apply(plugin = "com.google.gms.google-services")
}
