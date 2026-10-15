// Kunlik test sessiyasi — sof (immutable) holat mashinasi:
// javob tanlash → tekshirish (to'g'ri/xato + izoh) → keyingi savol → yakun.

import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';

/// Har to'g'ri javob uchun DON va hammasi to'g'ri bo'lsa bonus.
const kDonPerCorrect = 2;
const kPerfectBonusDon = 10;

/// Natija uchun DON mukofoti.
int donFor(int correct, int total) {
  if (total <= 0 || correct <= 0) return 0;
  return correct * kDonPerCorrect + (correct == total ? kPerfectBonusDon : 0);
}

enum QuizPhase {
  /// Javob tanlanmoqda.
  answering,

  /// Javob tekshirildi — to'g'ri javob va izoh ko'rsatiladi.
  checked,

  /// Barcha savollar tugadi.
  finished,
}

class QuizSession {
  const QuizSession._({
    required this.subject,
    required this.questions,
    required this.index,
    required this.selectedIndex,
    required this.answers,
    required this.phase,
    required this.startedAt,
  });

  /// Yangi sessiya (savollar bo'sh bo'lmasligi kerak).
  factory QuizSession.start({
    required Subject subject,
    required List<QuizQuestion> questions,
    required DateTime startedAt,
  }) {
    if (questions.isEmpty) {
      throw ArgumentError.value(questions, 'questions', 'bo\'sh');
    }
    return QuizSession._(
      subject: subject,
      questions: List.unmodifiable(questions),
      index: 0,
      selectedIndex: null,
      answers: const [],
      phase: QuizPhase.answering,
      startedAt: startedAt,
    );
  }

  final Subject subject;
  final List<QuizQuestion> questions;

  /// Joriy savol tartibi (0 dan).
  final int index;

  /// Tanlangan variant (`null` — hali tanlanmagan).
  final int? selectedIndex;
  final List<QuizAnswer> answers;
  final QuizPhase phase;
  final DateTime startedAt;

  QuizQuestion get current => questions[index];
  int get total => questions.length;
  bool get isLast => index == questions.length - 1;
  int get correctCount => answers.where((a) => a.isCorrect).length;

  /// Joriy savolga berilgan javob (tekshirilgandan keyin).
  QuizAnswer? get currentAnswer =>
      phase == QuizPhase.checked ? answers.last : null;

  QuizSession _copy({
    int? index,
    int? Function()? selectedIndex,
    List<QuizAnswer>? answers,
    QuizPhase? phase,
  }) => QuizSession._(
    subject: subject,
    questions: questions,
    index: index ?? this.index,
    selectedIndex: selectedIndex != null ? selectedIndex() : this.selectedIndex,
    answers: answers ?? this.answers,
    phase: phase ?? this.phase,
    startedAt: startedAt,
  );

  /// Variant tanlash — faqat javob berish bosqichida.
  QuizSession select(int option) {
    if (phase != QuizPhase.answering) return this;
    if (option < 0 || option >= current.options.length) return this;
    return _copy(selectedIndex: () => option);
  }

  /// Tanlangan javobni tekshirish.
  QuizSession check() {
    final selected = selectedIndex;
    if (phase != QuizPhase.answering || selected == null) return this;
    final answer = QuizAnswer(
      questionId: current.id,
      selectedIndex: selected,
      isCorrect: selected == current.answerIndex,
    );
    return _copy(
      answers: List.unmodifiable([...answers, answer]),
      phase: QuizPhase.checked,
    );
  }

  /// Keyingi savol yoki yakun.
  QuizSession next() {
    if (phase != QuizPhase.checked) return this;
    if (isLast) return _copy(phase: QuizPhase.finished);
    return _copy(
      index: index + 1,
      selectedIndex: () => null,
      phase: QuizPhase.answering,
    );
  }

  /// Eng ko'p uchragan mavzu — natija sarlavhasi uchun.
  LocalizedText get mainTopic {
    final counts = <String, int>{};
    final byId = <String, LocalizedText>{};
    for (final q in questions) {
      final key = q.topic.of(kLearningLanguages.first);
      counts[key] = (counts[key] ?? 0) + 1;
      byId.putIfAbsent(key, () => q.topic);
    }
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return byId[best.key]!;
  }

  /// Yakunlangan sessiyadan natija.
  TestResult toResult({required String id, required DateTime finishedAt}) {
    final seconds = finishedAt.difference(startedAt).inSeconds;
    return TestResult(
      id: id,
      subject: subject,
      topic: mainTopic,
      correct: correctCount,
      total: answers.length,
      date: finishedAt,
      answers: answers,
      donEarned: donFor(correctCount, answers.length),
      durationSeconds: seconds < 0 ? 0 : seconds,
    );
  }
}
