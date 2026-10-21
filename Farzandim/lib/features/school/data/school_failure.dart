// ─────────────────────────────────────────────────────────────────────
// SchoolFailure — maktab (va Growth) API xatolarining turi + i18n kaliti
// ─────────────────────────────────────────────────────────────────────
//
// Maktab xatosi `{statusCode, code, message}`; `message` — i18n kalit yoki id
// (masalan "code: errors.school.inviteCodeFormat"), shuning uchun
// `friendlyError()` (u `message`ni aynan ko'rsatadi) bu yerda YAROQSIZ.
//
// Qoidalar:
//   - ma'lum `code` → o'z turi (birma-bir);
//   - 404 `code`siz → `unavailable` (backend'da bo'lim yo'q: hali deploy
//     qilinmagan yoki orqaga qaytarilgan) — UI bo'limni yashiradi;
//   - 429 → `tooManyAttempts` (kod xatolari limiti ham, throttler ham);
//   - javob umuman yo'q → `network`.

import 'package:dio/dio.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

enum SchoolFailureKind {
  validation,
  inviteFormat,
  inviteInvalid,
  tooManyAttempts,
  studentNotFound,
  childNotFound,
  studentLinkedElsewhere,
  linkNotFound,
  notFound,
  earlyExitPending,
  verificationOpen,
  conflict,
  forbidden,
  sessionExpired,
  unavailable,
  network,
  server,
  unknown,
}

/// Taklif kodi formati xatosi (VALIDATION `message`ida keladi).
const String _inviteFormatMessage = 'errors.school.inviteCodeFormat';

/// CONFLICT `message` qiymatlari (backend qisqa sabab yozadi).
const String _earlyExitPendingMessage = 'pending';
const String _verificationOpenMessage = 'open verification exists';

@immutable
class SchoolFailure implements Exception {
  const SchoolFailure(this.kind, {this.code, this.detail, this.statusCode});

  /// Istalgan xatodan (DioException, SchoolFailure yoki boshqa).
  factory SchoolFailure.fromError(Object error) {
    if (error is SchoolFailure) return error;
    if (error is! DioException) {
      return const SchoolFailure(SchoolFailureKind.unknown);
    }
    final response = error.response;
    if (response == null) {
      return SchoolFailure(
        error.type == DioExceptionType.cancel
            ? SchoolFailureKind.unknown
            : SchoolFailureKind.network,
      );
    }
    final status = response.statusCode;
    final body = asJsonMap(response.data);
    final code = body?.readStringOrNull('code');
    final detail = _messageOf(body);
    return SchoolFailure(
      _kindOfCode(code, detail) ?? _kindOfStatus(status, hasCode: code != null),
      code: code,
      detail: detail,
      statusCode: status,
    );
  }

  final SchoolFailureKind kind;

  /// Backend `code` (bo'lsa).
  final String? code;

  /// Backend `message` — i18n kalit, id yoki qisqa sabab. UI'da
  /// KO'RSATILMAYDI (log va tahlil uchun).
  final String? detail;
  final int? statusCode;

  /// Backend'da bo'lim yo'q — UI yashiriladi.
  bool get isUnavailable => kind == SchoolFailureKind.unavailable;

  /// Mahalliy ro'yxat eskirgan bo'lishi mumkin — qayta yuklash kerak.
  bool get shouldRefresh => switch (kind) {
    SchoolFailureKind.studentNotFound ||
    SchoolFailureKind.childNotFound ||
    SchoolFailureKind.studentLinkedElsewhere ||
    SchoolFailureKind.linkNotFound ||
    SchoolFailureKind.notFound ||
    SchoolFailureKind.earlyExitPending ||
    SchoolFailureKind.verificationOpen ||
    SchoolFailureKind.conflict ||
    SchoolFailureKind.unavailable => true,
    SchoolFailureKind.validation ||
    SchoolFailureKind.inviteFormat ||
    SchoolFailureKind.inviteInvalid ||
    SchoolFailureKind.tooManyAttempts ||
    SchoolFailureKind.forbidden ||
    SchoolFailureKind.sessionExpired ||
    SchoolFailureKind.network ||
    SchoolFailureKind.server ||
    SchoolFailureKind.unknown => false,
  };

