// Daily Learning ma'lumot manbai interfeysi — server (`/api/learning`).
// Javob serverda tekshiriladi, DON / XP yakunda serverda beriladi.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';

abstract interface class LearningRepository {
  /// O'quv profili (`null` — hali tanlanmagan).
  Future<LearningProfile?> loadProfile();

  Future<LearningProfile> saveProfile(LearningProfile profile);

  /// Yechilgan testlar — yangisi birinchi.
  Future<List<TestResult>> loadResults({int limit});

  /// Fan testini boshlash yoki bugungi yarim qolganini davom ettirish.
  Future<QuizAttempt> startAttempt(Subject subject);

  Future<AnswerFeedback> submitAnswer({
    required String attemptId,
    required String questionId,
    required int selectedIndex,
  });

  /// Yakunlash (idempotent) — natija va DON.
  Future<TestResult> completeAttempt(String attemptId);

  Future<AttemptReview> loadReview(String resultId);
}

/// Server xato kodlari (UI tegishli matnni tanlaydi).
enum LearningErrorCode {
  profileRequired,

  /// Fan bolaning (profildagi) sinfida hali o'qitilmaydi — masalan, maktab
  /// topshirig'idagi fan yoki sinf noto'g'ri tanlangan.
  subjectNotInGrade,
  noQuestions,
  attemptClosed,
  network,
  unknown,
}

class LearningException implements Exception {
  const LearningException(this.code, [this.message]);

  final LearningErrorCode code;
  final String? message;

  @override
  String toString() =>
      'LearningException($code${message == null ? '' : ': $message'})';
}
