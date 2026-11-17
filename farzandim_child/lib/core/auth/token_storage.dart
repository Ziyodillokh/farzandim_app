// ─────────────────────────────────────────────────────────────────────
// TokenStorage — JWT access/refresh tokenlarini xavfsiz saqlash
// ─────────────────────────────────────────────────────────────────────
//
// Backend POST /api/auth/child-pair familyCode → JWT pair beradi:
//   - accessToken: 15 daqiqa
//   - refreshToken: 30 kun
//
// Android KeyStore + iOS Keychain — SharedPreferences emas (secrets).
// Web preview/dev — SharedPreferences fallback (flutter_secure_storage_web
// SubtleCrypto'da OperationError beradi).
//
// 1.0.20 (batareya / barqarorlik):
//   • Ikkala token BITTA kalitda (`auth.tokens.v2`, JSON) — yozuv atomik.
//     Eski ikki kalit (`jwt_access_token`, `jwt_refresh_token`) o'qiladi va
//     birinchi o'qishda yangi kalitga ko'chiriladi.
//   • Isolate bo'yicha UMUMIY xotira (TokenMemory): so'rovlar tokenni
//     xotiradan oladi; storage birinchi ishlatishda va 401 kelganda qayta
//     o'qiladi (boshqa isolate tokenni yangilagan bo'lishi mumkin).
//   • `null` yoki xato o'qish — NOMA'LUM, hech qachon "chiqib ketgan" emas.
//     Sessiyani faqat server javobi bekor qiladi (token_refresher.dart).
//     UI "sessiya yo'q" qarorini faqat [TokenStorage.isSessionDefinitelyMissing]
//     bilan qiladi.

// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:farzandim_child/core/auth/token_memory.dart';
import 'package:farzandim_child/core/auth/token_pair.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

abstract class _Backend {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class _SecureStorageBackend implements _Backend {
  _SecureStorageBackend()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _SharedPrefsBackend implements _Backend {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }
}

class TokenStorage {
  /// [keyPrefix] — Growth v5 da qurilma egasi bo'lmagan qo'shimcha akkaunt
  /// tokenlari alohida kalitlarda (`acct_<childId>_…`). Bo'sh prefiks —
  /// qurilma egasining (juftlangan bola) odatiy kalitlari: fon isolate'i va
  /// native xizmatlar faqat shularni o'qiydi.
  ///
  /// [memory] — faqat testlar uchun (ikki isolate'ni bitta testda taqlid
  /// qilish); odatda isolate'ning umumiy xotirasi.
  // ignore: library_private_types_in_public_api
  TokenStorage({_Backend? backend, this.keyPrefix = '', TokenMemory? memory})
    : _backend =
          backend ?? (kIsWeb ? _SharedPrefsBackend() : _SecureStorageBackend()),
      _memory = memory ?? TokenMemory.isolate;

  final _Backend _backend;
  final TokenMemory _memory;
  final String keyPrefix;

  /// [isSessionDefinitelyMissing] ikkinchi o'qishdan oldin kutadi.
  @visibleForTesting
  static Duration missingRecheckDelay = const Duration(milliseconds: 400);

  static const _kAccessToken = 'jwt_access_token';
  static const _kRefreshToken = 'jwt_refresh_token';
  static const _kTokens = 'auth.tokens.v2';

  /// SharedPreferences (sir emas): "shu akkaunt tokenlari saqlangan va
  /// [clear] qilinmagan". Secure storage `null` qaytarsa ham sessiya
  /// yo'qolgan deb hisoblanmasligi uchun (flutter_secure_storage 9.x
  /// Keystore xatosidan keyin dvigatel umri bo'yi `null` beradi).
  static const _kPresentMarker = 'auth.tokens_present.v1';

  String get _accessKey => '$keyPrefix$_kAccessToken';
  String get _refreshKey => '$keyPrefix$_kRefreshToken';
  String get _tokensKey => '$keyPrefix$_kTokens';
  String get _markerKey => '$keyPrefix$_kPresentMarker';

  // ── Xotira ─────────────────────────────────────────────────────────

  /// Shu isolate xotirasidagi juft (storage'ga tegmaydi).
  TokenPair? get cachedPair => _memory.pairOf(keyPrefix);

  /// Shu isolate'dagi saqlash/tozalashlar hisoblagichi.
  int get generation => _memory.generationOf(keyPrefix);

  /// Har so'rov uchun access token: xotiradan; xotira bo'sh bo'lsa storage
  /// bir marta o'qiladi (parallel so'rovlar bitta o'qishni kutadi). Topilmasa
  /// yoki o'qib bo'lmasa — `null` (so'rov tokensiz ketadi, xato tashlamaydi).
  Future<String?> accessTokenForRequest() async {
    final cached = cachedPair;
    if (cached != null) return _nonEmpty(cached.accessToken);
    await _sharedRead();
    return _nonEmpty(cachedPair?.accessToken);
  }

