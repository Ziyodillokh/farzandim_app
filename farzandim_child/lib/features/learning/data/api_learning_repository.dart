// Server Daily Learning manbai (`/api/learning`, CHILD token).

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:flutter/foundation.dart';

/// Natijalar ro'yxati (statistika uchun yetarli tarix).
const kResultsHistoryLimit = 100;

class ApiLearningRepository implements LearningRepository {
  ApiLearningRepository(this._dio);

  final Dio _dio;

  @override
  Future<LearningProfile?> loadProfile() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>('/learning/profile');
    return LearningProfile.tryFromJson(res.data?['profile']);
  });

  @override
  Future<LearningProfile> saveProfile(LearningProfile profile) =>
      _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/learning/profile',
          data: profile.toJson(),
        );
        return LearningProfile.tryFromJson(res.data?['profile']) ??
            (throw const LearningException(LearningErrorCode.unknown));
      });

  @override
  Future<List<TestResult>> loadResults({int limit = kResultsHistoryLimit}) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/learning/results',
          queryParameters: {'limit': limit},
        );
        final items = res.data?['items'];
        return List.unmodifiable([
          if (items is List)
            for (final item in items) ?TestResult.tryFromJson(item),
        ]);
      });

  @override
  Future<QuizAttempt> startAttempt(Subject subject) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/learning/attempts',
      data: {'subject': subject.name},
    );
    return QuizAttempt.fromJson(res.data!);
  });

  @override
  Future<AnswerFeedback> submitAnswer({
    required String attemptId,
    required String questionId,
    required int selectedIndex,
  }) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/learning/attempts/$attemptId/answers',
      data: {'questionId': questionId, 'selectedIndex': selectedIndex},
    );
    return AnswerFeedback.fromJson(res.data!);
  });

  @override
  Future<TestResult> completeAttempt(String attemptId) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/learning/attempts/$attemptId/complete',
    );
    return TestResult.tryFromJson(res.data) ??
        (throw const LearningException(LearningErrorCode.unknown));
  });

  @override
  Future<AttemptReview> loadReview(String resultId) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/learning/attempts/$resultId/review',
    );
    return AttemptReview.fromJson(res.data!);
  });

  /// Dio / format xatolarini `LearningException`ga aylantiradi.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      debugPrint(
        '[learning] ${e.requestOptions.path}: ${e.response?.statusCode} ${e.message}',
      );
      throw LearningException(_codeOf(e), e.message);
    } on FormatException catch (e) {
      debugPrint('[learning] javob formati: $e');
      throw LearningException(LearningErrorCode.unknown, e.message);
    }
  }

  static LearningErrorCode _codeOf(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['code'] : null;
    return switch (code) {
      'PROFILE_REQUIRED' => LearningErrorCode.profileRequired,
      'SUBJECT_NOT_IN_GRADE' => LearningErrorCode.subjectNotInGrade,
      'NO_QUESTIONS' => LearningErrorCode.noQuestions,
      'ATTEMPT_CLOSED' => LearningErrorCode.attemptClosed,
      _ when e.response == null => LearningErrorCode.network,
      _ => LearningErrorCode.unknown,
    };
  }
}
