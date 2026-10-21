// Server maktab manbai (`/api/child/school/*`, CHILD token).
//
// Javoblar `Object?` sifatida olinadi va xavfsiz o'qiladi: Dio'ning
// `get<Map>` cast'i ro'yxat javobida "tarmoq xatosi"ga aylanib ketardi.
// Kirish ma'lumoti so'rovdan oldin tekshiriladi (`validation`, so'rovsiz).

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/kiosk_qr.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:flutter/foundation.dart';

/// Test yechish vaqti chegarasi (soniya, server bilan bir xil).
const kMaxTestDurationSec = 86400;

const _invalidInput = SchoolException(SchoolErrorCode.validation);

class ApiSchoolRepository implements SchoolRepository {
  ApiSchoolRepository(this._dio);

  final Dio _dio;

  @override
  Future<SchoolToday?> loadToday() => _guard(() async {
    final data = await _get('/child/school/today');
    if (data is! Map) throw const FormatException('today: obyekt kerak');
    final today = data['today'];
    if (today == null) return null;
    return SchoolToday.tryFromJson(today) ??
        (throw const FormatException('today: noto\'g\'ri'));
  });

  @override
  Future<CheckInResult> checkIn(String token) => _guard(() async {
    final value = token.trim();
    if (value.isEmpty || value.length > kKioskTokenMaxLength) {
      throw _invalidInput;
    }
    final data = await _post('/child/school/check-in', {'token': value});
    return CheckInResult.tryFromJson(data) ??
        (throw const FormatException('check-in: noto\'g\'ri'));
  });

  @override
  Future<CareSurveyStatus> loadCareSurvey() => _guard(() async {
    final data = await _get('/child/school/care/survey');
    return CareSurveyStatus.tryFromJson(data) ??
        (throw const FormatException('survey: noto\'g\'ri'));
  });

  @override
  Future<void> submitCareSurvey(String surveyId, Map<String, int> answers) =>
      _guard(() async {
        final isValid =
            surveyId.isNotEmpty &&
            answers.isNotEmpty &&
            answers.length <= kMaxSurveyQuestions &&
            answers.entries.every(
              (a) =>
                  a.key.isNotEmpty &&
                  a.value >= kSurveyScoreMin &&
                  a.value <= kSurveyScoreMax,
            );
        if (!isValid) throw _invalidInput;
        await _post(
          '/child/school/care/survey/${_segment(surveyId)}/responses',
          {'answers': answers},
        );
      });

  @override
  Future<List<CareRequest>> loadCareRequests() => _guard(() async {
    final data = await _get('/child/school/care/requests');
    if (data is! List) throw const FormatException('requests: ro\'yxat kerak');
    return jsonList(data, CareRequest.tryFromJson);
  });

  @override
  Future<CareRequest> createCareRequest({
    required CareTopic topic,
    required String message,
    CareUrgency urgency = CareUrgency.normal,
  }) => _guard(() async {
    final text = message.trim();
    if (topic == CareTopic.unknown ||
        urgency == CareUrgency.unknown ||
        text.isEmpty ||
        text.length > kCareMessageMaxLength) {
      throw _invalidInput;
    }
    final data = await _post('/child/school/care/requests', {
      'topic': topic.wire,
      'message': text,
      'urgency': urgency.wire,
    });
    return CareRequest.tryFromJson(data) ??
        (throw const FormatException('request: noto\'g\'ri'));
  });

  @override
  Future<List<PsychAssignmentSummary>> loadPsychAssignments() => _guard(
    () async {
      final data = await _get('/child/school/assessments');
      if (data is! Map) throw const FormatException('assessments: obyekt');
      return jsonList(data['assignments'], PsychAssignmentSummary.tryFromJson);
    },
  );

  @override
  Future<PsychTest> loadPsychTest(String assignmentId) => _guard(() async {
    if (assignmentId.isEmpty) throw _invalidInput;
    final data = await _get(
      '/child/school/assessments/${_segment(assignmentId)}',
    );
    return PsychTest.tryFromJson(data) ??
        (throw const FormatException('test: noto\'g\'ri'));
  });

  @override
  Future<void> submitPsychTest(
    PsychTest test, {
    required Map<String, PsychAnswer> answers,
    int? durationSec,
  }) => _guard(() async {
    final encoded = encodePsychAnswers(test, answers);
    if (encoded == null) throw _invalidInput;
    await _post(
      '/child/school/assessments/${_segment(test.assignmentId)}/submit',
      {
        'answers': encoded,
        if (durationSec != null)
          'durationSec': durationSec.clamp(0, kMaxTestDurationSec),
      },
    );
  });

  @override
  Future<List<SchoolAssignment>> loadAssignments() => _guard(() async {
    final data = await _get('/child/school/assignments');
    if (data is! List) throw const FormatException('assignments: ro\'yxat');
    return jsonList(data, SchoolAssignment.tryFromJson);
  });

  Future<Object?> _get(String path) async =>
      (await _dio.get<Object?>(path)).data;

  Future<Object?> _post(String path, Map<String, Object?> body) async =>
      (await _dio.post<Object?>(path, data: body)).data;

  /// Yo'l bo'lagi (id) — maxsus belgilar kodlanadi.
  static String _segment(String id) => Uri.encodeComponent(id);

  /// Dio / format xatolarini `SchoolException`ga aylantiradi.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      debugPrint(
        '[school] ${e.requestOptions.path}: ${e.response?.statusCode} ${e.message}',
      );
      throw SchoolException(_codeOf(e), _serverMessage(e) ?? e.message);
    } on FormatException catch (e) {
      debugPrint('[school] javob formati: $e');
      throw SchoolException(SchoolErrorCode.unknown, e.message);
    }
  }

  static SchoolErrorCode _codeOf(DioException e) {
    final response = e.response;
    if (response == null) return SchoolErrorCode.network;
    final data = response.data;
    final code = data is Map ? data['code'] : null;
    return switch (code) {
      'NOT_ENROLLED' => SchoolErrorCode.notEnrolled,
      'KIOSK_TOKEN_INVALID' => SchoolErrorCode.kioskInvalid,
      'KIOSK_TOKEN_EXPIRED' => SchoolErrorCode.kioskExpired,
      'OUTSIDE_SCHOOL_HOURS' => SchoolErrorCode.outsideHours,
      'SURVEY_NOT_FOUND' => SchoolErrorCode.surveyNotFound,
      'ALREADY_ANSWERED' => SchoolErrorCode.alreadyAnswered,
      'ASSIGNMENT_NOT_FOUND' => SchoolErrorCode.assignmentNotFound,
      'ALREADY_SUBMITTED' => SchoolErrorCode.alreadySubmitted,
      'TOO_MANY_REQUESTS' => SchoolErrorCode.tooManyRequests,
      'NOT_CONFIGURED' => SchoolErrorCode.notConfigured,
      'VALIDATION' => SchoolErrorCode.validation,
      // Eski server (maktab yo'llari hali yo'q): Nest "Cannot GET …" — kodsiz.
      null when response.statusCode == 404 => SchoolErrorCode.unavailable,
      // Umumiy cheklovchi (throttler) ham kodsiz 429 qaytaradi.
      _ when response.statusCode == 429 => SchoolErrorCode.tooManyRequests,
      _ => SchoolErrorCode.unknown,
    };
  }

  static String? _serverMessage(DioException e) {
    final data = e.response?.data;
    final message = data is Map ? data['message'] : null;
    return message is String ? message : null;
  }
}
