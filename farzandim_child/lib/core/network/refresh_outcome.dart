// ─────────────────────────────────────────────────────────────────────
// RefreshOutcome — POST /auth/refresh natijasi
// ─────────────────────────────────────────────────────────────────────
//
// Backend (auth.service.ts refreshToken) 401 sabablari:
//   • {code:'SESSION_REVOKED', reason, message:'Session revoked'} — sessiya
//     yopilgan (qayta tiklash, boshqa qurilmada kirish, chiqish, ...);
//   • 'Token revoked' — tokenVersion o'zgargan ("hamma joydan chiqish");
//   • 'User not found or inactive' — hisob o'chirilgan / bloklangan;
//   • 'Session rotated' — eski refresh token (boshqa jarayon yangilagan;
//     server oldingi tokenni 60 s davomida joriy juftga almashtiradi);
//   • 'Invalid refresh token' — imzo / muddat.
// Sessiyani FAQAT birinchi uchtasi yopadi. Qolgani — tokenlar saqlanadi.

import 'package:farzandim_child/core/auth/token_pair.dart';

sealed class RefreshOutcome {
  const RefreshOutcome();
}

/// Yangi juft berildi.
final class RefreshIssued extends RefreshOutcome {
  const RefreshIssued(this.pair);
  final TokenPair pair;
}

/// Server sessiyani ANIQ yopdi — tokenlar tozalanadi, UI'ga xabar.
final class RefreshRevoked extends RefreshOutcome {
  const RefreshRevoked({this.reason});

  /// `SESSION_REVOKED.reason` (RECOVERED, SIGNED_OUT, ...) yoki `null`.
  final String? reason;
}

/// Rad etildi, lekin sessiya yopilgani aniq emas ('Session rotated' va h.k.).
final class RefreshRejected extends RefreshOutcome {
  const RefreshRejected(this.message);
  final String? message;
}

/// Tarmoq / 5xx / 429 / noto'g'ri javob — hech narsa o'zgarmaydi.
final class RefreshUnavailable extends RefreshOutcome {
  const RefreshUnavailable();
}

const _revokingMessages = {
  'Session revoked',
  'Token revoked',
  'User not found or inactive',
};

/// /auth/refresh 401/403 javob tanasini tasniflaydi.
RefreshOutcome classifyRefreshRejection(Object? body) {
  if (body is! Map) return const RefreshRejected(null);
  final message = _messageOf(body['message']);
  if (body['code'] == 'SESSION_REVOKED') {
    final reason = body['reason'];
    return RefreshRevoked(reason: reason is String ? reason : null);
  }
  if (message != null && _revokingMessages.contains(message)) {
    return const RefreshRevoked();
  }
  return RefreshRejected(message);
}

/// Muvaffaqiyatli javobdan juft. Refresh token kelmasa — yuborilgani qoladi.
RefreshOutcome issuedFrom(Object? body, {required String sentRefreshToken}) {
  if (body is! Map) return const RefreshUnavailable();
  final access = body['accessToken'];
  if (access is! String || access.isEmpty) return const RefreshUnavailable();
  final refresh = body['refreshToken'];
  return RefreshIssued(
    TokenPair(
      accessToken: access,
      refreshToken: refresh is String && refresh.isNotEmpty
          ? refresh
          : sentRefreshToken,
    ),
  );
}

String? _messageOf(Object? message) {
  if (message is String) return message.trim();
  if (message is List && message.isNotEmpty) return message.join(' ').trim();
  return null;
}
