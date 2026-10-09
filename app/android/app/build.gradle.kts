import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.romaclubmatera.tema"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "it.romaclubmatera.tema"
        // Android 8: icone adattive e sfondo separato per la schermata di blocco
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Home RCM: accesa (pubblica dalla 1.5.0); -PhomeRcm=false la spegne
        manifestPlaceholders["homeRcm"] = (project.findProperty("homeRcm") ?: "true").toString()
    }

    // Stessa chiave delle altre app del Club. key.properties (ignorato da git)
    // dice dove si trova e con quali password; senza, la release si firma con
    // la chiave di debug e va bene solo per provare.
    val firma = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    signingConfigs {
        if (firma.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(firma.getProperty("storeFile"))
                storePassword = firma.getProperty("storePassword")
                keyAlias = firma.getProperty("keyAlias")
                keyPassword = firma.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // le icone sono lette dai launcher per nome: lo shrinking non le
            // vede usate e le toglierebbe (vedi res/raw/keep.xml)
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

dependencies {
    // firma sul telefono del pacchetto di icone per Theme Park (Pacchetto.kt)
    implementation("com.android.tools.build:apksig:8.13.1")
}
