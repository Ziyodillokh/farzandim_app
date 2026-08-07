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
    namespace = "com.farzandim.farzandim_child"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uchun core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Google Play'da `com.farzandim.child` band bo'lib chiqdi (boshqa
        // egada), shuning uchun Play uchun paket `com.farzandim.growth`
        // (ilova nomi "Parvoz Growth"ga mos). MUHIM: bu o'zgarganda
        // `google-services.json` ichida SHU paket ro'yxatdan o'tgan bo'lishi
        // shart — aks holda Gradle "No matching client found" bilan yiqiladi.
        // Kotlin namespace (com.farzandim.farzandim_child) o'zgarmaydi.
        applicationId = "com.farzandim.growth"
        minSdk = 28
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
            // ⚠️ R8 minify HOZIRCHA O'CHIQ (barqarorlik uchun). R8 reflection
            // ishlatadigan plugin sinflarini obfuscate/o'chirib, ba'zi kod
            // yo'llarida KUTILMAGANDA native crash ("ilova ishdan chiqdi")
            // berardi (bola app tasodifiy yopilardi). Boshqa hajm
            // optimizatsiyalari (assets WebP, x86_64 chiqarish, o'lik dep)
            // SAQLANGAN — faqat R8 qismi (~11MB) qaytdi. proguard-rules.pro
            // qoldi (kelajakda qurilmada sinovdan keyin qayta yoqish uchun).
            // MUHIM: minify=false bilan shrinkResources ham OSHKORA false
            // bo'lishi shart — aks holda Flutter gradle plugin/AGP uni yoqib
            // "Removing unused resources requires code shrinking" build xatosi
            // beradi (--no-shrink bayrog'i o'zi yetmaydi).
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// Release APK'dan x86_64 native .so'larni chiqaramiz — real telefonlar arm
// (x86_64 = faqat emulyator). --target-platform faqat Flutter libs'ni oladi;
// plugin AAR .so'lari (pdfium, ML Kit libbarhopper) qoladi — shuni packaging
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // FarzandimMessagingService (native "ring" FCM ushlovchisi) firebase-messaging
    // SDK klasslariga (RemoteMessage, FirebaseMessagingService) TO'G'RIDAN kirishi
    // kerak. firebase_messaging Flutter plugin ularni faqat `implementation`
    // sifatida beradi, shuning uchun app modulida ko'rinmaydi. firebase_core
    // ishlatadigan BoM versiyasi bilan bir xil (33.16.0) — ziddiyat yo'q.
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    implementation("com.google.firebase:firebase-messaging")
}
