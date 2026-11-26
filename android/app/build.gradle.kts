import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val appPackageName = System.getenv("PACKAGE_NAME")?.trim()?.takeIf { it.isNotEmpty() } ?: "com.feyakit.cinebox"

val releaseKey = rootProject.file("key.properties")
val releaseProperties = Properties()
if (releaseKey.exists()) {
    releaseKey.inputStream().use { releaseProperties.load(it) }
} else {
    mapOf(
        "storeFile" to "ANDROID_KEYSTORE_PATH",
        "storePassword" to "ANDROID_KEYSTORE_PASSWORD",
        "keyAlias" to "ANDROID_KEY_ALIAS",
        "keyPassword" to "ANDROID_KEY_PASSWORD",
    ).forEach { (key, name) -> System.getenv(name)?.let { releaseProperties[key] = it } }
}
val hasReleaseKey = releaseProperties.getProperty("storeFile") != null

android {
    namespace = "com.gomovie"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = appPackageName
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "GoMovie"
        manifestPlaceholders["appBanner"] = "@drawable/tv_banner"
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                val rawStore = requireNotNull(releaseProperties.getProperty("storeFile"))
                storeFile = if (file(rawStore).exists()) file(rawStore) else rootProject.file(rawStore)
                storePassword = requireNotNull(releaseProperties.getProperty("storePassword"))
                keyAlias = requireNotNull(releaseProperties.getProperty("keyAlias"))
                keyPassword = requireNotNull(releaseProperties.getProperty("keyPassword"))
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            // TVBox 的 spider jar 运行时靠 DexClassLoader 继承 com.github.catvod.crawler.Spider，
            // 不 keep 就会在真机上报 "Class not found using the boot class loader"。
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        getByName("profile") {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // TVBox spider jar 通过 DexClassLoader 在运行时链接这些库（R8 看不到引用，
    // 所以 proguard-rules.pro 里同时 keep），缺失会报 Lokhttp3/ConnectionPool 之类。
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.code.gson:gson:2.11.0")
    implementation("org.jsoup:jsoup:1.17.2")
}

flutter { source = "../.." }

tasks.withType<JavaCompile>().configureEach {
    if (name.contains("Release")) {
        doFirst {
            val registrant = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
            if (registrant.exists()) {
                val generated = registrant.readText()
                val integrationPlugin = Regex(
                    """(?s)    try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{[^}]*\}\s*"""
                )
                val release = generated.replace(integrationPlugin, "")
                if (release != generated) registrant.writeText(release)
            }
        }
    }
}