  /// Foydalanuvchiga ko'rsatiladigan xabar kaliti (`.tr()` bilan).
  String get messageKey => switch (kind) {
    SchoolFailureKind.validation => 'school.errors.validation',
    SchoolFailureKind.inviteFormat => 'school.errors.inviteFormat',
    SchoolFailureKind.inviteInvalid => 'school.errors.inviteInvalid',
    SchoolFailureKind.tooManyAttempts => 'school.errors.tooManyAttempts',
    SchoolFailureKind.studentNotFound => 'school.errors.studentNotFound',
    SchoolFailureKind.childNotFound => 'school.errors.childNotFound',
    SchoolFailureKind.studentLinkedElsewhere => 'school.errors.linkedElsewhere',
    SchoolFailureKind.linkNotFound => 'school.errors.linkNotFound',
    SchoolFailureKind.notFound => 'school.errors.notFound',
    SchoolFailureKind.earlyExitPending => 'school.errors.earlyExitPending',
    SchoolFailureKind.verificationOpen => 'school.errors.verificationOpen',
    SchoolFailureKind.conflict => 'school.errors.conflict',
    SchoolFailureKind.forbidden => 'errors.forbidden',
    SchoolFailureKind.sessionExpired => 'errors.sessionExpired',
    SchoolFailureKind.unavailable => 'school.errors.unavailable',
    SchoolFailureKind.network => 'errors.noInternet',
    SchoolFailureKind.server => 'school.errors.server',
    SchoolFailureKind.unknown => 'errors.generic',
  };

  static SchoolFailureKind? _kindOfCode(String? code, String? detail) =>
      switch (code) {
        'VALIDATION' =>
          detail != null && detail.contains(_inviteFormatMessage)
              ? SchoolFailureKind.inviteFormat
              : SchoolFailureKind.validation,
        'INVITE_INVALID' => SchoolFailureKind.inviteInvalid,
        'TOO_MANY_ATTEMPTS' => SchoolFailureKind.tooManyAttempts,
        'STUDENT_NOT_FOUND' => SchoolFailureKind.studentNotFound,
        'CHILD_NOT_FOUND' => SchoolFailureKind.childNotFound,
        'STUDENT_LINKED_ELSEWHERE' => SchoolFailureKind.studentLinkedElsewhere,
        'LINK_NOT_FOUND' => SchoolFailureKind.linkNotFound,
        'NOT_FOUND' => SchoolFailureKind.notFound,
        'CONFLICT' => switch (detail) {
          _earlyExitPendingMessage => SchoolFailureKind.earlyExitPending,
          _verificationOpenMessage => SchoolFailureKind.verificationOpen,
          _ => SchoolFailureKind.conflict,
        },
        'FORBIDDEN' => SchoolFailureKind.forbidden,
        _ => null,
      };

  static SchoolFailureKind _kindOfStatus(
    int? status, {
    required bool hasCode,
  }) => switch (status) {
    404 => hasCode ? SchoolFailureKind.notFound : SchoolFailureKind.unavailable,
    429 => SchoolFailureKind.tooManyAttempts,
    400 || 422 => SchoolFailureKind.validation,
    401 => SchoolFailureKind.sessionExpired,
    403 => SchoolFailureKind.forbidden,
    409 => SchoolFailureKind.conflict,
    final int s when s >= 500 => SchoolFailureKind.server,
    _ => SchoolFailureKind.unknown,
  };

  /// `message` — satr yoki (class-validator) satrlar ro'yxati.
  static String? _messageOf(Map<String, dynamic>? body) {
    final message = body?['message'];
    if (message is String) return message;
    if (message is List && message.isNotEmpty) return '${message.first}';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SchoolFailure &&
      other.kind == kind &&
      other.code == code &&
      other.detail == detail &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(kind, code, detail, statusCode);

  @override
  String toString() =>
      'SchoolFailure(${kind.name}, code: $code, status: $statusCode)';
}

/// Repository chaqiruvini o'raydi: DioException → [SchoolFailure] (log
/// bilan). Boshqa xatolar (ichki [SchoolFailure] ham) o'zgarishsiz o'tadi.
Future<T> guardSchoolCall<T>(String tag, Future<T> Function() body) async {
  try {
    return await body();
  } on DioException catch (e) {
    final failure = SchoolFailure.fromError(e);
    debugPrint('[school] $tag: $failure');
    throw failure;
  }
}
