// ─────────────────────────────────────────────────────────────────────
// ParentPinStore — "Ekran vaqti" sozlamalarini himoyalovchi ota-ona PIN'i
// ─────────────────────────────────────────────────────────────────────
//
// Cheklanadigan ilovalar tanlovini faqat ota-ona o'zgartirishi uchun (Apple
// Screen Time parolining o'xshashi). PIN Keychain'da (faqat shu qurilma);
// 5 marta xato kiritilsa 5 daqiqaga bloklanadi — 4 xonali PIN'ni terib
// topish amalda imkonsiz bo'ladi. Keychain ilova o'chirilganda ham qoladi,
// shuning uchun yangi o'rnatishda va uzishda (unpair) tozalanadi.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PinCheckResult { ok, wrong, locked }

class ParentPinStore {
  ParentPinStore({FlutterSecureStorage? storage, DateTime Function()? clock})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            ),
        _clock = clock ?? DateTime.now;

  static const pinLength = 4;
  static const maxAttempts = 5;
  static const lockDuration = Duration(minutes: 5);

  static const _pinKey = 'screenTime.parentPin.v1';
  static const _failuresKey = 'screenTime.pinFailures.v1';
  static const _lockedUntilKey = 'screenTime.pinLockedUntil.v1';

  /// SharedPreferences ilova o'chirilganda yo'qoladi, Keychain esa yo'q —
  /// shu belgi bo'lmasa bu yangi o'rnatish, eski PIN tozalanadi.
  static const _installMarkerKey = 'screenTime.installMarker.v1';

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  bool _installChecked = false;

  static bool isValidFormat(String pin) =>
      RegExp('^\\d{$pinLength}\$').hasMatch(pin);

  Future<bool> hasPin() async {
    await _clearIfFreshInstall();
    return (await _storage.read(key: _pinKey)) != null;
  }

  Future<void> setPin(String pin) async {
    if (!isValidFormat(pin)) {
      throw ArgumentError.value(pin, 'pin', '$pinLength ta raqam kerak');
    }
    await _clearIfFreshInstall();
    await _storage.write(key: _pinKey, value: pin);
    await _resetFailures();
  }

  /// Bloklanish tugashiga qolgan vaqt; bloklanmagan bo'lsa null.
  Future<Duration?> lockRemaining() async {
    final raw = await _storage.read(key: _lockedUntilKey);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null) return null;
    final left = until.difference(_clock());
    return left.isNegative || left == Duration.zero ? null : left;
  }

  Future<PinCheckResult> verify(String pin) async {
    await _clearIfFreshInstall();
    if (await lockRemaining() != null) return PinCheckResult.locked;
    final stored = await _storage.read(key: _pinKey);
    if (stored != null && _constantTimeEquals(stored, pin)) {
      await _resetFailures();
      return PinCheckResult.ok;
    }
    final failures =
        (int.tryParse(await _storage.read(key: _failuresKey) ?? '') ?? 0) + 1;
    if (failures >= maxAttempts) {
      await _storage.write(
        key: _lockedUntilKey,
        value: _clock().add(lockDuration).toIso8601String(),
      );
      await _storage.delete(key: _failuresKey);
      return PinCheckResult.locked;
    }
    await _storage.write(key: _failuresKey, value: '$failures');
    return PinCheckResult.wrong;
  }

  /// Uzish (unpair) paytida.
  Future<void> clear() async {
    await _storage.delete(key: _pinKey);
    await _resetFailures();
  }

  Future<void> _resetFailures() async {
    await _storage.delete(key: _failuresKey);
    await _storage.delete(key: _lockedUntilKey);
  }

  Future<void> _clearIfFreshInstall() async {
    if (_installChecked) return;
    _installChecked = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_installMarkerKey) ?? false) return;
    await clear();
    await prefs.setBool(_installMarkerKey, true);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
