// ─────────────────────────────────────────────────────────────────────
// OemBackgroundService — telefon ishlab chiqaruvchisining «avtomatik ishga
// tushish» sozlamasi (Xiaomi/Redmi, Tecno/Infinix, Honor/Huawei,
// Oppo/Realme, Vivo, Samsung)
// ─────────────────────────────────────────────────────────────────────
//
// Bu qobiqlar Android'ning batareya ruxsatidan tashqari o'z «autostart»
// taqiqini qo'yadi: u o'chiq bo'lsa ilova yopilgach (xotira tozalash,
// telefonni qayta yoqish) Parvoz o'zi qayta ishga tusha olmaydi — bloklash
// to'xtaydi, ota-ona «oflayn» ko'radi (kill-native-no-oem-autostart).
//
// Native — `OemBackgroundHelper`, MethodChannel `farzandim/oem_background`
// (faqat Android):
//   info          → {manufacturer, brand, hasAutostartScreen,
//                    ignoringBatteryOptimizations}
//   openAutostart → bool (sozlama ochildimi)
// Kanal yo'q (iOS, web, eski build) — «mavjud emas».
//
// Tizim sozlama yoqilganini aytmaydi: bola «Yoqdim» deb tasdiqlaydi
// (prefs `oem_autostart_confirmed`). Onboarding'ni hech qachon to'xtatmaydi.

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bola «Yoqdim» deb tasdiqlagan (native'da `flutter.oem_autostart_confirmed`).
const kOemAutostartConfirmedKey = 'oem_autostart_confirmed';

/// Ruxsatlari allaqachon to'liq telefonda ruxsat ekrani avtozapusk uchun bir
/// marta ochilgan (eski o'rnatishlar bu qatorni boshqa yo'l bilan ko'rmaydi).
const kOemAutostartNudgedKey = 'oem_autostart_nudged';

/// Splash: barcha ruxsatlar bor, lekin avtozapusk hali tasdiqlanmagan va
/// eslatma ko'rsatilmagan bo'lsa — ruxsat ekrani BIR MARTA ochiladi.
bool shouldNudgeAutostart({
  required bool hasAutostartScreen,
  required bool confirmed,
  required bool alreadyNudged,
}) => hasAutostartScreen && !confirmed && !alreadyNudged;

class OemBackgroundService {
  const OemBackgroundService({MethodChannel channel = _defaultChannel})
    : _channel = channel;

  static const _defaultChannel = MethodChannel('farzandim/oem_background');

  final MethodChannel _channel;

  /// Telefonda ishlab chiqaruvchining «avtomatik ishga tushish» ekrani bormi.
  Future<bool> hasAutostartScreen() async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      final info = await _channel.invokeMapMethod<Object?, Object?>('info');
      return info?['hasAutostartScreen'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('[oem] info xato: ${e.code}');
      return false;
    }
  }

  /// Sozlama ekranini ochadi. `false` — hech qanday ekran ochilmadi.
  Future<bool> openAutostart() async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openAutostart') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('[oem] openAutostart xato: ${e.code}');
      return false;
    }
  }

  /// Bola avval «Yoqdim» deganmi.
  Future<bool> isAutostartConfirmed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kOemAutostartConfirmedKey) ?? false;
    } on Object catch (e) {
      debugPrint('[oem] tasdiq o\'qilmadi: ${e.runtimeType}');
      return false;
    }
  }

  /// «Yoqdim» — saqlanadi (qayta so'ralmaydi).
  Future<void> confirmAutostart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOemAutostartConfirmedKey, true);
    } on Object catch (e) {
      debugPrint('[oem] tasdiq saqlanmadi: ${e.runtimeType}');
    }
  }
}
