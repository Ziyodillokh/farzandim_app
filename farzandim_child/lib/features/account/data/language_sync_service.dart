// ─────────────────────────────────────────────────────────────────────
// LanguageSyncService — ilova tilini bola hisobiga yozish
// ─────────────────────────────────────────────────────────────────────
//
// Server maktab so'rovnomasi va psixologik test matnlarini `User.language`
// bo'yicha beradi (ru — ruscha, qolgani — o'zbekcha). Ilova uni hech qachon
// yozmagan edi, shuning uchun rus tilidagi bola ham o'zbekcha matn olardi.
// Endi ulangandan keyin va til almashganda `PUT /users/me {language}`
// yuboriladi. Oxirgi muvaffaqiyatli qiymat (hisob bilan) SharedPreferences'da
// — takroriy so'rov yo'q; xato bo'lsa keyingi safar (ilovaga qaytish, bosh
// sahifa yangilanishi) qayta uriniladi.
//
// Hisob — bolaning server foydalanuvchisi (`currentUserId`): har ulanishda
// server yangi bola foydalanuvchisini yaratadi (tili standart "uz"), `childId`
// esa o'zgarmaydi. Belgi `childId` bo'yicha bo'lsa, qayta ulangandan keyin
// til hech qachon qayta yozilmasdi.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oxirgi yozilgan til: `"<hisob>:<til>"` (hisob — bola foydalanuvchisi).
const kSyncedLanguageKey = 'account.syncedLanguage.v1';

/// Server qabul qiladigan tillar (`UpdateUserDto.language`).
const kServerLanguages = {'uz', 'ru', 'en'};

/// [LanguageSyncService.sync] natijasi.
enum LanguageSyncResult {
  /// Serverga yozildi — serverdagi til o'zgardi.
  written,

  /// Shu hisobga allaqachon yozilgan — so'rov yuborilmadi.
  unchanged,

  /// Yozilmadi (tarmoq xatosi, server bilmaydigan til yoki hisob yo'q).
  failed,
}

class LanguageSyncService {
  LanguageSyncService(this._dio);

  final Dio _dio;

  /// Chaqiruvlar navbati — ketma-ket bajariladi, oxirgi til yutadi.
  Future<LanguageSyncResult> _queue = Future.value(
    LanguageSyncResult.unchanged,
  );

  /// [language]ni [account] (ulangan bola foydalanuvchisi) hisobiga yozadi;
  /// shu hisobga allaqachon yozilgan bo'lsa so'rov yuborilmaydi.
  /// Xato tashlamaydi.
  Future<LanguageSyncResult> sync({
    required String account,
    required String language,
  }) {
    final next = _queue
        .then((_) => _syncNow(account, language))
        .catchError(_logFailure);
    _queue = next;
    return next;
  }

  /// Kutilmagan xato (masalan, SharedPreferences) navbatni to'xtatmaydi.
  static LanguageSyncResult _logFailure(Object error) {
    debugPrint('[language] sinxronlash xato: $error');
    return LanguageSyncResult.failed;
  }

  Future<LanguageSyncResult> _syncNow(String account, String language) async {
    final code = language.toLowerCase();
    if (account.isEmpty || !kServerLanguages.contains(code)) {
      return LanguageSyncResult.failed;
    }
    final marker = '$account:$code';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(kSyncedLanguageKey) == marker) {
      return LanguageSyncResult.unchanged;
    }
    try {
      await _dio.put<Object?>('/users/me', data: {'language': code});
    } on DioException catch (e) {
      debugPrint(
        '[language] yozilmadi: ${e.response?.statusCode} ${e.message}',
      );
      return LanguageSyncResult.failed;
    }
    await prefs.setString(kSyncedLanguageKey, marker);
    return LanguageSyncResult.written;
  }
}
