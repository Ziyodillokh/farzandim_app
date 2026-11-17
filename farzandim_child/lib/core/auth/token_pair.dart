// ─────────────────────────────────────────────────────────────────────
// TokenPair — access + refresh tokenlari BITTA qiymat sifatida
// ─────────────────────────────────────────────────────────────────────
//
// Secure storage'da bitta kalit (`auth.tokens.v2`, JSON) — yozuv atomik:
// boshqa isolate hech qachon "yangi access + eski refresh" aralashmasini
// ko'rmaydi (avval ikki ketma-ket yozuv orasida o'qilib, sessiya o'chib
// ketardi — rob-dart-refresh-race-session-wipe).
//
// JWT `iat` (berilgan vaqt) — ikki juftdan qaysi biri YANGIROQ ekanini
// bilish uchun: "farq qiladi" har doim "yangiroq" degani emas (masalan
// boshqa isolate eski juftni ko'chirib yozgan bo'lsa).

import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  /// `auth.tokens.v2` qiymati. Bo'sh yoki buzilgan bo'lsa — `null`.
  static TokenPair? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final access = json['access'];
      final refresh = json['refresh'];
      if (access is! String || refresh is! String) return null;
      return fromParts(access, refresh);
    } on FormatException {
      return null;
    }
  }

  /// Eski ikki kalitdan (`jwt_access_token` / `jwt_refresh_token`).
  /// Ikkalasi ham bo'sh bo'lsa — `null`.
  static TokenPair? fromParts(String? access, String? refresh) {
    final a = access ?? '';
    final r = refresh ?? '';
    if (a.isEmpty && r.isEmpty) return null;
    return TokenPair(accessToken: a, refreshToken: r);
  }

  final String accessToken;
  final String refreshToken;

  /// Refresh token bor — sessiyani yangilash mumkin.
  bool get canRefresh => refreshToken.isNotEmpty;

  String encode() =>
      jsonEncode({'v': 2, 'access': accessToken, 'refresh': refreshToken});

  @override
  bool operator ==(Object other) =>
      other is TokenPair &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);

  // Token qiymatlari hech qachon log'ga tushmasin.
  @override
  String toString() => 'TokenPair(***)';
}

/// JWT `iat` (soniya). JWT bo'lmasa yoki o'qib bo'lmasa — `null`.
int? jwtIssuedAt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final json = jsonDecode(payload);
    if (json is! Map) return null;
    final iat = json['iat'];
    return iat is num ? iat.toInt() : null;
  } on FormatException {
    return null;
  }
}

/// [candidate] 401 olgan [failed] tokendan KEYIN berilganmi — shu bilan
/// so'rovni qayta yuborish ma'nolimi. JWT vaqtlari noma'lum bo'lsa, farq
/// qilishning o'zi yetarli (eski xatti-harakat).
bool isLaterToken(String candidate, String? failed) {
  if (candidate.isEmpty || candidate == failed) return false;
  if (failed == null || failed.isEmpty) return true;
  final a = jwtIssuedAt(candidate);
  final b = jwtIssuedAt(failed);
  if (a == null || b == null) return true;
  return a > b;
}

/// [candidate] [current]dan ANIQ eskiroqmi (ikkala JWT vaqti ma'lum).
bool isOlderToken(String candidate, String current) {
  final a = jwtIssuedAt(candidate);
  final b = jwtIssuedAt(current);
  return a != null && b != null && a < b;
}
