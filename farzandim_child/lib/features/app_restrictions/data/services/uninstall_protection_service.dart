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

class UninstallProtectionService {
  const UninstallProtectionService();

  static const MethodChannel _channel = MethodChannel(
    'farzandim_child/device_admin',
  );

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
  Future<void> requestActivation() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestActivation');
    } catch (e) {
      debugPrint('UninstallProtection.requestActivation: $e');
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
  /// ochishga ruxsatmi (faqat FOREGROUND'da, app COLD ochilganda true; resume/
  /// taymerda false — dialog loop bo'lmasin). O'chirish (deaktivatsiya) har
  /// doim bajariladi (dialogsiz). `null` siyosat = hech nima (holat saqlanadi).
  Future<void> apply(bool? shouldProtect, {bool allowPrompt = true}) async {
    if (!_isAndroid || shouldProtect == null) return;
    final active = await isActive();
    if (shouldProtect && !active) {
      if (allowPrompt) await requestActivation();
    } else if (!shouldProtect && active) {
      await removeAdmin();
    }
  }
}

/// Bola app foreground'ga chiqqanda `apply` chaqirilishi kerak (dialog uchun).
const uninstallProtectionService = UninstallProtectionService();
