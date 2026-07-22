# ─────────────────────────────────────────────────────────────────────
# Farzandim Parent — R8/ProGuard keep qoidalari
# ─────────────────────────────────────────────────────────────────────
# R8 (minify + shrinkResources) FAQAT Java/Kotlin (plugin) kodi va Android
# resurslarini qisqartiradi. Ilovaning Dart kodi (libapp.so) TEGILMAYDI.
# Quyidagi qoidalar reflection ishlatadigan pluginlar sinflarini saqlaydi —
# aks holda R8 ularni "ishlatilmagan" deb o'chirib, runtime crash bo'lardi.

# ── Ilovaning O'Z native komponentlari (MainActivity va h.k.) — R8 tegmasin ──
-keep class com.farzandim.parent.** { *; }

# ── Flutter engine (Flutter o'z default qoidalarini ham qo'shadi) ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Firebase (core / analytics / crashlytics / messaging / app_check) ──
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
# Crashlytics: o'qiladigan stack-trace uchun manba fayl + qatorni saqlash
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,Exceptions,InnerClasses,EnclosingMethod
-keep class com.google.firebase.crashlytics.** { *; }

# ── ML Kit barcode (mobile_scanner → libbarhopper) — QR skaner ──
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# ── CameraX (camera plugin) — dumaloq video yozish ──
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ── ExoPlayer / Media3 (just_audio, video_player) ──
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# ── WebView (webview_flutter) — Telegram login JS interfeysi ──
-keep class * extends android.webkit.WebViewClient { *; }
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }

# ── Google / Apple Sign-In ──
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── Play Core (Flutter split/deferred referenslari) — R8 "Missing class" oldini olish ──
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

# ── Boshqa pluginlar (geolocator, permission_handler, local_notifications,
#    record, socket_io) — odatda o'z consumer qoidalarini olib keladi;
#    dontwarn xavfsizlik uchun ──
-dontwarn com.baseflow.**
-dontwarn com.dexterous.**
