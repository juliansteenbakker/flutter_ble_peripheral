group = "dev.steenbakker.flutter_ble_peripheral"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
}

// AGP 9 provides Kotlin support itself, but only when android.builtInKotlin is
// enabled. Flutter's templates ship AGP 9 with it disabled, so gate on the
// effective property rather than the AGP version alone.
val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()
val builtInKotlin = agpMajor >= 9 &&
    (findProperty("android.builtInKotlin")?.toString() ?: "true").toBoolean()
if (!builtInKotlin) {
    apply(plugin = "kotlin-android")
}

android {
    namespace = "dev.steenbakker.flutter_ble_peripheral"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 21
    }
}

// kotlinOptions is gone in AGP 9. The Kotlin plugin may be applied above, or
// later by the Flutter Gradle Plugin, so configure the extension either way.
fun configureKotlinJvmTarget() {
    extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }
}

if (extensions.findByName("kotlin") != null) {
    configureKotlinJvmTarget()
} else {
    plugins.withId("org.jetbrains.kotlin.android") { configureKotlinJvmTarget() }
}
