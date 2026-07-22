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

// ─── local.properties yoki ENV dan secret kalitlarni o'qish ──────────
// MAPS_API_KEY git'ga commit qilinmaydi. Lokal: local.properties'ga yoziladi.
// CI (GitHub Actions): MAPS_API_KEY env-var sifatida beriladi (local.properties
// yozilmaydi) — shuning uchun env fallback. Topilmasa bo'sh string (xarita
// ishlamaydi, lekin build buzilmaydi).
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        load(FileInputStream(file))
    }
}
val mapsApiKey: String =
    localProperties.getProperty("MAPS_API_KEY")
        ?: System.getenv("MAPS_API_KEY")
        ?: ""

// Himoya: kalit bo'sh bo'lsa xarita plitkalari chiqmaydi (bo'm-bo'sh kulrang).
// Jimgina o'tib ketmasligi uchun build logida ko'rinadigan ogohlantirish beramiz.
if (mapsApiKey.isBlank()) {
    logger.warn(
        "⚠️  MAPS_API_KEY BO'SH — Google Maps plitkalari chiqmaydi. " +
            "Lokalda: android/local.properties'ga MAPS_API_KEY=... yozing. " +
            "CI'da: 'Build parent APK' qadamiga env MAPS_API_KEY: \${{ secrets.MAPS_API_KEY }} bering.",
    )
}

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
            // R8: ishlatilmagan Java/Kotlin (plugin) kodi + resurslarni qisqartirish.
            // Dart kodiga (libapp.so) ta'sir qilmaydi. proguard-rules.pro reflection
            // ishlatadigan pluginlarni (Firebase, ML Kit, camera, webview...) saqlaydi.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Release APK'dan x86_64 native .so'larni chiqaramiz — real telefonlar arm
// (x86_64 = faqat emulyator). --target-platform faqat Flutter libs'ni oladi;
// plugin AAR .so'lari (ML Kit libbarhopper) x86_64'i qoladi — packaging
// darajasida kesamiz. FAQAT release: debug/emulyator TEGILMAYDI.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        variant.packaging.jniLibs.excludes.add("**/x86_64/**")
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
