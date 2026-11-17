// ─────────────────────────────────────────────────────────────────────
// TokenStorage — JWT access/refresh tokenlarini xavfsiz saqlash
// ─────────────────────────────────────────────────────────────────────
//
// Backend Telegram Login + JWT pair beradi (Sprint 4.4):
//   - accessToken: 15 daqiqa amal qiladi, har request'ga Bearer header
//   - refreshToken: 30 kun amal qiladi, access token expire bo'lganda
//                   `/api/auth/refresh` ga yuboriladi
//
// SharedPreferences EMAS — secrets uchun encrypted storage kerak:
//   - Android: KeyStore (Android Keystore System)
//   - iOS: Keychain Services (kSecAttrAccessibleAfterFirstUnlock)
//
// "O'zidan login'ga chiqib ketish"ga qarshi (2026-11-16):
//   - Ikkala token XOTIRADA keshlanadi — har so'rovda shifrlangan xotira
//     (har chaqiruvda Keystore'ni qayta ishga tushiradi) o'qilmaydi.
//   - Juftlik BITTA kalitda (JSON) yoziladi — access va refresh hech qachon
//     turli javoblardan aralashib qolmaydi. Eski ikki kalit ham yoziladi
//     (eski versiyaga qaytsa ham chiqib ketmasin) va o'qishda qo'llanadi.
//   - flutter_secure_storage 9.x da bitta Keystore xatosidan keyin `read`
//     butun jarayon umri davomida null qaytaradi. Shuning uchun null yoki
//     xato "chiqilgan" degani EMAS: [isSessionDefinitelyMissing] faqat
//     toza "yo'q" va SharedPreferences belgisi ham yo'q bo'lsa true. Belgi
//     tokenlar saqlanganda qo'yiladi, [clear]da olinadi.
//   - O'qish bir vaqtda bitta; o'qish paytida tokenlar yangilangan bo'lsa
//     eski natija keshni bosib ketmaydi (avlod hisoblagichi).
//
// API:
//   await storage.saveTokens(accessToken: ..., refreshToken: ...);
//   final access = await storage.readAccessToken();
//   await storage.clear(); // logout

import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Riverpod provider — global singleton.
final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

/// Token saqlash backend interfeysi — platformaga qarab tanlanadi.
abstract class TokenStorageBackend {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class _SecureStorageBackend implements TokenStorageBackend {
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

class _SharedPrefsBackend implements TokenStorageBackend {
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

/// Xotiradan o'qish natijasi.
enum TokenReadResult {
  /// Juftlik topildi (keshga yozildi).
  found,

  /// O'qish toza o'tdi, token yo'q.
  absent,

  /// O'qish xato berdi — natija noma'lum (kesh o'zgarmadi).
  failed,
}

class TokenStorage {
  TokenStorage({TokenStorageBackend? backend})
    : _backend =
          backend ?? (kIsWeb ? _SharedPrefsBackend() : _SecureStorageBackend());

  final TokenStorageBackend _backend;

  static const _kAccessToken = 'jwt_access_token';
  static const _kRefreshToken = 'jwt_refresh_token';

  /// Atomik juftlik kaliti (JSON: {"a": access, "r": refresh}).
  static const _kPair = 'jwt_tokens_v2';

  /// SharedPreferences: tokenlar saqlangan (clear() gacha). Shifrlangan
  /// xotira null qaytarsa ham bu belgi "aslida kirgan" deb aytadi.
  static const kTokensPresentKey = 'auth.tokens_present.v1';

  /// Belgi bor, lekin tokenlar o'qilmagan ketma-ket ishga tushishlar soni.
  static const kUnreadableStartsKey = 'auth.tokens_unreadable_starts.v1';

  /// Shuncha ketma-ket ishga tushishda o'qilmasa — Keystore kaliti buzilgan
  /// deb hisoblanadi va login so'raladi ("kirgan, lekin ishlamaydi" holati
  /// qolib ketmasin). Bir jarayonlik "doim null" xatosi bunga yetmaydi.
  static const maxUnreadableStarts = 2;

  // Isolate bo'yicha umumiy kesh (barcha TokenStorage nusxalari uchun).
  static String? _cachedAccess;
  static String? _cachedRefresh;
  static bool _loaded = false;