  /// Storage'ni qayta o'qiydi (401 kelganda — boshqa isolate tokenni
  /// yangilagan bo'lishi mumkin). Topilgan juft xotiraga olinadi, agar u
  /// xotiradagidan eskiroq bo'lmasa.
  Future<TokenRead> reload() => _sharedRead();

  // ── Ommaviy API (avvalgidek) ───────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final pair = TokenPair(accessToken: accessToken, refreshToken: refreshToken);
    // Avval xotira — parallel so'rovlar yangi tokenni darhol ishlatadi.
    _memory.put(keyPrefix, pair);
    await _backend.write(_tokensKey, pair.encode());
    await _setPresentMarker(present: true);
  }

  /// Storage'dan YANGI o'qish. Xatosiz "yo'q" bo'lsa — `null`; o'qib
  /// bo'lmasa — xotiradagi qiymat (bo'lmasa xato tashlanadi).
  Future<String?> readAccessToken() async =>
      _nonEmpty((await _readForCaller())?.accessToken);

  Future<String?> readRefreshToken() async =>
      _nonEmpty((await _readForCaller())?.refreshToken);

  Future<void> updateAccessToken(String newAccessToken) async {
    final current = cachedPair ?? (await _sharedRead()).pair;
    await saveTokens(
      accessToken: newAccessToken,
      refreshToken: current?.refreshToken ?? '',
    );
  }

  Future<void> updateRefreshToken(String newRefreshToken) async {
    final current = cachedPair ?? (await _sharedRead()).pair;
    await saveTokens(
      accessToken: current?.accessToken ?? '',
      refreshToken: newRefreshToken,
    );
  }

  Future<void> clear() async {
    _memory.forget(keyPrefix);
    // Belgi AVVAL o'chadi: jarayon shu yerda o'lsa, keyingi ochilishda
    // tokenlar hali o'qiladi (server yana rad etadi) — "belgi bor, token
    // yo'q" (abadiy noaniq) holat qolmaydi.
    await _setPresentMarker(present: false);
    await Future.wait([
      _backend.delete(_tokensKey),
      _backend.delete(_accessKey),
      _backend.delete(_refreshKey),
    ]);
    // O'chirish davomida boshlangan o'qish eski juftni xotiraga va belgini
    // qayta yozgan bo'lishi mumkin — yana tozalaymiz.
    _memory.forget(keyPrefix);
    await _writeMarker(present: false);
  }

  /// Server [rejectedRefreshToken]ni ANIQ bekor qildi. Shu orada boshqa
  /// isolate yoki qayta kirish yangi juft yozgan bo'lsa — u saqlanadi va
  /// `false`; aks holda tokenlar tozalanadi va `true`.
  Future<bool> clearIfCurrent(String rejectedRefreshToken) async {
    await _sharedRead();
    final best = cachedPair;
    if (best != null &&
        best.canRefresh &&
        best.refreshToken != rejectedRefreshToken) {
      return false;
    }
    await clear();
    return true;
  }

  /// Refresh token bormi. O'qib bo'lmasa — xotiradagi qiymat (yo'q bo'lsa
  /// `false`: bu faqat "parol so'rash" kabi buzmaydigan qarorlar uchun).
  Future<bool> hasValidSession() async {
    final read = await _sharedRead();
    if (read.failed) return cachedPair?.canRefresh ?? false;
    final pair = read.pair;
    if (pair == null) return false;
    return (cachedPair ?? pair).canRefresh;
  }

