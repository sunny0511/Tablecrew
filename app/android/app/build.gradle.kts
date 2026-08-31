plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tablecrew.android"
    // Pinned rather than inherited from flutter.compileSdkVersion (2026-08-31).
    // A plugin in the current dependency set requires 37, and the Gradle build
    // says so explicitly: "Fix this issue by compiling against the highest
    // Android SDK version (they are backward compatible)." compileSdk only
    // affects what APIs are compiled against, not the minimum device supported
    // — minSdk below is what governs that — so raising it is backward
    // compatible, as the message states.
    //
    // Pinning is also consistent with Recommendation R5's "pin exact versions"
    // convention. The cost is that this no longer tracks the Flutter SDK
    // automatically: when Flutter's own default moves past 37, this line has
    // to move with it, and a plugin needing something newer will fail loudly
    // rather than silently picking it up.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tablecrew.android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
