import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kioku.app"
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
        applicationId = "com.kioku.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    val isCi = System.getenv("CI") != null || System.getenv("GITHUB_ACTIONS") != null
    val requireSigned = project.hasProperty("requireReleaseSigning") || isCi

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { path -> file(path) }
                storePassword = keystoreProperties.getProperty("storePassword")
            } else if (System.getenv("KIOKU_KEY_ALIAS") != null) {
                keyAlias = System.getenv("KIOKU_KEY_ALIAS")
                keyPassword = System.getenv("KIOKU_KEY_PASSWORD")
                storeFile = System.getenv("KIOKU_KEYSTORE_FILE")?.let { path -> file(path) }
                storePassword = System.getenv("KIOKU_STORE_PASSWORD")
            } else if (requireSigned) {
                throw GradleException("FATAL: Release signing config missing: key.properties not found and CI/production signing secrets are required.")
            } else {
                logger.warn("WARNING: key.properties not found. Using local dev signing config. Configure android/key.properties before store publishing.")
                val debugConfig = signingConfigs.getByName("debug")
                keyAlias = debugConfig.keyAlias
                keyPassword = debugConfig.keyPassword
                storeFile = debugConfig.storeFile
                storePassword = debugConfig.storePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
