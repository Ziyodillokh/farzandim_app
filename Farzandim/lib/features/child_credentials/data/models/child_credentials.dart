// ─────────────────────────────────────────────────────────────────────
// ChildCredentials — bolaning kirish ma'lumotlari holati (parol YO'Q)
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/children/:childId/credentials →
//   { login, issuedBy: 'PARENT'|'SCHOOL', issuedAt, mustChangePassword,
//     lastLoginAt }   yoki   null  (hali berilmagan).
// Parol hech qachon qaytmaydi va saqlanmaydi. Parse hech qachon otmaydi:
// noma'lum `issuedBy` → `unknown`, buzuq sana → `null`.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

/// Kirish ma'lumotlarini kim bergan.
enum CredentialsIssuer {
  parent,
  school,
  unknown;

  static CredentialsIssuer fromApi(Object? raw) => switch (raw) {
    'PARENT' => parent,
    'SCHOOL' => school,
    _ => unknown,
  };
}

@immutable
class ChildCredentials {
  const ChildCredentials({
    required this.login,
    required this.issuedBy,
    required this.mustChangePassword,
    this.issuedAt,
    this.lastLoginAt,
    this.temporaryPasswordExpiresAt,
  });

  /// `GET /children/:id/credentials` javobi. Obyekt bo'lmagan (`null`,
  /// bo'sh tana) yoki `login`siz javob — "hali berilmagan" (`null`).
  static ChildCredentials? tryParse(Object? raw) {
    final json = asJsonMap(raw);
    if (json == null) return null;
    final login = json.readStringOrNull('login');
    if (login == null) return null;
    return ChildCredentials(
      login: login,
      issuedBy: CredentialsIssuer.fromApi(json['issuedBy']),
      mustChangePassword: json.readBool('mustChangePassword'),
      issuedAt: json.readDateTime('issuedAt'),
      lastLoginAt: json.readDateTime('lastLoginAt'),
      temporaryPasswordExpiresAt: json.readDateTime(
        'temporaryPasswordExpiresAt',
      ),
    );
  }

  final String login;
  final CredentialsIssuer issuedBy;

  /// `true` — bola hali o'z parolini o'rnatmagan (vaqtinchalik parol
  /// amalda): birinchi kirish kutilmoqda.
  final bool mustChangePassword;
  final DateTime? issuedAt;
  final DateTime? lastLoginAt;

  /// Vaqtinchalik parol shu vaqtgacha amal qiladi (14 kun); keyin yangisi
  /// berilishi kerak.
  final DateTime? temporaryPasswordExpiresAt;

  /// Birinchi kirish (yoki yangilangan paroldan keyingi kirish) kutilmoqda.
  bool get isFirstLoginPending => mustChangePassword;

  /// Bola hech qachon kirmagan.
  bool get neverLoggedIn => lastLoginAt == null;

  @override
  bool operator ==(Object other) =>
      other is ChildCredentials &&
      other.login == login &&
      other.issuedBy == issuedBy &&
      other.mustChangePassword == mustChangePassword &&
      other.issuedAt == issuedAt &&
      other.lastLoginAt == lastLoginAt;

  @override
  int get hashCode =>
      Object.hash(login, issuedBy, mustChangePassword, issuedAt, lastLoginAt);

  @override
  String toString() =>
      'ChildCredentials($login, ${issuedBy.name}, '
      'pending: $mustChangePassword)';
}
