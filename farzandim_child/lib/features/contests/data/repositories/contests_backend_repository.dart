// ─────────────────────────────────────────────────────────────────────
// ContestsBackendRepository — Sprint 5.7c
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Sprint 5.7c):
//   GET  /api/content/olympiads             — list (published, age)
//   GET  /api/content/olympiads/:id         — detail + questions[]
//   POST /api/content/olympiads/:id/start   — attempt yaratish
//   POST /api/content/attempts/:id/submit   — yakunlash + score
//
// Admin Sprint 5.4'da yaratgan Olympiad'lar shu yerga keladi.

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/question_model.dart';

final contestsBackendRepositoryProvider = Provider<ContestsBackendRepository>((
  ref,
) {
  return ContestsBackendRepository(dio: ref.watch(dioClientProvider));
});

class ContestBundle {
  const ContestBundle({required this.active, required this.finished});
  final List<ContestModel> active;
  final List<ContestModel> finished;
}

class AttemptAnswer {
  const AttemptAnswer({required this.questionId, required this.selectedIndex});
  final String questionId;
  final int selectedIndex;
}

class ContestsBackendRepository {
  ContestsBackendRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<ContestBundle> fetchContests() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/content/olympiads',
      );
      final items = (response.data?['items'] as List<dynamic>?) ?? const [];
      final active = <ContestModel>[];
      final finished = <ContestModel>[];
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final contest = _toContestModel(raw);
        final lifecycle = (raw['lifecycle'] as String?) ?? 'finished';
        if (lifecycle == 'active' || lifecycle == 'scheduled') {
          active.add(contest);
        } else {
          finished.add(contest);
        }
      }
      return ContestBundle(active: active, finished: finished);
    } on DioException catch (e) {
      debugPrint(
        'ContestsBackend.fetch: ${e.response?.statusCode} ${e.message}',
      );
      rethrow;
    }
  }

  Future<List<QuestionModel>> fetchQuestions(String olympiadId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/content/olympiads/$olympiadId',
      );
      final qs = (response.data?['questions'] as List<dynamic>?) ?? const [];
      return qs.whereType<Map<String, dynamic>>().map((raw) {
        // Savol rasmi (ixtiyoriy) — imageKey bo'lsa public proxy URL.
        final imageKey = ((raw['imageKey'] as String?) ?? '').trim();
        final imageUrl = imageKey.isEmpty
            ? ''
            : '${EnvConfig.apiUrl}/olympiad-images/$imageKey';
        // Variant rasmlari (kalitlar) → to'liq URL (bo'sh kalit = "").
        final optionImages =
            ((raw['optionImages'] as List<dynamic>?) ?? const [])
                .map((e) => e.toString().trim())
                .map(
                  (k) =>
                      k.isEmpty ? '' : '${EnvConfig.apiUrl}/olympiad-images/$k',
                )
                .toList();
        return QuestionModel(
          id: (raw['id'] as String?) ?? '',
          text: (raw['text'] as String?) ?? '',
          options: ((raw['options'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          // Sprint 5.7e: correctIndex backend tomonida sir.
          // Lokal feedback uchun -1 (qarang QuizNotifier.selectAnswer).
          correctIndex: (raw['correctIndex'] as num?)?.toInt() ?? -1,
          timeSeconds: 40,
          bonus: (raw['points'] as num?)?.toInt() ?? 50,
          imageUrl: imageUrl,
          optionImages: optionImages,
        );
      }).toList();
    } on DioException catch (e) {
      debugPrint('ContestsBackend.fetchQuestions: ${e.message}');
      rethrow;
    }
  }

  Future<String?> startAttempt(String olympiadId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/content/olympiads/$olympiadId/start',
      );
      return response.data?['attemptId'] as String?;
    } on DioException catch (e) {
      debugPrint('ContestsBackend.start: ${e.message}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> submitAttempt({
    required String attemptId,
    required List<AttemptAnswer> answers,
    required int timeSec,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/content/olympiads/attempts/$attemptId/submit',
        data: {
          'answers': answers
              .map(
                (a) => {
                  'questionId': a.questionId,
                  'selectedIndex': a.selectedIndex,
                },
              )
              .toList(),
          'timeSec': timeSec,
        },
      );
      return response.data;
    } on DioException catch (e) {
      debugPrint('ContestsBackend.submit: ${e.message}');
      return null;
    }
  }

  /// Sprint 5.7e — per-question anti-cheat. Bola har savolga javob bergach
  /// shu yerga POST qiladi. Backend canonical correctIndex bilan compare
  /// qiladi va isCorrect qaytaradi.
  ///
  /// Response: AnswerFeedback (isCorrect, correctIndex, points, scoreSoFar,
  /// correctAnswers, questionsAnswered, isLastQuestion, attemptFinished).
  /// Yoki `null` agar tarmoq xato bo'lsa.
  ///
  /// HTTP 408 → vaqt tugab ketgan (attempt auto-finished).
  /// HTTP 409 → bu savol allaqachon javob berilgan.
  Future<AnswerFeedback?> submitSingleAnswer({
    required String attemptId,
    required String questionId,
    required int selectedIndex,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/content/olympiads/attempts/$attemptId/answer',
        data: {'questionId': questionId, 'selectedIndex': selectedIndex},
      );
      final data = response.data;
      if (data == null) return null;
      return AnswerFeedback.fromJson(data);
    } on DioException catch (e) {
      debugPrint(
        'ContestsBackend.answer: ${e.response?.statusCode} ${e.message}',
      );
      // 408 (vaqt) yoki 409 (duplicate) → autoFinished signal
      if (e.response?.statusCode == 408) {
        return const AnswerFeedback(
          isCorrect: false,
          correctIndex: -1,
          points: 0,
          scoreSoFar: 0,
          correctAnswers: 0,
          questionsAnswered: 0,
          questionsTotal: 0,
          isLastQuestion: true,
          attemptFinished: true,
          timeExpired: true,
        );
      }
      return null;
    }
  }

  ContestModel _toContestModel(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? '';
    final subject = (raw['subject'] as String?) ?? 'Aralash';
    final lifecycle = (raw['lifecycle'] as String?) ?? 'finished';
    final endTime =
        DateTime.tryParse((raw['endTime'] as String?) ?? '') ?? DateTime.now();
    final participants = (raw['participantCount'] as num?)?.toInt() ?? 0;
    final questions = (raw['questionCount'] as num?)?.toInt() ?? 0;
    // Banner (ixtiyoriy) — coverKey bo'lsa public proxy URL (bola dashboard
    // test karuseli banneri); bo'sh bo'lsa ContestModel placeholder ishlatadi.
    final coverKey = ((raw['coverKey'] as String?) ?? '').trim();
    final imageUrl = coverKey.isEmpty
        ? ''
        : '${EnvConfig.apiUrl}/olympiad-images/$coverKey';
    return ContestModel(
      id: id,
      title: (raw['title'] as String?) ?? '—',
      description: (raw['description'] as String?) ?? '',
      soha: subject,
      ishtirokchilarSoni: participants,
      deadline: endTime,
      isActive: lifecycle == 'active',
      imageUrl: imageUrl,
      placeholderColor: _colorForSubject(subject),
      placeholderIcon: _iconForSubject(subject),
      bonus: (raw['xpReward'] as num?)?.toInt() ?? 50,
      savollarSoni: questions,
      vaqtChegarasiDaq: (raw['durationMin'] as num?)?.toInt() ?? 30,
      minAge: (raw['ageFrom'] as num?)?.toInt(),
      maxAge: (raw['ageTo'] as num?)?.toInt(),
      finishedDate: lifecycle == 'finished' ? endTime : null,
    );
  }

  Color _colorForSubject(String subject) {
    switch (subject) {
      case 'Matematika':
        return AppColors.catIndigo;
      case 'Ona tili':
        return AppColors.catPink;
      case 'Ingliz':
        return AppColors.catTeal;
      case 'Fizika':
        return AppColors.catPurple;
      case 'Kimyo':
        return AppColors.warning;
      case 'IT':
        return AppColors.catEmerald;
      default:
        return AppColors.catLavenderDark;
    }
  }

  IconData _iconForSubject(String subject) {
    switch (subject) {
      case 'Matematika':
        return Icons.calculate_outlined;
      case 'Ona tili':
        return AppIcons.menu;
      case 'Ingliz':
        return Icons.language_outlined;
      case 'Fizika':
        return Icons.science_outlined;
      case 'Kimyo':
        return Icons.biotech_outlined;
      case 'IT':
        return Icons.code_outlined;
      default:
        return AppIcons.trophy;
    }
  }
}

