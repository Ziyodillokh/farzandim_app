import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_pair.dart';

import 'scripted_adapter.dart';

/// `iat` li soxta JWT (imzo tekshirilmaydi — faqat tartib uchun).
String fakeJwt(int iat) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'iat': iat, 'sub': 'child'})}.sig';
}

const sessionRotated = {
  'statusCode': 401,
  'message': 'Session rotated',
  'error': 'Unauthorized',
};

/// Backend `refreshToken` + `rotateSessionJti` (session-rotation.ts) ning
/// soddalashtirilgan nusxasi: atomik rotatsiya; oldingi jti [grace] ichida
/// joriy juftni oladi, undan keyin — 401 'Session rotated'.
class FakeAuthBackend {
  FakeAuthBackend({this.grace = const Duration(seconds: 60)});

  /// `Duration.zero` — eski (imtiyozsiz) backend.
  Duration grace;

  int _iat = 100;
  String currentJti = 'j0';
  String? prevJti;
  DateTime? rotatedAt;
  final Set<String> validAccess = {};
  int refreshCalls = 0;

  /// Javob qaytishidan oldingi kechikish (so'rov allaqachon bajarilgan).
  Duration refreshLatency = Duration.zero;

  /// `null` emas — har refresh shu tana bilan 401 (sessiya yopilgan).
  Map<String, Object?>? revokedBody;

  /// 'Session rotated' javobidan oldin (boshqa isolate yozuvini taqlid).
  Future<void> Function()? beforeRotatedReply;

  /// Boshlang'ich juft: access ESKIRGAN, refresh — joriy.
  TokenPair initialPair() => TokenPair(
    accessToken: fakeJwt(++_iat),
    refreshToken: 'r:$currentJti:${++_iat}',
  );

  /// Server tomonda rotatsiya (boshqa jarayon refresh qildi) — berilgan juft.
  TokenPair rotate({DateTime? at}) {
    prevJti = currentJti;
    currentJti = 'j${++_iat}';
    rotatedAt = at ?? DateTime.now();
    return _issue(currentJti);
  }

  bool isCurrentRefresh(String token) => _jtiOf(token) == currentJti;

  Future<FakeReply> handle(RequestOptions options) async {
    if (options.path == '/auth/refresh') {
      final body = options.data as Map;
      return _refresh(body['refreshToken'] as String);
    }
    final token = bearerOf(options);
    if (options.path == '/always-401' ||
        token == null ||
        !validAccess.contains(token)) {
      return const FakeReply(401, {'statusCode': 401, 'message': 'Unauthorized'});
    }
    return const FakeReply(200, {'ok': true});
  }

  Future<FakeReply> _refresh(String token) async {
    refreshCalls++;
    final reply = await _decide(token);
    if (refreshLatency > Duration.zero) {
      await Future<void>.delayed(refreshLatency);
    }
    return reply;
  }

  Future<FakeReply> _decide(String token) async {
    final revoked = revokedBody;
    if (revoked != null) return FakeReply(401, revoked);
    final jti = _jtiOf(token);
    if (jti == currentJti) return FakeReply(200, _json(rotate()));
    final at = rotatedAt;
    if (jti == prevJti &&
        at != null &&
        DateTime.now().difference(at) <= grace) {
      return FakeReply(200, _json(_issue(currentJti)));
    }
    await beforeRotatedReply?.call();
    return const FakeReply(401, sessionRotated);
  }

  TokenPair _issue(String jti) {
    final access = fakeJwt(++_iat);
    validAccess.add(access);
    return TokenPair(accessToken: access, refreshToken: 'r:$jti:${++_iat}');
  }

  static String _jtiOf(String refreshToken) {
    final parts = refreshToken.split(':');
    return parts.length == 3 ? parts[1] : '';
  }

  static Map<String, String> _json(TokenPair pair) => {
    'accessToken': pair.accessToken,
    'refreshToken': pair.refreshToken,
  };
}
