// ─────────────────────────────────────────────────────────────────────
// PlatformCapabilities — iOS/Android farqlari uchun YAGONA manba
// ─────────────────────────────────────────────────────────────────────
//
// Android'da nazorat UsageStats, overlay, Device Admin, batareya
// optimizatsiyasi va doimiy foreground service orqali ishlaydi. iOS'da bularning
// hech biri yo'q — ilovalarni bloklash va ekran vaqti Apple Family Controls
// (Screen Time API) orqali, QURILMANING O'ZIDA ishlaydi.
//
// Apple Family Controls ruxsati shartlari (2026-09, uz.parvoz.growth):
//   1) nazorat Apple Family Sharing orqali (AuthorizationCenter, .child);
//   2) ilovalardan foydalanish ma'lumoti qurilmadan CHIQMAYDI —
//      iOS'da ilovalar ro'yxati / usage statistikasi serverga YUBORILMAYDI.
//
// `defaultTargetPlatform` ishlatiladi — testlarda
// `debugDefaultTargetPlatformOverride` bilan almashtirish mumkin.

import 'package:flutter/foundation.dart';

abstract final class PlatformCapabilities {
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// UsageStats / overlay / batareya / Device Admin — Android nazorat to'plami.
  static bool get hasAndroidControls => isAndroid;

  /// Ilovalar ro'yxati va ulardan foydalanish statistikasini serverga yuborish.
  /// iOS'da Apple sharti bilan TAQIQLANGAN.
  static bool get canUploadAppUsage => isAndroid;

  /// Qurilmadagi ilovalardan foydalanish statistikasini ilovaning o'zida
  /// ko'rsatish (Android UsageStats). iOS'da bunday ma'lumot yo'q. Web
  /// preview'da UI avvalgidek ko'rinadi (namoyish rejimi).
  static bool get hasAppUsageStats => !isIOS;

  /// Doimiy foreground service (Android). iOS'da fon joylashuvi
  /// geolocator (`allowBackgroundLocationUpdates`) orqali ishlaydi.
  static bool get hasForegroundService => isAndroid;

  /// Health Connect (Android). iOS'da qadamlar CoreMotion (pedometer) orqali.
  static bool get hasHealthConnect => isAndroid;

  /// Ruxsatlar ekrani davom etishni bloklaydimi. Android'da — ha (Google Play
  /// monitoring siyosati). iOS'da — yo'q: Apple 5.1.1 foydalanuvchini
  /// ruxsat berishga majburlashni taqiqlaydi.
  static bool get permissionsAreBlocking => !isIOS;
}
