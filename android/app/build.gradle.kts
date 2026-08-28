import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}
val productionApplicationId = "com.example.mind_mates"
val stagingApplicationId = "com.example.mind_mates.staging"
val stagingFirebaseAppId = "1:978195258114:android:36354078e3d99999f5801b"

// The Google Services plugin resolves this file from src/<flavor>/.
// Validate the tester-facing staging variant explicitly so it can never fall
// back to production Firebase configuration.
tasks.configureEach {
    if (name.startsWith("processStaging") && name.endsWith("GoogleServices")) {
        doFirst {
            val stagingGoogleServices = file("src/staging/google-services.json")
            if (!stagingGoogleServices.isFile) {
                throw GradleException("android/app/src/staging/google-services.json is required for staging builds.")
            }
            val contents = stagingGoogleServices.readText()
            if (!contents.contains("\"project_id\": \"mindmate-staging\"") ||
                !contents.contains("\"package_name\": \"$stagingApplicationId\"") ||
                !contents.contains("\"mobilesdk_app_id\": \"$stagingFirebaseAppId\"")) {
                throw GradleException("Staging google-services.json does not match the registered staging Android app.")
            }
        }
    }
}
val requiredSigningKeys = listOf("keyAlias", "storeFile", "storePassword", "keyPassword")
val missingSigningKeys = requiredSigningKeys.filter { signingProperties.getProperty(it).isNullOrBlank() }
val configuredStoreFile = signingProperties.getProperty("storeFile")
val releaseConfigurationError = when {
    missingSigningKeys.isNotEmpty() ->
        "Release builds require android/key.properties with keyAlias, storeFile, storePassword, and keyPassword."
    configuredStoreFile == null || !rootProject.file(configuredStoreFile).isFile ->
        "Release signing keystore not found at android/${configuredStoreFile ?: "<missing storeFile>"}."
    else -> null
}

tasks.configureEach {
    if (name == "preReleaseBuild" || name == "assembleRelease" || name == "bundleRelease") {
        doFirst {
            if (releaseConfigurationError != null) {
                throw GradleException(releaseConfigurationError)
            }
        }
    }
}

android {
    namespace = productionApplicationId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = productionApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("development") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
        }
        create("production") {
            dimension = "environment"
        }
    }

    buildTypes {
        release {
            if (releaseConfigurationError == null) {
                signingConfig = signingConfigs.create("release") {
                    keyAlias = signingProperties.getProperty("keyAlias")
                    storeFile = rootProject.file(signingProperties.getProperty("storeFile"))
                    storePassword = signingProperties.getProperty("storePassword")
                    keyPassword = signingProperties.getProperty("keyPassword")
                }
            }
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
