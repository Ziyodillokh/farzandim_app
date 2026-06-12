// ─────────────────────────────────────────────────────────────────────
// DeviceMeta — "Faol sessiyalar" uchun qurilma modeli + platforma
// ─────────────────────────────────────────────────────────────────────
//
// Login (register/login) so'rovida backendga yuboriladi. Backend uni
// UserSession'ga yozadi va Sozlamalar > Faol sessiyalar ro'yxatida
// ko'rsatadi ("Redmi Note 12S", "iPhone 14 Pro Max", "Chrome (Windows)").

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Qurilma modeli + platforma (`android` | `ios` | `web`).
class DeviceMeta {
  const DeviceMeta({this.deviceModel, this.platform});

  final String? deviceModel;
  final String? platform;

  /// Bo'sh maydonlarni tashlab, request body uchun JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (deviceModel != null && deviceModel!.trim().isNotEmpty)
          'deviceModel': deviceModel!.trim(),
        if (platform != null && platform!.trim().isNotEmpty)
          'platform': platform!.trim(),
      };
}

/// Joriy qurilma ma'lumotini aniqlaydi. Xato bo'lsa bo'sh meta qaytaradi
/// (login baribir ishlaydi — qurilma nomi shunchaki noma'lum bo'ladi).
Future<DeviceMeta> currentDeviceMeta() async {
  final plugin = DeviceInfoPlugin();
  try {
    if (kIsWeb) {
      final web = await plugin.webBrowserInfo;
      final browser = _capitalize(web.browserName.name);
      final os = web.platform?.trim();
      final label = (os != null && os.isNotEmpty)
          ? '$browser ($os)'
          : browser;
      return DeviceMeta(deviceModel: label, platform: 'web');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await plugin.androidInfo;
        return DeviceMeta(
          deviceModel: _androidLabel(a.brand, a.model),
          platform: 'android',
        );
      case TargetPlatform.iOS:
        final i = await plugin.iosInfo;
        // modelName — marketing nomi ("iPhone 14 Pro Max"); bo'lmasa model.
        final label = i.modelName.trim().isNotEmpty ? i.modelName : i.model;
        return DeviceMeta(deviceModel: label, platform: 'ios');
      // Desktop platformalar — qurilma modeli aniqlanmaydi, bo'sh meta
      // (login baribir ishlaydi). `default` emas — yangi platforma
      // qo'shilsa analyzer ogohlantiradi.
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return const DeviceMeta();
    }
  } catch (_) {
    return const DeviceMeta();
  }
}

/// Brand + model — takror bo'lsa (`model` allaqachon brand bilan boshlansa)
/// faqat `model`. Misol: brand=Redmi, model="Redmi Note 12S" →
/// "Redmi Note 12S".
String _androidLabel(String brand, String model) {
  final b = brand.trim();
  final m = model.trim();
  if (m.isEmpty) return b;
  if (b.isEmpty) return m;
  if (m.toLowerCase().startsWith(b.toLowerCase())) return m;
  return '$b $m';
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
