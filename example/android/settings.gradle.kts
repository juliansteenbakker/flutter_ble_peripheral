pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        checkNotNull(properties.getProperty("flutter.sdk")) {
            "flutter.sdk not set in local.properties"
        }
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.3.2" apply false
    id("org.jetbrains.kotlin.android") version "2.3.21" apply false
}

include(":app")
