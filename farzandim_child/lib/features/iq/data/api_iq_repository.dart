// Server IQ manbai (`/api/iq/*`, CHILD token). Javoblar `Object?` sifatida
// olinadi va xavfsiz o'qiladi; Dio / format xatolari `IqException`ga.

import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/iq/data/iq_repository.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';

class ApiIqRepository implements IqRepository {
  ApiIqRepository(this._dio);

  final Dio _dio;

  @override
  Future<IqOverview> loadOverview() => _guard(
    () async => IqOverview.fromJson(await _send('GET', '/iq/overview')),
  );

  @override
  Future<IqSession> startSession() => _guard(
    () async => IqSession.fromJson(await _send('POST', '/iq/sessions')),
  );

  @override
  Future<void> saveAnswer({
    required String sessionId,
    required String itemId,
    required String choice,
    int? durationMs,
  }) => _guard(() async {
    final path = '/iq/sessions/${_seg(sessionId)}/answers/${_seg(itemId)}';
    await _send('PUT', path, {
      'choice': choice,
      if (durationMs != null && durationMs >= 0) 'durationMs': durationMs,
    });
  });

  @override
  Future<IqSession> completeSession(String sessionId) => _guard(() async {
    final path = '/iq/sessions/${_seg(sessionId)}/complete';
    return IqSession.fromJson(await _send('POST', path));
  });

  Future<Object?> _send(String method, String path, [Object? body]) async {
    final response = await _dio.request<Object?>(
      path,
      data: body,
      options: Options(method: method),
    );
    return response.data;
  }

  static String _seg(String id) {
    final value = id.trim();
    if (value.isEmpty) throw const IqException(IqErrorCode.sessionNotFound);
    return Uri.encodeComponent(value);
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      developer.log(
        '${e.requestOptions.method} ${e.requestOptions.path}: $status',
        name: 'iq',
      );
      throw _exceptionOf(e);
    } on FormatException catch (e) {
      developer.log('javob formati: ${e.message}', name: 'iq');
      throw IqException(IqErrorCode.unknown, message: e.message);
    }
  }

  static IqException _exceptionOf(DioException e) {
    final response = e.response;
    if (response == null) {
      return IqException(IqErrorCode.network, message: e.message);
    }
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : null;
    final message = data?['message'];
    return IqException(
      _codeOf(data?['code'], response.statusCode),
      message: message is String ? message : e.message,
      nextAvailableAt: jsonInstant(data?['nextAvailableAt']),
    );
  }

  static IqErrorCode _codeOf(Object? code, int? status) => switch (code) {
    'AGE_REQUIRED' => IqErrorCode.ageRequired,
    'AGE_OUT_OF_RANGE' => IqErrorCode.ageOutOfRange,
    'RETAKE_TOO_SOON' => IqErrorCode.retakeTooSoon,
    'NO_ITEMS' => IqErrorCode.noItems,
    'SESSION_CLOSED' => IqErrorCode.sessionClosed,
    'UNANSWERED' => IqErrorCode.unanswered,
    'INVALID_CHOICE' || 'ITEM_NOT_IN_SESSION' => IqErrorCode.invalidChoice,
    'SESSION_NOT_FOUND' => IqErrorCode.sessionNotFound,
    // Eski server (IQ yo'llari hali yo'q): Nest "Cannot GET …" — kodsiz.
    null when status == 404 => IqErrorCode.unavailable,
    _ => IqErrorCode.unknown,
  };
}
