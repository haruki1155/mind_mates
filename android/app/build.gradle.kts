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
val configuredApplicationId = providers.gradleProperty("androidApplicationId").orNull
val releaseConfigurationError = when {
    configuredApplicationId.isNullOrBlank() || configuredApplicationId == "com.example.mind_mates" ->
        "Release builds require -PandroidApplicationId with the production package name."
    listOf("keyAlias", "storeFile", "storePassword", "keyPassword")
        .any { signingProperties.getProperty(it).isNullOrBlank() } ->
        "Release builds require android/key.properties with a production keystore."
    else -> null
}

tasks.configureEach {
    if (name == "assembleRelease" || name == "bundleRelease") {
        doFirst {
            if (releaseConfigurationError != null) {
                throw GradleException(releaseConfigurationError)
            }
        }
    }
}

android {
    namespace = "com.example.mind_mates"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = configuredApplicationId ?: "com.example.mind_mates"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val requiredSigningKeys = listOf("keyAlias", "storeFile", "storePassword", "keyPassword")
            val missingSigningKeys = requiredSigningKeys.filter { signingProperties.getProperty(it).isNullOrBlank() }
            if (configuredApplicationId != null &&
                configuredApplicationId != "com.example.mind_mates" &&
                missingSigningKeys.isEmpty()) {
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
