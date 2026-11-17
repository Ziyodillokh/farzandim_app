// Ilova qulfi (PIN-kod): bola o'zi qo'yadigan 4 xonali kod — ilova ochilganda
// va fonda belgilangan vaqtdan ko'p turgach qaytganda so'raladi (Telegram
// kabi). Butun qurilma uchun bitta (akkauntlardan qat'i nazar).
//
// PIN o'zi saqlanmaydi: xavfsiz xotirada (Keychain / KeyStore) tasodifiy tuz
// bilan SHA-256 xeshi. 5 ta xato urinishdan keyin kutish (30 s, har keyingi
// xatoda ikki baravar, ko'pi bilan 15 daqiqa); hisob ilova qayta ochilganda
// ham saqlanadi. Unutilsa — telefonning o'z qulfi (barmoq izi / ekran kodi)
// bilan tasdiqlab, kod o'chiriladi.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PIN uzunligi.
const kPinLength = 4;

/// Shuncha xatodan keyin kutish boshlanadi.
const kPinFreeAttempts = 5;

const _kFirstBlock = Duration(seconds: 30);
const _kMaxBlock = Duration(minutes: 15);

/// Fondan qaytganda qachon qulflanadi.
enum AutoLock {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5));

  const AutoLock(this.after);

  final Duration after;

  static AutoLock fromWire(String? value) => AutoLock.values.firstWhere(
    (a) => a.name == value,
    orElse: () => AutoLock.oneMinute,
  );
}

/// Kod tekshiruvi natijasi.
enum PinCheck { ok, wrong, blocked }

/// Kalit–qiymat xotira (testda — xotirada).
abstract interface class LockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureLockStore implements LockStore {
  const SecureLockStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

class AppLock extends ChangeNotifier {
  AppLock(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Ilova bo'ylab yagona qulf (ildiz va «Men» bo'limi bir obyektni ko'radi).
  static final instance = AppLock(const SecureLockStore());

  static const _pinKey = 'g5_lock_pin_v1';
  static const _bioKey = 'g5_lock_bio_v1';
  static const _autoKey = 'g5_lock_auto_v1';
  static const _failKey = 'g5_lock_fail_v1';
  static const _untilKey = 'g5_lock_until_v1';

  final LockStore _store;
  final DateTime Function() _clock;

  String? _record;
  bool _biometrics = false;
  AutoLock _autoLock = AutoLock.oneMinute;
  int _failures = 0;
  DateTime? _blockedUntil;
  bool _locked = false;
  DateTime? _pausedAt;
  bool _systemAuth = false;

  bool get isEnabled => _record != null;

  /// Hozir qulf ekrani ko'rinishi kerak.
  bool get isLocked => isEnabled && _locked;

  bool get biometrics => _biometrics;
  AutoLock get autoLock => _autoLock;

  /// Kutish tugaydigan vaqt (`null` — urinish mumkin).
  DateTime? get blockedUntil {
    final until = _blockedUntil;
    return until != null && until.isAfter(_clock()) ? until : null;
  }

  /// Ilova ishga tushganda: kod bo'lsa — darhol qulflangan.
  Future<void> load() async {
    try {
      _record = await _store.read(_pinKey);
      _biometrics = await _store.read(_bioKey) == 'true';
      _autoLock = AutoLock.fromWire(await _store.read(_autoKey));
      _failures = int.tryParse(await _store.read(_failKey) ?? '') ?? 0;
      final until = await _store.read(_untilKey);
      _blockedUntil = until == null ? null : DateTime.tryParse(until);
    } on Object catch (e) {
      // O'qib bo'lmasa — qulfsiz ochiladi (bola ilovasiz qolmasin).
      debugPrint('[lock] o\'qilmadi: ${e.runtimeType}');
    }
    _locked = isEnabled;
    notifyListeners();
  }

  /// Yangi kod (o'rnatish yoki almashtirish). Qulf ochiq holatda qoladi.
  Future<void> setPin(String pin) async {
    assert(pin.length == kPinLength);
    final salt = base64Encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    _record = '$salt:${_hash(salt, pin)}';
    _locked = false;
    await _store.write(_pinKey, _record);
    await _resetFailures();
    notifyListeners();
  }

  /// Qulf ekranidagi kod: to'g'ri bo'lsa ochiladi.
  Future<PinCheck> unlock(String pin) async {
    final result = await verify(pin);
    if (result == PinCheck.ok) {
      _locked = false;
      notifyListeners();
    }
    return result;
  }

  /// Kodni tekshiradi (sozlamalarda o'zgartirish / o'chirishdan oldin ham);
  /// xatolar umumiy hisobga qo'shiladi.
  Future<PinCheck> verify(String pin) async {
    if (blockedUntil != null) return PinCheck.blocked;
    final record = _record;
    if (record == null) return PinCheck.ok;
    final i = record.indexOf(':');
    if (i > 0 &&
        _hash(record.substring(0, i), pin) == record.substring(i + 1)) {
      await _resetFailures();
      return PinCheck.ok;
    }
    _failures++;
    if (_failures >= kPinFreeAttempts) {
      final extra = _failures - kPinFreeAttempts;
      final wait = _kFirstBlock * (1 << extra.clamp(0, 5));
      _blockedUntil = _clock().add(wait > _kMaxBlock ? _kMaxBlock : wait);
    }
    await _store.write(_failKey, '$_failures');
    await _store.write(_untilKey, _blockedUntil?.toIso8601String());
    notifyListeners();
    return _blockedUntil != null && _blockedUntil!.isAfter(_clock())
        ? PinCheck.blocked
        : PinCheck.wrong;
  }

  /// Barmoq izi / telefon qulfi tasdiqlangach.
  void unlockTrusted() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  /// Kodni o'chirish (sozlamalarda yoki «unutdim» — telefon qulfi bilan).
  Future<void> disable() async {
    _record = null;
    _biometrics = false;
    _locked = false;
    await _store.write(_pinKey, null);
    await _store.write(_bioKey, null);
    await _resetFailures();
    notifyListeners();
  }

  Future<void> setBiometrics(bool value) async {
    _biometrics = value;
    await _store.write(_bioKey, value ? 'true' : null);
    notifyListeners();
  }

  Future<void> setAutoLock(AutoLock value) async {
    _autoLock = value;
    await _store.write(_autoKey, value.name);
    notifyListeners();
  }

  /// Ilova fonga o'tdi.
  void onBackground() {
    if (_systemAuth) return;
    _pausedAt ??= _clock();
  }

  /// Telefonning tasdiq oynasi (barmoq izi / ekran kodi) ilovani fonga
  /// o'tkazishi mumkin — shu oyna tufayli qaytish qayta qulflamaydi.
  Future<T> duringSystemAuth<T>(Future<T> Function() action) async {
    _systemAuth = true;
    try {
      return await action();
    } finally {
      _systemAuth = false;
      _pausedAt = null;
    }
  }

  /// Ilova qaytdi: fonda [autoLock] dan ko'p turgan bo'lsa — qulflanadi.
  void onForeground() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (!isEnabled || _locked || pausedAt == null) return;
    if (_clock().difference(pausedAt) >= _autoLock.after) {
      _locked = true;
      notifyListeners();
    }
  }

  Future<void> _resetFailures() async {
    if (_failures == 0 && _blockedUntil == null) return;
    _failures = 0;
    _blockedUntil = null;
    await _store.write(_failKey, null);
    await _store.write(_untilKey, null);
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt|$pin')).toString();
}

/// Ilova qulfi (testda — xotiradagi qulf bilan almashtiriladi).
final appLockProvider = Provider<AppLock>((_) => AppLock.instance);
