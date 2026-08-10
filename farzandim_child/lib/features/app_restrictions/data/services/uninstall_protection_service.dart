// ─────────────────────────────────────────────────────────────────────
// UninstallProtectionService — "O'chirishni taqiqlash" (Device Admin)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona `blockUninstall` toggle'ini yoqsa, bola Farzandim ilovasini
// o'chira olmasligi kerak. Buni Android Device Admin ta'minlaydi: admin
// faol bo'lganda Sozlamalarda "O'chirish" tugmasi o'chadi.
//
// Native MethodChannel `farzandim_child/device_admin`:
//   isActive           → admin faolmi (bool)
//   requestActivation  → sistema dialogini ochadi (FOREGROUND shart)
//   removeAdmin        → admin'ni o'chiradi (uninstall ochiladi)

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UninstallProtectionService {
  const UninstallProtectionService();

  static const MethodChannel _channel = MethodChannel(
    'farzandim_child/device_admin',
  );

  // Native `onDisabled` (admin o'chirilganda) shu bayroqni qo'yadi. Dart o'qib
  // ota-onaga xabar beradi, so'ng tozalaydi.
  static const String _deactivatedKey = 'uninstall_guard.deactivated';

  // Native `onEnabled` (admin YOQILGANDA) qo'yadigan bayroq — simmetrik.
  static const String _activatedKey = 'uninstall_guard.activated';

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Admin faolmi (o'chirish taqiqlanganmi).
  Future<bool> isActive() async {
    if (!_isAndroid) return false;
    try {
      return (await _channel.invokeMethod<bool>('isActive')) ?? false;
    } catch (e) {
      debugPrint('UninstallProtection.isActive: $e');
      return false;
    }
  }

  /// Admin'ni yoqish — sistema dialogini ochadi (foydalanuvchi tasdiqlaydi).
  /// FAQAT foreground'da chaqirilishi kerak (Activity kerak).
  ///
  /// Qaytadi: admin dialog CHAQIRILGUNCHA allaqachon faol bo'lganmi.
  /// Dialog natijasi asinxron keladi — uni bilish uchun dialogdan keyin
  /// [isActive] ni qayta o'qing (ekran resume bo'lganda) yoki
  /// [consumeActivatedFlag] dan foydalaning.
  Future<bool> requestActivation() async {
    if (!_isAndroid) return false;
    try {
      return (await _channel.invokeMethod<bool>('requestActivation')) ?? false;
    } catch (e) {
      debugPrint('UninstallProtection.requestActivation: $e');
      return false;
    }
  }

  /// Admin'ni o'chirish — himoya bekor, uninstall ochiladi.
  Future<void> removeAdmin() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('removeAdmin');
    } catch (e) {
      debugPrint('UninstallProtection.removeAdmin: $e');
    }
  }

  /// Siyosatni qo'llaydi: `shouldProtect` true → admin yoqadi (faol bo'lmasa),
  /// false → admin o'chiradi. `allowPrompt` — faollashtirish sistema dialogini
  /// ochishga ruxsatmi (foreground shart). O'chirish (deaktivatsiya) har
  /// doim bajariladi (dialogsiz). `null` siyosat = hech nima (holat saqlanadi).
  ///
  /// Qaytadi: siyosat qo'llangandan keyingi HAQIQIY holat — admin faolmi.
  /// Chaqiruvchi buni backendga yuboradi, shunda ota-ona ilovasida toggle
  /// "istak" emas, qurilmadagi haqiqiy holatni ko'rsatadi.
  ///
  /// ⚠️ Avval bu `Future<void>` edi va `shouldProtect && !active && !allowPrompt`
  /// holatida JIMGINA hech nima qilmasdi — natijada ota-ona toggle'ni yoqsa
  /// ham (bola app'i ochiq turgani uchun dialog chiqmay), himoya AMALDA
  /// yoqilmay qolardi va buni hech kim bilmasdi. Endi holat har doim
  /// qaytariladi.
  Future<bool> apply(bool? shouldProtect, {bool allowPrompt = true}) async {
    if (!_isAndroid) return false;
    var active = await isActive();
    if (shouldProtect == null) return active;
    if (shouldProtect && !active) {
      if (allowPrompt) {
        await requestActivation();
        // Dialog natijasi asinxron — bu yerda hali eski holat bo'lishi mumkin.
        // Ekran resume bo'lganda qayta tekshiriladi (didChangeAppLifecycleState).
        active = await isActive();
      }
    } else if (!shouldProtect && active) {
      await removeAdmin();
      active = await isActive();
    }
    return active;
  }

  /// Bola himoyani (admin'ni) o'chirgan bo'lsa `true` qaytaradi va bayroqni
  /// TOZALAYDI (bir marta xabar berish uchun). Native `onDisabled` qo'ygan.
  Future<bool> consumeDeactivatedFlag() async => _consumeFlag(_deactivatedKey);

  /// Bola admin dialogini TASDIQLAGAN bo'lsa `true` (native `onEnabled`).
  /// Bayroqni tozalaydi — bir martalik signal.
  Future<bool> consumeActivatedFlag() async => _consumeFlag(_activatedKey);

  Future<bool> _consumeFlag(String key) async {
    if (!_isAndroid) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Native tomon prefs'ni to'g'ridan yozgan bo'lishi mumkin — Dart
      // keshini yangilamasak eski qiymat o'qiladi.
      await prefs.reload();
      final v = prefs.getBool(key) ?? false;
      if (v) await prefs.remove(key);
      return v;
    } catch (_) {
      return false;
    }
  }
}

/// Bola app foreground'ga chiqqanda `apply` chaqirilishi kerak (dialog uchun).
const uninstallProtectionService = UninstallProtectionService();
