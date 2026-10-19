// Xotiradagi Daily Learning manbai — widget / provider testlari va skrinshot
// harness'i uchun (server qoidalari soddalashtirilgan: savolning to'g'ri
// javobi `indeks % 4`, DON kunlik birinchi urinishga).

import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';

class FakeLearningRepository implements LearningRepository {
  FakeLearningRepository({
    this.profile,
    List<TestResult> results = const [],
    DateTime Function()? clock,
  }) : results = [...results],
       _clock = clock ?? DateTime.now;

  LearningProfile? profile;
  final List<TestResult> results;
  final DateTime Function() _clock;

  /// Keyingi so'rov shu xato bilan yiqiladi (bir marta).
  LearningException? failNext;

  final Map<String, _FakeAttempt> _attempts = {};
  int _attemptSeq = 0;

  static const questionCount = 10;

  static int correctIndexOf(String questionId) =>
      int.parse(questionId.split('-').last) % 4;

  void _maybeFail() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  @override
  Future<LearningProfile?> loadProfile() async {
    _maybeFail();
    return profile;
  }

  @override
  Future<LearningProfile> saveProfile(LearningProfile profile) async {
    _maybeFail();
    return this.profile = profile;
  }

  @override
  Future<List<TestResult>> loadResults({int limit = 100}) async {
    _maybeFail();
    return List.unmodifiable(results.take(limit));
  }

  @override
  Future<QuizAttempt> startAttempt(Subject subject) async {
    _maybeFail();
    if (profile == null) {
      throw const LearningException(LearningErrorCode.profileRequired);
    }
    for (final a in _attempts.values) {
      if (a.subject == subject && a.result == null) return a.view();
    }
    final today = _clock();
    final isDaily = !results.any(
      (r) =>
          r.subject == subject &&
          r.isDaily &&
          r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day,
    );
    final id = 'attempt-${++_attemptSeq}';
    final attempt = _FakeAttempt(
      id: id,
      subject: subject,
      isDaily: isDaily,
      questions: [
        for (var i = 0; i < questionCount; i++)
          QuizQuestion(
            id: '${subject.name}-$_attemptSeq-$i',
            difficulty: 1 + i ~/ 4,
            topic: const LocalizedText({
              'uz': 'Kasrlar',
              'ru': 'Дроби',
              'en': 'Fractions',
            }),
            prompt: LocalizedText.same('${i + 1} + ${i + 2} = ?'),
            options: [
              for (var o = 0; o < 4; o++)
                LocalizedText.same('${2 * i + 3 + o - i % 4}'),
            ],
          ),
      ],
    );
    _attempts[id] = attempt;
    return attempt.view();
  }

  @override
  Future<AnswerFeedback> submitAnswer({
    required String attemptId,
    required String questionId,
    required int selectedIndex,
  }) async {
    _maybeFail();
    final attempt = _attempts[attemptId]!;
    final existing = attempt.answers[questionId];
    if (existing != null) return existing;
    final correct = correctIndexOf(questionId);
    return attempt.answers[questionId] = AnswerFeedback(
      questionId: questionId,
      selectedIndex: selectedIndex,
      isCorrect: selectedIndex == correct,
      correctIndex: correct,
      explanation: LocalizedText.same('To‘g‘ri javob ${correct + 1}-variant.'),
    );
  }

  @override
  Future<TestResult> completeAttempt(String attemptId) async {
    _maybeFail();
    final attempt = _attempts[attemptId]!;
    final done = attempt.result;
    if (done != null) return done;
    final correct = attempt.answers.values.where((a) => a.isCorrect).length;
    final result = TestResult(
      id: attemptId,
      subject: attempt.subject,
      topic: attempt.questions.first.topic,
      correct: correct,
      total: attempt.questions.length,
      date: _clock(),
      isDaily: attempt.isDaily,
      donEarned: attempt.isDaily && correct > 0
          ? correct * 2 + (correct == attempt.questions.length ? 10 : 0)
          : 0,
      durationSeconds: 155,
    );
    results.insert(0, result);
    return attempt.result = result;
  }

  @override
  Future<AttemptReview> loadReview(String resultId) async {
    _maybeFail();
    final attempt = _attempts[resultId]!;
    return AttemptReview(
      result: attempt.result!,
      items: [
        for (final q in attempt.questions)
          ReviewItem(
            question: q,
            correctIndex: correctIndexOf(q.id),
            explanation: LocalizedText.same('Izoh'),
            selectedIndex: attempt.answers[q.id]?.selectedIndex,
            isCorrect: attempt.answers[q.id]?.isCorrect ?? false,
          ),
      ],
    );
  }
}

class _FakeAttempt {
  _FakeAttempt({
    required this.id,
    required this.subject,
    required this.isDaily,
    required this.questions,
  });

  final String id;
  final Subject subject;
  final bool isDaily;
  final List<QuizQuestion> questions;
  final Map<String, AnswerFeedback> answers = {};
  TestResult? result;

  QuizAttempt view() => QuizAttempt(
    id: id,
    subject: subject,
    isDaily: isDaily,
    questions: questions,
    answers: [
      for (final q in questions)
        if (answers[q.id] case final AnswerFeedback a) a,
    ],
  );
}