  /// Har saqlash/yangilash/clear'da oshadi: shu orada boshlangan o'qish
  /// natijasi (eskirgan) keshni bosib ketmaydi.
  static int _generation = 0;
  static Future<TokenReadResult>? _reloadInFlight;

  @visibleForTesting
  static void resetCacheForTest() {
    _cachedAccess = null;
    _cachedRefresh = null;
    _loaded = false;
    _generation++;
    _reloadInFlight = null;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _setCache(accessToken, refreshToken);
    await _writePair(accessToken, refreshToken);
    await _setMarker(present: true);
  }

  Future<String?> readAccessToken() async {
    if (!_loaded) await reload();
    return _cachedAccess;
  }

  Future<String?> readRefreshToken() async {
    if (!_loaded) await reload();
    return _cachedRefresh;
  }

  /// Xotiradan qayta o'qiydi (bir vaqtda bittasi). Xato bo'lsa kesh
  /// o'zgarmaydi — oxirgi ma'lum tokenlar bilan ishlash davom etadi.
  Future<TokenReadResult> reload() {
    final inFlight = _reloadInFlight;
    if (inFlight != null) return inFlight;
    final future = _reloadOnce();
    _reloadInFlight = future;
    return future.whenComplete(() {
      if (identical(_reloadInFlight, future)) _reloadInFlight = null;
    });
  }

  Future<TokenReadResult> _reloadOnce() async {
    final generation = _generation;
    final ({String? access, String refresh})? pair;
    try {
      pair = await _readPair();
    } catch (_) {
      return TokenReadResult.failed;
    }
    // O'qish paytida saqlash/yangilash/clear bo'lgan — natija eskirgan.
    final isStale = generation != _generation;
    if (pair == null) {
      // Toza "yo'q" — faqat hali hech narsa bilinmagan bo'lsa qo'llanadi
      // (shu jarayonda saqlangan tokenni o'chirmaymiz).
      if (!isStale && !_loaded) _setCacheFromRead(null, null);
      return TokenReadResult.absent;
    }
    if (isStale) return TokenReadResult.found;
    _setCacheFromRead(pair.access, pair.refresh);
    // Eski o'rnatishlar uchun belgi (birinchi muvaffaqiyatli o'qishda).
    await _setMarker(present: true);
    await _resetUnreadableStarts();
    return TokenReadResult.found;
  }

  Future<void> updateAccessToken(String newAccessToken) =>
      updateTokens(accessToken: newAccessToken);

  Future<void> updateRefreshToken(String newRefreshToken) =>
      updateTokens(refreshToken: newRefreshToken);

  /// Refresh javobi: ikkala token bitta yozuvda. Server tokenni allaqachon
  /// almashtirgan — yozish xato bersa ham kesh yangi juftda qoladi va
  /// so'rovlar davom etadi (xato tashlanmaydi, faqat log).
  Future<void> updateTokens({String? accessToken, String? refreshToken}) async {
    if (!_loaded) await reload();
    final access = accessToken ?? _cachedAccess;
    final refresh = refreshToken ?? _cachedRefresh;
    _setCache(access, refresh);
    try {
      if (access == null || refresh == null) {
        // Juftlikning yarmi — faqat eski kalitga (kamdan-kam: refresh yo'q).
        if (accessToken != null) {
          await _backend.write(_kAccessToken, accessToken);
        }
        if (refreshToken != null) {
          await _backend.write(_kRefreshToken, refreshToken);
        }
        return;
      }
      await _writePair(access, refresh);
    } catch (e) {
      debugPrint('TokenStorage: yangilangan tokenlar yozilmadi — $e');
      return;
    }
    await _setMarker(present: true);
  }

  /// Logout. Kesh va belgi darhol tozalanadi; shifrlangan xotiradan o'chirish
  /// best-effort (xato bo'lsa ham chiqish to'xtamaydi).
  Future<void> clear() async {
    _setCache(null, null);
    await _setMarker(present: false);
    await _resetUnreadableStarts();
    try {
      await Future.wait([
        _backend.delete(_kPair),
        _backend.delete(_kAccessToken),
        _backend.delete(_kRefreshToken),
      ]);
    } catch (e) {
      debugPrint('TokenStorage: tokenlar o`chirilmadi — $e');
    }
  }

