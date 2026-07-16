// ─────────────────────────────────────────────────────────────────────
// QuizState — konkurs savol-javob holati
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 5.7d: `questions: List<QuestionModel>` field qo'shildi. Real
// backend'dan kelgan questions ishlatiladi; agar bo'sh bo'lsa
// `MockQuestions.all` fallback (offline/401/eski sessiya).

import 'package:farzandim_child/features/contests/data/mock_questions.dart';
import 'package:farzandim_child/features/contests/data/models/question_model.dart';

enum QuizStatus { loading, intro, playing, paused, finished }

enum AnswerState { none, correct, wrong, timeout }

/// Mukofot uchun minimal natija — bundan past bo'lsa DON berilmaydi (30%).
///
/// MUHIM: backend'dagi `REWARD_THRESHOLD_PERCENT` bilan AYNAN bir xil
/// bo'lishi shart (`consumer-olympiads.service.ts`).
const double kRewardThreshold = 0.30;

/// Test mukofoti (DON) — to'g'ri javoblarga PROPORSIONAL.
///
/// Backend `rewardFor()` bilan AYNAN bir xil formula — ekranda ko'rsatilgan
/// son bolaning balansiga tushadigan son bilan mos bo'lishi uchun. Avval
/// ekranda `isWinner ? bonus : 0` turardi (80% dan to'liq fond), backend esa
/// boshqacha hisoblaydi → ekran yolg'on son ko'rsatardi.
///
/// `pool` — testga ajratilgan to'liq mukofot (`Olympiad.xpReward`).
/// Masalan 20 talik testga 20 DON: 8 ta topgan bola 8 DON oladi.
int rewardFor({required int pool, required int correct, required int total}) {
  if (pool <= 0 || total <= 0 || correct <= 0) return 0;
  if (correct / total < kRewardThreshold) return 0;
  return (correct * (pool / total)).round();
}

class QuizState {
  /// G'olib chegarasi — YAGONA manba (UI, provider, XP bir xil ishlatadi).
  /// Avval UI 0.7, provider/XP 0.8 edi: 70-79% bola "Tabriklaymiz" ko'rib,
  /// g'olib XP olmasdi (nomuvofiqlik).
  ///
  /// DIQQAT: bu FAQAT tabrik/konfetti uchun. DON mukofoti boshqa qoida bilan
  /// beriladi — `rewardFor()` (30% dan boshlab, proporsional).
  static const double winnerThreshold = 0.80;

  final QuizStatus status;
  final int currentIndex;
  final int? selectedAnswer;
  final AnswerState answerState;
  final int totalScore;
  final int correctCount;
  final int wrongCount;
  final int currentStreak;
  final int maxStreak;
  final int timeRemaining;
  final Duration totalElapsed;
  final List<int?> answers;

  /// Har savol natijasi (nuqtalar uchun): none=javob berilmagan,
  /// correct=to'g'ri, wrong/timeout=noto'g'ri. `answers` bilan bir o'lchamda.
  final List<AnswerState> results;

  /// Ochilgan to'g'ri javob indeksi (javob berilgach backend/mock beradi) —
  /// noto'g'ri belgilanganda TO'G'RI variantni yashil ko'rsatish uchun.
  /// null = hali ochilmagan / noma'lum (tarmoq xatosi).
  final List<int?> correctIndices;

  final List<QuestionModel> questions;

  /// Backend attempt ID (sertifikat endpoint'iga kerak — #56). Real attempt
  /// boshlanganda o'rnatiladi; mock/offline rejimda null.
  final String? attemptId;

  /// Bu test bo'yicha shaxsiy REKORD (eng ko'p to'g'ri javob) — lokal.
  /// Yakunlanganda hisoblanadi ("Natija" kartasidagi "Rekord").
  final int? recordCorrect;

  const QuizState({
    this.status = QuizStatus.loading,
    this.currentIndex = 0,
    this.selectedAnswer,
    this.answerState = AnswerState.none,
    this.totalScore = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.timeRemaining = 40,
    this.totalElapsed = Duration.zero,
    this.answers = const [],
    this.results = const [],
    this.correctIndices = const [],
    this.questions = const [],
    this.attemptId,
    this.recordCorrect,
  });

  List<QuestionModel> get effectiveQuestions =>
      questions.isEmpty ? MockQuestions.all : questions;

  QuestionModel get currentQuestion => effectiveQuestions[currentIndex];

  bool get isLastQuestion => currentIndex >= effectiveQuestions.length - 1;

  double get accuracy {
    final total = correctCount + wrongCount;
    return total > 0 ? correctCount / total : 0;
  }

  /// G'olibmi — UI va XP AYNI shu getterdan foydalanadi (yagona chegara).
  bool get isWinner => accuracy >= winnerThreshold;

  QuizState copyWith({
    QuizStatus? status,
    int? currentIndex,
    int? selectedAnswer,
    bool clearSelected = false,
    AnswerState? answerState,
    int? totalScore,
    int? correctCount,
    int? wrongCount,
    int? currentStreak,
    int? maxStreak,
    int? timeRemaining,
    Duration? totalElapsed,
    List<int?>? answers,
    List<AnswerState>? results,
    List<int?>? correctIndices,
    List<QuestionModel>? questions,
    String? attemptId,
    int? recordCorrect,
  }) {
    return QuizState(
      status: status ?? this.status,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedAnswer: clearSelected
          ? null
          : (selectedAnswer ?? this.selectedAnswer),
      answerState: answerState ?? this.answerState,
      totalScore: totalScore ?? this.totalScore,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      totalElapsed: totalElapsed ?? this.totalElapsed,
      answers: answers ?? this.answers,
      results: results ?? this.results,
      correctIndices: correctIndices ?? this.correctIndices,
      questions: questions ?? this.questions,
      attemptId: attemptId ?? this.attemptId,
      recordCorrect: recordCorrect ?? this.recordCorrect,
    );
  }
}
