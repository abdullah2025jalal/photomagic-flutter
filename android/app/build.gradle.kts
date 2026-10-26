plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    // (Kotlin is built into AGP 9+ - no separate kotlin-android plugin.)
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.abodycode.photomagic_flutter"
    compileSdk = flutter.compileSdkVersion
    // No ndkVersion: this app is pure Dart + Java/Kotlin plugins, so the
    // NDK is not needed (saves a ~3 GB auto-download).

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.abodycode.photomagic_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Field tools are distributed by sideloading; sign with debug keys
            // for evaluation builds. Replace with your own keystore for store
            // or fleet distribution (see README "Release signing").
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
