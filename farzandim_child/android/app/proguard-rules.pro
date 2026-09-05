# ─────────────────────────────────────────────────────────────────────
# Farzandim Child (Parvoz Growth) — R8/ProGuard keep qoidalari
# ─────────────────────────────────────────────────────────────────────
# R8 (minify + shrinkResources) FAQAT Java/Kotlin (plugin) kodi va Android
# resurslarini qisqartiradi. Dart kodi (libapp.so) TEGILMAYDI. Quyidagi
# qoidalar reflection / manifest orqali chaqiriladigan plugin sinflarini
# saqlaydi — aks holda R8 ularni o'chirib runtime crash bo'lardi.

# ── Ilovaning O'Z native komponentlari — R8 TEGMASIN ──
# UsageStatsPlugin (ilova statistikasi), RestrictionService (ilova cheklovi),
# BootReceiver, DeviceAdminReceiver (o'chirishni taqiqlash) — manifest va
# MethodChannel orqali chaqiriladi. R8 obfuscate/optimize qilsa bu kritik
# funksiyalar (usage-access tekshiruvi, fon xizmat, uninstall himoya) buzilishi
# mumkin. Shuning uchun ilova paketini butunlay saqlaymiz (hajmi arzimas).
-keep class com.farzandim.farzandim_child.** { *; }

# ── Flutter engine ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Firebase (core / auth / messaging / storage) ──
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,Exceptions,InnerClasses,EnclosingMethod

# ── ML Kit barcode (mobile_scanner) — QR skan (qurilma ulash) ──
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# ── CameraX (camera plugin) ──
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ── ExoPlayer / Media3 (just_audio) + audio_service (audiokitob bg audio) ──
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**
-keep class androidx.media.** { *; }
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# ── flutter_foreground_task (fon joylashuv xizmati — manifestdan chaqiriladi) ──
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**

# ── WebView (webview_flutter) — JS interfeysi ──
-keep class * extends android.webkit.WebViewClient { *; }
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }

# ── Google auth (agar ishlatilsa) ──
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── Play Core (Flutter split/deferred referenslari) ──
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── Umumiy: annotatsiya, enum, native, parcelable, serializable ──
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
-keepclassmembers enum * { public static **[] values(); public static ** valueOf(java.lang.String); }
-keepclasseswithmembernames class * { native <methods>; }
-keepclassmembers class * implements android.os.Parcelable { public static final ** CREATOR; }
# ⚠️ `-keep class * implements java.io.Serializable { *; }` OLIB
# TASHLANDI: u har bir kutubxonadagi serializable sinfni saqlab,
# obfuskatsiyaning asosiy to'sig'i edi. Bizda Java serializatsiyasi
# ishlatilmaydi (ma'lumot JSON orqali).
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
}

# ── Kotlin metadata / coroutines ──
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.**

# ── Boshqa plaginlar (geolocator, permission_handler, local_notifications,
#    record) — odatda o'z consumer qoidalarini olib keladi; dontwarn xavfsizlik ──
-dontwarn com.baseflow.**
-dontwarn com.dexterous.**

# ═════════════════════════════════════════════════════════════════════
# 2026-09-05 — R8 QAYTA YOQILDI. Quyidagilar shu paytda qo'shildi.
#
# ⚠️ NEGA R8 ILGARI CRASH BERGAN: bu fayl YOZILGAN, lekin
# build.gradle.kts da `proguardFiles(...)` YO'Q edi — ya'ni R8 uni
# UMUMAN O'QIMASDI va faqat standart qoidalar bilan ishlardi. Natijada
# ilovaning O'Z Kotlin servislari (Accessibility, Device Admin,
# foreground) obfuscate bo'lib native crash berardi. Muammo qoidalarda
# emas, ularning ulanmaganida edi.
# ═════════════════════════════════════════════════════════════════════

# ── Crashlytics (ota-ona ilovasida bor edi, bu yerda yo'q edi) ──
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# ── Manifestda NOM bilan ko'rsatilgan komponentlar ──
# ⚠️ Bu yerda `-keep class * extends Activity/Service/BroadcastReceiver`
# YOZILMAYDI: AGP birlashtirilgan manifestdagi har bir komponent uchun
# keep qoidasini O'ZI yaratadi, ya'ni ular ortiqcha bo'lardi — lekin
# BUTUN kutubxonalarni (AndroidX, Firebase, ExoPlayer...) ham saqlab,
# obfuskatsiyani 3% ga tushirardi. Ilovaning o'z sinflari yuqoridagi
# `com.farzandim.farzandim_child.**` qoidasi bilan saqlanadi.

# ── Audio (fon audiokitob) — MediaBrowserService reflection ishlatadi ──
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.**
-keep class androidx.media.** { *; }
-dontwarn androidx.media.**

# ── Qadam hisoblagich va Health Connect ──
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.connect.**
-keep class cachet.plugins.health.** { *; }
-dontwarn cachet.plugins.health.**

# ── Kotlin coroutines ichki sinflari (fon servislar shularga tayanadi) ──
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory
