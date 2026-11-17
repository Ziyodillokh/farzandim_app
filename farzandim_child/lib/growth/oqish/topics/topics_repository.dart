// Mavzular manbai (server). Eski server (endpoint yo'q, 404) yoki bo'sh
// katalog — bo'sh xarita: ilova fan bo'yicha aralash mashqni taklif qiladi.

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class TopicsRepository {
  Future<SubjectTopicMap> loadSubjectMap(Subject subject);

  Future<LearningTopic?> loadTopic(String topicId);

  /// Mavzu bo'yicha urinish (yangi yoki shu kungi tugallanmagan).
  Future<QuizAttempt> startTopicAttempt(Subject subject, String topicId);
}

class ApiTopicsRepository implements TopicsRepository {
  ApiTopicsRepository(this._dio);

  final Dio _dio;

  @override
  Future<SubjectTopicMap> loadSubjectMap(Subject subject) => _guard(() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/learning/subjects/${subject.name}/topics',
      );
      return SubjectTopicMap.tryFromJson(subject, res.data) ??
          SubjectTopicMap.empty(subject);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return SubjectTopicMap.empty(subject);
      rethrow;
    }
  });

  @override
  Future<LearningTopic?> loadTopic(String topicId) => _guard(() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/learning/topics/$topicId',
      );
      return LearningTopic.tryFromJson(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  });

  @override
  Future<QuizAttempt> startTopicAttempt(Subject subject, String topicId) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/learning/attempts',
          data: {'subject': subject.name, 'topicId': topicId},
        );
        return QuizAttempt.fromJson(res.data!);
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      debugPrint(
        '[topics] ${e.requestOptions.path}: ${e.response?.statusCode} ${e.message}',
      );
      final data = e.response?.data;
      final code = data is Map ? data['code'] : null;
      throw LearningException(switch (code) {
        'PROFILE_REQUIRED' => LearningErrorCode.profileRequired,
        'SUBJECT_NOT_IN_GRADE' => LearningErrorCode.subjectNotInGrade,
        'ATTEMPT_CLOSED' => LearningErrorCode.attemptClosed,
        'TOPIC_NOT_AVAILABLE' ||
        'NO_QUESTIONS' => LearningErrorCode.noQuestions,
        _ when e.response == null => LearningErrorCode.network,
        _ => LearningErrorCode.unknown,
      }, e.message);
    } on FormatException catch (e) {
      throw LearningException(LearningErrorCode.unknown, e.message);
    }
  }
}

final topicsRepositoryProvider = Provider<TopicsRepository>(
  (ref) => ApiTopicsRepository(ref.watch(dioClientProvider)),
);

final subjectTopicMapProvider = FutureProvider.autoDispose
    .family<SubjectTopicMap, Subject>(
      (ref, subject) =>
          ref.watch(topicsRepositoryProvider).loadSubjectMap(subject),
    );

final topicProvider = FutureProvider.autoDispose.family<LearningTopic?, String>(
  (ref, topicId) => ref.watch(topicsRepositoryProvider).loadTopic(topicId),
);

/// Mavzu bo'yicha urinish — ekran yopilganda tashlanadi.
final topicAttemptProvider = FutureProvider.autoDispose
    .family<QuizAttempt, ({Subject subject, String topicId})>(
      (ref, key) => ref
          .read(topicsRepositoryProvider)
          .startTopicAttempt(key.subject, key.topicId),
    );