class AnswerFeedback {
  const AnswerFeedback({
    required this.isCorrect,
    required this.correctIndex,
    required this.points,
    required this.scoreSoFar,
    required this.correctAnswers,
    required this.questionsAnswered,
    required this.questionsTotal,
    required this.isLastQuestion,
    required this.attemptFinished,
    this.timeExpired = false,
  });

  final bool isCorrect;
  final int correctIndex;
  final int points;
  final int scoreSoFar;
  final int correctAnswers;
  final int questionsAnswered;
  final int questionsTotal;
  final bool isLastQuestion;
  final bool attemptFinished;
  final bool timeExpired;

  factory AnswerFeedback.fromJson(Map<String, dynamic> j) {
    return AnswerFeedback(
      isCorrect: j['isCorrect'] == true,
      correctIndex: (j['correctIndex'] as num?)?.toInt() ?? -1,
      points: (j['points'] as num?)?.toInt() ?? 0,
      scoreSoFar: (j['scoreSoFar'] as num?)?.toInt() ?? 0,
      correctAnswers: (j['correctAnswers'] as num?)?.toInt() ?? 0,
      questionsAnswered: (j['questionsAnswered'] as num?)?.toInt() ?? 0,
      questionsTotal: (j['questionsTotal'] as num?)?.toInt() ?? 0,
      isLastQuestion: j['isLastQuestion'] == true,
      attemptFinished: j['attemptFinished'] == true,
    );
  }
}