  /// Kirilgan deb hisoblash mumkinmi (startup). Shifrlangan xotira xato
  /// bersa yoki null qaytarsa ham, belgi bor bo'lsa — ha.
  Future<bool> hasValidSession() async {
    return !(await isSessionDefinitelyMissing());
  }

  /// true — sessiya ANIQ yo'q: belgi yo'q va xotira toza "yo'q" dedi.
  /// O'qish xatosi — noma'lum (false). Belgi bor, lekin tokenlar
  /// o'qilmasa — [maxUnreadableStarts] marta ketma-ket bo'lgandagina true.
  /// Ilova ishga tushishida bir marta chaqiriladi.
  Future<bool> isSessionDefinitelyMissing() async {
    final cached = _cachedRefresh;
    if (cached != null && cached.isNotEmpty) return false;
    final hasMarker = await _readMarker();
    final result = await reload();
    if (result == TokenReadResult.found || _hasRefresh) return false;
    if (hasMarker) return _countUnreadableStart();
    return result == TokenReadResult.absent;
  }

  /// Belgi bor, tokenlar o'qilmadi: ketma-ket [maxUnreadableStarts] marta
  /// bo'lsagina sessiya yo'q deb hisoblanadi (belgi olib tashlanadi).
  Future<bool> _countUnreadableStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final starts = (prefs.getInt(kUnreadableStartsKey) ?? 0) + 1;
      if (starts < maxUnreadableStarts) {
        await prefs.setInt(kUnreadableStartsKey, starts);
        return false;
      }
      debugPrint('TokenStorage: tokenlar $starts marta o`qilmadi — login');
      await prefs.remove(kUnreadableStartsKey);
      await prefs.remove(kTokensPresentKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _resetUnreadableStarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(kUnreadableStartsKey)) {
        await prefs.remove(kUnreadableStartsKey);
      }
    } catch (_) {
      // best-effort
    }
  }

  bool get _hasRefresh => _cachedRefresh != null && _cachedRefresh!.isNotEmpty;

  /// Ilova o'zi yozgan qiymat (saqlash/yangilash/clear) — ustuvor.
  void _setCache(String? access, String? refresh) {
    _generation++;
    _setCacheFromRead(access, refresh);
  }

  void _setCacheFromRead(String? access, String? refresh) {
    _cachedAccess = access;
    _cachedRefresh = refresh;
    _loaded = true;
  }

  Future<void> _writePair(String access, String refresh) async {
    await _backend.write(_kPair, jsonEncode({'a': access, 'r': refresh}));
    // Eski kalitlar — eski versiyaga qaytilsa ham kirgan holat saqlansin.
    await Future.wait([
      _backend.write(_kAccessToken, access),
      _backend.write(_kRefreshToken, refresh),
    ]);
  }

  Future<({String? access, String refresh})?> _readPair() async {
    try {
      final raw = await _backend.read(_kPair);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw);
        if (json is Map) {
          final refresh = json['r'];
          if (refresh is String && refresh.isNotEmpty) {
            final access = json['a'];
            return (access: access is String ? access : null, refresh: refresh);
          }
        }
      }
    } catch (e) {
      // Juftlik o'qilmadi yoki buzilgan — eski kalitlar ham yozilgan.
      debugPrint('TokenStorage: juftlik o`qilmadi — $e');
    }
    // Eski (ikki kalitli) saqlash.
    final refresh = await _backend.read(_kRefreshToken);
    if (refresh == null || refresh.isEmpty) return null;
    final access = await _backend.read(_kAccessToken);
    return (access: access, refresh: refresh);
  }

  Future<bool> _readMarker() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kTokensPresentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setMarker({required bool present}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (present) {
        if (prefs.getBool(kTokensPresentKey) != true) {
          await prefs.setBool(kTokensPresentKey, true);
        }
      } else {
        await prefs.remove(kTokensPresentKey);
      }
    } catch (_) {
      // Belgi best-effort — asosiy saqlash shifrlangan xotirada.
    }
  }
}