  /// Sessiya ANIQ yo'qmi — UI "qayta ulanish / chiqildi" qarorini FAQAT shu
  /// bilan qiladi. `true` faqat quyidagilarning HAMMASI bajarilganda:
  ///   1. yangi kalit (`auth.tokens.v2`) ham, eski ikki kalit ham XATOSIZ
  ///      o'qildi va hech biri yo'q;
  ///   2. [missingRecheckDelay]dan keyingi ikkinchi o'qish ham xuddi shunday;
  ///   3. "tokenlar saqlangan" belgisi (SharedPreferences) yo'q — [clear] uni
  ///      o'chiradi. Belgi bor-u, secure storage `null` bersa — bu Keystore
  ///      xatosi (sticky null), sessiya emas: javob `false`.
  /// Har qanday o'qish xatosi — `false` (noaniq holatda ulanish uzilmaydi).
  /// Eslatma: absent bo'lsa ~[missingRecheckDelay] davom etadi.
  Future<bool> isSessionDefinitelyMissing() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future<void>.delayed(missingRecheckDelay);
      final seen = generation;
      final read = await _readStorage(seen);
      final pair = read.pair;
      if (pair != null) _memory.adopt(keyPrefix, pair, seenGeneration: seen);
      if (!read.isCleanAbsent) return false;
    }
    return !await _markerSaysPresent();
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  Future<TokenPair?> _readForCaller() async {
    final read = await _sharedRead();
    if (read.failed) {
      final cached = cachedPair;
      if (cached != null) return cached;
      throw read.error ?? StateError('token storage o\'qilmadi');
    }
    final pair = read.pair;
    if (pair == null) return null;
    // Xotira yangiroq bo'lishi mumkin (shu isolate refresh qilgan).
    return cachedPair ?? pair;
  }

  /// Bir vaqtdagi o'qishlar bitta storage o'qishini bo'lishadi.
  Future<TokenRead> _sharedRead() {
    final pending = _memory.pendingRead(keyPrefix);
    if (pending != null) return pending;
    final seen = generation;
    final read = _readStorage(seen).then((result) {
      final pair = result.pair;
      if (pair != null) _memory.adopt(keyPrefix, pair, seenGeneration: seen);
      return result;
    });
    _memory.beginRead(keyPrefix, read);
    // `_readStorage` hech qachon xato tashlamaydi.
    unawaited(read.whenComplete(() => _memory.endRead(keyPrefix, read)));
    return read;
  }

  /// Avval yangi kalit, bo'lmasa eski ikki kalit (topilsa ko'chiriladi).
  /// Hech qachon xato tashlamaydi.
  Future<TokenRead> _readStorage(int seenGeneration) async {
    try {
      final raw = await _backend.read(_tokensKey);
      final combined = TokenPair.tryDecode(raw);
      if (combined != null) {
        _rememberPresent(seenGeneration);
        return TokenRead.found(combined);
      }
      final refresh = await _backend.read(_refreshKey);
      final access = await _backend.read(_accessKey);
      final legacy = TokenPair.fromParts(access, refresh);
      if (legacy == null) {
        // Buzilgan yangi yozuv va eski kalitlar yo'q — "yo'q" emas, noma'lum.
        return raw == null
            ? const TokenRead.absent()
            : const TokenRead.failed(FormatException('auth.tokens.v2'));
      }
      await _migrateLegacy(legacy, seenGeneration);
      return TokenRead.found(legacy);
    } on Object catch (e) {
      debugPrint('[tokens] storage o\'qilmadi: ${e.runtimeType}');
      return TokenRead.failed(e);
    }
  }

  /// Eski ikki kalit → `auth.tokens.v2`. Best-effort; o'qish natijasiga
  /// ta'sir qilmaydi.
  Future<void> _migrateLegacy(TokenPair legacy, int seenGeneration) async {
    _rememberPresent(seenGeneration);
    if (!legacy.canRefresh || generation != seenGeneration) return;
    try {
      // Boshqa isolate shu orada yangi kalitga yozgan bo'lsa — tegmaymiz.
      if (await _backend.read(_tokensKey) != null) return;
      await _backend.write(_tokensKey, legacy.encode());
      await _backend.delete(_accessKey);
      await _backend.delete(_refreshKey);
    } on Object catch (e) {
      debugPrint('[tokens] ko\'chirilmadi: ${e.runtimeType}');
    }
  }

  /// Tokenlar topildi — belgini shu isolate'da bir marta yozamiz. O'qish
  /// boshlangandan beri saqlash/tozalash bo'lgan bo'lsa — yozilmaydi
  /// (tozalangan sessiyaning belgisi qayta tirilmasin).
  void _rememberPresent(int seenGeneration) {
    if (_memory.isMarkedPresent(keyPrefix) || generation != seenGeneration) {
      return;
    }
    _memory.markPresent(keyPrefix);
    unawaited(_writeMarker(present: true, onlyIfGeneration: seenGeneration));
  }

  Future<void> _setPresentMarker({required bool present}) async {
    if (present) _memory.markPresent(keyPrefix);
    await _writeMarker(present: present);
  }

  /// Best-effort: xato tashlamaydi (SharedPreferences yo'q testlarda ham).
  Future<void> _writeMarker({
    required bool present,
    int? onlyIfGeneration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (onlyIfGeneration != null && generation != onlyIfGeneration) return;
      if (present) {
        await prefs.setBool(_markerKey, true);
      } else {
        await prefs.remove(_markerKey);
      }
    } on Object catch (e) {
      debugPrint('[tokens] belgi yozilmadi: ${e.runtimeType}');
    }
  }

  Future<bool> _markerSaysPresent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Boshqa isolate (masalan fon) tozalagan bo'lishi mumkin.
      await prefs.reload();
      return prefs.getBool(_markerKey) ?? false;
    } on Object catch (e) {
      debugPrint('[tokens] belgi o\'qilmadi: ${e.runtimeType}');
      return true;
    }
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
