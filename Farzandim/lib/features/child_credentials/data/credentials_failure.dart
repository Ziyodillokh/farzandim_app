// ─────────────────────────────────────────────────────────────────────
// CredentialsFailure — kirish ma'lumotlari API xatolarining turi + i18n kaliti
// ─────────────────────────────────────────────────────────────────────
//
// Backend xatosi `{statusCode, code, message}`; `message` foydalanuvchiga
// KO'RSATILMAYDI (inglizcha/ichki) — tur bo'yicha o'z tarjimamiz chiqadi.
//
// Qoidalar (maktab bo'limi bilan bir xil):
//   - 409 `LOGIN_TAKEN` (yoki `code`siz 409) → login band;
//   - 404 `code`siz → `unavailable` (backend'da bo'lim yo'q: hali deploy
//     qilinmagan) — ekran "hozircha mavjud emas" deydi;
//   - 404 `REQUEST_NOT_FOUND` / 409 `ALREADY_RESOLVED` → `requestGone`
//     ("parolni unutdim" so'rovi allaqachon hal bo'lgan — ro'yxat yangilanadi);
//   - 429 → juda ko'p urinish; javob umuman yo'q → `network`.

import 'package:dio/dio.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

enum CredentialsFailureKind {
  loginTaken,
  validation,
  forbidden,
  notFound,

  /// "Parolni unutdim" so'rovi yo'q yoki allaqachon hal qilingan.
  requestGone,
  tooManyAttempts,
  sessionExpired,
  unavailable,
  network,
  server,

  /// Javob muvaffaqiyatli, lekin kutilgan ma'lumot (parol) yo'q.
  malformed,
  unknown,
}

@immutable
class CredentialsFailure implements Exception {
  const CredentialsFailure(this.kind, {this.code, this.statusCode});

  /// Istalgan xatodan (DioException, CredentialsFailure yoki boshqa).
  factory CredentialsFailure.fromError(Object error) {
    if (error is CredentialsFailure) return error;
    if (error is! DioException) {
      return const CredentialsFailure(CredentialsFailureKind.unknown);
    }
    final response = error.response;
    if (response == null) {
      return CredentialsFailure(
        error.type == DioExceptionType.cancel
            ? CredentialsFailureKind.unknown
            : CredentialsFailureKind.network,
      );
    }
    final status = response.statusCode;
    final code = asJsonMap(response.data)?.readStringOrNull('code');
    return CredentialsFailure(
      _kindOf(status, code),
      code: code,
      statusCode: status,
    );
  }

  final CredentialsFailureKind kind;

  /// Backend `code` (bo'lsa) — log va tahlil uchun.
  final String? code;
  final int? statusCode;

  /// Backend'da bo'lim yo'q.
  bool get isUnavailable => kind == CredentialsFailureKind.unavailable;

  /// Foydalanuvchiga ko'rsatiladigan xabar kaliti (`.tr()` bilan).
  String get messageKey => switch (kind) {
    CredentialsFailureKind.loginTaken => 'childCredentials.errors.loginTaken',
    CredentialsFailureKind.validation => 'childCredentials.errors.validation',
    CredentialsFailureKind.forbidden => 'errors.forbidden',
    CredentialsFailureKind.notFound => 'childCredentials.errors.notFound',
    CredentialsFailureKind.requestGone => 'childCredentials.errors.requestGone',
    CredentialsFailureKind.tooManyAttempts => 'childCredentials.errors.tooMany',
    CredentialsFailureKind.sessionExpired => 'errors.sessionExpired',
    CredentialsFailureKind.unavailable => 'childCredentials.errors.unavailable',
    CredentialsFailureKind.network => 'errors.noInternet',
    CredentialsFailureKind.server => 'childCredentials.errors.server',
    CredentialsFailureKind.malformed => 'childCredentials.errors.noPassword',
    CredentialsFailureKind.unknown => 'errors.generic',
  };

  static CredentialsFailureKind _kindOf(int? status, String? code) {
    if (code == 'LOGIN_TAKEN') return CredentialsFailureKind.loginTaken;
    if (code == 'REQUEST_NOT_FOUND' || code == 'ALREADY_RESOLVED') {
      return CredentialsFailureKind.requestGone;
    }
    return switch (status) {
      // Bu bo'limda 409 — faqat login bandligi.
      409 when code == null => CredentialsFailureKind.loginTaken,
      400 || 422 => CredentialsFailureKind.validation,
      401 => CredentialsFailureKind.sessionExpired,
      403 => CredentialsFailureKind.forbidden,
      404 =>
        code == null
            ? CredentialsFailureKind.unavailable
            : CredentialsFailureKind.notFound,
      429 => CredentialsFailureKind.tooManyAttempts,
      final int s when s >= 500 => CredentialsFailureKind.server,
      _ => CredentialsFailureKind.unknown,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CredentialsFailure &&
      other.kind == kind &&
      other.code == code &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(kind, code, statusCode);

  /// Tana (parol bo'lishi mumkin) hech qachon chiqmaydi — faqat tur va status.
  @override
  String toString() =>
      'CredentialsFailure(${kind.name}, code: $code, status: $statusCode)';
}

/// Repository chaqiruvini o'raydi: DioException → [CredentialsFailure]
/// (faqat tur va status log'ga yoziladi). Boshqa xatolar o'zgarishsiz o'tadi.
Future<T> guardCredentialsCall<T>(String tag, Future<T> Function() body) async {
  try {
    return await body();
  } on DioException catch (e) {
    final failure = CredentialsFailure.fromError(e);
    debugPrint('[credentials] $tag: $failure');
    throw failure;
  }
}
