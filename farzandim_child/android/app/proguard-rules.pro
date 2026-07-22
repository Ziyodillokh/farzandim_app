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
-keep class * implements java.io.Serializable { *; }

# ── Kotlin metadata / coroutines ──
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.**

# ── Boshqa plaginlar (geolocator, permission_handler, local_notifications,
#    record) — odatda o'z consumer qoidalarini olib keladi; dontwarn xavfsizlik ──
-dontwarn com.baseflow.**
-dontwarn com.dexterous.**
