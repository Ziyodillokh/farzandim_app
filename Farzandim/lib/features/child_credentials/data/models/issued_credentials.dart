// ─────────────────────────────────────────────────────────────────────
// IssuedCredentials — yangi berilgan login va VAQTINCHALIK PAROL
// ─────────────────────────────────────────────────────────────────────
//
// Backend: POST /api/children/:childId/credentials → 201
//   { login, temporaryPassword, issuedAt }
// Parol BIR MARTA ko'rsatiladi: hech qayerda saqlanmaydi (provayder,
// kesh, SharedPreferences, log) — faqat ochiq "parol varag'i" ushlab
// turadi va yopilganda unutiladi. Shu sabab `toString` parolni
// yashiradi (tasodifan log yoki xato xabariga tushmasin).

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

@immutable
class IssuedCredentials {
  const IssuedCredentials({
    required this.login,
    required this.temporaryPassword,
    this.issuedAt,
  });

  /// Javob: `login` va `temporaryPassword` bo'sh bo'lmagan satr bo'lishi
  /// shart; aks holda `null` (ko'rsatadigan narsa yo'q).
  static IssuedCredentials? tryParse(Object? raw) {
    final json = asJsonMap(raw);
    if (json == null) return null;
    final login = json.readStringOrNull('login');
    final password = json.readStringOrNull('temporaryPassword');
    if (login == null || password == null) return null;
    return IssuedCredentials(
      login: login,
      temporaryPassword: password,
      issuedAt: json.readDateTime('issuedAt'),
    );
  }

  final String login;
  final String temporaryPassword;
  final DateTime? issuedAt;

  @override
  bool operator ==(Object other) =>
      other is IssuedCredentials &&
      other.login == login &&
      other.temporaryPassword == temporaryPassword &&
      other.issuedAt == issuedAt;

  @override
  int get hashCode => Object.hash(login, temporaryPassword, issuedAt);

  @override
  String toString() => 'IssuedCredentials($login, password: ***)';
}
