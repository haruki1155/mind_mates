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
val productionApplicationId = "ph.edu.ucu.mindmates"
val productionFirebaseAppId = "1:842251480963:android:4c05d169dbacf125eb50b6"
val googleServicesFile = file("google-services.json")
val googleServicesConfigurationError = when {
    !googleServicesFile.isFile ->
        "android/app/google-services.json is required for $productionApplicationId."
    !googleServicesFile.readText().contains("\"package_name\": \"$productionApplicationId\"") ->
        "google-services.json does not match Android package $productionApplicationId."
    !googleServicesFile.readText().contains("\"mobilesdk_app_id\": \"$productionFirebaseAppId\"") ->
        "google-services.json does not match Firebase Android app $productionFirebaseAppId."
    else -> null
}
if (googleServicesConfigurationError != null) {
    throw GradleException(googleServicesConfigurationError)
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
