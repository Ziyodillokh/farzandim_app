import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ─── local.properties dan secret kalitlarni o'qish ───────────────────
// MAPS_API_KEY git'ga commit qilinmaydi — har dev/build mashinasida
// qo'lda yozish kerak. Topilmasa bo'sh string — bu holda xarita
// ishlamaydi, lekin build muvaffaqiyatli bo'ladi.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        load(FileInputStream(file))
    }
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY", "")

// ─── Release signing (H6) — key.properties dan o'qiladi (git'ga kirmaydi) ──
// Fayl mavjud bo'lsa release build shu keystore bilan imzolanadi; bo'lmasa
// debug imzo ishlatiladi (keystoresiz mashinada build buzilmasligi uchun).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // Release APK build'da lint bloklamasin (CI'da LintClassLoader xatosini oldini oladi)
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
    namespace = "com.farzandim.parent"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uchun core library desugaring.
        // https://developer.android.com/studio/write/java8-support
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.farzandim.parent"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Google Maps SDK 21 dan boshlab ishlaydi — explicit qiymat
        // bilan o'rnatamiz (flutter default 21+ bo'lsa ham, kafolat).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AndroidManifest.xml ichidagi ${MAPS_API_KEY} placeholder'ni
        // build paytida shu qiymatga almashtiradi.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties mavjud bo'lsa — release keystore; aks holda debug
            // (keystore yo'q mashinada `flutter run --release` ishlashi uchun).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring — flutter_local_notifications majburiy qiladi
    // (Android API 26-dan past versiyalarda Java 8+ API'larni emulyatsiya).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
