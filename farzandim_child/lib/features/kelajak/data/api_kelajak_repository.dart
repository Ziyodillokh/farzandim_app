// Server Kelajak manbai (`/api/kelajak/*`, CHILD token).
//
// Javoblar `Object?` sifatida olinadi va xavfsiz o'qiladi (Dio'ning
// `get<Map>` cast'i noto'g'ri javobni "tarmoq xatosi"ga aylantirardi).
// Noto'g'ri kirish so'rovsiz rad etiladi (`invalidAnswer` / `unknownType`).

import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_json.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';

/// Test turi nomi chegarasi (server bilan bir xil).
const _kTypeMaxLength = 40;

/// Natijalar sahifasi chegarasi (server bilan bir xil).
const _kResultsLimitMax = 100;

class ApiKelajakRepository implements KelajakRepository {
  ApiKelajakRepository(this._dio);

  final Dio _dio;

  @override
  Future<KelajakOverview> loadOverview() => _guard(
    () async =>
        KelajakOverview.fromJson(await _send('GET', '/kelajak/overview')),
  );

  @override
  Future<KelajakSession> startSession(String type) => _guard(() async {
    final value = type.trim();
    if (value.isEmpty || value.length > _kTypeMaxLength) {
      throw const KelajakException(KelajakErrorCode.unknownType);
    }
    final data = await _send('POST', '/kelajak/sessions', {'type': value});
    return KelajakSession.fromJson(data);
  });

  @override
  Future<KelajakSession> loadSession(String sessionId) => _guard(() async {
    final data = await _send('GET', '/kelajak/sessions/${_id(sessionId)}');
    return KelajakSession.fromJson(data);
  });

  @override
  Future<KelajakAnswerAck> saveAnswer({
    required String sessionId,
    required String questionId,
    int? value,
    String? text,
  }) => _guard(() async {
    final body = _answerBody(value, text);
    final question = _id(questionId, KelajakErrorCode.questionNotInSession);
    final path = '/kelajak/sessions/${_id(sessionId)}/answers/$question';
    return KelajakAnswerAck.fromJson(await _send('PUT', path, body));
  });

  @override
  Future<KelajakSession> completeSession(String sessionId) => _guard(() async {
    final path = '/kelajak/sessions/${_id(sessionId)}/complete';
    return KelajakSession.fromJson(await _send('POST', path));
  });

  @override
  Future<KelajakProgress> loadProgress() => _guard(
    () async =>
        KelajakProgress.fromJson(await _send('GET', '/kelajak/progress')),
  );

  @override
  Future<KelajakResultsPage> loadResults({
    String? before,
    int limit = kKelajakResultsPageSize,
  }) => _guard(() async {
    final cursor = before?.trim();
    final data = await _send('GET', '/kelajak/results', null, {
      'limit': limit.clamp(1, _kResultsLimitMax),
      if (cursor != null && cursor.isNotEmpty) 'before': cursor,
    });
    return KelajakResultsPage.fromJson(data);
  });

  /// Javob tanasi: aynan bittasi — shkala qiymati yoki ochiq matn
  /// (`""` — o'chirish). Aks holda so'rovsiz `invalidAnswer`.
  static Map<String, Object> _answerBody(int? value, String? text) {
    if ((value == null) == (text == null)) {
      throw const KelajakException(KelajakErrorCode.invalidAnswer);
    }
    if (value != null) return {'value': value};
    final trimmed = text!.trim();
    if (trimmed.length > kKelajakTextMaxLength) {
      throw const KelajakException(KelajakErrorCode.invalidAnswer);
    }
    return {'text': trimmed};
  }

  Future<Object?> _send(
    String method,
    String path, [
    Object? body,
    Map<String, Object?>? query,
  ]) async {
    final response = await _dio.request<Object?>(
      path,
      data: body,
      queryParameters: query,
      options: Options(method: method),
    );
    return response.data;
  }

  /// Yo'l bo'lagi (id) — bo'sh bo'lsa so'rovsiz [onEmpty]; maxsus belgilar
  /// kodlanadi.
  static String _id(
    String id, [
    KelajakErrorCode onEmpty = KelajakErrorCode.sessionNotFound,
  ]) {
    final value = id.trim();
    if (value.isEmpty) throw KelajakException(onEmpty);
    return Uri.encodeComponent(value);
  }

  /// Dio / format xatolarini `KelajakException`ga aylantiradi.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      developer.log(
        '${e.requestOptions.method} ${e.requestOptions.path}: $status',
        name: 'kelajak',
      );
      throw _exceptionOf(e);
    } on FormatException catch (e) {
      developer.log('javob formati: ${e.message}', name: 'kelajak');
      throw KelajakException(KelajakErrorCode.unknown, message: e.message);
    }
  }

  static KelajakException _exceptionOf(DioException e) {
    final response = e.response;
    if (response == null) {
      return KelajakException(KelajakErrorCode.network, message: e.message);
    }
    final data = jsonMap(response.data);
    final message = data?['message'];
    return KelajakException(
      _codeOf(data?['code'], response.statusCode),
      message: message is String ? message : e.message,
      remaining: jsonStrings(data?['remaining']),
    );
  }

  static KelajakErrorCode _codeOf(Object? code, int? status) => switch (code) {
    'AGE_REQUIRED' => KelajakErrorCode.ageRequired,
    'AGE_OUT_OF_RANGE' => KelajakErrorCode.ageOutOfRange,
    'NO_QUESTIONS' => KelajakErrorCode.noQuestions,
    'UNKNOWN_TYPE' => KelajakErrorCode.unknownType,
    'SESSION_CLOSED' => KelajakErrorCode.sessionClosed,
    'UNANSWERED' => KelajakErrorCode.unanswered,
    'INVALID_ANSWER' => KelajakErrorCode.invalidAnswer,
    'QUESTION_NOT_IN_SESSION' => KelajakErrorCode.questionNotInSession,
    'SESSION_NOT_FOUND' => KelajakErrorCode.sessionNotFound,
    'NOT_CONFIGURED' => KelajakErrorCode.notConfigured,
    // Eski server (Kelajak yo'llari hali yo'q): Nest "Cannot GET …" — kodsiz.
    null when status == 404 => KelajakErrorCode.unavailable,
    _ => KelajakErrorCode.unknown,
  };
}
